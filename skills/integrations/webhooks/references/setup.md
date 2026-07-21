# Webhooks - dashboard config, events, headers, payload

Source of truth: https://docs.linkrunner.io/features/webhooks

## 1. Configure the webhook URL

1. Go to [Linkrunner Settings -> Webhooks](https://dashboard.linkrunner.io/settings?s=webhooks).
2. Enter your webhook endpoint URL.
3. Save the configuration.

Your endpoint must be publicly accessible and respond with a 2xx status code
to acknowledge receipt. Before going live, confirm it can:

1. Accept POST requests with a JSON body.
2. Respond within a reasonable time (recommended under 5 seconds).
3. Return a 2xx status code on success.

## 2. Events and when they fire

| Event | Fires when |
| --- | --- |
| `install` | Linkrunner attributes an app installation to a campaign or organic source |
| `signup` | The app calls `.signup()` via the Linkrunner SDK |

### `install`

Fires immediately when Linkrunner attributes the install - at this point the
app has just been opened for the first time and the user hasn't had a chance
to sign up or log in yet. Because of this, identity fields (`user_id`,
`name`, `phone`, `email`, `additional_data`) are **not** present on install
webhooks; they only appear on `signup`.

The install webhook does include device identifiers (`gaid` for Android,
`idfa` for iOS) when available - use these to match the install with the
user later at signup.

Use it for: install counts by campaign, attribution analysis (network, ad
creative), app store conversion rate monitoring, and storing device ids to
link with the account later.

### `signup`

Fires when the app calls `.signup()` via the Linkrunner SDK, i.e. after the
user has signed up or logged in - so `user_id` contains the id passed to the
SDK. It includes device identifiers (`gaid`/`idfa`) alongside `user_id`,
giving you the full device + user picture. It also includes identity fields
(`name`, `phone`, `email`) and any custom key/value pairs passed via
`additional_data` (e.g. referral codes).

To receive signup webhooks at all, the app must call `.signup()` after the
user signs up or logs in - check the relevant SDK skill/reference if that
call isn't wired up yet.

Use it for: linking attribution to your user records, CRM/onboarding
integration, install-to-signup conversion rates, and forwarding custom
parameters (referral codes, etc.) to your backend.

## 3. Headers

| Header | Value |
| --- | --- |
| `Content-Type` | `application/json` |
| `linkrunner-key` | Your project's private key |

This shared key is the **only** authentication mechanism - there is no HMAC
request signature. Verify it with a constant-time comparison against the
private key you store server-side (see `references/handler.md`).

## 4. Body parameters

Every field can be `null` or omitted when not available for that event.

| Field | Type | Description |
| --- | --- | --- |
| `event_type` | `"install"` \| `"signup"` | The type of attribution event |
| `user_id` | `string` \| `null` | Customer user ID - signup only |
| `campaign_id` | `string` | Unique identifier for the campaign |
| `campaign_name` | `string` \| `null` | Human-readable campaign name |
| `network_name` | `string` \| `null` | Attribution network: `ORGANIC`, `META`, `GOOGLE`, etc. |
| `ad_channel` | `string` \| `null` | Ad channel: `META`, `GOOGLE`, `TIKTOK`, `APPLE_SEARCH_ADS`, etc. |
| `attributed_on` | ISO 8601 date | Timestamp when attribution occurred |
| `installed_at` | ISO 8601 date \| `null` | Timestamp of app installation |
| `store_click_at` | ISO 8601 date \| `null` | Timestamp of store redirect click |
| `link` | `string` | The campaign link URL |
| `app_version` | `string` \| `null` | Installed app version |
| `gaid` | `string` \| `null` | Google Advertising ID (Android) |
| `idfa` | `string` \| `null` | Identifier for Advertisers (iOS) |
| `name` | `string` \| `null` | User's name, from `user_data.name` passed to the SDK - signup only |
| `phone` | `string` \| `null` | User's phone, from `user_data.phone` passed to the SDK - signup only |
| `email` | `string` \| `null` | User's email, from `user_data.email` passed to the SDK - signup only |
| `additional_data` | `object` \| `null` | Custom parameters/device data from the SDK `data` field - signup only |
| `meta_campaign_details` | `object` \| `null` | Meta Ads campaign details, see below |
| `google_campaign_details` | `object` \| `null` | Google Ads campaign details, see below |
| `apple_search_ads_details` | `object` \| `null` | Apple Search Ads campaign details, see below |
| `campaign_details` | `object` \| `null` | Generic ad network campaign details, see below |

Network-specific detail objects are only populated when that network
provided attribution data for the event - the rest are `null`.

### `meta_campaign_details`

`ad_creative_id`, `ad_creative_name`, `ad_set_id`, `ad_set_name`,
`campaign_group_id`, `campaign_group_name`, `account_id`,
`ad_objective_name`, `is_instagram`, `publisher_platform`,
`platform_position`.

### `google_campaign_details`

`gclid`, `gbraid`, `ga_source`, `ad_group_id`, `ad_group_name`.

### `apple_search_ads_details`

`ad_group_id`, `ad_group_name`, `keyword_id`, `keyword_name`, `ad_id`,
`ad_name`, `country_or_region`.

### `campaign_details` (other ad networks)

`ad_network_code`, `ad_network_name`, `campaign_id`, `adset_id`,
`ad_creative_id`.

## 5. Example payloads

Install:

```json
{
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
}
```

Signup:

```json
{
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
}
```

## 6. Retry behavior

If your endpoint fails to respond with a 2xx status code, Linkrunner makes up
to 3 attempts total with exponential backoff:

| Attempt | Delay |
| --- | --- |
| 1st | Immediate |
| 2nd | 1 second after the first failure |
| 3rd | 2 seconds after the second failure |

After 3 failed attempts, the webhook is marked as failed - build handling and
idempotency (see `references/handler.md`) assuming redelivery can happen.

## 7. Slack integration

If your webhook URL contains `hooks.slack.com`, Linkrunner automatically
formats the payload as a Slack Block Kit message instead of sending raw JSON.
Create an [Incoming Webhook](https://api.slack.com/messaging/webhooks) in
your Slack workspace, copy the URL, and paste it as the webhook URL in
Linkrunner settings - no receiver code needed for this path.

## 8. Troubleshooting

**Webhooks not received?**
- Verify the endpoint URL is correct and publicly accessible.
- Confirm the server accepts POST requests with a JSON body.
- Confirm the firewall allows incoming requests from Linkrunner.

**Getting 401s?**
- Re-check the `linkrunner-key` header comparison in the handler.
- Confirm the stored private key matches the one in
  [dashboard settings](https://dashboard.linkrunner.io/settings).

**Missing data in payload?**
- `name`/`phone`/`email` require `user_data` passed to the SDK's `.signup()`
  or `.trigger()`.
- `user_id` requires the SDK's signup call to have run at all.
- `gaid`/`idfa` depend on user consent and SDK implementation.
- `additional_data` requires a `data` object passed through the SDK.
- Network-specific detail objects are only populated when that network
  provided attribution data.
