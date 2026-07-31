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

## 5. Google Integrated Conversion Measurement (optional)

ICM recovers Google App Campaign installs on iOS that Google cannot attribute
because there is no click identifier and no IDFA to match on - the normal
state once a user declines App Tracking Transparency. Set this up if the app
runs Google App Campaigns. Requires **`rn-linkrunner` 3.1.0+**. See
[Google ICM](https://docs.linkrunner.io/features/google-icm) for how it works
and the required Google Ads iOS link ID (separate from this SDK config).

### Add Google's On-Device Measurement SDK (iOS)

`rn-linkrunner` does not bundle this - it is detected at runtime, so apps that
skip ICM carry none of its weight. Already on the Firebase iOS SDK 11.14.0+?
The `FirebaseAnalytics` pod already brings it in - skip this step. Otherwise
add it inside the app target in `ios/Podfile`:

```ruby
target 'YourApp' do
  # ...your existing config
  pod 'GoogleAdsOnDeviceConversion'
end
```

Then `cd ios && pod install`. CocoaPods adds the `-ObjC` and `-lc++` linker
flags automatically - no Build Settings changes needed.

### Report consent

Google's App Conversion API treats consent as required whenever its value is
known. Call `setConsent` **before** `init`, and again whenever the user's
choice changes. This applies on both iOS and Android - Android has no ODM SDK
to add, but its installs reach Google through the App Conversion API, which
reads the same signals:

```javascript
import linkrunner from "rn-linkrunner";

linkrunner.setConsent({
    isEEA: "granted",
    hasConsentForDataUsage: "granted",
    hasConsentForAdsPersonalization: "denied",
});

await linkrunner.init("YOUR_PROJECT_TOKEN");
```

| Parameter | Meaning |
| --- | --- |
| `isEEA` | European regulations apply to this user (the EEA, the UK, or Switzerland) |
| `hasConsentForDataUsage` | The user agreed to their data being sent to Google for advertising |
| `hasConsentForAdsPersonalization` | The user agreed to their data being used to personalize ads |

Each takes `"granted"`, `"denied"`, or `"unknown"`. Anything omitted or left
`"unknown"` is dropped from the payload rather than sent as a denial - never
map `unknown` to `granted`. **For users outside the EEA/UK/Switzerland, report
`isEEA` as denied and leave the other two unset.** Consent persists between
launches, so call `setConsent` again whenever it changes or the previous value
keeps being sent. See
[Send Consent](https://docs.linkrunner.io/features/send-consent).

### Verify

With debug mode on, look for this line in the Xcode console:

```
Linkrunner: odm_available=true odm_fetch_result=success odm_fetch_latency_ms=124
```

`odm_available=false odm_fetch_result=unavailable` means Google's SDK is not
linked - confirm `pod install` picked up `GoogleAdsOnDeviceConversion`.

## 6. Initialize (required, before anything else)

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

## 7. Verify install

- `npm install`/`yarn` resolves cleanly, `pod install` succeeds with no errors
- App builds on both platforms
- With debug mode on, the SDK logs an init line on launch

Next: `references/events.md` (signup is required) and, if the user wants links
to open the app, `references/deep-linking.md`.
