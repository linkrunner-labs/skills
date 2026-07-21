# Flutter install + initialization

Source of truth: https://docs.linkrunner.io/sdk/flutter

## 1. Add the package

```bash
flutter pub add linkrunner
```

This adds the latest `linkrunner` to `pubspec.yaml` and installs it. Confirm the
resolved version is **3.9.1+** so Android SharedPreferences encryption is on by
default.

## 2. Android configuration

`android/app/build.gradle` - ensure `minSdkVersion` is at least 21:

```gradle
android {
    defaultConfig {
        minSdkVersion 21
    }
}
```

`android/app/src/main/AndroidManifest.xml` - add permissions inside `<manifest>`:

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
```

The `AD_ID` permission ships inside the SDK and is required for GAID collection.
**Only** remove it if the app targets children (Google Play Families). To remove:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    xmlns:tools="http://schemas.android.com/tools">
    <uses-permission
        android:name="com.google.android.gms.permission.AD_ID"
        tools:node="remove" />
</manifest>
```

...and call `setDisableAaidCollection(true)` at runtime (SDK 3.5.0+).

## 3. iOS configuration

`ios/Podfile` - deployment target 15.0+:

```ruby
platform :ios, '15.0'
```

`ios/Runner/Info.plist` - App Tracking Transparency usage string:

```xml
<key>NSUserTrackingUsageDescription</key>
<string>This identifier will be used to deliver personalized ads and improve your app experience.</string>
```

Then `cd ios && pod install`.

## 4. Initialize (required, before anything else)

`init()` returns nothing. Attribution + deeplink data comes from
`getAttributionData()` later (see `references/events.md`).

```dart
import 'package:linkrunner/linkrunner.dart';

Future<void> initLinkrunner() async {
  try {
    await LinkRunner().init(
      'YOUR_PROJECT_TOKEN',
      'YOUR_SECRET_KEY', // optional - only for SDK signing
      'YOUR_KEY_ID',     // optional - only for SDK signing
      false,             // disable IDFA collection on iOS (default false)
      true,              // debug mode (default false) - turn off for release
    );
  } catch (e) {
    debugPrint('Error initializing LinkRunner: $e');
  }
}

@override
void initState() {
  WidgetsFlutterBinding.ensureInitialized(); // required
  super.initState();
  initLinkrunner();
}
```

**SDK signing** (optional, more secure): `secretKey` + `keyId` from
dashboard → Settings → SDK Signing. Supports per-platform keys via
`Platform.isIOS ? ... : ...`.

## 5. Verify install

- `flutter pub get` resolves cleanly
- App builds on both platforms
- With debug mode on, the SDK logs an init line on launch

Next: `references/events.md` (signup is required) and, if the user wants links
to open the app, `references/deep-linking.md`.
