# Expo install + initialization

Source of truth: https://docs.linkrunner.io/sdk/expo (defers to
https://docs.linkrunner.io/sdk/react-native for all runtime API calls)

## 1. Install both packages

```bash
npm install rn-linkrunner

npx expo install expo-linkrunner
```

`rn-linkrunner` provides every runtime call. `expo-linkrunner` is a **config
plugin only** - it exists to wire up native config during prebuild, not to be
imported at runtime.

## 2. Add the plugin to app.json

```json
{
    "expo": {
        "plugins": [
            [
                "expo-linkrunner",
                {
                    "userTrackingPermission": "This identifier will be used to deliver personalized ads.",
                    "debug": true
                }
            ]
        ]
    }
}
```

What the plugin does to your iOS project on prebuild:

- Adds `NSUserTrackingUsageDescription` to `Info.plist` if not already present
  (uses the `userTrackingPermission` string above).
- Automatically applies the `expo-tracking-transparency` plugin with that
  message.

These are required for IDFA collection and Apple's App Tracking Transparency
(ATT) compliance. The doc does not describe any Android-side native changes
made by the plugin itself.

## 3. SKAdNetwork configuration (manual - the plugin does not add this)

To enable SKAdNetwork postback copies to be sent to Linkrunner, add these two
keys to your iOS `Info.plist`. The `expo-linkrunner` config plugin only adds
`NSUserTrackingUsageDescription` - it does not add these, so set them yourself
via `expo.ios.infoPlist` in `app.json` (or `app.config.js`):

```json
{
    "expo": {
        "ios": {
            "infoPlist": {
                "NSAdvertisingAttributionReportEndpoint": "https://linkrunner-skan.com",
                "AttributionCopyEndpoint": "https://linkrunner-skan.com"
            }
        }
    }
}
```

These merge into `Info.plist` on the next `expo prebuild` - do not hand-edit
`ios/*/Info.plist` directly if `ios/` is gitignored (CNG), it will be
overwritten. For complete SKAdNetwork integration details, see the
[SKAdNetwork Integration Guide](https://docs.linkrunner.io/features/skadnetwork-integration).

## 4. Prebuild your project

- **EAS Build**, with `android`/`ios` gitignored (recommended): prebuild runs
  automatically as part of the build. No manual action needed.
- **Local development or a custom dev client**:

  ```bash
  npx expo prebuild
  ```

**Expo Go will not work.** The SDK relies on native libraries, so you need a
[development build](https://docs.expo.dev/develop/development-builds/introduction/).

## 5. Android backup configuration (manual - the plugin does not add this)

The SDK excludes its SharedPreferences (the persisted install ID) from Android
backup/restore, so a restored device is correctly detected as a new install
rather than inheriting the old one. This is the same rule across every
Linkrunner SDK, and the Expo doc points at the native Android instructions for
it - it is **not** something `expo-linkrunner`'s plugin adds automatically.

In `android/app/src/main/AndroidManifest.xml`, inside `<application>`:

```xml
<application
    android:fullBackupContent="@xml/linkrunner_backup_descriptor"
    android:dataExtractionRules="@xml/linkrunner_backup_rules">
    <!-- Your app content -->
</application>
```

- `android:fullBackupContent` - Android 6-11
- `android:dataExtractionRules` - Android 12+

If you already have your own backup rules, merge the exclude entries into your
existing files instead of replacing them:

`res/xml/my_backup_descriptor.xml` (legacy, Android 6-11):

```xml
<full-backup-content>
    <exclude domain="sharedpref" path="io.linkrunner.sdk_prefs"/>
</full-backup-content>
```

`res/xml/my_backup_rules.xml` (modern, Android 12+):

```xml
<data-extraction-rules>
    <cloud-backup>
        <exclude domain="sharedpref" path="io.linkrunner.sdk_prefs"/>
    </cloud-backup>
    <device-transfer>
        <exclude domain="sharedpref" path="io.linkrunner.sdk_prefs"/>
    </device-transfer>
</data-extraction-rules>
```

**If `android/` is gitignored (CNG)**, editing these files directly does not
survive the next `expo prebuild`. Either check `android/` into version control
so it's no longer regenerated, or write a small custom config plugin (using
`withAndroidManifest` / `withDangerousMod` from `@expo/config-plugins`) that
injects the manifest attributes and XML resource files on every prebuild.

## 6. Initialize (required, before anything else)

All runtime calls come from `rn-linkrunner`, imported directly - identical to
the React Native SDK. `init()` returns nothing; read attribution later via
`getAttributionData()` (see `references/events.md`).

```javascript
import linkrunner from "rn-linkrunner";
import { useEffect } from "react";

// Inside your root component (App.tsx, or app/_layout.tsx for expo-router)
useEffect(() => {
    init();
}, []); // empty dependency array - run once

const init = async () => {
    await linkrunner.init(
        "YOUR_PROJECT_TOKEN",
        "YOUR_SECRET_KEY", // optional - only for SDK signing
        "YOUR_KEY_ID", // optional - only for SDK signing
        false, // optional - disable IDFA collection on iOS (default false)
        true // optional - debug mode (default false) - turn off for release
    );
    console.log("Linkrunner initialized");
};
```

**SDK signing** (optional, more secure): `secretKey` + `keyId` from
dashboard → Settings → SDK Signing.

## 7. Verify install

- `npx expo prebuild` completes without errors (or EAS Build succeeds)
- The app runs on a development build on both platforms
- With `debug: true` on the plugin (or debug mode `true` in `init`), Linkrunner
  logs an init line on launch

Next: `references/events.md` (signup is required) and, if the user wants links
to open the app, `references/deep-linking.md`.
