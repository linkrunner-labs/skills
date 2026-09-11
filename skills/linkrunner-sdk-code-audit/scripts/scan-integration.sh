#!/usr/bin/env bash
# scan-integration.sh - first-pass inventory of a Linkrunner SDK integration in a source repo.
#
# Prints: detected stack(s), the SDK dependency + version, every candidate SDK call site
# with file:line, config-file findings, and a list of hygiene smells worth checking by hand.
#
# This is a MAP, not a verdict. Every line it prints must be opened and read before it
# becomes a finding - see references/call-site-analysis.md.
#
#   usage: bash scripts/scan-integration.sh [app-root]
set -uo pipefail

ROOT="${1:-.}"
cd "$ROOT" 2>/dev/null || { echo "no such directory: $ROOT" >&2; exit 1; }
ROOT="$(pwd)"

# Vendored / generated trees never contain the app's own call sites. Excluding them is the
# single most important thing this script does - an unfiltered grep in an RN repo returns
# thousands of hits from node_modules and every one of them is noise.
EXC=(--exclude-dir=node_modules --exclude-dir=Pods --exclude-dir=.git --exclude-dir=build
     --exclude-dir=Build --exclude-dir=DerivedData --exclude-dir=dist --exclude-dir=.dart_tool
     --exclude-dir=.gradle --exclude-dir=vendor --exclude-dir=Carthage --exclude-dir=.next
     --exclude-dir=coverage --exclude-dir=Library --exclude-dir=Temp --exclude-dir=obj
     --exclude-dir=.expo --exclude-dir=.yarn --exclude-dir=Frameworks --exclude-dir=out
     --exclude-dir=.linkrunner --exclude-dir=.claude --exclude-dir=.cursor --exclude-dir=.windsurf)
# Source extensions only: keeps docs/READMEs/lockfiles out of the call-site list.
INC=(--include="*.ts" --include="*.tsx" --include="*.js" --include="*.jsx" --include="*.mjs"
     --include="*.cjs" --include="*.dart" --include="*.kt" --include="*.java" --include="*.swift"
     --include="*.m" --include="*.mm" --include="*.cs" --include="*.vue" --include="*.svelte"
     --include="*.html")

hdr() { printf '\n\033[1m== %s\033[0m\n' "$1"; }
sub() { printf '\n-- %s\n' "$1"; }
say() { printf '   %s\n' "$1"; }

echo "Linkrunner integration scan - $ROOT"
echo "$(date '+%Y-%m-%d %H:%M')"

# ---------------------------------------------------------------- 1. stack detection
hdr "1. Tech stack"
STACKS=""
mark() { STACKS="$STACKS $1"; say "$1  ($2)"; }
[ -f package.json ] && grep -q '"react-native"' package.json 2>/dev/null && mark "react-native" "package.json"
[ -f package.json ] && grep -qE '"expo"' package.json 2>/dev/null && mark "expo" "package.json"
[ -f pubspec.yaml ] && mark "flutter" "pubspec.yaml"
[ -f capacitor.config.ts ] || [ -f capacitor.config.json ] || [ -f capacitor.config.js ] && mark "capacitor" "capacitor.config.*"
[ -f config.xml ] && grep -qi cordova config.xml 2>/dev/null && mark "cordova" "config.xml"
[ -d ProjectSettings ] && [ -d Assets ] && mark "unity" "ProjectSettings/ + Assets/"
[ -f package.json ] && grep -qE '"next"|"nuxt"|"@angular/core"|"vue"' package.json 2>/dev/null && mark "web" "package.json"
# Native projects - only call it native if no cross-platform wrapper claimed it first.
NATIVE_ANDROID=$(find . -name "AndroidManifest.xml" -not -path "*/node_modules/*" -not -path "*/build/*" 2>/dev/null | head -3)
NATIVE_IOS=$(find . -name "*.xcodeproj" -o -name "Package.swift" 2>/dev/null | grep -v node_modules | head -3)
if [ -z "$STACKS" ]; then
  [ -n "$NATIVE_ANDROID" ] && mark "android-native" "AndroidManifest.xml"
  [ -n "$NATIVE_IOS" ] && mark "ios-native" "xcodeproj / Package.swift"
fi
[ -z "$STACKS" ] && say "UNKNOWN - inspect manually (references/detect-stack.md)"

# ---------------------------------------------------------------- 2. SDK dependency
hdr "2. Linkrunner SDK dependency & version"
FOUND_DEP=0
for f in package.json; do
  [ -f "$f" ] || continue
  grep -nE '"(rn-linkrunner|expo-linkrunner|capacitor-linkrunner|@linkrunner/[a-z-]+|cordova-linkrunner)"' "$f" \
    | sed 's/^/   package.json:/'
  grep -qE 'linkrunner' "$f" && FOUND_DEP=1
