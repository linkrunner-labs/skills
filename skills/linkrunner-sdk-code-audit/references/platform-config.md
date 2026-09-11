# Platform configuration: what to check and what each omission breaks

App code is only half the integration. Deep links, install-id integrity, and iOS attribution all live in
config files, and they fail *silently* - which is why they survive so long in shipped apps. Every stack
has an `android/` and `ios/` project underneath, so these checks apply to Flutter, RN, Expo, Capacitor and
Cordova apps too, not only native ones.

## Android - `AndroidManifest.xml`

Audit `app/src/main/AndroidManifest.xml`. **Build-variant overlays** (`src/debug/`, `src/release/`,
`src/<flavor>/`) are *merged* into it, so something "missing" from an overlay is normal - never report it.
Library manifests also merge in, which is why the `AD_ID` permission appears without the app declaring it.

| Check | Grep | If absent |
|---|---|---|
| `android.permission.INTERNET` | `grep INTERNET` | No SDK call can leave the device. Total failure. |
| `ACCESS_NETWORK_STATE` | `grep ACCESS_NETWORK_STATE` | The SDK can't detect connectivity for queue/retry - calls are lost on flaky networks instead of retried. |
| Backup exclusion (`android:fullBackupContent`, `android:dataExtractionRules`) | `grep -E 'fullBackupContent\|dataExtractionRules'` | The install id is restored from cloud backup onto a new device, so a **fresh install is counted as a returning user**. Attribution and reinstall detection both degrade. |
| `<intent-filter android:autoVerify="true">` with your `https` host(s) | `grep -A6 autoVerify` | App Links don't verify → links open the browser instead of the app. |
| `asset_statements` meta-data + `res/values/strings.xml` entry | `grep asset_statements` | The Linkrunner redirect page can't detect the app is installed, so no "Continue to app" popup. |
| `AD_ID` permission | `grep permission.AD_ID` | Present by default (from the SDK). Only expect `tools:node="remove"` in a Designed-for-Families app - and then `setDisableAaidCollection` should also be called. |
| The `Application` class is registered | `grep 'android:name="\.'` | A native `Application.onCreate` init never runs if the class isn't declared. |

**Backup rules - the merge case.** If the app already points at its own backup files, the exclusion must be
added *inside them*, not by overwriting the attribute. Open the referenced `res/xml/*.xml` and check for:

```xml
<!-- res/xml/<their file>.xml, Android 6-11 -->
<full-backup-content>
  <exclude domain="sharedpref" path="io.linkrunner.sdk_prefs"/>
</full-backup-content>

<!-- Android 12+ -->
<data-extraction-rules>
  <cloud-backup><exclude domain="sharedpref" path="io.linkrunner.sdk_prefs"/></cloud-backup>
  <device-transfer><exclude domain="sharedpref" path="io.linkrunner.sdk_prefs"/></device-transfer>
</data-extraction-rules>
```
An app that sets `android:fullBackupContent="@xml/my_rules"` and never adds the exclude is the common
half-configured state - the attribute is present, the rule is not. Check the file, not just the attribute.

**Deep-link intent filters.** Verify the hosts listed match the domains actually used for campaign links
(including the Linkrunner subdomain), that `autoVerify="true"` is on the `https` filter, and that custom
schemes sit in their **own** intent-filter - mixing a custom scheme into the `autoVerify` filter can break
verification for the whole filter.

```bash
grep -n -A8 "intent-filter" app/src/main/AndroidManifest.xml | grep -E "autoVerify|scheme|host|action|category"
```
Every App Links filter needs `VIEW` + `DEFAULT` + `BROWSABLE`; missing `BROWSABLE` means links from a
browser never reach the app.

## Android - Gradle

- The dependency and its version (`io.linkrunner:android-sdk:x.y.z`) - see `detect-stack.md` §4.
- `mavenCentral()` present in the repositories block.
- `minSdk` ≥ 21.
- **R8/ProGuard**: check `proguard-rules.pro` for any rule stripping or renaming SDK classes. Rare, but a
  broken release build that works in debug points straight here.

