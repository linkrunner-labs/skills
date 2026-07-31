# Android install + initialization

Source of truth: https://docs.linkrunner.io/sdk/android

## 1. Add the Gradle dependency

`app/build.gradle` (or `build.gradle.kts`):

```gradle
dependencies {
    implementation 'io.linkrunner:android-sdk:3.10.0'
}
```

Confirm `settings.gradle` resolves from Maven Central:

```gradle
dependencyResolutionManagement {
    repositories {
        google()
        mavenCentral()
    }
}
```

Confirm the resolved version is **3.8.1+** so SharedPreferences encryption is
on by default (see Step 4).

## 2. Required permissions

`app/src/main/AndroidManifest.xml` - add inside `<manifest>`:

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
```

The `AD_ID` permission ships inside the SDK and is required for GAID
collection. **Only** remove it if the app targets children (Google Play
Families - see [Designed for
Families](https://support.google.com/googleplay/android-developer/topic/9877766?hl=en&ref_topic=9858052)).
To remove:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    xmlns:tools="http://schemas.android.com/tools">
    <uses-permission
        android:name="com.google.android.gms.permission.AD_ID"
        tools:node="remove" />
</manifest>
```

...and call `LinkRunner.getInstance().setDisableAaidCollection(true)` before
`init()` (SDK 3.5.0+). Disabling AAID reduces Google Ads attribution accuracy,
so only do this when the Family Policy actually requires it. Check the
current state with `LinkRunner.getInstance().isAaidCollectionDisabled()`.

## 3. Backup configuration (recommended)

Excludes the SDK's SharedPreferences from Android backup/restore, so a
reinstall isn't mistaken for a returning user because the old install ID was
restored from backup.

`AndroidManifest.xml`, inside `<application>`:

```xml
<application
    android:fullBackupContent="@xml/linkrunner_backup_descriptor"
    android:dataExtractionRules="@xml/linkrunner_backup_rules">
```

- `android:fullBackupContent` - Android 6-11
- `android:dataExtractionRules` - Android 12+

If the app already declares its own backup rules, merge these entries instead
of overwriting the attributes:

`res/xml/<your_backup_descriptor>.xml` (legacy, Android 6-11):

```xml
<full-backup-content>
    <exclude domain="sharedpref" path="io.linkrunner.sdk_prefs"/>
</full-backup-content>
```

`res/xml/<your_backup_rules>.xml` (modern, Android 12+):

```xml
<data-extraction-rules>
    <cloud-backup>
        <exclude domain="sharedpref" path="io.linkrunner.sdk_prefs"/>
    </cloud-backup>
    <device-transfer>
        <exclude domain="sharedpref" path="io.linkrunner.sdk_prefs"/>
    </device-transfer>
</data-extraction-rules>
```

## 4. Encrypted SharedPreferences

From `android-sdk` **v3.8.1+**, the SDK automatically encrypts what it stores
in SharedPreferences using a hardware-protected key in the [Android
Keystore](https://developer.android.com/training/articles/keystore) - no
config needed. Upgrading from an older version migrates existing plaintext
entries transparently on next read.

## 5. Import

```kotlin
// Kotlin
import io.linkrunner.sdk.LinkRunner
```

```java
// Java
import io.linkrunner.sdk.LinkRunner;
```

## 6. Google Ads consent

If the app runs Google App Campaigns, report the user's consent choices.
Google's App Conversion API treats these values as required whenever they are
known and reads them when it matches installs, so an install with no consent
state attached is harder to attribute - this matters most for users in the
EEA, UK, and Switzerland. Requires **`android-sdk` 4.1.0+**. There is no extra
SDK to add here - Android installs reach Google through the App Conversion
API, which reads these signals; the on-device SDK in
[Google ICM](https://docs.linkrunner.io/features/google-icm) is iOS only.

Call `setConsent` **before** `init`, and again whenever the user's choice
changes:

```kotlin
import io.linkrunner.sdk.models.ConsentStatus
import io.linkrunner.sdk.models.LinkrunnerConsent

LinkRunner.getInstance().setConsent(
    LinkrunnerConsent(
        isEEA = ConsentStatus.GRANTED,
        hasConsentForDataUsage = ConsentStatus.GRANTED,
        hasConsentForAdsPersonalization = ConsentStatus.DENIED
    )
)
```

| Parameter | Meaning |
| --- | --- |
| `isEEA` | European regulations apply to this user (the EEA, the UK, or Switzerland) |
| `hasConsentForDataUsage` | The user agreed to their data being sent to Google for advertising |
| `hasConsentForAdsPersonalization` | The user agreed to their data being used to personalize ads |

Each takes `ConsentStatus.GRANTED`, `.DENIED`, or `.UNKNOWN`. Anything left
`UNKNOWN` is dropped from the payload rather than sent as a denial - never map
`unknown` to `granted`. **For users outside the EEA/UK/Switzerland, report
`isEEA` as denied and leave the other two unset.** Consent persists between
launches, so call `setConsent` again whenever it changes or the previous value
keeps being sent. See
[Send Consent](https://docs.linkrunner.io/features/send-consent).

## 7. Initialize (required, before anything else)

Call in your `Application` subclass's `onCreate()`. `init()` returns nothing -
attribution + deeplink data comes from `getAttributionData()` later (see
`references/events.md`).

```kotlin
import android.app.Application
import io.linkrunner.sdk.LinkRunner
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

class MyApplication : Application() {
    override fun onCreate() {
        super.onCreate()

        CoroutineScope(Dispatchers.IO).launch {
            try {
                LinkRunner.getInstance().init(
                    context = applicationContext,
                    token = "YOUR_PROJECT_TOKEN",
                    secretKey = "YOUR_SECRET_KEY", // Optional - only for SDK signing
                    keyId = "YOUR_KEY_ID", // Optional - only for SDK signing
                    debug = true // Optional, defaults to false - turn off for release
                )
            } catch (e: Exception) {
                println("Exception during initialization: ${e.message}")
            }
        }
    }
}
```

Register the class in `AndroidManifest.xml` if it isn't already:

```xml
<application android:name=".MyApplication" ...>
```

**SDK signing** (optional, more secure): `secretKey` + `keyId` from
dashboard → Settings → SDK Signing.

## 8. Verify install

- Gradle sync resolves the dependency cleanly
- App builds and launches
- With `debug = true`, the SDK logs an init line on launch

Next: `references/events.md` (signup is required) and, if the user wants
links to open the app, `references/deep-linking.md`.