done
if [ -f pubspec.yaml ]; then
  grep -nE '^\s*linkrunner\s*:' pubspec.yaml | sed 's/^/   pubspec.yaml:/'
  grep -qE '^\s*linkrunner\s*:' pubspec.yaml && FOUND_DEP=1
  [ -f pubspec.lock ] && grep -A2 -n '^  linkrunner:' pubspec.lock | grep -E 'version' | sed 's/^/   pubspec.lock:/'
fi
GRADLE_HITS=$(grep -rn "io.linkrunner" --include="*.gradle" --include="*.gradle.kts" --include="*.toml" "${EXC[@]}" . 2>/dev/null | head -5)
[ -n "$GRADLE_HITS" ] && { FOUND_DEP=1; echo "$GRADLE_HITS" | sed 's|^\./|   |'; }
# Match the dependency, not the app's own target name (apps are often called "…Linkrunner…").
POD_HITS=$(grep -rn -E "(pod\s+['\"][^'\"]*[Ll]inkrunner|LinkrunnerKit|linkrunner-ios|linkrunner-labs)" --include="Podfile" --include="Podfile.lock" --include="*.podspec" --include="Package.swift" --include="Package.resolved" "${EXC[@]}" . 2>/dev/null | head -8)
[ -n "$POD_HITS" ] && { FOUND_DEP=1; echo "$POD_HITS" | sed 's|^\./|   |'; }
CDN_HITS=$(grep -rn "cdn.linkrunner.io" "${EXC[@]}" "${INC[@]}" . 2>/dev/null | head -5)
[ -n "$CDN_HITS" ] && { FOUND_DEP=1; sub "web SDK script tag"; echo "$CDN_HITS" | sed 's|^\./|   |'; }
[ "$FOUND_DEP" = 0 ] && say "NO Linkrunner dependency found - confirm before reporting 'not integrated' (monorepo? submodule? vendored?)"

# ---------------------------------------------------------------- 3. call sites
hdr "3. Candidate SDK call sites (open each one - a grep hit is not a call site)"
# Anchor on a receiver so we don't match every init()/signup() in the app.
RECV='linkrunner|LinkRunner|LinkrunnerSDK|Linkrunner|LinkrunnerKit|lr'
for m in init initialize initializeSDK Initialize signup Signup setUserData SetUserData \
         trackEvent TrackEvent capturePayment CapturePayment removePayment RemovePayment \
         setAdditionalData SetAdditionalData setPushToken SetPushToken \
         setCustomerUserId SetCustomerUserId getAttributionData GetAttributionData \
         handleDeeplink HandleDeeplink setConsent SetConsent; do
  HITS=$(grep -rnE "(${RECV})[a-zA-Z]*(\(\))?[.:]{1,2}[a-zA-Z]*\.?${m}\s*[(<]" "${EXC[@]}" "${INC[@]}" . 2>/dev/null \
         | grep -vE '^\s*(//|#|\*|/\*)' | head -20)
  [ -n "$HITS" ] && { sub "$m"; echo "$HITS" | sed 's|^\./|   |'; }
done

sub "any file that imports the SDK (these hold the direct call sites)"
grep -rnE "(from|require|import)\s*\(?['\"](rn-linkrunner|expo-linkrunner|capacitor-linkrunner|@linkrunner/[a-z-]+)['\"]|import\s+['\"]package:linkrunner/|import\s+io\.linkrunner|import\s+LinkrunnerKit|using\s+Linkrunner" \
  "${EXC[@]}" "${INC[@]}" . 2>/dev/null | sed 's|^\./|   |' | head -20

sub "custom event names passed to trackEvent (the coded event inventory)"
grep -rhoE "trackEvent\s*\(\s*[\"'\`][^\"'\`]{1,60}[\"'\`]" "${EXC[@]}" "${INC[@]}" . 2>/dev/null \
  | sed -E "s/trackEvent\s*\(\s*[\"'\`]//; s/[\"'\`]$//" | sort | uniq -c | sort -rn | head -40
DYN=$(grep -rnE "trackEvent\s*\(\s*[\`\$]|trackEvent\s*\(\s*[a-zA-Z_][a-zA-Z0-9_.]*\s*[,)]" "${EXC[@]}" "${INC[@]}" . 2>/dev/null | head -10)
[ -n "$DYN" ] && { sub "DYNAMIC / variable event names (unqueryable in the dashboard - check these)"; echo "$DYN" | sed 's|^\./|   |'; }

