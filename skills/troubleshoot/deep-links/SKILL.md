---
name: linkrunner-troubleshoot-deep-links
description: >-
  Diagnose why Linkrunner deep links (iOS Universal Links / Android App Links)
  open the browser instead of the app, or do not open the app at all. Runs the
  full verification gauntlet - hosted apple-app-site-association and
  assetlinks.json, Apple CDN freshness, Android fingerprint + verification
  state, associated-domains entitlement, manifest intent filters - and reports
  exactly what is broken and how to fix it. Use when someone says a Linkrunner
  link opens Safari/Chrome, App Links will not verify, or a universal link is
  ignored.
metadata:
  category: troubleshoot
  slug: deep-links
  docs: https://docs.linkrunner.io/features/deep-linking-setup#debugging-domain-verification
---

# Linkrunner - deep link troubleshooter

The symptom is almost always: **an HTTPS link opens the browser instead of the
app.** That means domain verification is failing somewhere between the hosted
file, Apple/Google's cache, the app's native config, and the device. Diagnose in
order - do not guess.

## 0. Gather the facts first

Ask for / detect these before running anything:

- The **domain** the links use (e.g. `app.example.com`).
- **Android package name** (from `applicationId` in `android/app/build.gradle` or
  the manifest).
- **iOS appID** = `TEAM_ID.BUNDLE_ID` (Team ID from Apple Developer → Membership;
  bundle id from Xcode).
- Which **build** is on the device (debug vs release - they are signed with
  different keystores and have different fingerprints).
- Whether the user is testing by **typing the URL into Safari** - that never
  opens the app on iOS; it must be tapped from another app (e.g. Notes). Rule
  this out first.

## 1. Run the diagnostic

From the app project root:

```bash
bash scripts/diagnose-deep-links.sh <domain> <android_package> <ios_team_id.bundle_id>
```

It checks the hosted files, Apple's CDN, the Google Digital Asset Links API, the
local native wiring, and - if a device is connected over `adb` - the live
Android verification state. Read its output, then use the references below to fix
whatever it flags.

## 2. Interpret and fix

| What you see | Go to |
| --- | --- |
| assetlinks 404, fingerprint mismatch, `1024`/`legacy_failure`, works on debug not release | `references/android.md` |
| AASA 404/stale, CDN serving old file, link opens Safari | `references/ios.md` |
| Both platforms | do both |

## 3. The usual root causes (in frequency order)

1. **Android fingerprint mismatch** - the SHA-256 in `assetlinks.json` is not the
   keystore that signed the build on the device. Debug and release differ; Play
   App Signing uses the Play Console fingerprint, not your local keystore.
2. **Cached verification** - the hosted file is now correct but the device/OS
   still holds the old result. Android needs an explicit re-verify; iOS needs the
   Apple CDN to refresh (up to a day) or developer mode.
3. **File not hosted** - not saved in dashboard → Project Settings → Domain
   Verification, so the `.well-known/` URL 404s.
4. **Native config missing** - no `android:autoVerify="true"` intent filter for
   the host, or the **Associated Domains** capability / `applinks:` entry absent.
5. **Testing wrong** - typing a universal link into Safari (never works).

## 4. Confirm the fix

Re-run the diagnostic, then test for real:

```bash
# Android
adb shell am start -a android.intent.action.VIEW -d "https://<domain>/path" <android_package>
# iOS simulator
xcrun simctl openurl booted "https://<domain>/path"
```

On iOS, tap a link from Notes (not Safari). Report which checks pass and which
dashboard/native step the user still needs to complete.

## References

- `references/android.md` - App Links verification: fingerprints, `adb pm` states, re-verify, force-approve
- `references/ios.md` - Universal Links verification: AASA, Apple CDN, developer mode, swcd logs
