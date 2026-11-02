# The SDK surface: naming per stack, correct cadence, and what each call must carry

Every Linkrunner mobile SDK exposes the same twelve-method surface; only the receiver and casing change.
Learn the table once and you can audit any stack.

## 1. The same method, five names

| Concept | React Native / Expo / Capacitor / Cordova | Flutter | Native Android | Native iOS | Unity |
|---|---|---|---|---|---|
| receiver | `linkrunner` (default import) | `LinkRunner()` | `LinkRunner.getInstance()` | `LinkrunnerSDK.shared` | `LinkrunnerSDK` (static) |
| initialize | `init` | `init` | `init` | **`initialize`** | `Initialize` |
| identify user | `signup` | `signup` | `signup` | `signup` | `Signup` |
| own user id | `setCustomerUserId` | `setCustomerUserId` | `setCustomerUserId` | `setCustomerUserId` | *(check docs)* |
| user details | `setUserData` | `setUserData` | `setUserData` | `setUserData` | `SetUserData` |
| custom event | `trackEvent` | `trackEvent` | `trackEvent` | `trackEvent` | `TrackEvent` |
| revenue (new majors) | `trackEvent` + payment keys | `trackEvent` + payment keys | `trackEvent` + payment keys | `trackEvent` + payment keys | `TrackEvent` + payment keys in the JSON |
| refund (new majors) | `trackEvent`, `status: PAYMENT_CANCELLED` | same | same | same | same |
| revenue / refund (deprecated) | `capturePayment` / `removePayment` | `capturePayment` / `removePayment` | `capturePayment` / `removePayment` | `capturePayment` / `removePayment` | `CapturePayment` / `RemovePayment` (old bridges) |
| 3rd-party ids | `setAdditionalData` | `setAdditionalData` | `setAdditionalData` | `setAdditionalData` | `SetAdditionalData` |
| push token | `setPushToken` | `setPushToken` | `setPushToken` | `setPushToken` | `SetPushToken` |
| attribution / deferred DL | `getAttributionData` | `getAttributionData` | `getAttributionData` | `getAttributionData` | `GetAttributionData` |
| direct deep link | `handleDeeplink` | `handleDeeplink` | `handleDeeplink` | `handleDeeplink` | `HandleDeeplink` |
| consent (Google ICM) | `setConsent` | `setConsent` | `setConsent` | `setConsent` | `SetConsent` |
| privacy | `enablePIIHashing`, `setDisableAaidCollection` | same | same | `enablePIIHashing` | `SetDisableAaidCollection` |

Notes that catch people out:
- **iOS is `initialize`, not `init`** (`init` is a Swift keyword). Searching only for `init` misses it.
- **Unity has no dedicated SDK.** `LinkrunnerSDK` is the C# wrapper from the Unity guide, sitting on a Java
  bridge and a Swift bridge that the app itself contains - so the bridge code is app code and in scope.
  It is also callback-driven: `Initialize`/`GetAttributionData` return `void` and deliver results via
  `OnInitialized` / `OnAttributionData` / `OnDeeplinkHandled` events. A Unity app that calls
  `GetAttributionData` but subscribes to no handler has a dead chain - the exact bug to look for there.
- **Payments are `trackEvent` from the new majors.** Android, iOS and Flutter 5.0.0, `rn-linkrunner`
  and `expo-linkrunner` 4.0.0, `capacitor-linkrunner` 3.0.0, `cordova-linkrunner` 2.0.0, Unity bridges on
  native 5.0.0. A `trackEvent` whose event data has `amount`, `paymentId` **and** `currency` is a payment
  (revenue); count those call sites as revenue coverage. `amount` or `currency` without `paymentId` is a
  plain custom event, not revenue. `capturePayment` / `removePayment` are **deprecated** on those versions
  (still work, IDE warning, removed in a future major) and the only payment API below them.
- **Web is a different, smaller surface**: `lr.identify(userId)` and `lr.track(...)`, loaded via the CDN
  script or `@linkrunner/web`. Page views are automatic. Don't apply the mobile cadence rules to it.

## 2. Correct cadence - the rule you judge each call site against

