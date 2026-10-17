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
| revenue | `capturePayment` | `capturePayment` | `capturePayment` | `capturePayment` | `CapturePayment` |
| refund | `removePayment` | `removePayment` | `removePayment` | `removePayment` | `RemovePayment` |
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
| `trackEvent` | `/api/client/capture-event` | Throughout the app | On a real user action | Fires on plain screen render/scroll; or the name is built dynamically or per variant (`purchase_gold`) instead of one name with event parameters |
| `capturePayment` | `/api/client/capture-payment` | Payment processing | On payment **success** only | In the screen body, on checkout open, or on every retry |
| `removePayment` | `/api/client/remove-captured-payment` | Refund flow | On refund/cancellation | - (rarely present; absence is fine) |
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
- `capturePayment` → `amount` (a **number**), `userId`, and `paymentId` - `paymentId` must be the
  **payment provider's or your backend's stable id**, because the server deduplicates on it.
- `removePayment` → `userId`.
- `trackEvent` → `eventName`, a **static string**.
- `init` → the project token, and `debug` **false** on release paths.

**Optional - never a finding when absent:**
- **`eventId` on `trackEvent`.** Optional by design. Do not flag it, do not add it to fix snippets. Fix a
  duplicate event at the emitter instead.
- `name`, `phone`, `email`, `user_created_at`, `is_first_time_user`, `mixpanel_distinct_id`,
  `amplitude_device_id`, `posthog_distinct_id` on `signup`/`setUserData`.
- `type` and `status` on `capturePayment` (default `DEFAULT` / `PAYMENT_COMPLETED`).
- `paymentId` on `removePayment` (omitting it removes all of that user's payments - intentional).
- `secretKey`/`keyId` (SDK signing) - only required if the project enforces signing.

**Enum values worth checking against the docs** (a typo silently degrades to the default):
`type` ∈ `FIRST_PAYMENT | WALLET_TOPUP | FUNDS_WITHDRAWAL | SUBSCRIPTION_CREATED | SUBSCRIPTION_RENEWED |
ONE_TIME | RECURRING | DEFAULT`; `status` ∈ `PAYMENT_INITIATED | PAYMENT_COMPLETED | PAYMENT_FAILED |
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

For plain revenue sharing on a custom event, `amount` must be present **as a number**:
`trackEvent("purchase_completed", { amount: 149.99 })`. `amount: "149.99"` is a real finding - check the
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
