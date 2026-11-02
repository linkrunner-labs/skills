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

A payment is a `trackEvent` call with `amount`, `paymentId` and `currency`
together in `eventData`, plus `userId`. Needs `linkrunner` **5.0.0+** (older
versions: see below). Revenue is stored for all users, including organic ones.

```dart
try {
  await LinkRunner().trackEvent(
    eventName: 'purchase', // payment type in reports and mappings
    eventData: {
      'amount': 1499.0,          // required: order total, a number >= 0
      'paymentId': 'order_123',  // required: your order id, dedup key
      'currency': 'INR',         // required: 3-letter ISO 4217
      'userId': 'user_123',      // required: '' = user saved by signup
      'status': 'PAYMENT_COMPLETED', // optional, the default
      // optional: other keys stay event data (Meta/Google product fields)
      'content_ids': ['sku_1'],
      'num_items': 1,
      'order_id': 'order_123',
    },
  );
} on PlatformException catch (e) {
  // Android: invalid payment, code TRACK_EVENT_FAILED, nothing sent
  print('Invalid payment: ${e.message}');
}
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
  sent: on Android `trackEvent` throws `PlatformException` (code
  `TRACK_EVENT_FAILED`) with the reason. On iOS it does not throw: the payment
  is dropped and debug builds log the reason.
- Linkrunner keeps one payment per `paymentId` + event name + `status`, so
  retries are safe. The same `paymentId` under two event names counts twice.
- Refund or cancellation: same event name and `paymentId`, the original
  `amount` and `currency`, and `status` `PAYMENT_CANCELLED`.
- `PaymentStatus.X.name` gives the status string if you prefer the enum.

### Older SDK versions

From 5.0.0, `capturePayment` and `removePayment` are deprecated: they still
work, show an IDE deprecation warning, and will be removed in a future major
version. On 4.x, payments use
`LinkRunner().capturePayment(capturePayment: LRCapturePayment(...))` and
refunds use `removePayment(removePayment: LRRemovePayment(...))`.
`PaymentType.DEFAULT_PAYMENT`, and a call with no `type`, were stored as
`DEFAULT`, so their event name is `'DEFAULT'`.

To move existing calls to `trackEvent` (same payment name, `currency` added),
run `npx @linkrunner/skills add migrate-payments` or follow
https://docs.linkrunner.io/sdk/migrate-to-track-event.

## Custom / ecommerce events

```dart
await LinkRunner().trackEvent(
  eventName: 'AddToCart',                  // required
  eventData: { 'productId': 'SKU_123' },   // optional payload
  eventId: 'order_12345',                  // optional - your own unique event id (String or num), for dedup / correlating with your backend
);
```

Purchases are `trackEvent` payments (see Revenue) with the ecommerce fields
in `eventData`.

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