# ---------------------------------------------------------------- 4. hygiene smells
hdr "4. Hygiene smells (verify each by reading the file - many are false positives)"
smell() { local label="$1"; shift; local out; out=$("$@" 2>/dev/null | head -12); [ -n "$out" ] && { sub "$label"; echo "$out" | sed 's|^\./|   |'; }; }

smell "debug flag set true (must be false / env-driven in a release build)" \
  grep -rnE "debug\s*[:=]\s*true|debug:\s*kDebugMode|isDebug\s*[:=]\s*true" "${EXC[@]}" "${INC[@]}" .
smell "project token literal in source (check it is the PROD token and not committed by mistake)" \
  grep -rnE "(token|TOKEN)\s*[:=]\s*[\"'][A-Za-z0-9_-]{12,}[\"']" "${EXC[@]}" "${INC[@]}" .
smell "SDK secretKey / keyId literal in source (should come from a secret store, never a public repo)" \
  grep -rnE "(secretKey|secret_key|keyId|key_id)\s*[:=]\s*[\"'][^\"']{6,}[\"']" "${EXC[@]}" "${INC[@]}" .
smell "paymentId built from a timestamp/random value - breaks server-side payment dedup" \
  grep -rnE "paymentId\s*[:=].*(Date\.now|uuid|random|Random|DateTime\.now|timeIntervalSince)" "${EXC[@]}" "${INC[@]}" .
smell "amount passed as a string - ad-network revenue sharing needs a number" \
  grep -rnE "amount\s*[:=]\s*[\"']|amount\s*[:=]\s*(String|\.toString)" "${EXC[@]}" "${INC[@]}" .
smell "fire-and-forget SDK calls with no await/then (ordering + silent failure)" \
  grep -rnE "^\s*(linkrunner|LinkRunner\(\)|LinkrunnerSDK\.shared)\.[a-zA-Z]+\(" "${EXC[@]}" "${INC[@]}" .

# A guard *near* a call site is the highest-value smell: an SDK call that only runs in debug,
# on one platform, or behind a flag is invisible on the wire in prod. Print the call site only
# when a real condition appears in the 3 lines above it.
GUARDED=$(grep -rn -B3 -E "(linkrunner|LinkRunner|LinkrunnerSDK|Linkrunner)[a-zA-Z]*(\(\))?[.:]{1,2}[a-zA-Z]*\.?(init|initialize|Initialize|signup|trackEvent|capturePayment|getAttributionData)\s*[(<]" \
  "${EXC[@]}" "${INC[@]}" . 2>/dev/null \
  | grep -E "if\s*[({]|__DEV__|kDebugMode|kReleaseMode|BuildConfig\.DEBUG|#if\s+DEBUG|Platform\.(OS|isAndroid|isIOS)|isProduction|NODE_ENV|featureFlag|remoteConfig|enabled\s*[)&]" \
  | head -12)
[ -n "$GUARDED" ] && { sub "SDK call sites with a guard nearby (dev-only / one-platform / flagged - does it run in prod?)"; echo "$GUARDED" | sed 's|^\./|   |'; }

