# Android - users, events, revenue, attribution

Source of truth: https://docs.linkrunner.io/sdk/android

Call `init()` first (see `references/install.md`). Every SDK method below is
a Kotlin `suspend` function - call from a `CoroutineScope`/`lifecycleScope`.

## signup (required)

Call as soon as the user is identified - at signup OR login. This ties the
install and future events to a user id. If you don't already call your
analytics platform's own `identify()`, pass its distinct/device id here so
Linkrunner can stitch the same user across Mixpanel/PostHog/Amplitude.

```kotlin
private fun onSignup() {
    CoroutineScope(Dispatchers.IO).launch {
        try {
            val userData = UserDataRequest(
                id = "123", // Required: User ID
                name = "John Doe", // Optional
                phone = "9876543210", // Optional
                email = "user@example.com", // Optional
                mixpanelDistinctId = "mixpanel_distinct_id", // Optional
                amplitudeDeviceId = "amplitude_device_id", // Optional
                posthogDistinctId = "posthog_distinct_id", // Optional
                userCreatedAt = "2024-01-01T00:00:00Z", // Optional - helps detect reinstalls
                isFirstTimeUser = true, // Optional
            )

            LinkRunner.getInstance().signup(
                userData = userData,
                additionalData = mapOf("custom_field" to "custom_value") // Optional
            )
        } catch (e: Exception) {
            println("Exception during signup: ${e.message}")
        }
    }
}
```

## setCustomerUserId (set your own user id)

Attach your own user identifier to the device, ideally right after `init()`. Once
set, it is stored encrypted on-device and automatically attached to every event you
track, so you do not pass it on each `trackEvent`. Calling it again with a
different id updates the stored value; the same id is a no-op. `signup()` and
`setUserData()` also update it. It is a suspend function - call it from a coroutine.

```kotlin
LinkRunner.getInstance().setCustomerUserId("f47ac10b-58cc-4372-a567-0e02b2c3d479")
```

## setUserData (optional top-up)

Call every time the app opens while the user is logged in, to refresh details
that became available after signup (e.g. phone/email added later). **Not** a
replacement for `signup` - always `signup` first.

```kotlin
val result = LinkRunner.getInstance().setUserData(userData)
result.onSuccess { /* ... */ }.onFailure { error -> /* ... */ }
```

## Revenue

A payment is a `trackEvent` call with `amount`, `paymentId` and `currency`
together in `eventData`, plus `userId`. Needs `io.linkrunner:android-sdk`
**5.0.0+** (older versions: see below). Revenue is stored for all users,
including organic ones.

```kotlin
CoroutineScope(Dispatchers.IO).launch {
    LinkRunner.getInstance().trackEvent(
        eventName = "purchase", // payment type in reports and mappings
        eventData = mapOf(
            "amount" to 1499.0,          // required: order total, a number >= 0
            "paymentId" to "order_123",  // required: your order id, dedup key
            "currency" to "INR",         // required: 3-letter ISO 4217
            "userId" to "user_123",      // required: "" = user saved by signup
            "status" to "PAYMENT_COMPLETED", // optional, the default
            // optional: other keys stay event data (Meta/Google product fields)
            "content_ids" to listOf("sku_1"),
            "num_items" to 1,
            "order_id" to "order_123"
        )
    ).onFailure { error ->
        println("Invalid payment: ${error.message}")
    }
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
  sent: `trackEvent` returns a failed `Result` holding an
  `IllegalArgumentException` (it does not throw), so handle `onFailure`. From
  Java, `LinkrunnerJava.getInstance().trackEvent(...)` calls `onError` on the
  `LinkRunnerCallback`.
- Linkrunner keeps one payment per `paymentId` + event name + `status`, so
  retries are safe. The same `paymentId` under two event names counts twice.
- Refund or cancellation: same event name and `paymentId`, the original
  `amount` and `currency`, and `status` `PAYMENT_CANCELLED`.
- `io.linkrunner.sdk.models.PaymentStatus` has the same four values if you
  prefer an enum (`PaymentStatus.X.name` gives the string).

### Older SDK versions

From 5.0.0, `capturePayment` and `removePayment` are deprecated: they still
work, show an IDE deprecation warning, and will be removed in a future major
version. On 4.x, payments use
`LinkRunner.getInstance().capturePayment(CapturePaymentRequest(...))` with a
`PaymentType`, and refunds use `removePayment(RemovePaymentRequest(...))`.

To move existing calls to `trackEvent` (same payment name, `currency` added),
run `npx @linkrunner/skills add migrate-payments` or follow
https://docs.linkrunner.io/sdk/migrate-to-track-event.

## Custom / ecommerce events

Events are only stored for attributed users - `signup` must run first. From
**Android SDK v3.9.0**, `trackEvent` automatically includes the `user_id` set
via `signup()`/`setUserData()` - no need to pass it manually. Events tracked
before signup go out without a `user_id`.

```kotlin
LinkRunner.getInstance().trackEvent(
    eventName = "purchase_initiated",
    eventData = mapOf(
        "product_id" to "12345",
        "amount" to 99.99 // event data only, revenue needs the payment keys (see Revenue)
    ),
    eventId = "order_12345" // Optional: your own unique event identifier, useful for deduplication and correlating with your backend
)
```

**Parameters:** `eventName` (required), `eventData` (optional), `eventId`
(optional) - your own unique identifier for the event, useful for
deduplication and correlating with your backend.

For Meta Catalog Sales sync, `eventData` needs Meta's ecommerce fields
(`content_ids`, `contents`, `content_type`, `currency`, `value`,
`num_items`) - requires `android-sdk` **v3.6.0+**, and the custom event name
must be mapped to the standard commerce event in the Linkrunner Dashboard.
See [Meta Commerce Manager](https://docs.linkrunner.io/ecommerce-manager/meta-commerce-manager#understanding-event_data)
for the full field reference. Purchases are `trackEvent` payments (see
Revenue) with `order_id` and the product fields in `eventData`.

## Attribution + resolved deeplink

```kotlin
val attributionDataResult = LinkRunner.getInstance().getAttributionData()
attributionDataResult.onSuccess { attributionData ->
    // attributionData.deeplink      -> resolved destination (nullable)
    // attributionData.campaignData  -> id, name, adNetwork, type, installedAt,
    //   storeClickAt, groupName, assetName, assetGroupName, adNetworkCampaignId,
    //   adSetId, adSetName, adCreativeId, adCreativeName
}
```

Use `getAttributionData()` (not `init`'s return, which is void) to read
attribution and the deeplink that led to the install - useful for deferred
deep linking / routing a new user to the right screen after first open.

## Other identity/privacy calls

- `LinkRunner.getInstance().setAdditionalData(IntegrationData(clevertapId = "..."))` -
  set a third-party integration id (e.g. CleverTap) after the fact.
- `LinkRunner.getInstance().enablePIIHashing(true)` - hash name/email/phone
  with SHA-256 before sending, for privacy-sensitive apps. Check the current
  state with `LinkRunner.getInstance().isPIIHashingEnabled()`.
- `LinkRunner.getInstance().setPushToken(fcmToken)` - required for [uninstall
  tracking](https://docs.linkrunner.io/sdk/android#uninstall-tracking) via
  Firebase Cloud Messaging; call from `onNewToken` and on app start.
