# Unity - users, events, revenue, attribution (C# API)

Source of truth: https://docs.linkrunner.io/sdk/unity

Call `LinkrunnerSDK.Initialize(...)` first (see `references/install.md`). All
calls below assume the SDK is initialized and the `LinkrunnerCallbackHandler`
GameObject exists in the scene. Results arrive asynchronously via C# events,
not return values - subscribe before calling.

## Signup (required)

Call as soon as the user is identified - at signup OR login. This ties the
install and future events to a user id.

```csharp
var userData = new LinkrunnerUserData
{
    id = "user_123",
    name = "Jane Doe",
    email = "jane@example.com",
    isFirstTimeUser = true
};

LinkrunnerSDK.Signup(userData);
```

`LinkrunnerUserData` fields: `id` (required), `name`, `phone`, `email`,
`mixpanelDistinctId`, `amplitudeDeviceId`, `posthogDistinctId`,
`brazeDeviceId`, `gaAppInstanceId`, `gaSessionId`, `userCreatedAt` (helps
detect reinstalls), `isFirstTimeUser` - all optional except `id`.

Subscribe: `LinkrunnerSDK.OnSignedUp += (success, message) => { ... };`

## SetUserData (optional top-up)

Call on app open when the user is logged in, to refresh details that became
available after signup (phone, email, profile completion). **Not** a
replacement for `Signup` - always `Signup` first.

```csharp
LinkrunnerSDK.SetUserData(userData);
```

Subscribe: `LinkrunnerSDK.OnUserDataSet += (success, message) => { ... };`

## Revenue

A payment is a `trackEvent` call with `amount`, `paymentId` and `currency`
together in `eventData`, plus `userId`. Needs the bridges built on Android SDK
**5.0.0+** and LinkrunnerKit **5.0.0+** (older versions: see below). Revenue
is stored for all users, including organic ones.

```csharp
// Payment keys and product details in one JSON string
string eventDataJson =
    "{\"amount\":1499.0," +            // required: order total, a number >= 0
    "\"paymentId\":\"order_123\"," +   // required: your order id, dedup key
    "\"currency\":\"INR\"," +          // required: 3-letter ISO 4217
    "\"userId\":\"user_123\"," +       // required: "" = user saved by Signup
    "\"status\":\"PAYMENT_COMPLETED\"," + // optional, the default
    "\"content_ids\":[\"sku_1\"],\"num_items\":1,\"order_id\":\"order_123\"}";

// Subscribe once, for example in Awake
LinkrunnerSDK.OnEventTracked += (success, message) =>
{
    if (!success) Debug.LogError($"Error tracking payment: {message}");
};

LinkrunnerSDK.TrackEvent("purchase", eventDataJson);
```

- **The event name is the payment type.** It is stored exactly as sent and
  matched exactly, letter case included, against Meta, Google, SKAN and
  affiliate mappings. Old payment types keep their uppercase spelling:
  `FIRST_PAYMENT`, `SECOND_PAYMENT`, `TRIAL_STARTED`, `TRIAL_CANCELLED`,
  `WALLET_TOPUP`, `FUNDS_WITHDRAWAL`, `SUBSCRIPTION_CREATED`,
  `SUBSCRIPTION_RENEWED`, `SUBSCRIPTION_CANCELLED`, `SUBSCRIPTION_REFUNDED`,
  `SUBSCRIPTION_BILLING_ISSUE`, `DEFAULT`, `ONE_TIME`, `RECURRING`.
  `first_payment` is a new type that no existing mapping matches, and any new
  name (such as `purchase`) needs its own dashboard mapping before it reaches
  ad networks.
- Required: `amount` (a number, 0 or more, the order total), `paymentId` (your
  stable order or transaction id, never a random value), `currency` (3-letter
  ISO 4217, such as `INR`) and `userId` (`""` uses the user saved by `signup`
  or `setUserData`).
- `status` is optional: `PAYMENT_INITIATED`, `PAYMENT_COMPLETED` (default),
  `PAYMENT_FAILED`, `PAYMENT_CANCELLED`. Only `PAYMENT_COMPLETED` counts as
  revenue and is sent to ad networks.
