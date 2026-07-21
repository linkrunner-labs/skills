# iOS Universal Links - diagnosis and fix

Source of truth: https://docs.linkrunner.io/features/deep-linking-setup#debugging-domain-verification

A universal link opening Safari means the association is not verified on the
device. Note: **typing a link into Safari never opens the app** - test by tapping
from another app (Notes). Rule that out first.

## 1. Is the hosted file correct?

```bash
curl -v https://<domain>/.well-known/apple-app-site-association
```

- **404** -> re-save in dashboard → Project Settings → Domain Verification.
- Must be valid JSON, served over HTTPS with **no redirects**, and `appID` must
  be exactly `TEAM_ID.BUNDLE_ID`.

```json
{ "applinks": { "apps": [], "details": [ { "appID": "TEAM_ID.BUNDLE_ID", "paths": ["/*"] } ] } }
```

## 2. Check Apple's CDN (the #1 iOS cause)

Devices do not fetch the file from your domain. Apple's CDN fetches it from your
domain, and devices download it from the CDN:

```bash
curl -v https://app-site-association.cdn-apple.com/a/v1/<domain>
```

If this is older than what your server returns, the CDN has not picked up your
change. There is **no way to purge it**. It usually propagates within a few hours
but can take up to a day.

## 3. Bypass the CDN with developer mode (while testing)

1. In Xcode, change the Associated Domains entry to
   `applinks:<domain>?mode=developer`
2. On the device: **Settings → Developer → Associated Domains Development** = on
3. Delete the app and reinstall

Development builds now fetch the file directly from your domain, skipping the CDN
cache. App Store builds ignore developer mode - test with the normal entitlement
before release.

## 4. Clear the device's cached copy

iOS caches the association at install/update time. To force a re-fetch, delete
the app and reinstall.

## 5. Read the verification logs

Connect the device to a Mac, open **Console.app**, filter for `swcd` (the daemon
that downloads and verifies associated domains). Reinstall the app and watch for
download failures or parse errors.

## 6. Native config

Xcode → **Signing & Capabilities** → add **Associated Domains**:

```
applinks:app.example.com
```

The Team ID in `appID` must match this app's signing team.

## Checklist when it still fails

- `appID` is `TEAM_ID.BUNDLE_ID` with the correct Team ID.
- Associated Domains capability lists the exact domain.
- Apple CDN copy is current (or developer mode is on).
- You are tapping the link from another app, not typing it into Safari.
