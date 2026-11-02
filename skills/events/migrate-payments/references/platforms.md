# Per-platform migration

Each section has the upgrade step and the same payment before and after. The
example is a first booking of 1200 INR. Replace the values with the ones at
your call site, and the currency with the one the user gave you.

Product details for ad networks are optional and go in the same event data:
Meta reads `content_ids`, `contents`, `content_type`, `num_items` and
`order_id`, and Google reads `content_ids` as item ids. `amount` stays the
order total.

## Android (Kotlin and Java)

Upgrade: `implementation("io.linkrunner:android-sdk:5.0.0")` or newer, then
Gradle sync.

Before:

```kotlin
LinkRunner.getInstance().capturePayment(
    CapturePaymentRequest(
        paymentId = "bk_10231",
        userId = "u_8842",
        amount = 1200.0,
        type = PaymentType.FIRST_PAYMENT,
        status = PaymentStatus.PAYMENT_COMPLETED,
        eventData = mapOf("plan" to "monthly")
    )
)
```

After:

```kotlin
LinkRunner.getInstance().trackEvent(
    eventName = "FIRST_PAYMENT",
    eventData = mapOf(
        "amount" to 1200.0,
        "paymentId" to "bk_10231",
        "currency" to "INR",
        "userId" to "u_8842",
        "status" to "PAYMENT_COMPLETED",
        "plan" to "monthly"
    )
)
```

`trackEvent` is a `suspend` function, like `capturePayment`, so it stays in
the same coroutine scope. From Java, replace
`LinkrunnerJava.getInstance().capturePayment(request, callback)` with
`LinkrunnerJava.getInstance().trackEvent("FIRST_PAYMENT", eventData, null, callback)`,
where `eventData` is a `Map<String, Object>` with the same keys.

Refund: same name and `paymentId`, the original `amount` and `currency`, and
`"status" to "PAYMENT_CANCELLED"`.

## iOS (Swift)

Upgrade: `pod 'LinkrunnerKit', '~> 5.0'` then `pod install`, or Swift Package
Manager `from: "5.0.0"` on `https://github.com/linkrunner-labs/linkrunner-ios.git`.

Before:

```swift
await LinkrunnerSDK.shared.capturePayment(
    amount: 1200,
    userId: "u_8842",
    paymentId: "bk_10231",
    type: .firstPayment,
    status: .completed,
    eventData: ["plan": "monthly"]
)
```

After:

```swift
await LinkrunnerSDK.shared.trackEvent(
    eventName: "FIRST_PAYMENT",
    eventData: [
        "amount": 1200,
        "paymentId": "bk_10231",
        "currency": "INR",
        "userId": "u_8842",
        "status": "PAYMENT_COMPLETED",
        "plan": "monthly"
    ]
)
```

Use the raw string of the old enum case as the event name (`.firstPayment`
is `"FIRST_PAYMENT"`, `.default` is `"DEFAULT"`). An invalid payment is logged
and dropped, not thrown, so check the debug console during the test.

## React Native

Upgrade: `npm install rn-linkrunner@^4.0.0` (or yarn), then `cd ios && pod install`.

Before:

```javascript
await linkrunner.capturePayment({
  amount: 1200,
  userId: "u_8842",
  paymentId: "bk_10231",
  type: "FIRST_PAYMENT",
  status: "PAYMENT_COMPLETED",
  eventData: { plan: "monthly" },
});
```

After:

```javascript
await linkrunner.trackEvent("FIRST_PAYMENT", {
  amount: 1200,
  paymentId: "bk_10231",
  currency: "INR",
  userId: "u_8842",
  status: "PAYMENT_COMPLETED",
  plan: "monthly",
});
```

`PaymentStatus` can be imported from `rn-linkrunner` if you prefer
`PaymentStatus.PAYMENT_COMPLETED` over the string.

## Expo

Upgrade both: `npx expo install expo-linkrunner@^4.0.0 rn-linkrunner@^4.0.0`,
then `npx expo prebuild --clean` or a new EAS build. The code change is the
same as React Native.

## Flutter

Upgrade: `linkrunner: ^5.0.0` in `pubspec.yaml`, `flutter pub get`, then
`cd ios && pod install`.

