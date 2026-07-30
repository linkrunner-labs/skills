# iOS install + initialization

Source of truth: https://docs.linkrunner.io/sdk/ios

## Requirements

- iOS 15.0 or higher
- Swift 5.9 or higher
- Xcode 14.0 or higher

## 1. Add the package

The docs only cover **Swift Package Manager** for `linkrunner-ios` - there is
no published CocoaPods pod for this SDK. Don't invent one; if the user insists
on CocoaPods, point them at the docs URL above instead of guessing a pod name.

### Via Xcode

1. **File -> Add Package Dependencies...**
2. Enter the repository URL:
   ```
   https://github.com/linkrunner-labs/linkrunner-ios.git
   ```
3. Select the version (latest recommended)
4. **Add Package**
5. Choose the library type **LinkrunnerKitStatic**

### Via `Package.swift`

```swift
dependencies: [
    .package(url: "https://github.com/linkrunner-labs/linkrunner-ios.git", from: "3.12.0")
]
```

```swift
targets: [
    .target(
        name: "YourApp",
        dependencies: [
            .product(name: "LinkrunnerKitStatic", package: "linkrunner-ios")
        ]
    )
]
```

### Import

```swift
import LinkrunnerKit
```

Use `import LinkrunnerKit` for v3.0.0 and later. The public API remains
`LinkrunnerSDK.shared`.

## 2. Info.plist configuration

### App Tracking Transparency (if collecting IDFA)

```xml
<key>NSUserTrackingUsageDescription</key>
<string>This identifier will be used to deliver personalized ads and improve your app experience.</string>
```

### SKAdNetwork (optional - to receive SKAN postback copies)

```xml
<key>NSAdvertisingAttributionReportEndpoint</key>
<string>https://linkrunner-skan.com</string>
<key>AttributionCopyEndpoint</key>
<string>https://linkrunner-skan.com</string>
```

See the [SKAdNetwork Integration Guide](https://docs.linkrunner.io/sdk/skadnetwork-integration)
for the full setup.

### Network access

The SDK needs network access - no extra entitlement beyond the app's normal
internet access is required.

## 3. Google Integrated Conversion Measurement (optional)

ICM recovers Google App Campaign installs that Google cannot attribute because
there is no click identifier and no IDFA to match on - the normal state once a
user declines App Tracking Transparency. Set this up if the app runs Google
App Campaigns. Requires **LinkrunnerKit 4.1.0+**. See
[Google ICM](https://docs.linkrunner.io/features/google-icm) for how it works
and the required Google Ads iOS link ID (separate from this SDK config).

### Add Google's On-Device Measurement SDK

LinkrunnerKit does not bundle this - it is detected at runtime, so apps that
skip ICM carry none of its weight. Already on the Firebase iOS SDK 11.14.0+?
The `FirebaseAnalytics` pod already brings it in - skip this step.

**Swift Package Manager:**
Add `https://github.com/googleads/google-ads-on-device-conversion-ios-sdk` via
**File -> Add Package Dependencies...** and select the
`GoogleAdsOnDeviceConversion` product.

**CocoaPods:**

```ruby
target 'YourApp' do
  # ...your existing pods
  pod 'GoogleAdsOnDeviceConversion'
end
```

Then `pod install`.

### Add the `-ObjC` linker flag (SPM only)

Using CocoaPods? Skip this - it adds `-ObjC` and `-lc++` automatically when
linking Google's static framework. If installed via SPM, add to **Build
Settings -> Other Linker Flags** on the app target:

```
-ObjC
```

Without it, ICM silently does nothing and the build still succeeds - Google's
class is found through the Objective-C runtime, so nothing references it at
link time and the linker drops it from Google's static library. This is the
most common reason `odm_available` comes back `false` (see Verify, below).

### Report consent

Google's App Conversion API treats consent as required whenever its value is
known. Call `setConsent` **before** `initialize()`, and again whenever the
user's choice changes:

```swift
LinkrunnerSDK.shared.setConsent(
    LinkrunnerConsent(
        isEEA: .granted,
        hasConsentForDataUsage: .granted,
        hasConsentForAdsPersonalization: .denied
    )
)

try await LinkrunnerSDK.shared.initialize(token: "YOUR_PROJECT_TOKEN")
```

| Parameter | Meaning |
| --- | --- |
| `isEEA` | European regulations apply to this user (the EEA, the UK, or Switzerland) |
| `hasConsentForDataUsage` | The user agreed to their data being sent to Google for advertising |
| `hasConsentForAdsPersonalization` | The user agreed to their data being used to personalize ads |

Each takes `.granted`, `.denied`, or `.unknown`. Anything left `.unknown` is
dropped from the request rather than sent as a denial - never map `unknown` to
`granted`. **For users outside the EEA/UK/Switzerland, report `isEEA` as
denied and leave the other two unset.** Consent persists between launches, so
call `setConsent` again whenever it changes or the previous value keeps being
sent. See [Send Consent](https://docs.linkrunner.io/features/send-consent).

### Verify

With `debug: true`, look for this line in the Xcode console:

```
Linkrunner: odm_available=true odm_fetch_result=success odm_fetch_latency_ms=124
```

`odm_available=false odm_fetch_result=unavailable` means Google's SDK is not
linked - check the `-ObjC` flag first if installed via SPM.

## 4. Initialize (required, before anything else)

`initialize()` is `async throws` and returns nothing. Attribution + deeplink
data comes from `getAttributionData()` later (see `references/events.md`).

Project token: dashboard -> Settings
([direct link](https://dashboard.linkrunner.io/dashboard?s=members&m=documentation)).

```swift
import LinkrunnerKit
import SwiftUI

@main
struct MyApp: App {
    init() {
        Task {
            do {
                try await LinkrunnerSDK.shared.initialize(
                    token: "YOUR_PROJECT_TOKEN",
                    secretKey: "YOUR_SECRET_KEY", // Optional - only for SDK signing
                    keyId: "YOUR_KEY_ID",         // Optional - only for SDK signing
                    debug: true                   // Optional (default false) - turn off for release
                )
                print("Linkrunner initialized successfully")
            } catch {
                print("Error initializing Linkrunner:", error)
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

For UIKit apps without SwiftUI's `App` protocol, call this from
`application(_:didFinishLaunchingWithOptions:)` in `AppDelegate` instead.

**SDK signing** (optional, more secure): `secretKey` + `keyId` from
dashboard -> Settings -> SDK Signing
([direct link](https://dashboard.linkrunner.io/settings?s=sdk-signing)).
`disableIdfa: Bool` (default false) is also accepted as an initialization
parameter to turn off IDFA collection.

## 5. Verify install

- Project builds with the Linkrunner package resolved
- With `debug: true`, the SDK prints an init line on launch
- No IDFA prompt or network errors at startup

Next: `references/events.md` (signup is required) and, if the user wants links
to open the app, `references/deep-linking.md`.
