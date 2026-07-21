# Unity deep linking (native bridge)

Source of truth: https://docs.linkrunner.io/sdk/unity and
https://docs.linkrunner.io/features/deep-linking-setup

Two approaches:

- **HTTP/HTTPS** (App Links on Android, Universal Links on iOS) - requires
  domain verification. This is what most campaigns use.
- **Custom URI scheme** (`myapp://`) - no verification, simpler, good as a
  fallback.

Unity has no built-in deep-link router (no `app_links`/go_router equivalent).
Capturing the URL is native code you write per platform; routing it to the
right scene/screen once `HandleDeeplink` returns is entirely up to the game's
own scene/UI logic - there's nothing to link to for that part because it
doesn't exist in the doc.

The most common failure is that native capture works but domain verification
never passes, so links open the browser instead. Do the verification parts
carefully and finish with `scripts/verify-deeplinks.sh`.

## Part A - capture the deep link into Unity (both approaches need this)

This is the part that's genuinely Unity-specific and under-documented -
Android has a concrete pattern in the doc, iOS is described but not fully
coded.

### Android - custom `UnityPlayerActivity`

Create `Assets/Plugins/Android/DeeplinkActivity.java`:

```java
package com.yourcompany.yourapp;

import android.content.Intent;
import android.os.Bundle;
import com.unity3d.player.UnityPlayerActivity;
import com.unity3d.player.UnityPlayer;

public class DeeplinkActivity extends UnityPlayerActivity {
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        handleDeeplink(getIntent());
    }

    @Override
    protected void onNewIntent(Intent intent) {
        super.onNewIntent(intent);
        setIntent(intent);
        handleDeeplink(intent);
    }

    private void handleDeeplink(Intent intent) {
        if (intent != null && intent.getData() != null) {
            String url = intent.getData().toString();
            UnityPlayer.UnitySendMessage("LinkrunnerCallbackHandler", "OnDeeplinkReceived", url);
        }
    }
}
```

Update `AndroidManifest.xml` to launch `DeeplinkActivity` (instead of the
default Unity activity) and add the intent filters from Part C below to it.
`LinkrunnerSDK.cs` already implements `OnDeeplinkReceived(string url)`, which
forwards straight into `HandleDeeplink(url)` - no extra C# wiring needed once
the GameObject and script are in the scene.

### iOS - AppDelegate / UnityAppController

The doc is explicit that this needs custom native code but does not provide
it: "Deeplinks on iOS are handled through the `AppDelegate`. After Unity
generates the Xcode project, modify `UnityAppController.mm` or use a native
plugin to forward deeplink URLs to Unity via `UnitySendMessage`." In
practice this means overriding `application(_:continue:restoringActivityState:)`
(Universal Links) and/or `application(_:open:options:)` (custom schemes) in
the generated `UnityAppController.mm`, extracting the URL, and calling
`UnitySendMessage("LinkrunnerCallbackHandler", "OnDeeplinkReceived", url)`.
Since Unity regenerates this file on rebuild, the same "must be re-added
every time" caveat as the SPM package applies - see `references/install.md`.

### Forwarding into the SDK

```csharp
public void OnDeeplinkReceived(string url)
{
    LinkrunnerSDK.HandleDeeplink(url);
}
```

```csharp
LinkrunnerSDK.OnDeeplinkHandled += (jsonString) =>
{
    // {"deeplink":"https://app.yourdomain.com/product/123"}
};
```

For Linkrunner campaign links, use the `deeplink` field from
`OnDeeplinkHandled` as the resolved destination, not the original tracking
URL. `is_linkrunner` tells you whether the link was created through
Linkrunner, for deciding whether to apply Linkrunner-specific attribution
logic.

## Part B - HTTP/HTTPS verification files

### Android - `assetlinks.json`

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

Get the fingerprint:

```bash
# debug
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
# release
keytool -list -v -keystore your_release_keystore.keystore -alias your_key_alias
```

Debug and release keystores produce **different** fingerprints. List both in
the array, or use the Play Console fingerprint (**Play Console → Setup → App
integrity**) if the project uses Google Play App Signing.

### iOS - `apple-app-site-association` (no extension)

```json
{
  "applinks": {
    "apps": [],
    "details": [
      { "appID": "TEAM_ID.BUNDLE_ID", "paths": ["/*"] }
    ]
  }
}
```

`TEAM_ID` from Apple Developer → Membership; `BUNDLE_ID` from the Xcode
project (Unity sets this under Player Settings → iOS → Bundle Identifier,
which flows into the generated Xcode project).

### Host them in Linkrunner

Dashboard → **Project Settings → Domain Verification**: paste the iOS JSON
and Android JSON, Save. Linkrunner hosts them at:

- `https://your-domain.io/.well-known/apple-app-site-association`
- `https://your-domain.io/.well-known/assetlinks.json`

## Part C - native config for HTTP/HTTPS links

### Android - `Assets/Plugins/Android/AndroidManifest.xml`, inside the (deeplink) `<activity>`

```xml
<intent-filter android:autoVerify="true">
  <action android:name="android.intent.action.VIEW" />
  <category android:name="android.intent.category.DEFAULT" />
  <category android:name="android.intent.category.BROWSABLE" />
  <data android:scheme="https" android:host="app.example.com" />
</intent-filter>
```

Put this on `DeeplinkActivity` from Part A if using the custom activity
pattern.

### iOS - Xcode → Signing & Capabilities → Associated Domains

```
applinks:app.example.com
```

Added in the **generated** Xcode project - like the SPM dependency, this does
not persist across a Unity rebuild that regenerates the project from scratch;
confirm it's still present after any full re-export.

## Custom URI scheme (no verification)

Android `<activity>` (or `DeeplinkActivity`):

```xml
<intent-filter>
  <action android:name="android.intent.action.VIEW" />
  <category android:name="android.intent.category.DEFAULT" />
  <category android:name="android.intent.category.BROWSABLE" />
  <data android:scheme="myapp" />
</intent-filter>
```

iOS `Info.plist` (via `Assets/Plugins/iOS/Info.plist` additions, or directly
in Xcode → Info → URL Types):

```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLName</key><string>com.example.myapp</string>
    <key>CFBundleURLSchemes</key><array><string>myapp</string></array>
  </dict>
</array>
```

## Testing

```bash
# Android
adb shell am start -a android.intent.action.VIEW -d "https://app.example.com/profile/123" your.package.name
# iOS simulator
xcrun simctl openurl booted "https://app.example.com/profile/123"
```

Note: typing a Universal Link in Safari never opens the app - tap it from
another app (e.g. Notes).

## Debugging (when HTTPS links open the browser)

- Android verification state: `adb shell pm get-app-links your.package.name`
  (`verified` = good; `1024`/`legacy_failure` = fingerprint or hosted-file
  problem). Clear + re-verify:
  ```bash
  adb shell pm set-app-links --package your.package.name 0 all
  adb shell pm verify-app-links --re-verify your.package.name
  ```
- iOS: devices fetch AASA from Apple's CDN, not your domain. Check the CDN:
  `curl -v https://app-site-association.cdn-apple.com/a/v1/your-domain.io`.
  If stale, use developer mode: set `applinks:your-domain.io?mode=developer`
  on the Associated Domains entry (re-add it after every Xcode regen), enable
  **Settings → Developer → Associated Domains Development** on the device,
  reinstall.

Run `scripts/verify-deeplinks.sh` to check most of this automatically.