Before:

```dart
await LinkRunner().capturePayment(
  capturePayment: LRCapturePayment(
    amount: 1200,
    userId: 'u_8842',
    paymentId: 'bk_10231',
    type: PaymentType.FIRST_PAYMENT,
    status: PaymentStatus.PAYMENT_COMPLETED,
    eventData: {'plan': 'monthly'},
  ),
);
```

After:

```dart
await LinkRunner().trackEvent(
  eventName: 'FIRST_PAYMENT',
  eventData: {
    'amount': 1200,
    'paymentId': 'bk_10231',
    'currency': 'INR',
    'userId': 'u_8842',
    'status': 'PAYMENT_COMPLETED',
    'plan': 'monthly',
  },
);
```

`PaymentType.DEFAULT_PAYMENT`, and a call with no `type`, become `'DEFAULT'`.
An invalid payment throws `PlatformException`, so keep the existing
`try`/`catch`.

## Capacitor

Upgrade: `npm install capacitor-linkrunner@^3.0.0`, then `npx cap sync`.

Before:

```typescript
await linkrunner.capturePayment({
  amount: 1200,
  userId: "u_8842",
  paymentId: "bk_10231",
  type: "FIRST_PAYMENT",
  status: "PAYMENT_COMPLETED",
});
```

After:

```typescript
await linkrunner.trackEvent("FIRST_PAYMENT", {
  amount: 1200,
  paymentId: "bk_10231",
  currency: "INR",
  userId: "u_8842",
  status: "PAYMENT_COMPLETED",
});
```

## Cordova

Upgrade: `npm install cordova-linkrunner@^2.0.0`, then
`cordova platform rm android ios && cordova platform add android ios` so the
new native SDKs are pulled.

Before:

```javascript
linkrunner.capturePayment({
  amount: 1200,
  userId: "u_8842",
  paymentId: "bk_10231",
  type: "FIRST_PAYMENT",
  status: "PAYMENT_COMPLETED",
  eventData: { plan: "monthly" },
});
```

After:

```javascript
linkrunner.trackEvent("FIRST_PAYMENT", {
  amount: 1200,
  paymentId: "bk_10231",
  currency: "INR",
  userId: "u_8842",
  status: "PAYMENT_COMPLETED",
  plan: "monthly",
}).catch(function (error) {
  console.error("Linkrunner payment failed:", error);
});
```

## Unity

Unity apps use one of two setups. Check which one before editing.

**Unity package** (`io.linkrunner.unity-sdk` in `Packages/manifest.json`).
Upgrade the package to 3.0.0 or newer, then let the External Dependency
Manager resolve Android SDK 5.0.0.

Before:

```csharp
var paymentData = new CapturePaymentRequest("u_8842", 1200.0)
{
    paymentId = "bk_10231",
    type = PaymentType.FIRST_PAYMENT,
    status = PaymentStatus.PAYMENT_COMPLETED
};
LinkrunnerSDK.OnCapturePaymentComplete += OnPaymentDone;
yield return StartCoroutine(LinkrunnerSDK.Instance.CapturePayment(paymentData));
```

After:

```csharp
LinkrunnerSDK.OnTrackEventComplete += OnPaymentDone;
yield return StartCoroutine(LinkrunnerSDK.Instance.TrackEvent("FIRST_PAYMENT", new Dictionary<string, object>
{
    { "amount", 1200.0 },
    { "paymentId", "bk_10231" },
    { "currency", "INR" },
    { "userId", "u_8842" },
    { "status", PaymentStatus.PAYMENT_COMPLETED }
}));
```

Move the result handling from `OnCapturePaymentComplete` to
`OnTrackEventComplete`.

**Hand-written bridges** (a Java bridge calling `LinkrunnerJava` and a Swift
bridge with `@_cdecl`, as in https://docs.linkrunner.io/sdk/unity). Bump the
native SDKs to Android 5.0.0 and LinkrunnerKit 5.0.0, then replace the
bridge's capture payment method with a call to the native `trackEvent` and
the payment fields in the event data, as in the Android and iOS sections
above. Follow https://docs.linkrunner.io/sdk/unity#track-payments for the
bridge and C# wrapper code.
