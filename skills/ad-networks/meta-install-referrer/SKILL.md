---
name: linkrunner-meta-install-referrer
description: >-
  Set up Meta Install Referrer so Linkrunner can read Meta (Facebook/Instagram)
  ad campaign metadata from the device and improve Meta attribution, including
  view-through installs. Android only - the setup is making your Facebook App ID
  available to the SDK via AndroidManifest.xml. Use when someone asks to enable
  Meta install referrer, improve Meta / view-through attribution with Linkrunner,
  or add the Facebook App ID for Linkrunner on Android.
metadata:
  category: ad-networks
  slug: meta-install-referrer
  docs: https://docs.linkrunner.io/features/meta-install-referrer
---

# Linkrunner - Meta Install Referrer (view-through) setup

Meta Install Referrer lets the Linkrunner SDK read ad campaign metadata that the
Facebook/Instagram app stored on the device, which improves Meta attribution
(including **view-through** installs - users who saw but did not click the ad).

**This is Android only.** On iOS, Meta attribution goes through SKAdNetwork, so
there is nothing to do here for iOS. The config lives in the Android project and
works the same whether the app uses the **native Android**, **Flutter**, or
**React Native** Linkrunner SDK.

## 0. Before you touch anything

1. Confirm there is an Android project (`android/` for Flutter/RN, or the app
   module for native Android). If the app is iOS-only, stop - this feature does
   not apply.
2. Find which Linkrunner SDK is in use and confirm it meets the minimum version
   (below). Meta Install Referrer support was added in specific versions.
3. Get the app's **Facebook App ID** (from the Meta app / developers.facebook.com).
   You need this value.
4. Check whether the app already integrates the **Facebook SDK** - that decides
   which of the two setups you use.

## 1. Requirements (verify, do not assume)

| SDK | Minimum version |
| --- | --- |
| Android (native) | 3.5.2+ |
| Flutter | 3.6.2+ |
| React Native | 2.6.2+ |

Device-side (out of your control, affects how many users get the lift): the user
must have Facebook **428.x+** or Instagram **296.x+** installed.

## 2. Configure

Make the Facebook App ID available to the SDK in `AndroidManifest.xml`. Two paths
depending on whether the Facebook SDK is already integrated - see
`references/setup.md` for the exact XML.

- **Facebook SDK already integrated:** the SDK reads the App ID from Facebook's
  standard `com.facebook.sdk.ApplicationId` meta-data - nothing extra to add if
  that is already present.
- **No Facebook SDK:** add Linkrunner's `com.linkrunner.FacebookApplicationId`
  meta-data pointing at a `facebook_application_id` string in `strings.xml`.

No SDK code change is needed beyond having `init()` already called - the SDK does
the Content Provider lookup on initialization.

## 3. Finish - verify

Run the validator from the project root to confirm the manifest/strings wiring is
present and correct:

```bash
bash scripts/verify-meta-referrer.sh
```

Then note to the user that the attribution lift only appears for installs where
the user had a recent enough Facebook/Instagram app, so it is a lift on top of
existing Meta attribution, not a replacement.

## References

- `references/setup.md` - exact AndroidManifest.xml / strings.xml for both setups + per-SDK file locations