# ---------------------------------------------------------------- 5. platform config
hdr "5. Platform configuration"
MANIFESTS=$(find . -name "AndroidManifest.xml" -not -path "*/node_modules/*" -not -path "*/build/*" -not -path "*/Pods/*" 2>/dev/null | head -5)
if [ -n "$MANIFESTS" ]; then
  for M in $MANIFESTS; do
    sub "AndroidManifest: $M"
    # Build-variant overlays (src/debug, src/release, …) are MERGED into the main manifest, so a
    # permission "missing" from an overlay is normal. Only judge src/main.
    case "$M" in
      */src/main/*) : ;;
      *) say "(build-variant overlay - merged into src/main; 'MISSING' below is expected here)" ;;
    esac
    grep -qE 'android.permission.INTERNET' "$M" && say "INTERNET ......................... present" || say "INTERNET ......................... MISSING"
    grep -qE 'ACCESS_NETWORK_STATE' "$M" && say "ACCESS_NETWORK_STATE ............. present" || say "ACCESS_NETWORK_STATE ............. MISSING"
    grep -qE 'fullBackupContent' "$M" && say "android:fullBackupContent ........ present" || say "android:fullBackupContent ........ absent (install-id survives backup/restore)"
    grep -qE 'dataExtractionRules' "$M" && say "android:dataExtractionRules ...... present" || say "android:dataExtractionRules ...... absent (Android 12+ backup)"
    grep -qE 'asset_statements' "$M" && say "asset_statements meta-data ....... present" || say "asset_statements meta-data ....... absent (no 'Continue to app' popup)"
    grep -qE 'permission.AD_ID' "$M" && say "AD_ID .... $(grep -E 'permission.AD_ID' "$M" | grep -q 'tools:node="remove"' && echo 'REVOKED (tools:node=remove)' || echo 'declared')"
    AV=$(grep -c 'autoVerify="true"' "$M" 2>/dev/null); say "App Links intent-filters (autoVerify=true): ${AV:-0}"
    grep -nE '<data android:scheme=' "$M" | sed 's/^/      /' | head -10
  done
else
  say "no AndroidManifest.xml found"
fi

PLISTS=$(find . -name "Info.plist" -not -path "*/node_modules/*" -not -path "*/Pods/*" -not -path "*/build/*" 2>/dev/null | head -4)
if [ -n "$PLISTS" ]; then
  for P in $PLISTS; do
    sub "Info.plist: $P"
    grep -q 'NSUserTrackingUsageDescription' "$P" && say "NSUserTrackingUsageDescription ... present" || say "NSUserTrackingUsageDescription ... absent (no ATT prompt possible → no IDFA)"
    grep -q 'NSAdvertisingAttributionReportEndpoint' "$P" && say "SKAdNetwork report endpoint ...... present" || say "SKAdNetwork report endpoint ...... absent (no SKAN postback copies)"
    grep -q 'CFBundleURLSchemes' "$P" && say "CFBundleURLSchemes ............... present" || say "CFBundleURLSchemes ............... absent (no custom URI scheme)"
  done
fi
ENTS=$(find . -name "*.entitlements" -not -path "*/node_modules/*" -not -path "*/Pods/*" 2>/dev/null | head -4)
for E in $ENTS; do
  sub "entitlements: $E"
  grep -q 'associated-domains' "$E" && { say "associated-domains ............... present"; grep -oE 'applinks:[^<]*' "$E" | sed 's/^/      /'; } || say "associated-domains ............... absent (Universal Links cannot work)"
done
[ -z "$ENTS" ] && [ -n "$PLISTS" ] && say "no .entitlements file found - Universal Links need the Associated Domains capability"

sub "expo config plugin"
for f in app.json app.config.js app.config.ts; do
  [ -f "$f" ] && grep -nE "linkrunner|scheme|associatedDomains|intentFilters" "$f" | sed "s|^|   $f:|" | head -10
done

# ---------------------------------------------------------------- 6. summary
hdr "6. Coverage summary (direct SDK calls only - indirect wrapper calls not counted)"
count_direct() {
  grep -rnE "(linkrunner|LinkRunner\(\)|LinkRunner\.getInstance\(\)|LinkrunnerSDK\.shared|LinkrunnerSDK)\.$1\s*[(<]" \
    "${EXC[@]}" "${INC[@]}" . 2>/dev/null | grep -vE '^\s*(//|#|\*)' | wc -l | tr -d ' '
}
for pair in "init:initialize|init|initializeSDK|Initialize" "signup:signup|Signup" \
            "setCustomerUserId:setCustomerUserId|SetCustomerUserId" "setUserData:setUserData|SetUserData" \
            "trackEvent:trackEvent|TrackEvent" "capturePayment:capturePayment|CapturePayment" \
            "removePayment:removePayment|RemovePayment" "setAdditionalData:setAdditionalData|SetAdditionalData" \
            "setPushToken:setPushToken|SetPushToken" "getAttributionData:getAttributionData|GetAttributionData" \
            "handleDeeplink:handleDeeplink|HandleDeeplink" "setConsent:setConsent|SetConsent"; do
  label="${pair%%:*}"; pat="${pair#*:}"
  n=$(count_direct "($pat)")
  case "$label" in
    init)   note=$([ "$n" = 0 ] && echo "NOT CALLED - nothing works without it" || { [ "$n" -gt 1 ] && echo "more than one init site - check for double init" || echo ""; }) ;;
    getAttributionData) note=$([ "$n" = 0 ] && echo "NOT CALLED - deferred deep linking is dead" || echo "verify the returned deeplink is actually routed") ;;
    signup) note=$([ "$n" = 0 ] && echo "NOT CALLED - installs never tie to a user" || echo "") ;;
    handleDeeplink) note=$([ "$n" = 0 ] && echo "NOT CALLED - no re-engagement / reattribution" || echo "need BOTH cold-start and warm-start paths") ;;
    *) note="" ;;
  esac
  printf '   %-20s %2s  %s\n' "$label" "$n" "$note"
done
say ""
say "A 0 here is a LEAD, not a finding: the call may be behind a wrapper, in another package"
say "of a monorepo, or named differently. Confirm by reading the code before reporting it."

hdr "Next"
say "This is a map. Open every call site above and judge it in context:"
say "  references/call-site-analysis.md  - is it reachable, correctly placed, correctly guarded?"
say "  references/api-surface.md         - is the cadence right for that method?"
say "  references/platform-config.md     - what each config finding above actually breaks"
