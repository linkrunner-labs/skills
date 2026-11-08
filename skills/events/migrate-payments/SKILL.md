---
name: linkrunner-migrate-payments
description: >-
  Migrate Linkrunner payments from the deprecated capturePayment and
  removePayment to trackEvent, which sends each payment as an in-app event with
  revenue. Detects the platform and installed SDK version, upgrades to the
  version where capturePayment is deprecated, rewrites every call with the
  exact same payment name so Meta, Google and partner mappings keep working,
  and verifies nothing is left. Use when someone says "migrate capturePayment
  to trackEvent", "capturePayment is deprecated", "upgrade Linkrunner SDK to
  5.0 / rn-linkrunner 4.0", or "move Linkrunner payments to in-app events".
metadata:
  category: events
  slug: migrate-payments
  docs: https://docs.linkrunner.io/sdk/migrate-to-track-event
---

# Linkrunner - migrate payments to trackEvent

In the new SDK versions a payment is an in-app event with revenue, sent with
`trackEvent`. `capturePayment` and `removePayment` still work but are
deprecated and will be removed in a future major version. Your job is to move
every call over **without changing what Linkrunner stores**, so the dashboard,
reports and ad-network mappings see exactly the same payments as before.

Work in this order. Do not skip the inventory or the verify step.

## 0. Detect the platform and the installed version

