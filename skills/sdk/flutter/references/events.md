# Flutter - users, events, revenue, attribution

Source of truth: https://docs.linkrunner.io/sdk/flutter

Call `init()` first (see `references/install.md`). All calls below assume the
SDK is initialized.

## signup (required)

Call as soon as the user is identified - at signup OR login. This ties the
install and future events to a user id.

```dart
await LinkRunner().signup(
  userData: LRUserData(
    id: '123',              // required
    name: 'John Doe',       // optional
    phone: '9876543210',    // optional
    email: 'user@example.com',
    userCreatedAt: '2024-01-01T00:00:00Z', // helps detect reinstalls
    isFirstTimeUser: true,
    // pass the analytics id if you don't call the platform's identify():
    mixpanelDistinctId: '...',
    amplitudeDeviceId: '...',
    posthogDistinctId: '...',
  ),
  data: {},
);
```

## setCustomerUserId (set your own user id)

Attach your own user identifier to the device, ideally right after `init()`. Once
set, it is stored securely on-device and automatically attached to every event you
track, so you do not pass it on each `trackEvent`. Calling it again with a
different id updates the stored value; the same id is a no-op. `signup()` and
`setUserData()` also update it.

```dart
await LinkRunner().setCustomerUserId('f47ac10b-58cc-4372-a567-0e02b2c3d479');
```

## setUserData (optional top-up)

Call on app open when the user is logged in, to refresh details that became
available after signup. **Not** a replacement for `signup` - always `signup`
first.

## Revenue

```dart
await LinkRunner().capturePayment(
  capturePayment: LRCapturePayment(
    userId: '123',                   // required
    amount: 499.0,                   // required
    paymentId: 'unique_payment_id',  // required - dedup key, used to avoid double-counting the payment
  ),
);

// refund / undo
await LinkRunner().removePayment(
  removePayment: LRRemovePayment(paymentId: 'unique_payment_id'),
);
```

`removePayment` needs either `paymentId` or `userId`. With only `userId`, all of
that user's payments are removed.

## Custom / ecommerce events

```dart
await LinkRunner().trackEvent(
  eventName: 'AddToCart',                  // required
  eventData: { 'productId': 'SKU_123' },   // optional payload
  eventId: 'order_12345',                  // optional - your own unique event id (String or num), for dedup / correlating with your backend
);
```

Purchases go through `capturePayment` with the ecommerce payload (see docs).

### Event parameters: one event, not one per variant

Send one event with parameters, not one event per variant: send `purchase`
with `{ plan: "gold" }`, not `purchase_gold` and `purchase_silver`. One event
name keeps funnels, campaign columns and postback mappings simple, and the
dashboard can filter and break down by `plan`.

```dart
await LinkRunner().trackEvent(
  eventName: 'purchase',
  eventData: {'plan': 'gold'}, // not purchase_gold / purchase_silver
);
```

Keep keys top-level and values flat and short, use the same key names and
value types every time for an event, and never put PII in them. The same
applies to the `eventData` in `LRCapturePayment`. See
[Event parameters](https://docs.linkrunner.io/features/event-parameters).

## Attribution + resolved deeplink

```dart
final attributionData = await LinkRunner().getAttributionData();
// attributionData.deeplink        -> resolved destination (nullable)
// attributionData.campaignData.id / .name / .adNetwork / .groupName / .assetGroupName / .assetName
// attributionData.campaignData.adNetworkCampaignId / .adSetId / .adSetName / .adCreativeId / .adCreativeName
// attributionData.campaignData.type / .installedAt / .storeClickAt
```

Use `getAttributionData()` (not `init`'s return) to read attribution and the
deeplink that led to the install - useful for deferred deep linking / routing a
new user to the right screen after first open. The `adNetworkCampaignId` /
`adSetId` / `adSetName` / `adCreativeId` / `adCreativeName` fields are
optional and populated for Meta/Google inorganic installs.

## Uninstall tracking (setPushToken)

Uninstall detection needs a push token so Linkrunner can send a silent
notification. On Android that means an FCM token; on iOS an APNs token. Fetch
it and hand it to the SDK:

```dart
String? token = await FirebaseMessaging.instance.getToken(); // Android (FCM)
// String? token = await FirebaseMessaging.instance.getAPNSToken(); // iOS (APNs)
if (token != null) {
  await LinkRunner().setPushToken(token);
}
```

Also call `setPushToken` again from `FirebaseMessaging.instance.onTokenRefresh`
so a rotated token stays current. This is only half the setup - you also need
Firebase Cloud Messaging wired up in the app and the FCM project ID
(Android) / APNs key, Key ID, Bundle ID, Team ID (iOS) entered under
Linkrunner dashboard Settings -> Uninstall Tracking. Full walkthrough:
https://docs.linkrunner.io/sdk/flutter#uninstall-tracking
