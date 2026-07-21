# Android App Links - diagnosis and fix

Source of truth: https://docs.linkrunner.io/features/deep-linking-setup#debugging-domain-verification

An HTTPS link opening the browser means App Links verification is not passing for
that host. Work top to bottom.

## 1. Is the hosted file correct?

```bash
curl https://<domain>/.well-known/assetlinks.json
```

- **404** -> not saved. Re-save in dashboard → Project Settings → Domain
  Verification.
- **Loads** -> confirm `package_name` matches your app and
  `sha256_cert_fingerprints` includes the fingerprint of the keystore that signed
  the build **on the device**.

Let Google validate the format (surfaces subtle errors):

```bash
curl "https://digitalassetlinks.googleapis.com/v1/statements:list?source.web.site=https://<domain>&relation=delegate_permission/common.handle_all_urls"
```

## 2. Fingerprint mismatch (the #1 cause)

Debug and release builds are signed with different keystores -> different SHA-256.
Verification only passes for the build whose fingerprint is saved in Linkrunner.

```bash
# debug
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
# release
keytool -list -v -keystore your_release_keystore.keystore -alias your_key_alias
```

Fixes:
- List **both** debug and release fingerprints in `sha256_cert_fingerprints`.
- If you use **Google Play App Signing**, the production fingerprint comes from
  **Play Console → Setup → App integrity**, not your local upload keystore.

## 3. Check the live verification state (Android 12+)

```bash
adb shell pm get-app-links your.package.name
```

| State | Meaning |
| --- | --- |
| `verified` | Passed. Links open your app. |
| `none` | Not run yet (runs ~20s after install). |
| `1024` / `legacy_failure` | Failed - fix fingerprint / hosted file. |
| `approved` | Manually approved by the user. |
| `denied` | Manually disallowed by the user. |

On Android 11 and below: `adb shell dumpsys package domain-preferred-apps`, and
watch `adb logcat | grep IntentFilter` during install.

## 4. Clear cached state and re-verify

Android caches results, so fixing `assetlinks.json` has no effect until
verification re-runs:

```bash
adb shell pm set-app-links --package your.package.name 0 all
adb shell pm verify-app-links --re-verify your.package.name
# wait a few seconds
adb shell pm get-app-links your.package.name
```

Reinstalling the app also triggers a fresh pass.

## 5. Force-approve while debugging (optional)

Test in-app navigation before verification passes (equivalent to the user
enabling **Open supported links**):

```bash
adb shell pm set-app-links-user-selection --user cur --package your.package.name true all
```

If links open the app after this but verification still fails, the problem is the
hosted file or fingerprint, not your app code.

## 6. Native config

`android/app/src/main/AndroidManifest.xml`, inside `<activity>`:

```xml
<intent-filter android:autoVerify="true">
  <action android:name="android.intent.action.VIEW" />
  <category android:name="android.intent.category.DEFAULT" />
  <category android:name="android.intent.category.BROWSABLE" />
  <data android:scheme="https" android:host="app.example.com" />
</intent-filter>
```

Must have `android:autoVerify="true"` and list the exact host being tested. Use
lowercase schemes.
