---
name: linkrunner-sdk-code-audit
description: >-
  Audit an existing Linkrunner SDK integration by reading the app's source
  code, on any stack (React Native, Expo, Flutter, native Android, native iOS,
  Capacitor, Cordova, Unity, web) - no device or emulator needed. Finds every
  SDK call site (through wrapper modules and monorepo packages), checks each
  against the Function Placement Guide, traces the deferred and direct
  deep-link chains through to navigation, checks the platform config the SDK
  depends on (AndroidManifest, backup rules, Info.plist, Associated Domains,
  Expo plugin), and reports every defect with file:line evidence and a fix.
  Use when someone asks "is Linkrunner integrated correctly?", "review our
  Linkrunner integration", "audit the SDK setup before release", or says
  attribution or deferred deep linking is not working and the code should be
  checked.
metadata:
  category: troubleshoot
  slug: code-audit
  docs: https://docs.linkrunner.io/testing/integration-testing
---

# Linkrunner - SDK code audit

Answers **"is Linkrunner wired up correctly in this app?"** by reading the code, whatever the app is
built with. It is read-only: it finds what is wrong, proves it with file:line evidence, and proposes the
fix. To *add* or *rewrite* the integration, use the platform skill (`npx @linkrunner/skills add
<platform>`). To prove behaviour on a device, follow
[SDK Integration Testing](https://docs.linkrunner.io/testing/integration-testing).

## 0. Gather the facts first

Detect or ask for these before judging anything:

- **Which package ships.** In a monorepo, a hit in `examples/` or a legacy app is not the integration.
- **The stack and the pinned SDK version**, from the lockfile rather than the manifest range
  (`references/detect-stack.md`). Several methods are version-gated, so "not called" can mean "not
  available in your version".
- **The commit or branch** you are auditing. Findings are only true for that tree.
- **Report or fix?** The default is a report. Only edit code when asked.

## 1. Run the scanner

```bash
bash scripts/scan-integration.sh <app-root>   # scripts/ is relative to this skill
```

It prints the stack, the SDK dependency and version, every candidate call site with file:line, the
`trackEvent` name inventory, hygiene smells (hardcoded `debug: true`, token literals, unstable
`paymentId`, string `amount`, guarded calls), the platform config, and a per-method coverage count.
**It is a map, not a verdict.** Open and read every line before it becomes a finding.

## 2. Resolve and judge

| Question | Go to |
| --- | --- |
| Which stack, package, and version? Is a capability version-gated? | `references/detect-stack.md` |
| Is this call real, reachable, placed correctly, and not guarded out of production? | `references/call-site-analysis.md` |
| What is the correct cadence and payload for this method on this stack? | `references/api-surface.md` |
| Manifest, backup rules, Info.plist, entitlements, Expo plugin | `references/platform-config.md` |
| Writing the report | `references/report.md` |

## 3. Golden rules

1. **A grep hit is a lead, not a finding.** Every finding names a file:line you opened, the enclosing
   function, and what triggers it.
2. **Trace wrappers.** Most apps call the SDK through their own service. The direct call sits in one
   file; the placement question lives at the wrapper's call sites.
3. **Never report "never called" from one search.** Search the whole workspace, every naming variant
   (iOS spells it `initialize`, Unity uses PascalCase), and native bridges. Say what you searched.
4. **Reachability is part of the finding.** A call behind `__DEV__`, `kDebugMode`, `#if DEBUG`,
   `Platform.OS`, or a remote flag, or in code nothing invokes, does not run where the team thinks.
5. **Walk both deep-link chains to the navigation call.**
   Deferred: `init` → `getAttributionData` → read `deeplink` → navigate.
   Direct: cold start and warm start → `handleDeeplink` → route on the returned `deeplink`.
   A fetched result that is only logged is a dead chain.
6. **Judge placement by lifecycle.** `init` runs once per cold start at app entry - never in a Flutter
   `build()`, a React `useEffect` with missing or changing deps, `Activity.onCreate`, a SwiftUI
   `onAppear`, or a routed screen.
7. **Do not flag optional parameters.** `eventId` on `trackEvent` is optional - never a finding, never
   in a fix. The load-bearing fields are the user `id` and a stable, provider-issued `paymentId`.
8. **Report what is correct too.** Confirming correct placement is what makes the defects credible.

## 4. What only the code can show

Runtime testing cannot see these, so spend your attention here:

- A guard that disables a call in production builds or on one platform.
- `getAttributionData` called but its `deeplink` never routed - the request succeeds and the user still
  lands on the home screen.
- `paymentId` built from `Date.now()` or a fresh UUID - server-side dedup fails and retries double-count.
- `amount` passed as a string - ad-network revenue sharing drops it.
- Event names built with template strings or concatenation, which fill the dashboard with one-off names.
- A hardcoded, staging, or wrong project token; `debug: true` on a release path.
- Two `init` sites, or call sites in code that never runs.
- Missing config: `ACCESS_NETWORK_STATE`, backup exclusion rules, an `autoVerify` intent filter, the
  Associated Domains entitlement, the ATT usage string.

## 5. Not findings

- Absent optional parameters (rule 7).
- Behaviour inside the Linkrunner SDK itself. Report it to support@linkrunner.io instead.
- Revenue sent server-to-server instead of through `capturePayment` - a valid design. Check the backend
  before calling it missing.
- Development-only effects: React StrictMode double effects, Fast Refresh re-runs.
- Code style, wrapper design, file layout.

## 6. Safety

- **Read-only by default.** Propose diffs; do not edit or commit unless asked. When asked to fix, keep
  each finding a separate, reviewable change.
- **Do not run the app's build, install, or `postinstall` scripts** to check something. Reading is the job.
- **Never print a secret.** For a committed token or `secretKey`, report the file:line, never the value,
  and tell the user directly so it can be rotated.

## 7. Finish

Write `LINKRUNNER_INTEGRATION_REVIEW.md` in the project root (`references/report.md`): the stack line, a
summary and findings table, one section per finding (quoted evidence, consequence, fix diff in the app's
own language, doc link), a "What's correct" section, the coverage checklist over all twelve methods plus
platform config, and the limits of a static review. Then tell the user:

- the top one to three fixes, in order;
- to verify on a device with [SDK Integration Testing](https://docs.linkrunner.io/testing/integration-testing);
- which skill applies the fixes: `npx @linkrunner/skills add <platform>`, `add events` for event and
  revenue wiring, `add deep-links` if links open the browser.

## References

- `references/detect-stack.md` - framework, SDK package, pinned version, monorepos, version-gate table
- `references/api-surface.md` - the twelve methods on every stack, correct cadence, required vs optional parameters, the two deep-link chains
- `references/call-site-analysis.md` - resolving call sites, tracing wrappers, per-framework lifecycle traps, anti-pattern catalogue
- `references/platform-config.md` - AndroidManifest, Gradle, Info.plist, entitlements, Expo, Cordova/Capacitor, uninstall tracking
- `references/report.md` - report structure, severity, coverage checklist, limits
