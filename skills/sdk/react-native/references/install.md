# React Native install + initialization

Source of truth: https://docs.linkrunner.io/sdk/react-native

## 1. Add the package

```bash
npm install rn-linkrunner
# or
yarn add rn-linkrunner
```

## 2. iOS configuration

```bash
cd ios && pod install
```

`ios/<App>/Info.plist` - App Tracking Transparency usage string:

```xml
<key>NSUserTrackingUsageDescription</key>
<string>This identifier will be used to deliver personalized ads and improve your app experience.</string>
```

SKAdNetwork postback copies (optional, needed for iOS SKAN attribution) - add
to the same `Info.plist`:

```xml
<key>NSAdvertisingAttributionReportEndpoint</key>
<string>https://linkrunner-skan.com</string>
<key>AttributionCopyEndpoint</key>
<string>https://linkrunner-skan.com</string>
```

Full setup: https://docs.linkrunner.io/features/skadnetwork-integration

## 3. Android configuration

The SDK ships backup rules that exclude its SharedPreferences from Android
auto-backup, so the install ID isn't retained across a reinstall (which would
hide a real reinstall as an existing install). If the app has its own custom
backup rules, merge in the SDK's - see
https://docs.linkrunner.io/sdk/android#backup-configuration for the exact rule.

From `rn-linkrunner` **v2.10.1+**, values the SDK writes to SharedPreferences
are encrypted at rest with a hardware-protected key in the Android Keystore -
no config needed, just confirm the resolved version is 2.10.1 or above. On an
upgrade from an older version, existing plaintext entries are migrated
transparently on the next read.

## 4. Expo (dev builds only)

If the app uses Expo, install the package the same way, then switch to a
**development build** - the SDK relies on native modules and does not work in
Expo Go. See https://docs.expo.dev/develop/development-builds/introduction/.
(An Expo managed project using the config plugin is the `linkrunner-expo`
skill, not this one.)

## 5. Initialize (required, before anything else)

`init()` returns nothing. Attribution + deeplink data comes from
`getAttributionData()` later (see `references/events.md`).

```javascript
import linkrunner from "rn-linkrunner";

// Inside your App.tsx component
useEffect(() => {
  init();
}, []); // empty dependency array - run once

const init = async () => {
  await linkrunner.init(
    "YOUR_PROJECT_TOKEN",
    "YOUR_SECRET_KEY", // optional - only for SDK signing
    "YOUR_KEY_ID",     // optional - only for SDK signing
    false,             // disable IDFA collection on iOS (default false)
    true               // debug mode (default false) - turn off for release
  );
};
```

**SDK signing** (optional, more secure): `secretKey` + `keyId` from
dashboard → Settings → SDK Signing.

## 6. Verify install

- `npm install`/`yarn` resolves cleanly, `pod install` succeeds with no errors
- App builds on both platforms
- With debug mode on, the SDK logs an init line on launch

Next: `references/events.md` (signup is required) and, if the user wants links
to open the app, `references/deep-linking.md`.
