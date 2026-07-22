# Unity install + initialization (native bridge)

Source of truth: https://docs.linkrunner.io/sdk/unity

There is no `linkrunner` Unity package. You are adding two native SDKs plus a
bridge layer per platform, then a shared C# wrapper. Read the whole doc
section for the platform you're touching before pasting - the code below is
condensed to the parts that change per-project; the full bridge files are in
the doc.

## 1. Android setup

### Add the SDK dependency

Unity's own Gradle template files, not a `.jar` drop. Create/edit
`Assets/Plugins/Android/mainTemplate.gradle`:

```gradle
dependencies {
    implementation 'io.linkrunner:android-sdk:3.6.0'
}
```

Ensure Maven Central is reachable in `Assets/Plugins/Android/settingsTemplate.gradle`:

```gradle
dependencyResolutionManagement {
    repositories {
        google()
        mavenCentral()
    }
}
```

Custom Gradle templates require **Player Settings → Publishing Settings** to
have the Custom Main/Settings Gradle Template checkboxes enabled. On Unity
2022.2+ with the newer Gradle template system, the dependency may instead
need to go in `unityLibrary/build.gradle` - check what the project's Unity
version actually generates.

### Permissions

`Assets/Plugins/Android/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
<uses-permission android:name="com.google.android.gms.permission.AD_ID" />
```

Only remove `AD_ID` (via `tools:node="remove"`) if the app targets children
under Google Play's Family Policy - it's a primary Google Ads attribution
signal, so removing it reduces accuracy.

### Java bridge class

Create `Assets/Plugins/Android/LinkrunnerBridge.java` (package
`com.linkrunner.unity`, class `LinkrunnerBridge`). It wraps
`io.linkrunner.sdk.LinkrunnerJava` - the SDK's callback-based Java API that
handles all Kotlin coroutine execution internally, so the bridge needs no
Kotlin imports or manual threading. Static methods to implement, each calling
the matching `LinkrunnerJava` method and reporting back via
`UnityPlayer.UnitySendMessage("LinkrunnerCallbackHandler", "<OnXComplete>", <json>)`:

`initialize`, `signup`, `setUserData`, `getAttributionData`, `trackEvent`,
`capturePayment`, `removePayment`, `setPushToken`, `setAdditionalData`,
`enablePIIHashing`, `setDisableAaidCollection`, `handleDeeplink`.

The full ~300-line class (JSON parsing helpers, `PaymentType`/`PaymentStatus`
enum mapping, every method body) is in the doc's **Android Setup → Step 3**
- copy it verbatim as a starting point, then adjust only if the SDK version
differs.

### ProGuard/R8

```
-keep class io.linkrunner.sdk.** { *; }
-keep class com.linkrunner.unity.** { *; }
```

## 2. iOS setup

### Add the SDK (manual, every Xcode regeneration)

After Unity builds the Xcode project:

1. Xcode → **File → Add Package Dependencies...**
2. URL: `https://github.com/linkrunner-labs/linkrunner-ios.git`
3. Version 3.8.0+, add package, select the **LinkrunnerKitStatic** library (not
   the dynamic variant - picking the wrong one causes linker errors)

This step does not survive Unity regenerating the Xcode project, so it must
be repeated on every rebuild unless automated (see below).

### Info.plist

```xml
<key>NSUserTrackingUsageDescription</key>
<string>This identifier will be used to deliver personalized ads and improve your app experience.</string>
<key>NSAdvertisingAttributionReportEndpoint</key>
<string>https://linkrunner-skan.com</string>
<key>AttributionCopyEndpoint</key>
<string>https://linkrunner-skan.com</string>
```

Can be added via `Assets/Plugins/iOS/Info.plist` additions, or automated with
a `PostProcessBuild` script (see doc's **Automating iOS Dependency** section
- it covers the Info.plist keys only, not the SPM package itself).

### Swift bridge

`LinkrunnerKit` is a pure Swift module - no `NSObject` inheritance, no
`@objc`, so Objective-C/Unity can't call it directly. Create
`Assets/Plugins/iOS/LinkrunnerUnityBridge.swift` exposing `@_cdecl`-annotated
C-callable functions that wrap the SDK's `async` calls in `Task { ... }` and
report back via a `@_silgen_name("UnitySendMessage")` declaration to
`sendToUnity(method, message)`. Functions to expose, matching the C# `DllImport`
names 1:1: `_LinkrunnerInitialize`, `_LinkrunnerSignup`,
`_LinkrunnerSetUserData`, `_LinkrunnerGetAttributionData`,
`_LinkrunnerTrackEvent`, `_LinkrunnerCapturePayment`,
`_LinkrunnerRemovePayment`, `_LinkrunnerSetPushToken`,
`_LinkrunnerSetAdditionalData`, `_LinkrunnerEnablePIIHashing`,
`_LinkrunnerHandleDeeplink`.

