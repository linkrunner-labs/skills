# Expo deep linking

Source of truth: https://docs.linkrunner.io/features/deep-linking-setup

Two approaches:

- **HTTP/HTTPS** (App Links on Android, Universal Links on iOS) - requires
  domain verification. This is what most campaigns use.
- **Custom URI scheme** (`myapp://`) - no verification, simpler, good as a
  fallback.

The most common failure is that the app config looks correct but domain
verification never passes, so links open the browser instead. On Expo there is
a second common failure: the config was added to `app.json` but the project
was never re-prebuilt, so the installed build doesn't have it yet. Do the
verification parts carefully and finish with `scripts/verify-deeplinks.sh`.

## Part A - capture deep links into the SDK (both approaches need this)

The Linkrunner call is `handleDeeplink` from `rn-linkrunner` - identical to the
React Native SDK. Feed it URLs from the standard `Linking` API (from
`react-native`, which works the same inside Expo).

```javascript
import { useEffect } from "react";
import { Linking } from "react-native";
import linkrunner from "rn-linkrunner";

useEffect(() => {
    // Cold start - app launched by a deeplink
    Linking.getInitialURL().then((url) => {
        if (url) {
            linkrunner.handleDeeplink(url);
        }
    });

    // Warm start - deeplink while app was backgrounded
    const subscription = Linking.addEventListener("url", ({ url }) => {
        linkrunner.handleDeeplink(url);
    });

    return () => subscription.remove();
}, []);
```

Put this in the root component - `app/_layout.tsx` for expo-router, or
`App.tsx` otherwise - after `init()` has run. Linkrunner returns a resolved
`deeplink` after processing. For Linkrunner campaign links, navigate to the
**returned** deeplink, not the original tracking URL.

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
# release, or the EAS-managed keystore
keytool -list -v -keystore your_release_keystore.keystore -alias your_key_alias
```

Debug and release keystores produce **different** fingerprints. If you use EAS
Build's managed credentials, get the fingerprint from `eas credentials`
(Android → your build profile) or the Play Console. List both debug and
release fingerprints in the array so both verify.

### iOS - `apple-app-site-association` (no extension)

```json
{
    "applinks": {
        "apps": [],
        "details": [{ "appID": "TEAM_ID.BUNDLE_ID", "paths": ["/*"] }]
    }
}
```

`TEAM_ID` from Apple Developer → Membership; `BUNDLE_ID` is your app's
`expo.ios.bundleIdentifier` in `app.json`.

### Host them in Linkrunner

Dashboard → **Project Settings → Domain Verification**: paste the iOS JSON and
Android JSON, Save. Linkrunner hosts them at:

- `https://your-domain.io/.well-known/apple-app-site-association`
- `https://your-domain.io/.well-known/assetlinks.json`

## Part C - native config for HTTP/HTTPS links

On Expo, configure this through `app.json` rather than editing native files
directly - if `android/`/`ios/` are gitignored (Continuous Native Generation),
hand-edited `AndroidManifest.xml` / entitlements get overwritten on the next
`expo prebuild`.

`app.json`:

```json
{
    "expo": {
        "ios": {
            "bundleIdentifier": "com.example.myapp",
            "associatedDomains": ["applinks:app.example.com"]
        },
        "android": {
            "package": "com.example.myapp",
            "intentFilters": [
                {
                    "action": "VIEW",
                    "autoVerify": true,
                    "data": [{ "scheme": "https", "host": "app.example.com" }],
                    "category": ["BROWSABLE", "DEFAULT"]
                }
            ]
        }
    }
}
```

This is Expo's standard config schema for Associated Domains /
`intentFilters` (not Linkrunner-specific) - see
[Expo's app config reference](https://docs.expo.dev/versions/latest/config/app/)
if you need more than one domain or path. After changing it, run
`npx expo prebuild` (or a fresh EAS build) so the native projects regenerate
with the new config - the change does nothing until then.

If `android/`/`ios/` are committed and no longer regenerated (bare-ish
workflow), you can instead edit the native files directly, the same way the
[React Native / Flutter guide](https://docs.linkrunner.io/features/deep-linking-setup#step-3-update-native-configuration)
describes:

- Android `AndroidManifest.xml`, inside `<activity>`: an `<intent-filter
  android:autoVerify="true">` with the same `<data>` entries.
- iOS: Xcode → Signing & Capabilities → Associated Domains → `applinks:app.example.com`.

## Part D - navigation

### expo-router

With expo-router, file-based routes under `app/` already match your URL
paths once `expo.scheme` (custom scheme) and the Associated
Domains/`intentFilters` above are set - a Universal Link to
`https://app.example.com/profile/123` opens `app/profile/[id].tsx` with no
extra linking config. Read the id with `useLocalSearchParams()`.

If a link's host needs to map to a different route root (e.g.
`store.example.com` should resolve under a different top-level route), handle
it in the same place you call `handleDeeplink` (Part A): inspect the resolved
URL and use `router.replace()` / `router.push()` to send the user to the right
screen after Linkrunner processes the link.

### Classic React Navigation (no expo-router)

Use the same `linking` config as the plain React Native guide:

```javascript
import { NavigationContainer } from "@react-navigation/native";

const linking = {
    prefixes: ["https://app.example.com", "myapp://"],
    config: {
        screens: {
            Home: "",
            Profile: "profile/:id",
        },
    },
};

<NavigationContainer linking={linking}>{/* screens */}</NavigationContainer>;
```

## Custom URI scheme (no verification)

Set the top-level `scheme` in `app.json` - Expo wires this into both native
projects on prebuild automatically, no manual manifest/plist edits needed:

```json
{
    "expo": {
        "scheme": "myapp"
    }
}
```

Then `npx expo prebuild` to regenerate the native projects with the scheme
registered.

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

- First, confirm the build under test actually has the config: if
  `android/`/`ios/` are gitignored, a stale dev build predates your `app.json`
  change. Re-run `npx expo prebuild` and reinstall.
- Android verification state: `adb shell pm get-app-links your.package.name`
  (`verified` = good; `1024`/`legacy_failure` = fingerprint or hosted-file
  problem). Clear + re-verify:
  ```bash
  adb shell pm set-app-links --package your.package.name 0 all
  adb shell pm verify-app-links --re-verify your.package.name
  ```
- iOS: devices fetch AASA from Apple's CDN, not your domain. Check the CDN:
  `curl -v https://app-site-association.cdn-apple.com/a/v1/your-domain.io`.
  If stale, use developer mode: set `applinks:your-domain.io?mode=developer` in
  `app.json`'s `associatedDomains`, enable **Settings → Developer →
  Associated Domains Development** on the device, prebuild, and reinstall.

Run `scripts/verify-deeplinks.sh` to check most of this automatically.
