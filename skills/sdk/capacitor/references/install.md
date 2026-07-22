# Capacitor install + initialization

Source of truth: https://docs.linkrunner.io/sdk/capacitor

## 1. Add the package

```bash
npm install capacitor-linkrunner
# or
yarn add capacitor-linkrunner
```

## 2. Sync native projects

```bash
npx cap sync
```

Required any time the package is added or updated - Capacitor won't pick up
the native plugin otherwise.

## 3. iOS configuration

If the app targets iOS, install pods for the package:

```bash
cd ios/App && pod install
```

`ios/App/App/Info.plist` - App Tracking Transparency usage string:

```xml
<key>NSUserTrackingUsageDescription</key>
<string>This identifier will be used to deliver personalized ads and improve your app experience.</string>
```

## 4. SKAdNetwork configuration (iOS)

To enable SKAdNetwork postback copies to be sent to Linkrunner, add these keys
to `ios/App/App/Info.plist`:

```xml
<key>NSAdvertisingAttributionReportEndpoint</key>
<string>https://linkrunner-skan.com</string>
<key>AttributionCopyEndpoint</key>
<string>https://linkrunner-skan.com</string>
```

Full setup: https://docs.linkrunner.io/features/skadnetwork-integration

## 5. Android backup configuration

The SDK provides backup rules to exclude its SharedPreferences from Android
backup. This prevents the Linkrunner install ID from surviving a backup/restore,
so reinstalls and re-installs are detected correctly. Full XML rules:
https://docs.linkrunner.io/sdk/android#backup-configuration

## 6. Android configuration - Kotlin Gradle plugin

The Capacitor SDK ships a native Kotlin module and requires the Kotlin Gradle
plugin. Add it to the root `build.gradle` under `dependencies`:

```gradle
buildscript {
    dependencies {
        classpath "org.jetbrains.kotlin:kotlin-gradle-plugin:$kotlin_version"
    }
}
```

Check whether the project already declares `kotlin_version` (common in
Capacitor/Ionic Android projects); if not, pin one, e.g.:

```gradle
buildscript {
    dependencies {
        classpath "org.jetbrains.kotlin:kotlin-gradle-plugin:1.9.22"
    }
}
```

Without this, the Android build fails - check for it before assuming the
integration is broken elsewhere.

## 7. Initialize (required, before anything else)

`init()` returns nothing. Attribution + deeplink data comes from
`getAttributionData()` later (see `references/events.md`). Call it from the
same place the app initializes other Capacitor plugins.

```typescript
import linkrunner from "capacitor-linkrunner";

const init = async () => {
    await linkrunner.init(
        "YOUR_PROJECT_TOKEN",
        "YOUR_SECRET_KEY", // Optional: Required for SDK signing
        "YOUR_KEY_ID", // Optional: Required for SDK signing
        false, // Optional: disable IDFA collection on iOS (defaults to false)
        true // Optional: debug mode (defaults to false) - turn off for release
    );
    console.log("Linkrunner initialized");
};

init();
```

**SDK signing** (optional, more secure): `secretKey` + `keyId` from
dashboard → Settings → SDK Signing.

## 8. Verify install

- `npm install` / `yarn` resolves cleanly and `npx cap sync` completes without
  errors
- App builds on both platforms (Android build fails immediately if the Kotlin
  Gradle plugin step above was skipped)
- With debug mode on, the SDK logs an init line on launch

Next: `references/events.md` (signup is required) and, if the user wants links
to open the app, `references/deep-linking.md`.
