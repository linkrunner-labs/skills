# Flutter deep linking

Source of truth: https://docs.linkrunner.io/features/deep-linking-setup

Two approaches:

- **HTTP/HTTPS** (App Links on Android, Universal Links on iOS) - requires
  domain verification. This is what most campaigns use.
- **Custom URI scheme** (`myapp://`) - no verification, simpler, good as a
  fallback.

The most common failure is that the app code is correct but domain verification
never passes, so links open the browser instead. Do the verification parts
carefully and finish with `scripts/verify-deeplinks.sh`.

## Part A - capture deep links into the SDK (both approaches need this)

Uses the `app_links` package. This is what powers remarketing/reattribution.

```bash
flutter pub add app_links
```

```dart
import 'package:app_links/app_links.dart';
import 'package:linkrunner/linkrunner.dart';

final _appLinks = AppLinks();

Future<void> _initLinkRunner() async {
  await LinkRunner().init('YOUR_PROJECT_TOKEN'); // init first

  // Cold start - app launched by a deeplink
  final initialLink = await _appLinks.getInitialLink();
  if (initialLink != null) {
    LinkRunner().handleDeeplink(initialLink.toString());
  }

  // Warm start - deeplink while app was backgrounded
  _appLinks.uriLinkStream.listen((Uri uri) {
    LinkRunner().handleDeeplink(uri.toString());
  });
}
```

Linkrunner returns a resolved `deeplink` after processing. For Linkrunner
campaign links, navigate to the **returned** deeplink, not the original tracking
URL.

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
  <data android:scheme="https" android:host="app.example.com" />
</intent-filter>
```

### iOS - Xcode → Signing & Capabilities → Associated Domains

```
applinks:app.example.com
```

## Part D - navigation (go_router example)

```dart
final GoRouter _router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (c, s) => HomeScreen()),
    GoRoute(path: '/profile/:id',
      builder: (c, s) => ProfileScreen(id: s.params['id']!)),
  ],
);

// MaterialApp.router(routerConfig: _router)
```

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

Run `scripts/verify-deeplinks.sh` to check most of this automatically.