The full bridge file (JSON dict helpers, `parseUserData`,
`parsePaymentType`/`parsePaymentStatus`, every `@_cdecl` function body) is in
the doc's **iOS Setup → Step 3** - copy verbatim, adjust only for SDK API
changes.

**Unity does not compile `.swift` files in `Assets/Plugins/iOS/` automatically.**
After Unity generates the Xcode project, manually:

1. Add `LinkrunnerUnityBridge.swift` to the **UnityFramework** target's
   **Compile Sources** build phase
2. Accept Xcode's bridging-header prompt if it appears
3. Set **SWIFT_VERSION** to 5.0+ on the UnityFramework target

## 3. C# wrapper

Create `Assets/Scripts/LinkrunnerSDK.cs` - a `MonoBehaviour` singleton that
must be attached to a `GameObject` named exactly `LinkrunnerCallbackHandler`
in the first scene (both native bridges call back into that name via
`UnitySendMessage`). It:

- Declares `[DllImport("__Internal")]` externs for every `_LinkrunnerX`
  function under `#if UNITY_IOS && !UNITY_EDITOR`
- Wraps `AndroidJavaClass("com.linkrunner.unity.LinkrunnerBridge")` under
  `#if UNITY_ANDROID && !UNITY_EDITOR`
- Exposes `static` methods (`Initialize`, `Signup`, `SetUserData`,
  `GetAttributionData`, `TrackEvent`, `CapturePayment`, `RemovePayment`,
  `SetPushToken`, `SetAdditionalData`, `EnablePIIHashing`, `HandleDeeplink`,
  `SetDisableAaidCollection`) that dispatch to the right platform and no-op
  (log only) in the Editor
- Exposes C# `event Action<...>` callbacks (`OnInitialized`, `OnSignedUp`,
  `OnUserDataSet`, `OnAttributionData`, `OnEventTracked`, `OnPaymentCaptured`,
  `OnPaymentRemoved`, `OnDeeplinkHandled`) fired from native callback methods
  (`OnInitComplete`, `OnSignupComplete`, etc.) that Unity invokes on the
  `LinkrunnerCallbackHandler` GameObject
- Defines `[Serializable] class LinkrunnerUserData` (`id` required; `name`,
  `phone`, `email`, `mixpanelDistinctId`, `amplitudeDeviceId`,
  `posthogDistinctId`, `brazeDeviceId`, `gaAppInstanceId`, `gaSessionId`,
  `userCreatedAt`, `isFirstTimeUser` optional) serialized with
  `JsonUtility.ToJson` before crossing the bridge

The full class (~330 lines) is in the doc's **C# Wrapper** section - copy
verbatim, it's the one piece meant to be used as-is rather than adjusted.

## 4. Scene setup

1. Create an empty `GameObject` in the first scene
2. Name it **`LinkrunnerCallbackHandler`** (exact match - both native sides
   depend on this name)
3. Attach `LinkrunnerSDK.cs`

## 5. Initialize (required, before anything else)

```csharp
void Start()
{
    LinkrunnerSDK.OnInitialized += (success, message) =>
    {
        Debug.Log($"Linkrunner initialized: {success}");
    };

    LinkrunnerSDK.Initialize(
        token: "YOUR_PROJECT_TOKEN",
        debug: true  // set false in production
    );
}
```

Optional args: `secretKey`, `keyId` (SDK signing, dashboard → Settings → SDK
Signing), `disableIdfa` (iOS). `SetDisableAaidCollection(true)` (Android) must
be called before `Initialize` if used.

## 6. Verify install

- Android: Gradle sync resolves `io.linkrunner:android-sdk`, build succeeds
- iOS: after regenerating the Xcode project, the SPM package and Swift bridge
  are (re-)added, build succeeds
- With `debug: true`, `OnInitialized` fires with `success: true` on device
  (Editor always no-ops - test on real devices)

Next: `references/events.md` (signup is required) and, if the game needs
links to open it, `references/deep-linking.md`.
