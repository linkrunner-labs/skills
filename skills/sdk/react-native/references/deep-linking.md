# React Native deep linking

Source of truth: https://docs.linkrunner.io/features/deep-linking-setup
(React Native tab) and https://docs.linkrunner.io/sdk/react-native#handle-deeplink

Two approaches:

- **HTTP/HTTPS** (App Links on Android, Universal Links on iOS) - requires
  domain verification. This is what most campaigns use.
- **Custom URI scheme** (`myapp://`) - no verification, simpler, good as a
  fallback.

The most common failure is that the app code is correct but domain
verification never passes, so links open the browser instead. Do the
verification parts carefully and finish with `scripts/verify-deeplinks.sh`.

## Part A - capture deep links into the SDK (both approaches need this)

Uses React Native's built-in `Linking` module. This is what powers
remarketing/reattribution.

```javascript
import { useEffect } from 'react';
import { Linking } from 'react-native';
import linkrunner from 'rn-linkrunner';

function App() {
  useEffect(() => {
    // Cold start - app was launched by a deeplink
    Linking.getInitialURL().then((url) => {
      if (url) {
        linkrunner.handleDeeplink(url);
      }
    });

    // Warm start - app was in background, deeplink brought it to foreground
    const subscription = Linking.addEventListener('url', ({ url }) => {
      linkrunner.handleDeeplink(url);
    });

    return () => subscription.remove();
  }, []);

  return (
    // your app content
  );
}
```

Linkrunner sends the updated deeplink back after processing:

```json
{ "deeplink": "https://app.yourdomain.com/product/123" }
```

For Linkrunner campaign links, use the returned `deeplink` as the resolved
destination instead of the original tracking URL.

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

Debug and release keystores produce **different** fingerprints. List both in
the array, or use the Play Console fingerprint (**Play Console → Setup → App
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

`TEAM_ID` from Apple Developer → Membership; `BUNDLE_ID` from Xcode.

### Host them in Linkrunner

Dashboard → **Project Settings → Domain Verification**: paste the iOS JSON and
Android JSON, Save. Linkrunner hosts them at:

- `https://your-domain.io/.well-known/apple-app-site-association`
- `https://your-domain.io/.well-known/assetlinks.json`

## Part C - native config for HTTP/HTTPS links

### Android - `android/app/src/main/AndroidManifest.xml`, inside `<activity>`

```xml
<intent-filter android:autoVerify="true">
  <action android:name="android.intent.action.VIEW" />
  <category android:name="android.intent.category.DEFAULT" />
  <category android:name="android.intent.category.BROWSABLE" />
  <!-- Your domain and subdomains -->
  <data android:scheme="https" android:host="app.example.com" />
</intent-filter>
```

### iOS - Xcode → Signing & Capabilities → Associated Domains

```
applinks:app.example.com
```

## Part D - navigation (React Navigation)

React Native uses [React Navigation](https://reactnavigation.org/) for
handling deep links via its `linking` prop:

```javascript
// App.js or your navigation configuration file
import { NavigationContainer } from "@react-navigation/native";
import { createStackNavigator } from "@react-navigation/stack";

const Stack = createStackNavigator();

function App() {
  const linking = {
    prefixes: [
      "https://example.com",
      "https://app.example.com",
      "https://store.example.com",
    ],
    config: {
      screens: {
        Home: "",
        Profile: "profile/:id",
        Store: {
          path: "store/:category?",
          parse: {
            category: (category) => category || "all",
          },
        },
      },
    },
  };

  return (
    <NavigationContainer linking={linking}>
      <Stack.Navigator>{/* Your screens */}</Stack.Navigator>
    </NavigationContainer>
  );
}

export default App;
```

The `linking` prop only controls React Navigation's own routing - it does not
call into the Linkrunner SDK. Keep the `Linking` listener from Part A mounted
alongside it (they don't conflict) so `handleDeeplink` still fires on every
cold/warm start regardless of which screen React Navigation resolves to.

## Custom URI scheme (no verification)

Android `<activity>`:

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
# Android
adb shell am start -a android.intent.action.VIEW -d "https://app.example.com/profile/123" your.package.name
adb shell am start -a android.intent.action.VIEW -d "myapp://profile/123" your.package.name
# iOS simulator
xcrun simctl openurl booted "https://app.example.com/profile/123"
xcrun simctl openurl booted "myapp://profile/123"
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

Run `scripts/verify-deeplinks.sh` to check most of this automatically.