- `amount` or `currency` without `paymentId` is a normal custom event.
  `paymentId` with `amount` or `currency` missing, a negative `amount`, a
  blank `paymentId` or a non-3-letter `currency` is rejected and nothing is
  sent: on Android `LinkrunnerSDK.OnEventTracked` reports `false` with the
  error. On iOS the payment is dropped and debug builds log the reason.
- Linkrunner keeps one payment per `paymentId` + event name + `status`, so
  retries are safe. The same `paymentId` under two event names counts twice.
- Refund or cancellation: same event name and `paymentId`, the original
  `amount` and `currency`, and `status` `PAYMENT_CANCELLED`.
- `amount` must be a JSON number, not a string.

### Older SDK versions

From 5.0.0, `capturePayment` and `removePayment` are deprecated: they still
work, show an IDE deprecation warning, and will be removed in a future major
version. Bridges built on Android SDK 4.x or LinkrunnerKit 4.x expose
`LinkrunnerSDK.CapturePayment(...)` / `RemovePayment(...)` (results on
`OnPaymentCaptured` / `OnPaymentRemoved`); the current doc bridges no longer
include them.

To move existing calls to `trackEvent` (same payment name, `currency` added),
run `npx @linkrunner/skills add migrate-payments` or follow
https://docs.linkrunner.io/sdk/migrate-to-track-event.

## Custom events

```csharp
LinkrunnerSDK.TrackEvent("level_complete");

// with data (JSON string)
string eventData = JsonUtility.ToJson(new { level = 5, score = 1200 });
LinkrunnerSDK.TrackEvent("level_complete", eventData);

// with a dedup id
LinkrunnerSDK.TrackEvent("purchase", eventData, eventId: "purchase_abc123");
```

`eventDataJson` and `eventId` are passed as pre-serialized JSON strings, not
C# objects - the C# wrapper does not serialize event payloads for you beyond
`LinkrunnerUserData`.

Subscribe: `LinkrunnerSDK.OnEventTracked += (success, message) => { ... };`

## Attribution + resolved deeplink

```csharp
LinkrunnerSDK.OnAttributionData += (jsonString) =>
{
    // parse jsonString - shape differs by platform, see below
};

LinkrunnerSDK.GetAttributionData();
```

The result arrives as a raw JSON string on `OnAttributionData`, and **the
shape differs by platform** with the reference bridge code in the doc:

iOS:
```json
{
    "deeplink": "https://...",
    "attributionSource": "ORGANIC | META | GOOGLE | ...",
    "campaignData": { "id": "...", "name": "...", "groupName": "...", "assetName": "...", "assetGroupName": "..." }
}
```

Android (bridge returns the Kotlin object's `toString()`, not structured JSON):
```json
{ "raw": "AttributionData(deeplink=..., campaignData=CampaignData(...))" }
```

If cross-platform parsing needs a consistent shape, that's a bridge-code
change to make in `LinkrunnerBridge.java` (build a real JSON object from
`AttributionData` instead of `.toString()`) - the doc's Android bridge does
not do this out of the box.

## Push token

```csharp
LinkrunnerSDK.SetPushToken("your_firebase_or_apns_token");
```

## Privacy controls

```csharp
// hash PII (email, phone, etc.) before sending
LinkrunnerSDK.EnablePIIHashing(true);

// Android only, COPPA/Families compliance - call BEFORE Initialize
LinkrunnerSDK.SetDisableAaidCollection(true);
```

## Function placement guide

| Function | Where to call | When |
| --- | --- | --- |
| `Initialize` | First scene / app startup | Once at launch |
| `GetAttributionData` | After init completes | When you need campaign/deeplink info |
| `Signup` | After onboarding | Once per user |
| `SetUserData` | Auth/session logic | Every app open with a logged-in user |
| `TrackEvent` | Throughout the app | On user actions |
| `TrackEvent` with payment keys | Payment flow | When payment succeeds; again with `PAYMENT_CANCELLED` on refund |
| `SetPushToken` | After token refresh | When push token changes |
| `HandleDeeplink` | Deeplink entry points | When app is opened via a deeplink (see `references/deep-linking.md`) |

All calls no-op and log to console in the Unity Editor - test actual
attribution/event behavior on Android/iOS devices.
