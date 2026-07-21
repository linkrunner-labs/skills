# Cordova install + initialization

Source of truth: https://docs.linkrunner.io/sdk/cordova

## 1. Add prerequisites to config.xml (before adding platforms)

```xml
<widget id="com.your.app" ...>
    <!-- Required: iOS minimum deployment target (Linkrunner requires iOS 15+) -->
    <preference name="deployment-target" value="15.0" />

    <!-- Required: Enable Kotlin support for Android -->
    <preference name="GradlePluginKotlinEnabled" value="true" />
    <preference name="GradlePluginKotlinCodeStyle" value="official" />
</widget>
```

These preferences **must** be set before running `cordova platform add ios` or
`cordova platform add android`. If the platforms are already added, remove and
re-add them after updating `config.xml`:

```bash
cordova platform remove ios android
cordova platform add ios android
```

## 2. Install the plugin

```bash
cordova plugin add cordova-linkrunner
```

This single command handles everything automatically:

- Downloads the package from npm
- Copies native Swift/Kotlin bridge code into your project
- Adds the iOS pod dependency (LinkrunnerKit)
- Adds the Android gradle dependency (Linkrunner android-sdk)
- Injects iOS Info.plist entries (SKAN endpoints, tracking description)
- Registers the JS module globally as `window.linkrunner`

### What the plugin auto-configures

No manual editing of `Info.plist` or `build.gradle` is required - `plugin.xml`
does it for you:

**iOS (auto-injected into Info.plist):**

```xml
<key>NSUserTrackingUsageDescription</key>
<string>This identifier will be used to deliver personalized ads to you.</string>

<key>NSAdvertisingAttributionReportEndpoint</key>
<string>https://linkrunner-skan.com</string>

<key>AttributionCopyEndpoint</key>
<string>https://linkrunner-skan.com</string>
```

- LinkrunnerKit pod dependency (iOS 15+)

**Android (auto-injected into build.gradle and AndroidManifest.xml):**

- Linkrunner SDK gradle dependency
- Kotlin stdlib and coroutines dependencies
- `android.permission.INTERNET` and `android.permission.ACCESS_NETWORK_STATE` permissions
- Backup rules exclusion for SharedPreferences

For complete SKAdNetwork integration details, see the
[SKAdNetwork Integration Guide](https://docs.linkrunner.io/features/skadnetwork-integration).
For detailed Android backup configuration, see
[Android SDK Backup Configuration](https://docs.linkrunner.io/sdk/android#backup-configuration).

## 3. Initialize (required, before anything else)

No import or require is needed - `linkrunner` is globally available on
`window` once the plugin is installed. Initialize inside the `deviceready`
event.

`init()` resolves with no value. Attribution + deeplink data comes from
`getAttributionData()` later (see `references/events.md`).

```javascript
document.addEventListener('deviceready', function () {

    linkrunner.init({
        token: "YOUR_PROJECT_TOKEN",
        secretKey: "YOUR_SECRET_KEY", // Optional: Required for SDK signing
        keyId: "YOUR_KEY_ID", // Optional: Required for SDK signing
        disableIdfa: false, // Optional: disable IDFA collection on iOS (default false)
        debug: true // Optional: enable debug mode for development (default false)
    }).then(function () {
        console.log("Linkrunner initialized");
    }).catch(function (error) {
        console.error("Linkrunner init failed:", error);
    });

}, false);
```

Find your project token at
[dashboard → Settings → Project Details](https://dashboard.linkrunner.io/dashboard/settings/project-details).

**SDK signing** (optional, more secure): `secretKey` + `keyId` from
[dashboard → Settings → SDK Signing](https://dashboard.linkrunner.io/settings?s=sdk-signing).

Turn `debug` off before shipping a release build.

## 4. Verify install

- `cordova plugin list` shows `cordova-linkrunner`
- App builds on both platforms after `cordova prepare`
- With debug mode on, the SDK logs an init line on launch

Next: `references/events.md` (signup is required) and, if the user wants links
to open the app, `references/deep-linking.md`.
