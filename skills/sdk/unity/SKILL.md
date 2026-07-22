---
name: linkrunner-unity
description: >-
  Integrate Linkrunner mobile attribution into a Unity app via the native
  Android and iOS bridge - there is no dedicated Unity package. Wires the
  Java-callback Android SDK and the Swift @_cdecl iOS bridge behind a shared
  C# LinkrunnerSDK.cs, then sets up deep linking (App Links / Universal Links
  / custom schemes) with domain verification. Use when someone asks to add
  Linkrunner to a Unity game, wire up attribution in Unity, or debug why the
  Unity Android/iOS bridge is not calling through to Linkrunner.
metadata:
  category: sdk
  platform: unity
  package: "native bridge (io.linkrunner:android-sdk + LinkrunnerKit)"
  docs: https://docs.linkrunner.io/sdk/unity
---

# Linkrunner - Unity integration

**Linkrunner has no dedicated Unity SDK.** You are wiring the native Android
SDK (`io.linkrunner:android-sdk`, via its Java-friendly `LinkrunnerJava`
callback wrapper) and the native iOS SDK (`LinkrunnerKit` via SPM, wrapped in
a Swift `@_cdecl` bridge) behind a single `LinkrunnerSDK.cs` C# facade. Every
file in `references/` is **reference code from the official doc**, not a
drop-in package - read the project before pasting, and expect to adjust
signatures for the project's Unity/Xcode/SDK versions.

## 0. Before you touch anything

1. Confirm this is a Unity project: `Assets/`, `ProjectSettings/`, ideally a
   `.sln`/`Packages/manifest.json`. Note the Unity version (`ProjectSettings/ProjectVersion.txt`)
   - the doc targets **Unity 2021.3 LTS+**.
2. Check which platforms the project actually builds: is there an
   `Assets/Plugins/Android/` (Gradle template files?) and does the team ship
   iOS via Xcode? Do not wire a platform nobody ships.
3. If Android: check for `Assets/Plugins/Android/mainTemplate.gradle` and
   `settingsTemplate.gradle` (custom Gradle templates must be enabled in
   **Player Settings → Publishing Settings**) - the dependency goes there, not
   in a `.jar` drop.
4. If iOS: confirm the team already has an Xcode workflow for adding SPM
   packages after Unity's `Build`, since this is a recurring manual step (see
   golden rules).
5. Ask the user for their **project token** (dashboard → Documentation). If
   they use SDK signing, get `secretKey` + `keyId` too.
6. Check current SDK versions against requirements before bumping anything.

## 1. Architecture (read this before writing any bridge code)

```
C# (LinkrunnerSDK.cs)
    ├── Android → Java Bridge → io.linkrunner.sdk.LinkrunnerJava (callback API)
    └── iOS → Swift Bridge (@_cdecl) → LinkrunnerSDK.shared (Swift async)
```

- **Android**: a Java bridge class (`LinkrunnerBridge.java`) calls
  `LinkrunnerJava` - the SDK's callback-based Java wrapper that sidesteps
  Kotlin coroutine/Java interop issues - and reports back to Unity via
  `UnityPlayer.UnitySendMessage`.
- **iOS**: `LinkrunnerKit` is a pure Swift module with no `@objc` surface, so
  a Swift bridge file exposes `@_cdecl` C-callable functions wrapping its
  `async` methods; Unity calls them through `[DllImport("__Internal")]`.
- **C#**: `LinkrunnerSDK.cs` picks the right path per platform behind
  `#if UNITY_ANDROID` / `#if UNITY_IOS` and is a no-op (logs only) in the
  Editor.

## 2. Decide what the user actually needs

| They want... | Do this |
| --- | --- |
| "Add Linkrunner / set up attribution in Unity" | `references/install.md` then `references/events.md` (at minimum init + signup) |
| "Set up deep links" / "links open the browser not my game" | `references/deep-linking.md` + run `scripts/verify-deeplinks.sh` |
| "Track purchases / events" | `references/events.md` |

Most first integrations need **Android bridge + iOS bridge + C# wrapper →
Initialize → Signup → HandleDeeplink**, in that order. Deep-link
*verification* (AASA / assetlinks) is separate infrastructure work and is the
part that usually breaks - treat it as its own step, and confirm which
platforms the game actually ships before wiring both bridges.

## 3. Requirements (verify, don't assume)

- Unity 2021.3 LTS or newer
- Android: API 21+ (Android 5.0+), Gradle 8.0+, `io.linkrunner:android-sdk:3.6.0+`
- iOS: iOS 15.0+, Xcode 14.0+, Swift 5.9+, `linkrunner-ios` 3.8.0+ (`LinkrunnerKitStatic` library)
- A `GameObject` named exactly `LinkrunnerCallbackHandler` in the first scene,
  carrying `LinkrunnerSDK.cs` - both native bridges call back into it by name.

## 4. Golden rules

- `Initialize()` must run **before** any other Linkrunner call, as early as
  possible in the startup scene.
- Call `Signup()` the moment a user is identified (signup or login) - this is
  what ties the install to a user. `SetUserData()` is a later top-up, never a
  replacement.
- **This is reference code, not a package.** The bridge files in
  `references/install.md` come straight from the official doc; inspect the
  project's existing `Assets/Plugins/Android/` and `Assets/Plugins/iOS/`
  before adding new ones, and expect to adjust for the project's SDK/Xcode
  version.
- **The iOS SPM dependency does not survive Xcode regeneration.** Every time
  Unity rebuilds the Xcode project, `LinkrunnerKit` must be re-added via
  *File → Add Package Dependencies*, and `LinkrunnerUnityBridge.swift` must be
  re-added to the **UnityFramework** target's Compile Sources. A
  `PostProcessBuild` script can automate the Info.plist entries but not the
  SPM package itself - say this plainly, don't imply it is automated.
- For HTTP/HTTPS deep links, the bridge code is worthless until the hosted
  `assetlinks.json` (Android) and `apple-app-site-association` (iOS) verify.
  Always finish by running `scripts/verify-deeplinks.sh`.
- The Android SHA-256 fingerprint saved in Linkrunner must match the keystore
  that signed the build on the device. Debug and release differ.
- All SDK calls no-op (log only) in the Unity Editor - verify on real Android/iOS
  devices, never assume Editor behavior generalizes.

## 5. Finish

After editing, rebuild the Android/iOS export, re-add the iOS SPM dependency
and Swift bridge to the regenerated Xcode project if it changed, and run
`scripts/verify-deeplinks.sh <domain> <android_package> <ios_team_id.bundle_id>`
to confirm deep-link verification is actually live. Report which checks
passed and which the user still has to do in the dashboard (host
AASA/assetlinks under Project Settings → Domain Verification) or in Xcode
(re-adding the SPM package/bridge file).

## References

- `references/install.md` - Android Gradle/Java bridge, iOS SPM/Swift bridge, C# `LinkrunnerSDK.cs` wrapper + init
- `references/deep-linking.md` - App Links / Universal Links / custom schemes + native wiring + debugging
- `references/events.md` - C# API: signup, setUserData, revenue, trackEvent, attribution