## iOS - `Info.plist`, entitlements, Podfile

| Check | Where | If absent |
|---|---|---|
| `NSUserTrackingUsageDescription` | `Info.plist` | The app can never show the ATT prompt, so IDFA is always unavailable - a large attribution accuracy loss. |
| `NSAdvertisingAttributionReportEndpoint` + `AttributionCopyEndpoint` = `https://linkrunner-skan.com` | `Info.plist` | No SKAdNetwork postback copies reach Linkrunner. |
| `CFBundleURLTypes` / `CFBundleURLSchemes` | `Info.plist` | Custom-scheme deep links don't open the app. |
| `com.apple.developer.associated-domains` with `applinks:<host>` | `*.entitlements` | Universal Links silently open Safari. **No entitlements file at all** means Universal Links cannot work. |
| `LinkrunnerKit` dependency | `Package.swift` / `Podfile` / `Package.resolved` | - |
| `pod 'GoogleAdsOnDeviceConversion'` | `Podfile` | Only needed for Google ICM; absent is fine unless the team runs Google App Campaigns on iOS (then `setConsent` alone does nothing). |

The associated-domains entries must list every host used in campaign links, including the Linkrunner
subdomain. Apple's `applinks:` entry must match the host exactly (no scheme, no path).

```bash
find . -name "*.entitlements" -not -path "*/Pods/*" -exec grep -l associated-domains {} \; 
grep -oE "applinks:[^<]*" **/*.entitlements 2>/dev/null
```

Note that Associated Domains can also be configured in Xcode's Signing & Capabilities UI - which writes
the entitlements file. If you see the capability in `project.pbxproj` but no entitlements file, say the
configuration is inconsistent rather than guessing.

## Expo - the config plugin

Expo apps have no checked-in `android/`/`ios/` unless prebuilt, so the config lives in `app.json` /
`app.config.js`:

```jsonc
{
  "expo": {
    "scheme": "myapp",                       // custom URI scheme
    "plugins": ["expo-linkrunner"],          // the plugin must be listed
    "ios":     { "associatedDomains": ["applinks:example.com"] },
    "android": { "intentFilters": [ { "autoVerify": true, "data": [{ "scheme": "https", "host": "example.com" }] } ] }
  }
}
```
Check: the plugin is in `plugins`, `scheme` is set, and both `associatedDomains` and `intentFilters` are
declared. Expo also requires **development builds** - the SDK is native, so it cannot work in Expo Go.
If the repo's scripts only ever run Expo Go, note it.

If the project *has been* prebuilt (an `android/`/`ios/` directory exists), audit the generated files too,
and flag any hand-edit there as fragile - the next `prebuild --clean` erases it.

## Cordova / Capacitor

- **Cordova:** the plugin declared in `config.xml`; deep-link scheme/host preferences present; and the
  `deviceready` requirement from `call-site-analysis.md` §3.
- **Capacitor:** `capacitor.config.*` for `appId`/`server` settings, plus the native projects, which are
  checked in and fully in scope.

## Uninstall tracking (if the team uses it)

Mostly dashboard-side, with one code-side requirement worth checking:
`setPushToken` must be called from the **token-refresh callback** (`onNewToken` on Android FCM,
`didRegisterForRemoteNotificationsWithDeviceToken` on iOS), not only once at startup. A token that rotates
after the single startup call leaves a stale token and silently degrades uninstall detection.

```bash
grep -rn "onNewToken\|getToken()\|onTokenRefresh\|didRegisterForRemoteNotifications" --exclude-dir=node_modules .
```
Check that the Linkrunner `setPushToken` call sits inside those handlers.

## Reporting config findings

Config omissions are worth reporting even when every call site is perfect - they are often the actual
reason attribution "isn't working." For each, give: the file, the missing element, **what breaks in user
terms** ("links open the browser instead of the app"), and the exact snippet to add. Severity should track
user impact: a missing `INTERNET` permission or an un-verified App Link is critical; a missing SKAN
endpoint matters only to iOS ad spend; a missing backup rule is a slow data-quality leak.
