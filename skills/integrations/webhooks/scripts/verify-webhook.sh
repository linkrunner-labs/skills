#!/usr/bin/env bash
# Verify a Linkrunner webhook receiver: POST a documented-shaped sample
# install and signup payload and assert the endpoint responds 2xx.
#
# Usage:
#   bash verify-webhook.sh <url> <linkrunner-key>
#
# Example:
#   bash verify-webhook.sh https://api.example.com/webhooks/linkrunner my-private-key

set -euo pipefail

URL="${1:-}"
KEY="${2:-}"

if [[ -z "$URL" || -z "$KEY" ]]; then
  echo "usage: $0 <url> <linkrunner-key>" >&2
  exit 1
fi

INSTALL_PAYLOAD='{
  "event_type": "install",
  "campaign_id": "camp_XYZ123",
  "ad_channel": "META",
  "network_name": "META",
  "app_version": "2.4.1",
  "campaign_name": "Summer Promotion 2023",
  "attributed_on": "2026-03-24T08:11:00.464Z",
  "installed_at": "2026-03-24T08:11:00.464Z",
  "store_click_at": "2026-03-24T08:11:00.464Z",
  "link": "https://dl.linkrunner.io/?c=camp_XYZ123",
  "meta_campaign_details": {
    "ad_creative_id": "cr_987654321",
    "ad_creative_name": "Summer Sale Creative",
    "ad_set_id": "as_12345",
    "ad_set_name": "Mobile Users Segment",
    "campaign_group_id": null,
    "campaign_group_name": null,
    "account_id": "acc_1122334455",
    "ad_objective_name": "APP_INSTALLS",
    "is_instagram": null,
    "publisher_platform": "facebook",
    "platform_position": "feed"
  },
  "google_campaign_details": null,
  "apple_search_ads_details": null,
  "campaign_details": null,
  "gaid": "bk9384xs-p449-96ds-r132",
  "idfa": null
}'

SIGNUP_PAYLOAD='{
  "event_type": "signup",
  "user_id": "test_user_webhook_002",
  "campaign_id": "OgWmhiSXhG",
  "ad_channel": "META",
  "network_name": "META",
  "app_version": "1.0.0",
  "campaign_name": "TOF - Free trial - AAA - DSDT - 17/12",
  "attributed_on": "2026-03-25T15:52:00.007Z",
  "installed_at": "2025-12-30T12:34:29.742Z",
  "store_click_at": null,
  "link": "https://dl.linkrunner.io/?c=OgWmhiSXhG&utm_source=meta_ads",
  "meta_campaign_details": null,
  "google_campaign_details": null,
  "apple_search_ads_details": null,
  "campaign_details": null,
  "gaid": "5faa2433-d7e1-4a8e-9a1c-a5880c26ab5c",
  "idfa": null,
  "name": "Test User",
  "phone": "9876543210",
  "email": "test@example.com",
  "additional_data": {
    "id": "test_user_webhook_002",
    "name": "Test User",
    "email": "test@example.com",
    "phone": "9876543210",
    "device_data": {},
    "referral_code": "ABC123",
    "custom_param_name": "custom_value"
  }
}'

send() {
  local label="$1"
  local payload="$2"

  local status
  status=$(curl -s -o /tmp/verify-webhook-response.$$ -w '%{http_code}' \
    -X POST "$URL" \
    -H 'Content-Type: application/json' \
    -H "linkrunner-key: $KEY" \
    -d "$payload")

  local body
  body=$(cat /tmp/verify-webhook-response.$$ 2>/dev/null || true)
  rm -f /tmp/verify-webhook-response.$$

  if [[ "$status" -ge 200 && "$status" -lt 300 ]]; then
    echo "PASS  $label -> HTTP $status"
  else
    echo "FAIL  $label -> HTTP $status"
    [[ -n "$body" ]] && echo "      response: $body"
    return 1
  fi
}

failed=0
send "install event" "$INSTALL_PAYLOAD" || failed=1
send "signup event"  "$SIGNUP_PAYLOAD"  || failed=1

if [[ "$failed" -ne 0 ]]; then
  echo "One or more checks failed - see output above." >&2
  exit 1
fi

echo "All checks passed."
