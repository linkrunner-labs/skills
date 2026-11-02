#!/usr/bin/env bash
# Lists every deprecated Linkrunner payment call in a project, so each one can be migrated to trackEvent.
# Usage: bash find-payment-calls.sh [project_root]
set -euo pipefail

root="${1:-.}"
if [ ! -d "$root" ]; then
  echo "Not a directory: $root" >&2
  exit 2
fi

pattern='capturePayment|removePayment|CapturePayment|RemovePayment|CapturePaymentRequest|RemovePaymentRequest|LRCapturePayment|LRRemovePayment|PaymentType|capture-payment|remove-captured-payment'

excludes=(
  --exclude-dir=node_modules --exclude-dir=.git --exclude-dir=build --exclude-dir=dist
  --exclude-dir=Pods --exclude-dir=.dart_tool --exclude-dir=.gradle --exclude-dir=DerivedData
  --exclude-dir=Library --exclude-dir=Temp --exclude-dir=.expo
  --exclude-dir=platforms --exclude-dir=plugins --exclude-dir=.next --exclude-dir=coverage
)
includes=(
  --include='*.kt' --include='*.kts' --include='*.java' --include='*.swift' --include='*.m'
  --include='*.dart' --include='*.ts' --include='*.tsx' --include='*.js' --include='*.jsx'
  --include='*.mjs' --include='*.cjs' --include='*.cs' --include='*.py' --include='*.go'
  --include='*.rb' --include='*.php' --include='*.vue' --include='*.svelte'
)

hits="$(grep -rnE "$pattern" "${excludes[@]}" "${includes[@]}" "$root" 2>/dev/null || true)"

if [ -z "$hits" ]; then
  echo "No deprecated Linkrunner payment calls found under $root."
  exit 0
fi

count_of() { printf '%s\n' "$hits" | grep -cE "$1" || true; }

echo "Deprecated Linkrunner payment usage under $root"
echo
echo "capturePayment calls:        $(count_of 'capturePayment\(|CapturePayment\(')"
echo "removePayment calls:         $(count_of 'removePayment\(|RemovePayment\(')"
echo "PaymentType uses:            $(count_of 'PaymentType')"
echo "Server capture-payment URLs: $(count_of 'capture-payment|remove-captured-payment')"
echo
printf '%s\n' "$hits"
