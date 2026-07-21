---
name: linkrunner-react-native
description: >-
  Integrate the Linkrunner mobile attribution SDK into a React Native app -
  add the package, initialize it, identify users, track events and revenue,
  and set up deep linking (iOS Universal Links, Android App Links, and custom
  URI schemes) with domain verification. Use when someone asks to add
  Linkrunner to a React Native app, wire up attribution, or debug why
  Linkrunner deep links are not opening the app.
metadata:
  category: sdk
  platform: react-native
  package: rn-linkrunner
  docs: https://docs.linkrunner.io/sdk/react-native
---

# Linkrunner - React Native integration

You are integrating **Linkrunner** (mobile attribution + deep linking) into a
React Native app. Work in this order and **inspect the project before
editing** - do not paste snippets blindly.

## 0. Before you touch anything

1. Confirm this is a React Native app: there's a `package.json` with
   `react-native` as a dependency, and `android/` + `ios/` native folders
   (bare workflow, or an Expo project after `expo prebuild`/a dev build).
2. If this is an **Expo managed** project (no `ios/`/`android/` folders, config
   driven by `app.json`/`app.config.js`), stop and use the `linkrunner-expo`
   skill instead - it wraps this SDK in a config plugin and has its own init
   flow. This skill assumes native folders exist.
3. Find the app's root component (usually `App.tsx`/`App.js`) and how it
   bootstraps (`useEffect` on mount).
4. Ask the user for their **project token** (dashboard → Settings). If they use
   SDK signing, also get `secretKey` + `keyId`. Never hardcode these in a file
   that gets committed if the user keeps secrets elsewhere - ask where.
5. Check current versions against requirements (below) before bumping anything.

## 1. Decide what the user actually needs

| They want... | Do this |
| --- | --- |
| "Add Linkrunner / set up attribution" | `references/install.md` then `references/events.md` (at minimum init + signup) |
| "Set up deep links" / "links open the browser not my app" | `references/deep-linking.md` + run `scripts/verify-deeplinks.sh` |
| "Track purchases / events" | `references/events.md` |

Most first-time integrations need **install → init → signup → handle deeplink**,
in that order. Deep-link *verification* (assetlinks/AASA) is separate and is
the part that usually breaks - treat it as its own step.

## 2. Requirements (verify, don't assume)

- Bare React Native workflow, or Expo with a dev build (`expo prebuild` /
  EAS dev client) - the SDK relies on native modules, so **Expo Go is not
  supported**.
- iOS: `pod install` required after adding the package; App Tracking
  Transparency usage string in `Info.plist`.
- Android: SharedPreferences values are encrypted automatically from
  `rn-linkrunner` v2.10.1+ - confirm the resolved version.
- Deep-link capture uses React Native's built-in `Linking` module; navigation
  examples use React Navigation's `linking` prop. Check whether the app
  already has a navigator before adding one.

## 3. Golden rules

- `init()` must run once, in a top-level `useEffect` (e.g. in `App.tsx`),
  before any other Linkrunner call. It returns nothing - read attribution via
  `getAttributionData()`.
- Call `signup()` the moment a user is identified (signup OR login) - this is
  what ties the install to a user. `setUserData()` is a later top-up, never a
  replacement.
- For HTTP/HTTPS deep links, the app changes are worthless until the hosted
  `assetlinks.json` (Android) and `apple-app-site-association` (iOS) verify.
  Always finish by running `scripts/verify-deeplinks.sh`.
- The Android SHA-256 fingerprint saved in Linkrunner must match the keystore
  that signed the build on the device. Debug and release differ.

## 4. Finish

After editing, reinstall dependencies, run `cd ios && pod install` if iOS
config changed, build once, and run
`scripts/verify-deeplinks.sh <domain> <android_package> <ios_team_id.bundle_id>`
to confirm deep-link verification is actually live. Report which checks passed
and which the user still has to do in the dashboard (host AASA/assetlinks under
Project Settings → Domain Verification).

## References

- `references/install.md` - package add + iOS/Android native config + init
- `references/deep-linking.md` - Universal Links / App Links / React Navigation + custom schemes + debugging
- `references/events.md` - signup, setUserData, revenue, trackEvent, attribution