| Platform | Where the version is | Package |
| --- | --- | --- |
| Android | `build.gradle(.kts)` dependency | `io.linkrunner:android-sdk` |
| iOS | `Podfile` / `Podfile.lock`, or `Package.swift` / `Package.resolved` | `LinkrunnerKit` / `linkrunner-ios` |
| Flutter | `pubspec.yaml` / `pubspec.lock` | `linkrunner` |
| React Native | `package.json` | `rn-linkrunner` |
| Expo | `package.json` | `expo-linkrunner` and `rn-linkrunner` |
| Capacitor | `package.json` | `capacitor-linkrunner` |
| Cordova | `package.json` / `config.xml` | `cordova-linkrunner` |
| Unity (bridges) | the native Android and iOS versions your bridges use (most Unity apps, see https://docs.linkrunner.io/sdk/unity) | `io.linkrunner:android-sdk`, `LinkrunnerKit` |
| Unity (package) | `Packages/manifest.json` | `io.linkrunner.unity-sdk` |

A monorepo can have more than one. Migrate each app separately.

## 1. Pick the target version

| Platform | Older versions | New versions (`capturePayment` deprecated) |
| --- | --- | --- |
| Android | 4.x | 5.0.0 |
| iOS | 4.x | 5.0.0 |
| Flutter | 4.x | 5.0.0 |
| React Native | 3.x | 4.0.0 |
| Expo | 3.x | 4.0.0 (with `rn-linkrunner` 4.0.0 or later) |
| Capacitor | 2.x | 3.0.0 |
| Cordova | 1.x | 2.0.0 |
| Unity bridges | native 4.x | native 5.0.0 |
| Unity package | 2.x | 3.0.0 |

Use the newest published version that is at least the one above. Check the
registry before you edit anything (`npm view rn-linkrunner version`,
`flutter pub outdated`, Maven Central, `pod search LinkrunnerKit`). If the
target version is not published yet, stop and tell the user. Do not point a
project at an unreleased version.

Upgrade even if the backend already accepts the payment. On an older version
the backend stores a `trackEvent` with `paymentId`, `amount`, `currency` and
`userId` as a payment, but the SDK does not check it. A missing or invalid key
leaves a custom event, and the app sees no error.

## 2. Inventory every payment call

From the app root:

```bash
bash scripts/find-payment-calls.sh .
```

It lists every `capturePayment`, `removePayment`, `CapturePaymentRequest`,
`RemovePaymentRequest`, `LRCapturePayment`, `LRRemovePayment` and
`PaymentType` use, plus backend calls to `/api/v1/capture-payment`. For each
call write down: file and line, the payment `type`, where `amount`,
`paymentId` and `userId` come from, `status`, and any `eventData`. Show this
list to the user before changing code.

## 3. Ask for the currency

`trackEvent` payments need a 3-letter ISO 4217 `currency` (for example `INR`
or `USD`). `capturePayment` never sent one. **Ask the user** which currency
each payment is in, or where the app already keeps it (an order or product
object, a store config). Never guess it from the country, the locale or the
dashboard currency. A wrong currency changes revenue in every report.

## 4. Upgrade the SDK

Bump the package to the target version and do the native step the platform
needs: `pod install` (iOS, React Native, Capacitor, Flutter iOS), `npx expo
prebuild --clean` or an EAS build (Expo), `npx cap sync` (Capacitor),
re-adding the platform (Cordova), or a Gradle sync (Android). See
`references/platforms.md`.

## 5. Rewrite each capturePayment call

| `capturePayment` | `trackEvent` |
| --- | --- |
| `type` | the **event name**, its exact stored value in uppercase, see the table below |
| `amount` | `amount` in the event data (a number, the order total) |
| `paymentId` | `paymentId` in the event data |
| `userId` | `userId` in the event data (`""` still means the user saved by `signup` or `setUserData`) |
| `status` | `status` in the event data, optional, defaults to `PAYMENT_COMPLETED` |
| `eventData` | the other keys in the event data |
| not available | `currency` in the event data, new and required |

The event name must be the value Linkrunner stored before, character for
character. Linkrunner matches names exactly, so `first_payment` or
`FirstPayment` is a new event that no existing Meta, Google, SKAN or affiliate
mapping matches, and those payments silently stop reaching ad networks.

| Old type in code | Event name |
| --- | --- |
| no `type` passed | `"DEFAULT"` |
| `PaymentType.DEFAULT` (Android, Unity), `.default` (iOS), `'DEFAULT'` (JS) | `"DEFAULT"` |
| `PaymentType.DEFAULT_PAYMENT` (Flutter) | `"DEFAULT"` (it was stored as `DEFAULT`, not `DEFAULT_PAYMENT`) |
| `PaymentType.FIRST_PAYMENT` / `.firstPayment` / `'FIRST_PAYMENT'` | `"FIRST_PAYMENT"` |
| `.secondPayment` (iOS) | `"SECOND_PAYMENT"` |
| `WALLET_TOPUP` / `.walletTopup` | `"WALLET_TOPUP"` |
| `FUNDS_WITHDRAWAL` / `.fundsWithdrawal` | `"FUNDS_WITHDRAWAL"` |
| `SUBSCRIPTION_CREATED` / `.subscriptionCreated` | `"SUBSCRIPTION_CREATED"` |
| `SUBSCRIPTION_RENEWED` / `.subscriptionRenewed` | `"SUBSCRIPTION_RENEWED"` |
| `ONE_TIME` / `.oneTime` | `"ONE_TIME"` |
| `RECURRING` / `.recurring` | `"RECURRING"` |
| a variable holding the type | the same uppercase string it holds today; read where the variable is set |

Rules while rewriting:

- Send each payment through one path only. Never call both `capturePayment`
  and `trackEvent` for the same payment. The same `paymentId` under the same
  name is stored once; under different names it counts twice.
- Keep `amount`, `paymentId` and `currency` together. Only all three make the
  event a payment. `paymentId` with one of the others missing is rejected by
  the SDK and nothing is sent.
- `amount` must be a number of 0 or more. Keep it a number, never a string.
- `paymentId` must be a stable, non-empty id from your order or transaction.
  Older SDK versions let it be optional. If a call has none, ask the user for
  the order id to use. Never generate a random id at send time, because a
  retry would then count twice.
- If the old `eventData` already has a key named `amount`, `paymentId`,
  `currency`, `userId` or `status`, stop and ask. In the new API those keys
  are the payment fields.
- `amount` or `currency` without `paymentId` stays a custom event. Leave
  existing custom events that happen to carry `amount` alone.
- Remove imports that are now unused (`PaymentType`, `CapturePaymentRequest`,
  `LRCapturePayment`, and so on). Keep `PaymentStatus` if you pass a status.
- Keep the error handling the call site had. On Android an invalid payment
  rejects or throws (Flutter raises `PlatformException`). On iOS the native
  SDK logs the error and drops the payment, so test both platforms.

Exact before and after code for each platform is in
`references/platforms.md`.

## 6. removePayment

To cancel or refund a payment with `trackEvent`, send the **same event name**
and `paymentId` with `status: "PAYMENT_CANCELLED"`, plus the original
`amount` and `currency` (all three are needed for it to be a payment).

- If the call site has the original event name, amount and currency, rewrite
  it that way.
- If it does not (for example `removePayment` with only `userId`, which
  removes every payment of that user, or only a `paymentId`), **leave the
  `removePayment` call as it is** and list it in your report. It still works
  on the new versions and only shows a deprecation warning.

## 7. Server-side payments

Backend calls to `POST /api/v1/capture-payment` keep working. To migrate them,
call `POST /api/v1/capture-event` with `event_name` (same naming rule),
`amount`, `payment_id` and `currency` at the top level next to `user_id`. See
https://docs.linkrunner.io/api-reference/event-capture#payment-fields.

If the backend already queues events, `POST /api/v1/capture-event/batch` takes
up to 100 of them with the same fields. Check each event's result, because a
`200` can still contain failed events. Pass `event_timestamp` (ISO 8601 with a
timezone, at most 7 days old) when a payment is sent later than it happened, so
it keeps its real time.

## 8. Verify

1. Run the inventory script again. The only hits left should be
   `removePayment` calls you chose to keep and `PaymentStatus` imports.
2. Build or typecheck the app (`./gradlew assembleDebug`, `xcodebuild`,
   `flutter analyze`, `npx tsc --noEmit`, and so on). A deprecation warning
   left in the output points to a call you missed.
3. Run one test payment on a debug build with the SDK's debug logging on. It
   should show on https://dashboard.linkrunner.io/dashboard/events under the
   **same name** as before the migration.

## 9. Report

Tell the user: the SDK version change, each call you rewrote (file, old type,
new event name, currency used), each `removePayment` you kept and why, and
anything you could not verify. Remind them that a **new** event name (one that
is not an old type) needs a mapping in the dashboard for each ad network
before release, or those payments are saved but not sent to ad networks.

## References

- `references/platforms.md` - per-platform version detection, upgrade step, and before/after code
- `scripts/find-payment-calls.sh` - lists every deprecated payment call in a project
- https://docs.linkrunner.io/sdk/migrate-to-track-event - the migration guide this skill follows
