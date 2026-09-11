# The deliverable

Default output is a **Markdown report written into the repo** as `LINKRUNNER_INTEGRATION_REVIEW.md`, so it
can be read in a PR, diffed, and updated as fixes land.

Do not modify any other file unless the user asked for fixes to be applied.

## 1. Structure

````markdown
# Linkrunner integration review - <App name>

**Stack:** React Native 0.73 (bare) · `rn-linkrunner` 2.10.1 · audited at commit `a1b2c3d`, <date>
**Scope:** `apps/mobile` (JS layer + android/ + ios/ projects). Web SDK on the marketing site not reviewed.

## Summary
<3-5 sentences: is the integration fundamentally sound? What is the single most important thing to fix?
Lead with the answer, not the process.>

| # | Finding | Severity | Method / file |
|---|---|---|---|
| 1 | `paymentId` regenerated per attempt - payments double-count | **Critical** | `checkout/pay.ts:212` |
| 2 | Deferred deep link fetched but never routed | **High** | `App.tsx:64` |
| 3 | `init` called from HomeScreen, not app entry | **High** | `screens/HomeScreen.tsx:52` |
| 4 | No backup-exclusion rules → reinstalls misread | Medium | `AndroidManifest.xml` |
| 5 | `signup` on registration only, not on login | Medium | `auth/register.ts:88` |
| 6 | Init placement, event wiring, deep-link cold start | ✅ Correct | - |

## Findings
### 1. <title>  ·  Severity: Critical
**What's wrong** - one or two sentences.
**Evidence** - `path/file.ts:212`
```ts
<the actual lines, unmodified>
```
**Why it matters** - the behavioural consequence, in the user's/business's terms.
**Fix**
```diff
- paymentId: `${Date.now()}`,
+ paymentId: order.providerPaymentId,
```
**Reference** - https://docs.linkrunner.io/sdk/react-native#revenue-tracking

### 2. …

## What's correct
<Short section confirming the parts that are right. Not optional - see §3.>

## Coverage checklist
<the matrix from §4>

## Limits of this review
<§5>
````

## 2. Severity - use behaviour, not taste

| Severity | Means | Examples |
|---|---|---|
| **Critical** | Data is wrong or absent in a way that misleads decisions or spend | `init` never runs in production; unstable `paymentId` inflating revenue; missing `INTERNET`; wrong project token |
| **High** | A whole feature silently doesn't work | Deferred deep link never routed; App Links not verified; `signup` missing on login |
| **Medium** | Degraded accuracy or duplicate load | No backup rules; `setAdditionalData` on every launch; stale push token |
| **Low** | Hygiene, or a risk that hasn't bitten yet | Empty catch; old pinned SDK version; `debug: true` on a debug-only path |
| ✅ **Correct** | Verified right - state it explicitly | `init` at app entry, once; events on real actions |

Anything you could not determine is **not** a severity - it goes in Limits.

## 3. Every finding needs four things, and the report needs a fifth

Per finding: **the file:line**, **the code quoted as it is**, **the behavioural consequence**, and **a fix
in the app's own language**. A finding without a quoted line is an opinion; a finding without a
consequence is pedantry; a fix in the wrong language is unusable.

And the report as a whole needs a **"What's correct"** section. A review that is only complaints reads as
adversarial and gets dismissed; confirming the things that are right is what makes the defects credible.
It also tells the team what *not* to touch while fixing the rest.

Write fixes as **diffs against their actual code**, including their wrapper's naming - they should be able
to apply it without translating. If the fix is a config addition, give the exact XML/JSON block and the
file path it goes in.

## 4. The coverage checklist

Close with a matrix over the whole surface, so the reader can see what was examined rather than inferring
it from the findings. Mark every row.

```markdown
| Item | Status | Where |
|---|---|---|
| `init` | ✅ correct / ⚠️ defect / ❌ absent / - n/a | `App.tsx:31` |
| `signup` | ⚠️ registration only | `auth/register.ts:88` |
| `setCustomerUserId` | ❌ absent (SDK 2.10.1 - needs ≥ 2.11.0) | - |
| `setUserData` | ✅ | `auth/session.ts:44` |
| `trackEvent` | ✅ 14 events, static names | `events/` |
| `capturePayment` | ⚠️ unstable paymentId | `checkout/pay.ts:212` |
| `removePayment` | - not used (no refund flow) | - |
| `setAdditionalData` | - no third-party integration | - |
| `setPushToken` | ⚠️ startup only, not on refresh | `push/setup.ts:19` |
| `getAttributionData` | ⚠️ fetched, never routed | `App.tsx:64` |
| `handleDeeplink` | ⚠️ cold start only | `App.tsx:57` |
| `setConsent` | - not using Google ICM | - |
| Manifest permissions | ✅ | `AndroidManifest.xml` |
| Backup exclusion rules | ❌ absent | `AndroidManifest.xml` |
| App Links intent-filter | ✅ autoVerify on `app.example.com` | `AndroidManifest.xml:28` |
| iOS Associated Domains | ❌ no entitlements file | - |
| `Info.plist` (ATT, SKAN, schemes) | ⚠️ ATT string missing | `ios/App/Info.plist` |
| Token / debug hygiene | ✅ env-driven | `.env`, `App.tsx:31` |
```

`- n/a` is a real, useful verdict: "no refund flow exists, so `removePayment` is correctly absent" is
information. Don't leave a row blank.

## 5. Limits - always include

State plainly what static review cannot establish:

- It shows what the code *can* do, not what a build *did*. Call frequency, real payloads, server responses
  and install-referrer delivery need a runtime test - see
  [SDK Integration Testing](https://docs.linkrunner.io/testing/integration-testing).
- Runtime-flag branches: the repo shows the branch, not the live flag value - name the flags the team must
  check.
- Anything unresolved (a dynamic dispatch, a native bridge you couldn't follow, a package you weren't given).
- The commit/branch audited.

If runtime evidence was also available (debug-mode logs, the dashboard's Events page), say which findings
it corroborates - those are the ones the team can't argue with.

## 6. Tone

Write for the app's engineers. Placement bugs like an `init` in `build()` look correct in review and only
misbehave at runtime, so state the defect, the consequence, and the fix without editorializing, and keep
the whole thing short enough that it gets read.
