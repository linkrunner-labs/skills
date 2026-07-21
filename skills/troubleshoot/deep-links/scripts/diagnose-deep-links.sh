#!/usr/bin/env bash
# diagnose-deep-links.sh - full Linkrunner deep-link verification diagnostic.
#
# Extends the per-SDK verify-deeplinks.sh with live Android verification-state
# checks (via adb, when a device is connected). Deep-link verification is native
# to Android/iOS, so this is framework-agnostic.
#
# Usage:
#   diagnose-deep-links.sh <domain> [android_package] [ios_team_id.bundle_id]
set -uo pipefail

DOMAIN="${1:-}"; ANDROID_PKG="${2:-}"; IOS_APPID="${3:-}"
if [ -z "$DOMAIN" ]; then
  echo "usage: diagnose-deep-links.sh <domain> [android_package] [ios_team_id.bundle_id]" >&2
  exit 2
fi
DOMAIN="${DOMAIN#https://}"; DOMAIN="${DOMAIN#http://}"; DOMAIN="${DOMAIN%%/*}"

if [ -t 1 ]; then G=$'\033[32m'; R=$'\033[31m'; Y=$'\033[33m'; B=$'\033[1m'; N=$'\033[0m'; else G=""; R=""; Y=""; B=""; N=""; fi
fails=0
pass(){ echo "  ${G}PASS${N} $1"; }
warn(){ echo "  ${Y}WARN${N} $1"; }
fail(){ echo "  ${R}FAIL${N} $1"; fails=$((fails+1)); }
have(){ command -v "$1" >/dev/null 2>&1; }
json_ok(){ printf '%s' "$1" | python3 -c 'import sys,json; json.load(sys.stdin)' 2>/dev/null; }
json_has(){ printf '%s' "$1" | python3 -c "import sys,json; d=json.load(sys.stdin); sys.exit(0 if '$2' in json.dumps(d) else 1)" 2>/dev/null; }

echo "${B}Linkrunner deep-link diagnostic for ${DOMAIN}${N}"

# ---- Android hosted assetlinks.json ---------------------------------------
echo; echo "${B}Android - hosted assetlinks.json${N}"
AL=$(curl -fsSL --max-time 15 "https://${DOMAIN}/.well-known/assetlinks.json" 2>/dev/null)
if [ -z "$AL" ]; then fail "https://${DOMAIN}/.well-known/assetlinks.json not reachable (404 = not saved in dashboard → Project Settings → Domain Verification)"
elif ! json_ok "$AL"; then fail "assetlinks.json is not valid JSON"
else
  pass "hosted and valid JSON"
  json_has "$AL" "sha256_cert_fingerprints" && pass "sha256 fingerprint present" || fail "no sha256_cert_fingerprints (App Links cannot verify)"
  if [ -n "$ANDROID_PKG" ]; then json_has "$AL" "$ANDROID_PKG" && pass "package_name matches $ANDROID_PKG" || fail "package_name does not include $ANDROID_PKG"; else warn "pass android_package to check package_name"; fi
  GAPI=$(curl -fsSL --max-time 15 "https://digitalassetlinks.googleapis.com/v1/statements:list?source.web.site=https://${DOMAIN}&relation=delegate_permission/common.handle_all_urls" 2>/dev/null)
  printf '%s' "$GAPI" | grep -q '"statements"' && pass "Google Digital Asset Links API validated the statement" || warn "Google Asset Links API returned no statements (formatting error or propagation delay)"
fi

