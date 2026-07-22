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

## 3. Initialize (required, before anything else)

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

## 4. Verify install

- Project builds with the Linkrunner package resolved
- With `debug: true`, the SDK prints an init line on launch
- No IDFA prompt or network errors at startup

Next: `references/events.md` (signup is required) and, if the user wants links
to open the app, `references/deep-linking.md`.
