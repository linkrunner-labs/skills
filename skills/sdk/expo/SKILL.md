---
name: linkrunner-expo
description: >-
  Integrate the Linkrunner mobile attribution SDK into an Expo app via the
  expo-linkrunner config plugin - install rn-linkrunner + expo-linkrunner,
  wire the plugin into app.json, initialize, identify users, track events
  and revenue, and set up deep linking (iOS Universal Links, Android App
  Links, and custom URI schemes) with domain verification. Use when someone
  asks to add Linkrunner to an Expo app, wire up attribution in an
  Expo/expo-router project, or debug why Linkrunner deep links are not
  opening the app.
metadata:
  category: sdk
  platform: expo
  package: expo-linkrunner
  docs: https://docs.linkrunner.io/sdk/expo
---

# Linkrunner - Expo integration

You are integrating **Linkrunner** (mobile attribution + deep linking) into an
Expo app. `expo-linkrunner` is **only a config plugin** - it does the native
setup during prebuild. Every runtime call (`init`, `signup`, `handleDeeplink`,
`trackEvent`, ...) comes from the underlying **`rn-linkrunner`** package, with
the exact same API as the React Native SDK. Work in this order and **inspect
the project before editing** - do not paste snippets blindly.

## 0. Before you touch anything

1. Confirm this is an Expo app: `app.json` or `app.config.js/ts` with an
   `expo` key, and `expo` in `package.json` dependencies.
2. Check whether `android/` and `ios/` exist and whether they're gitignored.
   - Gitignored (or absent) = **managed / Continuous Native Generation (CNG)**:
     native projects are regenerated from `app.json` on every `expo prebuild`.
     Native config must go through `app.json` or a config plugin.
   - Committed = bare-ish workflow: the native files are edited directly and
     persist, but you then own keeping them in sync with any future prebuild.
3. Confirm the app uses a **development build**, not Expo Go - Linkrunner
   relies on native modules, so Expo Go cannot run it.
4. Find the app's entry point (`app/_layout.tsx` for expo-router, or `App.tsx`)
   and how/where it currently initializes any SDKs.
5. Ask the user for their **project token** (dashboard → Settings). If they use
   SDK signing, also get `secretKey` + `keyId`. Never hardcode these in a file
   that gets committed if the user keeps secrets elsewhere - ask where.
6. Check current versions against requirements (below) before bumping anything.

## 1. Decide what the user actually needs

| They want... | Do this |
| --- | --- |
| "Add Linkrunner / set up attribution" | `references/install.md` then `references/events.md` (at minimum init + signup) |
| "Set up deep links" / "links open the browser not my app" | `references/deep-linking.md` + run `scripts/verify-deeplinks.sh` |
| "Track purchases / events" | `references/events.md` |

Most first-time integrations need **install → plugin → prebuild → init →
signup → handle deeplink**, in that order. Deep-link *verification* (AASA /
assetlinks) is separate and is the part that usually breaks - treat it as its
own step.

## 2. Requirements (verify, don't assume)

- Expo SDK 52.0+, Node.js 18.0+, React Native 0.70+
- A development build (custom dev client or EAS Build) - not Expo Go
- Deep-link capture uses the `Linking` API (from `react-native` or
  `expo-linking`); routing examples assume `expo-router`. Check whether the
  app already has a router/linking setup before adding one.

## 3. Golden rules

- Install **both** packages - `rn-linkrunner` (the SDK logic) and
  `expo-linkrunner` (the config plugin). The plugin alone makes no runtime
  calls; without `rn-linkrunner` there is nothing to `import`.
- Add the plugin entry to `app.json`, then **run `npx expo prebuild`** (or let
  EAS Build run it automatically) before expecting native changes to exist.
  Editing `app.json` without prebuilding leaves the native projects stale.
- If `android/`/`ios/` are gitignored (CNG), **never hand-edit
  `AndroidManifest.xml` / `Info.plist` / entitlements** - they get regenerated
  from `app.json` on the next prebuild and your edits silently disappear. Use
  `expo.scheme`, `expo.ios.associatedDomains`, `expo.android.intentFilters`, or
  a small custom config plugin instead.
- `init()` must run **before** any other Linkrunner call, imported directly
  from `rn-linkrunner` - the same ordering rule as the React Native SDK.
- Call `signup()` the moment a user is identified (signup OR login) - this is
  what ties the install to a user. `setUserData()` is a later top-up, never a
  replacement.
- For HTTP/HTTPS deep links, the app changes are worthless until the hosted
  `assetlinks.json` (Android) and `apple-app-site-association` (iOS) verify.
  Always finish by running `scripts/verify-deeplinks.sh`.
- The Android SHA-256 fingerprint saved in Linkrunner must match the keystore
  that signed the build on the device (or the EAS/Play Store signing config).
  Debug and release differ.

## 4. Finish

After editing `app.json`, run `npx expo prebuild` (skip only if EAS Build owns
prebuild and `android`/`ios` stay gitignored) and rebuild the dev client, then
run `scripts/verify-deeplinks.sh <domain> <android_package> <ios_team_id.bundle_id>`
to confirm deep-link verification is actually live. Report which checks passed
and which the user still has to do in the dashboard (host AASA/assetlinks under
Project Settings → Domain Verification).

## References

- `references/install.md` - packages, plugin wiring, prebuild, Android backup
  config, init
- `references/deep-linking.md` - Universal Links / App Links / custom schemes
  via `app.json`, expo-router navigation, and debugging
- `references/events.md` - signup, setUserData, revenue, trackEvent, attribution
