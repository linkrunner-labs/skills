# iOS deep linking

Source of truth: https://docs.linkrunner.io/sdk/ios and
https://docs.linkrunner.io/features/deep-linking-setup

Two approaches:

- **Universal Links** (`https://`) - requires domain verification. This is
  what most campaigns use.
- **Custom URL scheme** (`myapp://`) - no verification, simpler, good as a
  fallback.

The most common failure is that the app code is correct but domain
verification never passes, so links open Safari instead of the app. Do the
verification parts carefully and finish with `scripts/verify-deeplinks.sh`.

## Part A - capture deep links into the SDK (both approaches need this)

This is what powers remarketing/reattribution - Linkrunner uses it to detect
returning users who open the app via a deep link. `initialize()` must run
before `handleDeeplink()`.

Add to `SceneDelegate.swift`:

```swift
class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    // Cold start via Universal Link
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        // Check if app was launched via a Universal Link
        if let userActivity = connectionOptions.userActivities.first,
           userActivity.activityType == NSUserActivityTypeBrowsingWeb,
           let url = userActivity.webpageURL {
            Task {
                await LinkrunnerSDK.shared.handleDeeplink(url: url.absoluteString)
            }
        }

        // Check if app was launched via a custom URL scheme
        if let urlContext = connectionOptions.urlContexts.first {
            Task {
                await LinkrunnerSDK.shared.handleDeeplink(url: urlContext.url.absoluteString)
            }
        }
    }

    // Warm start - Universal Links (app already running in background)
    func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
        guard userActivity.activityType == NSUserActivityTypeBrowsingWeb,
              let url = userActivity.webpageURL else { return }

        Task {
            await LinkrunnerSDK.shared.handleDeeplink(url: url.absoluteString)
        }
    }

    // Warm start - custom URL schemes (app already running in background)
    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let url = URLContexts.first?.url else { return }

        Task {
            await LinkrunnerSDK.shared.handleDeeplink(url: url.absoluteString)
        }
    }
}
```

If the app doesn't use a `SceneDelegate` (no scenes / plain `AppDelegate`
lifecycle), the equivalent system entry points are
`application(_:continue:restorationHandler:)` for Universal Links and
`application(_:open:options:)` for custom schemes - wire `handleDeeplink` the
same way inside those.

Linkrunner returns a resolved `deeplink` after processing. For Linkrunner
campaign links, navigate to the **returned** deeplink, not the original
tracking URL:

```json
{
    "deeplink": "https://app.yourdomain.com/product/123"
}
```

Read it via `getAttributionData()` (see `references/events.md`) when you need
it outside the handler above - e.g. for deferred deep linking on first open.

## Part B - Universal Links verification file

### `apple-app-site-association` (no file extension)

```json
{
    "applinks": {
        "apps": [],
        "details": [
            {
                "appID": "TEAM_ID.BUNDLE_ID",
                "paths": ["/*"]
            }
        ]
    }
}
```

Replace:
- `TEAM_ID` - Apple Developer Portal -> Membership Details
- `BUNDLE_ID` - your app's bundle identifier in Xcode

`paths` can be scoped to specific paths; `/*` handles all of them.

### Host it in Linkrunner

Dashboard -> **Project Settings -> Domain Verification**
([direct link](https://dashboard.linkrunner.io/settings?sort_by=activity-1&s=store-verification)):
paste the JSON into the iOS field, Save. Linkrunner hosts it at:

```
https://your-domain.io/.well-known/apple-app-site-association
```

## Part C - native config

### Associated Domains (Universal Links)

1. Open the project in Xcode -> **Signing & Capabilities**
2. Add the **Associated Domains** capability
3. Add your domain(s):
   ```
   applinks:app.example.com
   ```

### Custom URL scheme (`Info.plist`)

1. Xcode -> **Info** tab -> add an entry under **URL Types**:
   - Identifier: your bundle identifier (e.g. `com.example.myapp`)
   - URL Schemes: your custom scheme (e.g. `myapp`)

Or directly in `Info.plist`:

```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleTypeRole</key>
    <string>Editor</string>
    <key>CFBundleURLName</key>
    <string>com.example.myapp</string>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>myapp</string>
    </array>
  </dict>
</array>
```

## Testing

```bash
# Universal Link
xcrun simctl openurl booted "https://app.example.com/profile/123"

# Custom URL scheme
xcrun simctl openurl booted "myapp://profile/123"
```

Note: typing a Universal Link into Safari's address bar never opens the app -
paste it into Notes and long-press it instead (or tap it from any other app).
If **Open in "YourApp"** appears, verification succeeded.

## Debugging (when Universal Links open Safari instead of the app)

- **Check the hosted file:**
  `curl -v https://your-domain.io/.well-known/apple-app-site-association`.
  A 404 means it isn't saved in the dashboard. If it loads, confirm `appID` is
  exactly `TEAM_ID.BUNDLE_ID`.
- **Check Apple's CDN, not your domain** - devices fetch the file from Apple's
  CDN, which pulls from your domain on its own schedule:
  `curl -v https://app-site-association.cdn-apple.com/a/v1/your-domain.io`.
  If it's stale, propagation can take up to a day; there's no manual purge.
- **Bypass the CDN with developer mode while testing:** set the Associated
  Domains entry to `applinks:your-domain.io?mode=developer`, enable
  **Settings -> Developer -> Associated Domains Development** on the device,
  then delete and reinstall the app. App Store builds ignore developer mode.
- **Clear the device's cached copy:** iOS only refreshes the AASA at install/
  update time - delete and reinstall the app to force a re-fetch.
- **Read the verification logs:** connect the device to a Mac, open
  Console.app, filter for `swcd` (the daemon that downloads/verifies
  associated domains), and reinstall while watching for download or parse
  errors.

Run `scripts/verify-deeplinks.sh` to check the hosted file and CDN state
automatically.
