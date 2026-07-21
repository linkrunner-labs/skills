---
name: linkrunner-ios
description: >-
  Integrate the Linkrunner mobile attribution SDK into a native iOS (Swift)
  app - add the package via SPM, initialize it, identify users, track events
  and revenue, and set up deep linking (Universal Links and custom URL
  schemes) with domain verification. Use when someone asks to add Linkrunner
  to an iOS app, wire up attribution, or debug why Linkrunner deep links are
  not opening the app.
metadata:
  category: sdk
  platform: ios
  package: linkrunner-ios
  docs: https://docs.linkrunner.io/sdk/ios
---

# Linkrunner - iOS (native) integration

You are integrating **Linkrunner** (mobile attribution + deep linking) into a
native iOS Swift app. Work in this order and **inspect the project before
editing** - do not paste snippets blindly.

## 0. Before you touch anything

1. Confirm this is a native iOS app: there is an `.xcodeproj` or `.xcworkspace`
   and either a `Package.swift` or Xcode-managed Swift Package dependencies.
2. Find the app's entry point - the `@main` `App` struct (SwiftUI) or
   `AppDelegate`/`SceneDelegate` (UIKit) - and how it currently initializes.
3. Ask the user for their **project token** (dashboard -> Settings). If they
   use SDK signing, also get `secretKey` + `keyId`. Never hardcode these in a
   file that gets committed if the user keeps secrets elsewhere - ask where.
4. Check current versions against requirements (below) before bumping
   anything.

## 1. Decide what the user actually needs

| They want... | Do this |
| --- | --- |
| "Add Linkrunner / set up attribution" | `references/install.md` then `references/events.md` (at minimum init + signup) |
| "Set up deep links" / "links open Safari not my app" | `references/deep-linking.md` + run `scripts/verify-deeplinks.sh` |
| "Track purchases / events" | `references/events.md` |

Most first-time integrations need **install -> init -> signup -> handle
deeplink**, in that order. Deep-link *verification* (AASA) is separate and is
the part that usually breaks - treat it as its own step.

## 2. Requirements (verify, don't assume)

- iOS 15.0+, Swift 5.9+, Xcode 14.0+
- Install via **Swift Package Manager** - that is the only method documented
  for this SDK. If the project uses CocoaPods for everything else, still add
  Linkrunner through SPM (Xcode supports mixing both) rather than inventing a
  pod - none is published for `linkrunner-ios`.

## 3. Golden rules

- `initialize()` must run **before** any other Linkrunner call - in the
  `App` struct's `init()` (SwiftUI) or `application(_:didFinishLaunchingWithOptions:)`
  (UIKit), wrapped in a `Task` since it's `async throws`.
- Call `signup()` the moment a user is identified (signup OR login) - this is
  what ties the install to a user. `setUserData()` is a later top-up, never a
  replacement.
- For Universal Links, the app changes are worthless until the hosted
  `apple-app-site-association` file verifies **and** Apple's CDN has picked it
  up - that CDN, not your domain, is what devices actually fetch from. Always
  finish by running `scripts/verify-deeplinks.sh`.
- `appID` in the AASA must be exactly `TEAM_ID.BUNDLE_ID` - a mismatch is a
  common silent failure.
- Universal Links never open from a URL typed into Safari's address bar - only
  test by tapping a link from another app (e.g. Notes).

## 4. Finish

After editing, build once, and run
`scripts/verify-deeplinks.sh <domain> "" <team_id.bundle_id>` to confirm deep
-link verification is actually live (the script has no Android check to run
without a package name, so pass `""` for it on an iOS-only project). Report
which checks passed and which the user still has to do in the dashboard (host
the AASA under Project Settings -> Domain Verification).

## References

- `references/install.md` - SPM install + Info.plist config + initialization
- `references/deep-linking.md` - Universal Links / custom URL schemes + debugging
- `references/events.md` - signup, setUserData, revenue, trackEvent, attribution
