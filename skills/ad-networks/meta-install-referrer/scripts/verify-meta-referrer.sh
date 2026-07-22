#!/usr/bin/env bash
# verify-meta-referrer.sh - check Meta Install Referrer wiring in an Android project.
#
# Confirms the Facebook App ID is exposed to the Linkrunner SDK via one of the two
# supported meta-data tags, and that the referenced strings.xml value is a real
# numeric App ID (not the placeholder).
#
# Usage: run from the app/project root.  verify-meta-referrer.sh [android_dir]
set -uo pipefail

ROOT="${1:-.}"
if [ -t 1 ]; then G=$'\033[32m'; R=$'\033[31m'; Y=$'\033[33m'; B=$'\033[1m'; N=$'\033[0m'; else G=""; R=""; Y=""; B=""; N=""; fi
fails=0
pass(){ echo "  ${G}PASS${N} $1"; }
warn(){ echo "  ${Y}WARN${N} $1"; }
fail(){ echo "  ${R}FAIL${N} $1"; fails=$((fails+1)); }

echo "${B}Meta Install Referrer - Android config check${N}"

MANIFEST=$(find "$ROOT" -path '*/src/main/AndroidManifest.xml' 2>/dev/null | head -1)
if [ -z "$MANIFEST" ]; then
  fail "no AndroidManifest.xml found under $ROOT (run from the app/project root; Android only)"
  echo; echo "${R}${B}Cannot verify.${N} See https://docs.linkrunner.io/features/meta-install-referrer"; exit 1
fi
echo "  manifest: $MANIFEST"

FB_SDK=$(grep -o 'com.facebook.sdk.ApplicationId' "$MANIFEST" | head -1)
LR_META=$(grep -o 'com.linkrunner.FacebookApplicationId' "$MANIFEST" | head -1)

if [ -z "$FB_SDK" ] && [ -z "$LR_META" ]; then
  fail "neither com.facebook.sdk.ApplicationId nor com.linkrunner.FacebookApplicationId meta-data is in the manifest"
  echo "       add one of them inside <application> (see references/setup.md)"
  echo; echo "${R}${B}Not configured.${N}"; exit 1
fi
[ -n "$FB_SDK" ] && pass "Facebook SDK meta-data (com.facebook.sdk.ApplicationId) present"
[ -n "$LR_META" ] && pass "Linkrunner meta-data (com.linkrunner.FacebookApplicationId) present"

# Which @string does the active meta-data point at?
STRINGREF=$(grep -A2 -E 'com\.(facebook\.sdk\.ApplicationId|linkrunner\.FacebookApplicationId)' "$MANIFEST" \
  | grep -oE '@string/[A-Za-z0-9_]+' | head -1 | sed 's#@string/##')
if [ -z "$STRINGREF" ]; then
  warn "meta-data android:value is not an @string reference - cannot validate the App ID value"
  echo; [ "$fails" -eq 0 ] && exit 0 || exit 1
fi
echo "  App ID string: @string/$STRINGREF"

STRINGS=$(grep -rl "name=\"$STRINGREF\"" "$ROOT" --include=strings.xml 2>/dev/null | head -1)
if [ -z "$STRINGS" ]; then
  fail "@string/$STRINGREF is referenced but not defined in any strings.xml"
else
  LINE=$(grep -E "name=\"$STRINGREF\"" "$STRINGS" | head -1)
  VAL=$(printf '%s' "$LINE" | sed -E 's/.*<string[^>]*>[[:space:]]*([^<[:space:]]*)[[:space:]]*<\/string>.*/\1/')
  if printf '%s' "$LINE" | grep -qi 'YOUR_FACEBOOK_APP_ID'; then
    fail "$STRINGREF is still the placeholder - set your real Facebook App ID in $STRINGS"
  elif printf '%s' "$VAL" | grep -qE '^[0-9]{10,20}$'; then
    pass "$STRINGREF = $VAL (looks like a valid numeric Facebook App ID) in $STRINGS"
  elif [ -z "$VAL" ] || [ "$VAL" = "$LINE" ]; then
    fail "$STRINGREF is defined but empty/unreadable in $STRINGS - set your Facebook App ID"
  else
    warn "$STRINGREF = '$VAL' - Facebook App IDs are numeric; double-check this value"
  fi
fi

echo
if [ "$fails" -eq 0 ]; then
  echo "${G}${B}Meta Install Referrer is wired up.${N} The lift only shows for users with Facebook 428.x+ / Instagram 296.x+ installed."
  exit 0
else
  echo "${R}${B}${fails} check(s) failed.${N} See https://docs.linkrunner.io/features/meta-install-referrer"
  exit 1
fi
