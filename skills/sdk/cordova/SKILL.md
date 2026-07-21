---
name: linkrunner-cordova
description: >-
  Integrate the Linkrunner mobile attribution SDK into an Apache Cordova app -
  add the plugin, initialize it, identify users, track events and revenue,
  and set up deep linking (iOS Universal Links, Android App Links, and custom
  URI schemes) with domain verification. Use when someone asks to add
  Linkrunner to a Cordova app, wire up attribution, or debug why Linkrunner
  deep links are not opening the app.
metadata:
  category: sdk
  platform: cordova
  package: cordova-linkrunner
  docs: https://docs.linkrunner.io/sdk/cordova
---

# Linkrunner - Cordova integration

You are integrating **Linkrunner** (mobile attribution + deep linking) into an
Apache Cordova app. Work in this order and **inspect the project before
editing** - do not paste snippets blindly.

## 0. Before you touch anything

1. Confirm this is a Cordova app: there is a `config.xml` at the project root
   and a `www/` (or framework build output) folder. Check `platforms/` to see
   which platforms (`android`, `ios`) are already added.
2. Find where the app wires up `deviceready` (often `www/js/index.js` or an
   `app.js`), since `linkrunner.init()` must run there.
3. Ask the user for their **project token** (dashboard → Settings). If they use
   SDK signing, also get `secretKey` + `keyId`. Never hardcode these in a file
   that gets committed if the user keeps secrets elsewhere - ask where.
4. Check whether `config.xml` already has the required preferences (below)
   before adding platforms or the plugin - order matters here.

## 1. Decide what the user actually needs

| They want... | Do this |
| --- | --- |
| "Add Linkrunner / set up attribution" | `references/install.md` then `references/events.md` (at minimum init + signup) |
| "Set up deep links" / "links open the browser not my app" | `references/deep-linking.md` + run `scripts/verify-deeplinks.sh` |
| "Track purchases / events" | `references/events.md` |

Most first-time integrations need **install → init → signup → handle deeplink**,
in that order. Deep-link *verification* (AASA / assetlinks) is separate and is
the part that usually breaks - treat it as its own step.

## 2. Requirements (verify, don't assume)

- `config.xml` preferences `deployment-target` (15.0) and
  `GradlePluginKotlinEnabled` (+ `GradlePluginKotlinCodeStyle`) must be set
  **before** `cordova platform add ios android`. If platforms are already
  added, `cordova platform remove ios android` then re-add after editing
  `config.xml`.
- iOS deployment target 15.0+ (comes from the `deployment-target` preference).
- Kotlin support enabled for Android (comes from `GradlePluginKotlinEnabled`).

## 3. Golden rules

- `linkrunner.init()` must run inside the `deviceready` event handler, and only
  there - no import/require is needed, `linkrunner` is a global registered by
  the plugin.
- Call `signup()` the moment a user is identified (signup OR login) - this is
  what ties the install to a user. `setUserData()` is a later top-up, never a
  replacement.
- For HTTP/HTTPS deep links, the app changes are worthless until the hosted
  `assetlinks.json` (Android) and `apple-app-site-association` (iOS) verify.
  Always finish by running `scripts/verify-deeplinks.sh`.
- The Android SHA-256 fingerprint saved in Linkrunner must match the keystore
  that signed the build on the device. Debug and release differ.
- Cordova regenerates `platforms/android` and `platforms/ios` on
  `cordova prepare` / `cordova platform add`. Native edits made directly inside
  `platforms/` (manifest intent-filters, Xcode Associated Domains) get wiped -
  persist them through `config.xml` (`<config-file>`/`<edit-config>`, see
  [Apache Cordova's config.xml reference](https://cordova.apache.org/docs/en/latest/config_ref/index.html))
  or reapply them after every platform re-add.

## 4. Finish

After editing, run `cordova prepare`, build once per platform, and run
`scripts/verify-deeplinks.sh <domain> <android_package> <ios_team_id.bundle_id>`
to confirm deep-link verification is actually live. Report which checks passed
and which the user still has to do in the dashboard (host AASA/assetlinks under
Project Settings → Domain Verification).

## References

- `references/install.md` - config.xml prerequisites, plugin add, and init
- `references/deep-linking.md` - Universal Links / App Links / custom schemes + debugging
- `references/events.md` - signup, setUserData, revenue, trackEvent, attribution
