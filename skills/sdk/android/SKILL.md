---
name: linkrunner-android
description: >-
  Integrate the Linkrunner mobile attribution SDK into a native Android
  (Kotlin/Java) app - add the Maven dependency, initialize it, identify users,
  track events and revenue, and set up deep linking (App Links with
  assetlinks.json verification and custom URI schemes). Use when someone asks
  to add Linkrunner to an Android app, wire up attribution natively, or debug
  why Linkrunner App Links are not opening the app.
metadata:
  category: sdk
  platform: android
  package: io.linkrunner:android-sdk
  docs: https://docs.linkrunner.io/sdk/android
---

# Linkrunner - Android (native) integration

You are integrating **Linkrunner** (mobile attribution + deep linking) into a
native Android app. Work in this order and **inspect the project before
editing** - do not paste snippets blindly.

## 0. Before you touch anything

1. Confirm this is a native Android project: there is a top-level
   `build.gradle`/`build.gradle.kts` and `settings.gradle`, and an `app/`
   module with `src/main/AndroidManifest.xml`. (If it's a Flutter/React
   Native/Expo project, use that platform's skill instead - this one is for
   Kotlin/Java apps only.)
2. Find the `Application` subclass (or note there isn't one yet) and the main
   launcher `Activity` - these are where `init()` and deep-link handling go.
3. Ask the user for their **project token** (dashboard → Settings). If they
   use SDK signing, also get `secretKey` + `keyId`. Never hardcode these in a
   file that gets committed if the user keeps secrets elsewhere - ask where.
4. Check the current `minSdkVersion` and Gradle version against requirements
   (below) before bumping anything.

## 1. Decide what the user actually needs

| They want... | Do this |
| --- | --- |
| "Add Linkrunner / set up attribution" | `references/install.md` then `references/events.md` (at minimum init + signup) |
| "Set up deep links" / "links open the browser not my app" | `references/deep-linking.md` + run `scripts/verify-deeplinks.sh` |
| "Track purchases / events" | `references/events.md` |

Most first-time integrations need **install → init → signup → handle
deeplink**, in that order. Deep-link *verification* (`assetlinks.json`) is
separate and is the part that usually breaks - treat it as its own step.

## 2. Requirements (verify, don't assume)

- Android 5.0 (API level 21) or higher, Gradle 8.0+
- Android Studio Flamingo (2022.2.1) or newer
- Kotlin coroutines for the async SDK calls (all SDK methods are `suspend`
  functions)

## 3. Golden rules

- `init()` must run **before** any other Linkrunner call, in `Application.onCreate()`.
- Call `signup()` the moment a user is identified (signup OR login) - this is
  what ties the install to a user. `setUserData()` is a later top-up, never a
  replacement.
- For HTTP/HTTPS App Links, the app changes are worthless until the hosted
  `assetlinks.json` verifies. Always finish by running
  `scripts/verify-deeplinks.sh`.
- The SHA-256 fingerprint saved in Linkrunner must match the keystore that
  signed the build on the device. Debug and release differ.

## 4. Finish

After editing, sync Gradle, build once, and run
`scripts/verify-deeplinks.sh <domain> <android_package>` to confirm deep-link
verification is actually live. Report which checks passed and which the user
still has to do in the dashboard (host `assetlinks.json` under Project
Settings → Domain Verification).

## References

- `references/install.md` - Gradle dependency + manifest/permissions + init
- `references/deep-linking.md` - App Links + custom schemes + debugging
- `references/events.md` - signup, setUserData, revenue, trackEvent, attribution