# ---- Android live verification state (adb) ---------------------------------
echo; echo "${B}Android - live device state (adb)${N}"
if ! have adb; then warn "adb not installed - skipping live verification-state check"
elif [ -z "$(adb devices 2>/dev/null | sed -n '2p')" ]; then warn "no device/emulator connected - skipping live check"
elif [ -z "$ANDROID_PKG" ]; then warn "pass android_package to check live verification state"
else
  STATE=$(adb shell pm get-app-links "$ANDROID_PKG" 2>/dev/null)
  if [ -z "$STATE" ]; then warn "pm get-app-links returned nothing (Android 12+ only; on 11- use: adb shell dumpsys package domain-preferred-apps)"
  else
    LINE=$(printf '%s\n' "$STATE" | grep -iE "${DOMAIN}:" | head -1 | xargs)
    echo "  device reports: ${LINE:-<domain not listed in manifest>}"
    if printf '%s' "$LINE" | grep -qi 'verified'; then pass "$DOMAIN is verified on this device"
    elif printf '%s' "$LINE" | grep -qiE '1024|legacy_failure'; then fail "$DOMAIN verification FAILED - fingerprint or hosted-file problem. Fix assetlinks, then re-verify (see references/android.md)"
    elif printf '%s' "$LINE" | grep -qi 'none'; then warn "$DOMAIN not verified yet (runs ~20s after install). Re-verify: adb shell pm verify-app-links --re-verify $ANDROID_PKG"
    else warn "could not classify state - see references/android.md for the state table"
    fi
  fi
fi

# ---- iOS hosted AASA + Apple CDN ------------------------------------------
echo; echo "${B}iOS - apple-app-site-association${N}"
AASA=$(curl -fsSL --max-time 15 "https://${DOMAIN}/.well-known/apple-app-site-association" 2>/dev/null)
if [ -z "$AASA" ]; then fail "https://${DOMAIN}/.well-known/apple-app-site-association not reachable (404 = not saved in dashboard)"
elif ! json_ok "$AASA"; then fail "AASA is not valid JSON (must be JSON, HTTPS, no redirects)"
else
  pass "hosted and valid JSON"
  json_has "$AASA" "applinks" && pass "applinks block present" || fail "missing applinks block"
  if [ -n "$IOS_APPID" ]; then json_has "$AASA" "$IOS_APPID" && pass "appID matches $IOS_APPID" || fail "appID does not include $IOS_APPID (must be TEAM_ID.BUNDLE_ID)"; else warn "pass ios_team_id.bundle_id to check appID"; fi
  CDN=$(curl -fsSL --max-time 15 "https://app-site-association.cdn-apple.com/a/v1/${DOMAIN}" 2>/dev/null)
  if [ -n "$CDN" ] && json_ok "$CDN"; then
    [ "$CDN" = "$AASA" ] && pass "Apple CDN copy matches your hosted file" || warn "Apple CDN copy is STALE vs your file - it has not refreshed yet (up to a day). Use developer mode to bypass while testing (see references/ios.md)"
  else warn "Apple CDN has not fetched this domain yet (up to a day). Use developer mode to bypass while testing"; fi
fi

# ---- Local project wiring --------------------------------------------------
echo; echo "${B}Local project config${N}"
MANIFEST=$(find . -path '*/src/main/AndroidManifest.xml' 2>/dev/null | head -1)
if [ -n "$MANIFEST" ]; then
  grep -q 'android:autoVerify="true"' "$MANIFEST" && pass "autoVerify intent-filter in $MANIFEST" || fail "no android:autoVerify=\"true\" intent-filter in $MANIFEST"
  grep -q "$DOMAIN" "$MANIFEST" && pass "$DOMAIN referenced in manifest" || warn "$DOMAIN not in manifest <data android:host=...>"
else warn "AndroidManifest.xml not found (run from app root to check native wiring)"; fi
ENT=$(find . -name '*.entitlements' 2>/dev/null | head -1)
if [ -n "$ENT" ]; then grep -q "applinks:${DOMAIN}" "$ENT" && pass "applinks:${DOMAIN} in $ENT" || warn "applinks:${DOMAIN} not in $ENT (add via Xcode → Associated Domains)"; else warn "no .entitlements found (add Associated Domains capability in Xcode)"; fi

echo
if [ "$fails" -eq 0 ]; then echo "${G}${B}All hard checks passed.${N} Test by TAPPING a link from another app (Notes), not typing it in the browser."; exit 0
else echo "${R}${B}${fails} check(s) failed.${N} Fix per references/android.md and references/ios.md, then re-run."; exit 1; fi
