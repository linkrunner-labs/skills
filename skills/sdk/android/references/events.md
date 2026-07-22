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

Revenue is only stored for attributed users - `signup` must run first.

```kotlin
val paymentData = CapturePaymentRequest(
    paymentId = "payment_123", // Required: unique payment identifier
    userId = "user123", // Required
    amount = 99.99, // Required
    type = PaymentType.FIRST_PAYMENT, // Optional, defaults to DEFAULT
    status = PaymentStatus.PAYMENT_COMPLETED, // Optional, defaults to PAYMENT_COMPLETED
    eventData = mapOf( // Optional - ecommerce/custom payload
        "content_ids" to listOf("product_123"),
        "currency" to "USD",
        "value" to 99.99
    )
)
LinkRunner.getInstance().capturePayment(paymentData)

// refund / undo
val removeRequest = RemovePaymentRequest(
    paymentId = "payment_123", // Optional
    userId = "user123" // Optional
)
LinkRunner.getInstance().removePayment(removeRequest)
```

`removePayment` needs either `paymentId` or `userId`. With only `userId`, all
of that user's payments are removed.

**Payment types:** `FIRST_PAYMENT`, `SECOND_PAYMENT`, `WALLET_TOPUP`,
`FUNDS_WITHDRAWAL`, `SUBSCRIPTION_CREATED`, `SUBSCRIPTION_RENEWED`,
`ONE_TIME`, `RECURRING`, `DEFAULT`.

**Payment statuses:** `PAYMENT_INITIATED`, `PAYMENT_COMPLETED`,
`PAYMENT_FAILED`, `PAYMENT_CANCELLED`.

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
        "amount" to 99.99 // pass amount as a number for ad-network revenue sharing (Google/Meta)
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
for the full field reference. Purchases go through `capturePayment` (with
`order_id` in `eventData`), not `trackEvent`.

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
