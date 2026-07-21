#!/usr/bin/env bash
# verify-deeplinks.sh - check Linkrunner HTTP/HTTPS deep-link verification.
#
# Deep-link verification (App Links / Universal Links) is native to Android/iOS,
# so this script is framework-agnostic. It checks the two things that actually
# break: the hosted verification files (assetlinks.json / apple-app-site-
# association) and, if run from inside the app project, the native manifest/
# entitlement wiring.
#
# Usage:
#   verify-deeplinks.sh <domain> [android_package] [ios_team_id.bundle_id]
#
# Examples:
#   verify-deeplinks.sh app.example.com
#   verify-deeplinks.sh app.example.com com.acme.app ABCDE12345.com.acme.app
set -uo pipefail

DOMAIN="${1:-}"
ANDROID_PKG="${2:-}"
IOS_APPID="${3:-}"

if [ -z "$DOMAIN" ]; then
  echo "usage: verify-deeplinks.sh <domain> [android_package] [ios_team_id.bundle_id]" >&2
  exit 2
fi
DOMAIN="${DOMAIN#https://}"; DOMAIN="${DOMAIN#http://}"; DOMAIN="${DOMAIN%%/*}"

if [ -t 1 ]; then G=$'\033[32m'; R=$'\033[31m'; Y=$'\033[33m'; B=$'\033[1m'; N=$'\033[0m'; else G=""; R=""; Y=""; B=""; N=""; fi
fails=0
pass()  { echo "  ${G}PASS${N} $1"; }
warn()  { echo "  ${Y}WARN${N} $1"; }
fail()  { echo "  ${R}FAIL${N} $1"; fails=$((fails+1)); }
have()  { command -v "$1" >/dev/null 2>&1; }

json_ok()   { printf '%s' "$1" | python3 -c 'import sys,json; json.load(sys.stdin)' 2>/dev/null; }
json_has()  { printf '%s' "$1" | python3 -c "import sys,json; d=json.load(sys.stdin); sys.exit(0 if '$2' in json.dumps(d) else 1)" 2>/dev/null; }

echo "${B}Linkrunner deep-link verification for ${DOMAIN}${N}"

# ---- Android: hosted assetlinks.json --------------------------------------
echo
echo "${B}Android - assetlinks.json${N}"
AL_URL="https://${DOMAIN}/.well-known/assetlinks.json"
AL=$(curl -fsSL --max-time 15 "$AL_URL" 2>/dev/null)
if [ -z "$AL" ]; then
  fail "$AL_URL not reachable (404 = not saved in dashboard → Project Settings → Domain Verification)"
elif ! json_ok "$AL"; then
  fail "$AL_URL is not valid JSON"
else
  pass "hosted and valid JSON"
  json_has "$AL" "delegate_permission/common.handle_all_urls" && pass "relation present" || fail "missing handle_all_urls relation"
  json_has "$AL" "sha256_cert_fingerprints" && pass "sha256 fingerprint present" || fail "no sha256_cert_fingerprints (App Links will not verify)"
  if [ -n "$ANDROID_PKG" ]; then
    json_has "$AL" "$ANDROID_PKG" && pass "package_name matches $ANDROID_PKG" || fail "package_name does not include $ANDROID_PKG"
  else
    warn "pass android_package to check package_name"
  fi
  # Google's own validator surfaces formatting errors
  GAPI=$(curl -fsSL --max-time 15 "https://digitalassetlinks.googleapis.com/v1/statements:list?source.web.site=https://${DOMAIN}&relation=delegate_permission/common.handle_all_urls" 2>/dev/null)
  if printf '%s' "$GAPI" | grep -q '"statements"'; then pass "Google Digital Asset Links API validated the statement"
  else warn "Google Digital Asset Links API returned no statements (may be propagation delay)"; fi
fi

# ---- iOS: hosted AASA + Apple CDN -----------------------------------------
echo
echo "${B}iOS - apple-app-site-association${N}"
AASA_URL="https://${DOMAIN}/.well-known/apple-app-site-association"
AASA=$(curl -fsSL --max-time 15 "$AASA_URL" 2>/dev/null)
if [ -z "$AASA" ]; then
  fail "$AASA_URL not reachable (404 = not saved in dashboard)"
elif ! json_ok "$AASA"; then
  fail "$AASA_URL is not valid JSON (must be JSON, HTTPS, no redirects)"
else
  pass "hosted and valid JSON"
  json_has "$AASA" "applinks" && pass "applinks block present" || fail "missing applinks block"
  if [ -n "$IOS_APPID" ]; then
    json_has "$AASA" "$IOS_APPID" && pass "appID matches $IOS_APPID" || fail "appID does not include $IOS_APPID (must be TEAM_ID.BUNDLE_ID)"
  else
    warn "pass ios_team_id.bundle_id to check appID"
  fi
  CDN=$(curl -fsSL --max-time 15 "https://app-site-association.cdn-apple.com/a/v1/${DOMAIN}" 2>/dev/null)
  if [ -n "$CDN" ] && json_ok "$CDN"; then
    if [ "$CDN" = "$AASA" ]; then pass "Apple CDN copy matches your hosted file"
    else warn "Apple CDN copy differs from your file - CDN not refreshed yet (can take up to a day; use developer mode to bypass)"; fi
  else
    warn "Apple CDN has not fetched this domain yet"
  fi
fi

# ---- Local project wiring (best-effort) -----------------------------------
echo
echo "${B}Local project config${N}"
MANIFEST=$(find . -path '*/src/main/AndroidManifest.xml' 2>/dev/null | head -1)
if [ -n "$MANIFEST" ]; then
  grep -q 'android:autoVerify="true"' "$MANIFEST" && pass "autoVerify intent-filter found in $MANIFEST" || fail "no android:autoVerify=\"true\" intent-filter in $MANIFEST"
  grep -q "$DOMAIN" "$MANIFEST" && pass "$DOMAIN referenced in manifest" || warn "$DOMAIN not found in manifest <data android:host=...>"
else
  warn "AndroidManifest.xml not found (run from the app root to check native wiring)"
fi
ENT=$(find . -name '*.entitlements' 2>/dev/null | head -1)
if [ -n "$ENT" ]; then
  grep -q "applinks:${DOMAIN}" "$ENT" && pass "applinks:${DOMAIN} in $ENT" || warn "applinks:${DOMAIN} not in $ENT (add via Xcode → Associated Domains)"
else
  warn "no .entitlements file found (add Associated Domains capability in Xcode)"
fi

echo
if [ "$fails" -eq 0 ]; then echo "${G}${B}All hard checks passed.${N} Remember: test by tapping a link from another app, not by typing it in the browser."; exit 0
else echo "${R}${B}${fails} check(s) failed.${N} See https://docs.linkrunner.io/features/deep-linking-setup#debugging-domain-verification"; exit 1; fi
