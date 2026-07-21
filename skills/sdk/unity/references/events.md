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

```csharp
LinkrunnerSDK.CapturePayment(
    userId: "user_123",
    amount: 9.99,
    paymentId: "pay_abc123",
    type: "FIRST_PAYMENT",
    status: "PAYMENT_COMPLETED"
);

// refund / undo
LinkrunnerSDK.RemovePayment(userId: "user_123", paymentId: "pay_abc123");
```

`RemovePayment` needs `paymentId` or `userId`. With only `userId`, all of that
user's payments are removed.

Payment types: `FIRST_PAYMENT`, `SECOND_PAYMENT`, `WALLET_TOPUP`,
`FUNDS_WITHDRAWAL`, `SUBSCRIPTION_CREATED`, `SUBSCRIPTION_RENEWED`,
`ONE_TIME`, `RECURRING`, `DEFAULT`.

Payment statuses: `PAYMENT_INITIATED`, `PAYMENT_COMPLETED`, `PAYMENT_FAILED`,
`PAYMENT_CANCELLED`.

`amount` must be a numeric type, not a string - ad network revenue
optimization depends on it.

Subscribe: `LinkrunnerSDK.OnPaymentCaptured += (success, message) => { ... };`
and `LinkrunnerSDK.OnPaymentRemoved += (success, message) => { ... };`

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
| `CapturePayment` | Payment flow | When payment succeeds |
| `RemovePayment` | Refund flow | When payment is reversed |
| `SetPushToken` | After token refresh | When push token changes |
| `HandleDeeplink` | Deeplink entry points | When app is opened via a deeplink (see `references/deep-linking.md`) |

All calls no-op and log to console in the Unity Editor - test actual
attribution/event behavior on Android/iOS devices.
