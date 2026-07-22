---
name: linkrunner-flutter
description: >-
  Integrate the Linkrunner mobile attribution SDK into a Flutter/Dart app -
  add the package, initialize it, identify users, track events and revenue, and
  set up deep linking (iOS Universal Links, Android App Links, and custom URI
  schemes) with domain verification. Use when someone asks to add Linkrunner to
  a Flutter app, wire up attribution, or debug why Linkrunner deep links are not
  opening the app.
metadata:
  category: sdk
  platform: flutter
  package: linkrunner
  docs: https://docs.linkrunner.io/sdk/flutter
---

# Linkrunner - Flutter integration

You are integrating **Linkrunner** (mobile attribution + deep linking) into a
Flutter app. Work in this order and **inspect the project before editing** - do
not paste snippets blindly.

## 0. Before you touch anything

1. Confirm this is a Flutter app: there is a `pubspec.yaml` with a `flutter:`
   section and an `android/` + `ios/` (or `lib/`) tree.
2. Find the app's entry point (usually `lib/main.dart`) and how it initializes
   (`main()` / `initState`).
3. Ask the user for their **project token** (dashboard → Settings). If they use
   SDK signing, also get `secretKey` + `keyId`. Never hardcode these in a file
   that gets committed if the user keeps secrets elsewhere - ask where.
4. Check current versions against requirements (below) before bumping anything.

## 1. Decide what the user actually needs

| They want... | Do this |
| --- | --- |
| "Add Linkrunner / set up attribution" | `references/install.md` then `references/events.md` (at minimum init + signup) |
| "Set up deep links" / "links open the browser not my app" | `references/deep-linking.md` + run `scripts/verify-deeplinks.sh` |
| "Track purchases / events" | `references/events.md` |
| "Set up uninstall tracking" | `references/events.md` (setPushToken section) - also needs FCM (Android) / APNs (iOS) wired up and configured in the Linkrunner dashboard |

Most first-time integrations need **install → init → signup → handle deeplink**,
in that order. Deep-link *verification* (AASA / assetlinks) is separate and is
the part that usually breaks - treat it as its own step.

## 2. Requirements (verify, don't assume)

- Flutter 3.19.0+, Dart 3.3.0+
- Android `minSdkVersion` 21+, iOS deployment target 15.0+
- Deep-link capture uses the `app_links` package; navigation examples use
  `go_router`. Check whether the app already has a router before adding one.

## 3. Golden rules

- `init()` must run **before** any other Linkrunner call, after
  `WidgetsFlutterBinding.ensureInitialized()`.
- Call `signup()` the moment a user is identified (signup OR login) - this is
  what ties the install to a user. `setUserData()` is a later top-up, never a
  replacement.
- For HTTP/HTTPS deep links, the app changes are worthless until the hosted
  `assetlinks.json` (Android) and `apple-app-site-association` (iOS) verify.
  Always finish by running `scripts/verify-deeplinks.sh`.
- The Android SHA-256 fingerprint saved in Linkrunner must match the keystore
  that signed the build on the device. Debug and release differ.

## 4. Finish

After editing, run `flutter pub get`, build once, and run
`scripts/verify-deeplinks.sh <domain> <android_package> <ios_team_id.bundle_id>`
to confirm deep-link verification is actually live. Report which checks passed
and which the user still has to do in the dashboard (host AASA/assetlinks under
Project Settings → Domain Verification).

## References

- `references/install.md` - package add + Android/iOS native config + init
- `references/deep-linking.md` - Universal Links / App Links / custom schemes + debugging
- `references/events.md` - signup, setUserData, revenue, trackEvent, attribution
