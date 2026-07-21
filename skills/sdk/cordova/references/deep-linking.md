# Cordova deep linking

Source of truth: https://docs.linkrunner.io/sdk/cordova and
https://docs.linkrunner.io/features/deep-linking-setup

Two approaches:

- **HTTP/HTTPS** (App Links on Android, Universal Links on iOS) - requires
  domain verification. This is what most campaigns use.
- **Custom URI scheme** (`myapp://`) - no verification, simpler, good as a
  fallback.

The most common failure is that the app code is correct but domain verification
never passes, so links open the browser instead. Do the verification parts
carefully and finish with `scripts/verify-deeplinks.sh`.

## Part A - capture deep links into the SDK (both approaches need this)

This is what powers remarketing/reattribution.

**Cold start** - if the app is launched by a deeplink, it is automatically
captured by the native SDK during `init()`. You don't call anything extra; read
the result later from `getAttributionData()`.

**Warm start** - the app is already running. Cordova surfaces this through
`window.handleOpenURL`, which you pass straight to `linkrunner.handleDeeplink`:

```javascript
// Initialize SDK first
document.addEventListener('deviceready', function () {
    linkrunner.init({ token: "YOUR_PROJECT_TOKEN" });
}, false);

// Handle warm start deeplinks
window.handleOpenURL = function (url) {
    linkrunner.handleDeeplink(url).then(function (data) {
        console.log("Deeplink data:", JSON.stringify(data));

        if (data && data.deeplink) {
            var deeplink = data.deeplink;
            console.log("Navigate to:", deeplink);
        }
    }).catch(function (error) {
        console.error("Deeplink handling failed:", error);
    });
};
```

Linkrunner sends the updated deeplink back after processing. For Linkrunner
campaign links, navigate to the **returned** `deeplink`, not the original
tracking URL:

```json
{
    "deeplink": "https://app.yourdomain.com/product/123"
}
```

Cordova has no bundled router the way React Native has React Navigation or
Flutter has go_router, and the docs don't demonstrate app-side routing for
Cordova. Use the resolved `deeplink` (from `handleDeeplink` or
`getAttributionData`) with whatever navigation the app already has (a JS
router, `www/` page swap, hash-based routing, etc).

## Part B - HTTP/HTTPS verification files

### Android - `assetlinks.json`

```json
[
  {
    "relation": ["delegate_permission/common.handle_all_urls"],
    "target": {
      "namespace": "android_app",
      "package_name": "your.package.name",
      "sha256_cert_fingerprints": ["SHA-256:XX:XX:..."]
    }
  }
]
```

Get the fingerprint:

```bash
# debug
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
# release
keytool -list -v -keystore your_release_keystore.keystore -alias your_key_alias
```

Debug and release keystores produce **different** fingerprints. List both in the
array, or use the Play Console fingerprint (**Play Console → Setup → App
integrity**) if you use Google Play App Signing.

### iOS - `apple-app-site-association` (no extension)

```json
{
  "applinks": {
    "apps": [],
    "details": [
      { "appID": "TEAM_ID.BUNDLE_ID", "paths": ["/*"] }
    ]
  }
}
```

`TEAM_ID` from Apple Developer → Membership; `BUNDLE_ID` from your Cordova
`config.xml` widget `id`.

### Host them in Linkrunner

Dashboard → **Project Settings → Domain Verification**: paste the iOS JSON and
Android JSON, Save. Linkrunner hosts them at:

- `https://your-domain.io/.well-known/apple-app-site-association`
- `https://your-domain.io/.well-known/assetlinks.json`

## Part C - native config for HTTP/HTTPS links

These are the same native manifest / Xcode changes as any other Cordova app -
Linkrunner's docs only show them for React Native and Flutter, but they are
framework-agnostic native project settings, not JS API calls.

### Android - `platforms/android/app/src/main/AndroidManifest.xml`, inside `<activity>`

```xml
<intent-filter android:autoVerify="true">
  <action android:name="android.intent.action.VIEW" />
  <category android:name="android.intent.category.DEFAULT" />
  <category android:name="android.intent.category.BROWSABLE" />
  <data android:scheme="https" android:host="app.example.com" />
</intent-filter>
```

### iOS - Xcode → Signing & Capabilities → Associated Domains

Open `platforms/ios/<AppName>.xcworkspace` in Xcode and add:

```
applinks:app.example.com
```

**Gotcha:** Cordova regenerates `platforms/android` and `platforms/ios` on
`cordova prepare` / `cordova platform add`, so edits made directly inside
`platforms/` are lost on the next prepare or a platform remove+re-add. Persist
them through `config.xml` using `<config-file>` / `<edit-config>` (see
[Apache Cordova's config.xml reference](https://cordova.apache.org/docs/en/latest/config_ref/index.html)),
for example:

```xml
<platform name="android">
  <config-file target="AndroidManifest.xml" parent="./application/activity[@android:name='MainActivity']">
    <intent-filter android:autoVerify="true">
      <action android:name="android.intent.action.VIEW" />
      <category android:name="android.intent.category.DEFAULT" />
      <category android:name="android.intent.category.BROWSABLE" />
      <data android:scheme="https" android:host="app.example.com" />
    </intent-filter>
  </config-file>
</platform>
```

Otherwise, just remember to reapply the manifest/Associated Domains change by
hand after every `cordova platform remove ios android && cordova platform add
ios android`.

## Custom URI scheme (no verification)

Android `<activity>` (same persistence gotcha as Part C applies):

```xml
<intent-filter>
  <action android:name="android.intent.action.VIEW" />
  <category android:name="android.intent.category.DEFAULT" />
  <category android:name="android.intent.category.BROWSABLE" />
  <data android:scheme="myapp" />
</intent-filter>
```

iOS `Info.plist`:

```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLName</key><string>com.example.myapp</string>
    <key>CFBundleURLSchemes</key><array><string>myapp</string></array>
  </dict>
</array>
```

## Testing

```bash
# Android
adb shell am start -a android.intent.action.VIEW -d "https://app.example.com/profile/123" your.package.name
# iOS simulator
xcrun simctl openurl booted "https://app.example.com/profile/123"
```

Note: typing a Universal Link in Safari never opens the app - tap it from
another app (e.g. Notes).

## Debugging (when HTTPS links open the browser)

- Android verification state: `adb shell pm get-app-links your.package.name`
  (`verified` = good; `1024`/`legacy_failure` = fingerprint or hosted-file
  problem). Clear + re-verify:
  ```bash
  adb shell pm set-app-links --package your.package.name 0 all
  adb shell pm verify-app-links --re-verify your.package.name
  ```
- iOS: devices fetch AASA from Apple's CDN, not your domain. Check the CDN:
  `curl -v https://app-site-association.cdn-apple.com/a/v1/your-domain.io`.
  If stale, use developer mode: set `applinks:your-domain.io?mode=developer`,
  enable **Settings → Developer → Associated Domains Development**, reinstall.

Run `scripts/verify-deeplinks.sh` to check most of this automatically. Full
debugging walkthrough:
https://docs.linkrunner.io/features/deep-linking-setup#debugging-domain-verification