Sourced from each SDK guide's **Function Placement Guide** (`/sdk/<platform>#function-placement-guide`).
The endpoint column is what the call becomes on the wire (documented in the public
[SDK-less API reference](https://docs.linkrunner.io/sdk-less/api-reference)), which helps when you also
inspect network traffic or debug logs.

| Method | Endpoint | Where it belongs | When it should fire | Defect if… |
|---|---|---|---|---|
| `init` | `/api/client/init` | App entry point, before anything else | **Once per cold start**, regardless of login | Called from a screen, a rebuilt widget, per-activity, or more than once |
| `signup` | `/api/client/trigger` | The identification flow (signup **or** login) | Once, when the user becomes known | Only on signup and not on login → returning users never tie to the install |
| `setCustomerUserId` | *(SDK-managed)* | Right after `init`, as soon as the id is known | When the id becomes known/changes | Called with an unstable id (session id, device id regenerated per launch) |
| `setUserData` | `/api/client/set-user-data` | Auth logic, after `signup` | When user details actually **change** | Fires on every launch / profile view with an unchanged payload |
| `trackEvent` | `/api/client/capture-event` | Throughout the app | On a real user action | Fires on plain screen render/scroll; or the name is built dynamically |
| `trackEvent` (payment) | `/api/client/capture-event` (payment fields) | Payment processing | On each payment state you track; `PAYMENT_COMPLETED` (the default) on **success** only | Completed status sent on checkout open, in the screen body, or with a fresh `paymentId` on every retry |
| `trackEvent`, `PAYMENT_CANCELLED` | `/api/client/capture-event` | Refund flow | On refund/cancellation, same event name + `paymentId` | - (rarely present; absence is fine) |
| `capturePayment` *(deprecated)* | `/api/client/capture-payment` | Payment processing | On payment **success** only | Same as above; on SDK ≥ the new majors also a migration finding |
| `removePayment` *(deprecated)* | `/api/client/remove-captured-payment` | Refund flow | On refund/cancellation | - (rarely present; absence is fine) |
| `setAdditionalData` | `/api/client/integrations` | Integration setup code | **Once**, when a third-party id (e.g. CleverTap) first becomes available | On a screen view or every launch - it has no client-side dedup |
| `setPushToken` | `/api/client/update-push-token` | Push setup / token-refresh callback | When the FCM/APNs token changes | Called once at startup only, never on refresh → uninstall tracking degrades |
| `getAttributionData` | `/api/client/attribution-data` | After `init` | When attribution / the deferred deep link is needed | Never called (deferred deep linking is dead), or called and the result discarded |
| `handleDeeplink` | `/api/client/handle-deeplink` | Deep-link entry points | When the app opens **from a deep link** | Cold start wired but not warm start (or vice versa) |
| `setConsent` | *(stored on device, sent by the SDK)* | Before `init`, and on every consent change | Before `init`; again when consent changes | Set once and never updated after the user withdraws consent |

`setCustomerUserId` is the only method with a **built-in client-side guard** (it no-ops on an unchanged
value). Every other method sends what you tell it to, every time - which is why placement is the whole game.

## 3. Parameters that are load-bearing vs merely optional

Flagging an optional parameter as a defect is the fastest way to lose a report's credibility. This is the
line:

**Required / load-bearing - flag when wrong or absent:**
- `signup` → `user_data.id` - a **stable** identifier from the app's own system.
- `trackEvent` payment → event name, `amount` (a **number**, ≥ 0), `paymentId`, `currency` (3-letter ISO
  4217) and `userId` (`""` = the user saved by `signup`) all in the event data. `paymentId` must be the
  **payment provider's or your backend's stable id**: the server deduplicates on `paymentId` + event name +
  `status`. `paymentId` with `amount` or `currency` missing is rejected and nothing is sent.
- The payment **event name** is stored exactly as sent and matched exactly against Meta, Google, SKAN and
  affiliate mappings. A migrated old type must keep its uppercase spelling (`FIRST_PAYMENT`, `DEFAULT`,
  ...); `first_payment` or `FirstPayment` is a new, unmapped payment type.
- `capturePayment` *(deprecated)* → `amount` (a **number**), `userId`, and a stable `paymentId`.
- `removePayment` *(deprecated)* → `userId`.
- `trackEvent` → `eventName`, a **static string**.
- `init` → the project token, and `debug` **false** on release paths.

**Optional - never a finding when absent:**
- **`eventId` on `trackEvent`.** Optional by design. Do not flag it, do not add it to fix snippets. Fix a
  duplicate event at the emitter instead.
- `name`, `phone`, `email`, `user_created_at`, `is_first_time_user`, `mixpanel_distinct_id`,
  `amplitude_device_id`, `posthog_distinct_id` on `signup`/`setUserData`.
- `status` on a `trackEvent` payment (default `PAYMENT_COMPLETED`); `type` and `status` on `capturePayment`
  (default `DEFAULT` / `PAYMENT_COMPLETED`).
- `paymentId` on `removePayment` (omitting it removes all of that user's payments - intentional).
- `secretKey`/`keyId` (SDK signing) - only required if the project enforces signing.

**Enum values worth checking against the docs** (a typo silently degrades to the default):
old payment types (a `capturePayment` `type`, or a payment event name that must keep matching existing
mappings) ∈ `FIRST_PAYMENT | SECOND_PAYMENT | TRIAL_STARTED | TRIAL_CANCELLED | WALLET_TOPUP |
FUNDS_WITHDRAWAL | SUBSCRIPTION_CREATED | SUBSCRIPTION_RENEWED | SUBSCRIPTION_CANCELLED |
SUBSCRIPTION_REFUNDED | SUBSCRIPTION_BILLING_ISSUE | DEFAULT | ONE_TIME | RECURRING` (uppercase, exactly);
`status` ∈ `PAYMENT_INITIATED | PAYMENT_COMPLETED | PAYMENT_FAILED |
PAYMENT_CANCELLED`; consent signals ∈ `granted | denied | unknown`.

## 4. Ecommerce and revenue-sharing payloads

If the team syncs events to Meta or Google, `eventData` must carry the commerce fields, and the custom
event must be mapped to a standard commerce event **in the Linkrunner dashboard** (a config step, not a
code one - note it as an action item rather than a code defect):

```js
await linkrunner.trackEvent("add_to_cart", {
  content_ids: ["product_123"],
  contents: [{ id: "product_123", quantity: 1, item_price: 49.99 }],
  content_type: "product",
  currency: "USD",
  value: 49.99,
  num_items: 1,
});
```

Revenue reaches ad networks only as a **payment**: on the new majors, `amount`, `paymentId` and `currency`
together in the event data, `amount` **as a number** (the order total). On those versions a
`trackEvent("purchase_completed", { amount: 149.99 })` with no `paymentId`/`currency` is ordinary event data,
not revenue - a finding if the team expects it to count. `amount: "149.99"` is a real finding - check the
type at the call site, including whether an upstream `toString()`/template literal made it a string.

Requires the Ecommerce Event Manager minimum version - see `detect-stack.md` §4.

## 5. The two chains, in code

Most integrations break in a chain rather than a single call. Trace both fully.

**Deferred deep link (install → first open → route):**
```
init  →  getAttributionData()  →  result.deeplink  →  navigate(result.deeplink)
                                                       ^^^^^^^^^^^^^^^^^^^^^^^
                              this last hop is what traffic capture cannot see - verify it exists
```
`getAttributionData` is **pull-only**: the SDK never routes for you. A call whose result is logged,
stored in state and rendered on a debug screen, or destructured but unused, is a dead chain. Also check
it is called **after** `init` has completed, not racing it.

The returned shape (per the docs) is roughly:
```ts
{ deeplink?: string; campaignData?: { id, name, type, adNetwork, ... }; attributionSource?: ... }
```
Confirm the code reads `deeplink` (not a nested/renamed field it assumed) and handles `undefined`.

**Direct deep link (re-engagement):**
```
cold start: getInitialURL / onCreate intent / userActivity  →  handleDeeplink(url)  →  route
warm start: url listener / onNewIntent / continueUserActivity →  handleDeeplink(url)  →  route
```
Both paths must exist. Missing the warm-start listener is the single most common half-fix: deep links
work when the app was closed and silently do nothing when it was backgrounded. On Android also confirm
`onNewIntent` is implemented **and** the activity's `launchMode` doesn't discard it; on iOS both
`continueUserActivity` (Universal Links) and `open url` (custom schemes) need wiring.

Linkrunner returns a **resolved** `deeplink` from `handleDeeplink`. Routing on the original tracking URL
instead of the returned value sends the user to the wrong place - check which one the code navigates to.

## 6. Correlating with runtime evidence

If you can also run the app - debug-mode logs, the dashboard's Events page, or the
[SDK Integration Testing](https://docs.linkrunner.io/testing/integration-testing) flow - line the results up
with the code: a method with a call site in code but **no** activity at runtime is either dead code, a
guarded branch, or a screen no one reaches - and the code tells you which. That combination is the strongest possible finding, and it is
how you convert "the endpoint was never called" into "here is the line that should have called it."
