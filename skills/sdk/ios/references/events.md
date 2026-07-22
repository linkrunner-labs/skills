# iOS - users, events, revenue, attribution

Source of truth: https://docs.linkrunner.io/sdk/ios

Call `initialize()` first (see `references/install.md`). All calls below
assume the SDK is initialized and are `async throws` unless noted.

## signup (required)

Call as soon as the user is identified - at signup OR login. This ties the
install and future events to a user id.

It's recommended to use the integrated analytics platform's own identify call
first; if you don't, pass its id explicitly (`mixpanelDistinctId`,
`amplitudeDeviceId`, `posthogDistinctId`).

```swift
func onSignup() async {
    do {
        let userData = UserData(
            id: "123",              // Required: User ID
            name: "John Doe",       // Optional
            phone: "9876543210",    // Optional
            email: "user@example.com", // Optional
            isFirstTimeUser: isFirstTimeUser,
            userCreatedAt: "2022-01-01T00:00:00Z", // Optional - helps detect reinstalls
            mixpanelDistinctId: "mixpanelDistinctId", // Optional
            amplitudeDeviceId: "amplitudeDeviceId",   // Optional
            posthogDistinctId: "posthogDistinctId"    // Optional
        )

        try await LinkrunnerSDK.shared.signup(
            userData: userData,
            additionalData: [:] // Optional: any additional data
        )

        print("Signup successful")
    } catch {
        print("Error during signup:", error)
    }
}
```

## setCustomerUserId (set your own user id)

Attach your own user identifier to the device, ideally right after `initialize()`.
Once set, it is stored in the Keychain and automatically attached to every event you
track, so you do not pass it on each `trackEvent`. Calling it again with a
different id updates the stored value; the same id is a no-op. `signup()` and
`setUserData()` also update it.

```swift
await LinkrunnerSDK.shared.setCustomerUserId("f47ac10b-58cc-4372-a567-0e02b2c3d479")
```

## setUserData (optional top-up)

Call each time the app opens and the user is logged in, to refresh details
that became available after signup (phone, email, completed profile).
**Not** a replacement for `signup` - always `signup` first.

```swift
func setUserData() async {
    do {
        let userData = UserData(
            id: "123",
            name: "John Doe",
            phone: "9876543210",
            email: "user@example.com"
        )
        try await LinkrunnerSDK.shared.setUserData(userData)
    } catch {
        print("Error setting user data:", error)
    }
}
```

## setAdditionalData (e.g. CleverTap ID)

```swift
func setAdditionalData() async {
    do {
        let integrationData = IntegrationData(clevertapId: clevertapId)
        try await LinkrunnerSDK.shared.setAdditionalData(integrationData)
    } catch {
        print("Error setting CleverTap ID:", error)
    }
}
```

## Revenue

Revenue is only stored for attributed users - `signup` must run first.

```swift
try await LinkrunnerSDK.shared.capturePayment(
    amount: 99.99,        // Payment amount
    userId: "user123",    // User identifier
    paymentId: "payment456", // Required: unique payment identifier
    type: .firstPayment,  // Optional
    status: .completed,   // Optional
    eventData: [:]        // Optional: ecommerce/custom event data
)

// refund / undo
try await LinkrunnerSDK.shared.removePayment(
    userId: "user123",
    paymentId: "payment456" // Optional: unique payment identifier
)
```

`removePayment` needs either `paymentId` or `userId`. With only `userId`, all
of that user's payments are removed.

Payment types (`PaymentType`): `.firstPayment`, `.secondPayment`,
`.walletTopup`, `.fundsWithdrawal`, `.subscriptionCreated`,
`.subscriptionRenewed`, `.oneTime`, `.recurring`, `.default`.

Payment statuses (`PaymentStatus`): `.initiated`, `.completed`, `.failed`,
`.cancelled`.

## Custom / ecommerce events

Events are only stored for attributed users - `signup` must run first.

```swift
try await LinkrunnerSDK.shared.trackEvent(
    eventName: "purchase_initiated",
    eventData: [
        "product_id": "12345",
        "category": "electronics",
        "amount": 99.99 // number, not string - needed for ad-network revenue sharing
    ],
    eventId: "order_12345" // Optional: your own unique event identifier, useful for deduplication and correlating with your backend
)
```

For ad-network revenue sharing (Google/Meta campaign optimization on
conversion value), include `amount` as a `Double`/`Int` in `eventData`.

For Meta Catalog Sales ecommerce events (`AddToCart`, `ViewContent`, and
`Purchase` via `capturePayment`), `eventData` needs Meta's fields
(`content_ids`, `contents`, `content_type`, `currency`, `value`, `num_items`) -
see the [Meta Commerce Manager docs](https://docs.linkrunner.io/ecommerce-manager/meta-commerce-manager#understanding-event_data)
for the full shape, and map the custom event name to the standard commerce
event in the Linkrunner dashboard. Requires `linkrunner-ios` **3.8.0+**.

## Attribution + resolved deeplink

```swift
let attributionData = try await LinkrunnerSDK.shared.getAttributionData()
if let deeplink = attributionData.deeplink {
    // resolved destination - route the user here
}
```

```swift
public struct LRAttributionDataResponse: Codable, Sendable {
    public let deeplink: String?
    public let campaignData: CampaignData?
    public let attributionSource: String
}

public struct CampaignData: Codable, Sendable {
    public let id: String
    public let name: String
    public let type: CampaignType        // .organic ("ORGANIC") | .inorganic ("INORGANIC")
    public let adNetwork: AdNetwork?      // .meta ("META") | .google ("GOOGLE")
    public let groupName: String?
    public let assetGroupName: String?
    public let adNetworkCampaignId: String? // Ad network campaign ID
    public let adSetId: String?             // Ad set ID
    public let adSetName: String?           // Ad set name
    public let adCreativeId: String?        // Ad creative ID
    public let adCreativeName: String?      // Ad creative name
    public let assetName: String?
    public let installedAt: Date?
    public let storeClickAt: Date?
}

public enum CampaignType: String, Codable, Sendable {
    case organic = "ORGANIC"
    case inorganic = "INORGANIC"
}

public enum AdNetwork: String, Codable, Sendable {
    case meta = "META"
    case google = "GOOGLE"
}
```

Use `getAttributionData()` (not `initialize`'s return, which is `Void`) to
read attribution and the deeplink that led to the install - useful for
deferred deep linking / routing a new user to the right screen after first
open.

## Uninstall tracking (APNs)

Requires `linkrunner-ios` 3.4.0+ and an app registered with APNs. After
[connecting APNs credentials in the dashboard](https://docs.linkrunner.io/sdk/ios#uninstall-tracking)
(Settings -> Uninstall Tracking -> iOS: APNs auth key, Key ID, Bundle ID, Team
ID), forward the device token to Linkrunner once it's available:

```swift
func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
    Task {
        try? await LinkrunnerSDK.shared.setPushToken(tokenString)
    }
}
```

## Enhanced privacy (PII hashing)

```swift
LinkrunnerSDK.shared.enablePIIHashing(true)
let isHashingEnabled = LinkrunnerSDK.shared.isPIIHashingEnabled()
```

When enabled, name/email/phone are SHA-256 hashed before being sent to
Linkrunner servers.
