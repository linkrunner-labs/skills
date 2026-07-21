# Android deep linking

Source of truth: https://docs.linkrunner.io/features/deep-linking-setup and
https://docs.linkrunner.io/sdk/android

Two approaches:

- **HTTP/HTTPS** (App Links) - requires domain verification. This is what
  most campaigns use.
- **Custom URI scheme** (`myapp://`) - no verification, simpler, good as a
  fallback.

The most common failure is that the app code is correct but domain
verification never passes, so links open the browser instead. Do the
verification parts carefully and finish with `scripts/verify-deeplinks.sh`.

## Part A - capture deep links into the SDK (both approaches need this)

This is what powers [remarketing/reattribution](https://docs.linkrunner.io/features/remarketing) -
it lets Linkrunner detect returning users who open the app via a deep link.
Handle both cold start (app launched by the link) and warm start (app already
running, link arrives via `onNewIntent`):

```kotlin
class MainActivity : AppCompatActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        // Cold start deeplink
        handleDeeplinkFromIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)

        // Warm start deeplink
        handleDeeplinkFromIntent(intent)
    }

    private fun handleDeeplinkFromIntent(intent: Intent) {
        intent.data?.let { uri ->
            lifecycleScope.launch {
                LinkRunner.getInstance().handleDeeplink(uri.toString())
            }
        }
    }
}
```

Linkrunner sends back a resolved deeplink after processing:

```json
{ "deeplink": "https://app.yourdomain.com/product/123" }
```

For Linkrunner campaign links, navigate using the **returned** `deeplink`, not
the original tracking URL that was in `intent.data`. Read it back via
`getAttributionData()` (see `references/events.md`) or from the
`handleDeeplink` result, then route it with whatever the app already uses for
in-app navigation (explicit `Intent`/`Fragment` transaction, or [Jetpack
Navigation Component deep
links](https://developer.android.com/guide/navigation/design/deep-link) if
the app has one set up). Linkrunner does not prescribe a navigation library
for native Android.

## Part B - HTTP/HTTPS verification file

### Create `assetlinks.json`

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

Replace `your.package.name` and the fingerprint.

### Get your SHA-256 fingerprint

```bash
# debug
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
# release
keytool -list -v -keystore your_release_keystore.keystore -alias your_key_alias
```

Look for the "SHA-256 Certificate fingerprint" line. Debug and release
keystores produce **different** fingerprints - list both in the array, or use
the Play Console fingerprint (**Play Console → Setup → App integrity**) if
the app uses Google Play App Signing:

```json
"sha256_cert_fingerprints": [
    "SHA-256:DEBUG:FINGERPRINT:...",
    "SHA-256:RELEASE:FINGERPRINT:..."
]
```

App Links verification only succeeds for the build whose fingerprint is
currently saved in Linkrunner.

### Host it in Linkrunner

Dashboard → **Project Settings → Domain Verification**: paste the
`assetlinks.json` content, Save. Linkrunner hosts it at:

- `https://your-domain.io/.well-known/assetlinks.json`

## Part C - native config

`app/src/main/AndroidManifest.xml`, inside the launcher `<activity>`:

```xml
<intent-filter android:autoVerify="true">
  <action android:name="android.intent.action.VIEW" />
  <category android:name="android.intent.category.DEFAULT" />
  <category android:name="android.intent.category.BROWSABLE" />
  <!-- Your domain and subdomains -->
  <data android:scheme="https" android:host="app.example.com" />
</intent-filter>
```

List every subdomain the app should handle as its own `<data>` line.

## Custom URI scheme (no verification)

```xml
<intent-filter>
  <action android:name="android.intent.action.VIEW" />
  <category android:name="android.intent.category.DEFAULT" />
  <category android:name="android.intent.category.BROWSABLE" />
  <data android:scheme="myapp" />
</intent-filter>
```

Use lowercase schemes - Android matches them case-sensitively.

## Testing

```bash
# HTTP/HTTPS App Link
adb shell am start -a android.intent.action.VIEW -d "https://app.example.com/profile/123" your.package.name

# Custom URI scheme
adb shell am start -a android.intent.action.VIEW -d "myapp://profile/123" your.package.name
```

Typing a Universal/App Link into a browser's address bar never opens the app
- test by tapping it from another app instead (e.g. paste into Notes and
long-press, or use the `adb` command above).

## Debugging (when App Links open the browser)

1. **Check the hosted file:**

   ```bash
   curl https://your-domain.io/.well-known/assetlinks.json
   ```

   A 404 means it isn't saved - re-save it under Project Settings → Domain
   Verification. If it loads, confirm `package_name` and
   `sha256_cert_fingerprints` match the build under test. Google's validator
   surfaces formatting errors:

   ```bash
   curl "https://digitalassetlinks.googleapis.com/v1/statements:list?source.web.site=https://your-domain.io&relation=delegate_permission/common.handle_all_urls"
   ```

2. **Check the verification state** (Android 12+):

   ```bash
   adb shell pm get-app-links your.package.name
   ```

   | State | Meaning |
   | --- | --- |
   | `verified` | Passed - links open the app |
   | `none` | Hasn't run yet (runs ~20s after install) |
   | `1024` / `legacy_failure` | Failed - check fingerprint and hosted file |
   | `approved` | Manually approved by the user in app settings |
   | `denied` | Manually disallowed by the user |

   On Android 11 and below, use `adb shell dumpsys package
   domain-preferred-apps` and watch `adb logcat | grep IntentFilter` during
   install instead.

3. **Clear the cached state and re-verify** - Android caches verification
   results, so fixing `assetlinks.json` alone does nothing until verification
   re-runs:

   ```bash
   adb shell pm set-app-links --package your.package.name 0 all
   adb shell pm verify-app-links --re-verify your.package.name
   adb shell pm get-app-links your.package.name
   ```

   Reinstalling the app also triggers a fresh pass.

4. **Force-approve while debugging (optional)** - to test in-app navigation
   before verification passes:

   ```bash
   adb shell pm set-app-links-user-selection --user cur --package your.package.name true all
   ```

   If links open the app after this but verification still fails, the
   problem is the hosted file or fingerprint, not the app code.

Run `scripts/verify-deeplinks.sh` to check most of this automatically.
