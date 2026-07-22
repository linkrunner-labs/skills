# Meta Install Referrer - Android setup

Source of truth: https://docs.linkrunner.io/features/meta-install-referrer

## How it works

1. On `init()`, the Linkrunner SDK uses the app's Facebook App ID to query the
   Meta Content Provider API and retrieve campaign metadata stored by the
   Facebook/Instagram app on the device.
2. The SDK sends the install event plus that attribution data to Linkrunner.

The only thing you configure is **making the Facebook App ID available** in the
Android manifest.

## Where the Android files live

- **Native Android:** `app/src/main/AndroidManifest.xml` and
  `app/src/main/res/values/strings.xml`.
- **Flutter:** `android/app/src/main/AndroidManifest.xml` and
  `android/app/src/main/res/values/strings.xml`.
- **React Native:** `android/app/src/main/AndroidManifest.xml` and
  `android/app/src/main/res/values/strings.xml`.

The setup is identical in all three - it is native Android config, not SDK code.

## Option A - Facebook SDK already integrated

If the app already integrates the Facebook SDK, the Facebook App ID is already in
the manifest as Facebook's standard meta-data:

```xml
<meta-data
    android:name="com.facebook.sdk.ApplicationId"
    android:value="@string/facebook_app_id" />
```

The Linkrunner SDK reads the App ID from that tag - nothing extra to add. See
[Facebook's guide](https://developers.facebook.com/docs/android/getting-started)
if it is not present yet.

## Option B - no Facebook SDK

Add Linkrunner's meta-data tag inside `<application>` in `AndroidManifest.xml`:

```xml
<meta-data
    android:name="com.linkrunner.FacebookApplicationId"
    android:value="@string/facebook_application_id" />
```

Add the value to `strings.xml`:

```xml
<string name="facebook_application_id" translatable="false"><YOUR_FACEBOOK_APP_ID></string>
```

Example:

```xml
<string name="facebook_application_id" translatable="false">1234567890123456</string>
```

## Requirements recap

- Linkrunner SDK: Android 3.5.2+ / Flutter 3.6.2+ / React Native 2.6.2+.
- The user's device must have Facebook 428.x+ or Instagram 296.x+ for metadata to
  be available - this is why it is a lift, not a guarantee, per install.
- No SDK code change beyond the existing `init()`.

## Verify

`scripts/verify-meta-referrer.sh` checks the manifest for either meta-data tag and
that the referenced `facebook_application_id` string is a real numeric App ID.
