# From grep hit to verdict: resolving and judging call sites

This is where the audit is actually done. The scanner gives you candidates; this file turns them into
findings you can defend.

## 1. Resolve before you judge

For every candidate the scanner printed, answer four questions **in this order**. Stop at the first "no" -
a call site that isn't real or isn't reachable needs no cadence analysis.

1. **Is it a real call?** Not a comment, a doc URL (`https://docs.linkrunner.io/...`), a type definition,
   a test fixture, a string in a changelog, or vendored SDK source. Open the file and look.
2. **Is it reachable?** Which function encloses it, and what calls *that*? Follow until you reach an app
   entry point, a UI handler, or a route. If the trail ends in an unexported function nobody references,
   you have found dead code - a finding in itself.
3. **How often does the enclosing code run?** Once per process? Per screen mount? Per render/rebuild? Per
   tap? This is the question that decides most placement findings, and §3 gives the per-framework answer.
4. **Is it guarded?** Read the enclosing conditionals up to the function boundary. A call inside
   `if (__DEV__)`, `if (kDebugMode)`, `#if DEBUG`, `if (Platform.OS === 'android')`, or a feature flag
   does not run everywhere the team thinks it does.

Write the answers into a table as you go - this becomes the report's backbone:

| Method | Direct call site | Invoked from | Runs | Guarded | Verdict |
|---|---|---|---|---|---|
| `init` | `services/LinkrunnerService.ts:92` | `screens/HomeScreen.tsx:52` | every mount of Home | no | **Defect - not app entry** |

## 2. Trace the wrapper

Most teams wrap the SDK. The direct call lives in one file; the behaviour lives at the wrapper's call
sites. Judging the wrapper alone tells you almost nothing.

```bash
# 1. which files import the SDK directly? (usually exactly one)
grep -rnE "from ['\"]rn-linkrunner|import 'package:linkrunner|import io\.linkrunner|import LinkrunnerKit" \
  --exclude-dir=node_modules --exclude-dir=Pods --exclude-dir=build . 

# 2. inside that file, what are the exported wrapper functions?
grep -nE "export (async )?(function|const)|static .* function|fun [a-zA-Z]+|func [a-zA-Z]+" \
  src/services/LinkrunnerService.ts

# 3. where is each wrapper function called from? (this is the real call site)
grep -rn "LinkrunnerService.initialize\|LinkrunnerService.trackEvent" --exclude-dir=node_modules .
```

Watch for wrappers that **rename** the concept - `AnalyticsService.identify()` may be `signup` underneath,
`Tracker.logPurchase()` may be `capturePayment`. Map wrapper name → SDK method once, then work in the
team's vocabulary; your fix diffs should be written against *their* wrapper, which is what they'll edit.

Also check the wrapper itself for behaviour that changes the verdict: an internal `if (initialized) return`
guard turns a bad call site into a harmless one, and a `try {} catch {}` that swallows everything can hide
a permanently-failing integration.

## 3. Per-framework lifecycle traps

The same line of code is correct in one place and a defect thirty lines away. These are the placements
that matter, per stack.

### React Native / Expo

```tsx
// ❌ runs on EVERY render - no dependency array
useEffect(() => { linkrunner.init(TOKEN); });

// ❌ re-runs whenever `user` changes - repeated init
useEffect(() => { linkrunner.init(TOKEN); }, [user]);

// ❌ correct hook, wrong component: a screen mounts again on every navigation to it
function HomeScreen() { useEffect(() => { linkrunner.init(TOKEN); }, []); }

// ✅ root component, empty deps, awaited before dependent calls
function App() {
  useEffect(() => {
    (async () => {
      await linkrunner.init(TOKEN);
      const attr = await linkrunner.getAttributionData();
      if (attr?.deeplink) navigationRef.navigate(routeFor(attr.deeplink));
    })();
  }, []);
}
```

- **Missing dependency array** is the highest-yield thing to check on every RN `useEffect` containing an
  SDK call.
- **Deep-link listener cleanup:** `Linking.addEventListener('url', …)` without `return () => sub.remove()`
  leaks a listener on every remount, so one deep link fires `handleDeeplink` N times.
- **Not a finding:** React 18 StrictMode double-invoking effects, and Fast Refresh re-running them. Both
  are development-only. Say so if the team raises it.
- Note whether `init` is awaited before `signup`/`getAttributionData` - un-awaited, they race.

### Flutter

```dart
// ❌ build() runs on every rebuild - potentially many times per second
@override
Widget build(BuildContext context) {
  LinkRunner().init(token: TOKEN);
  return MaterialApp(...);
}

// ❌ initState of a widget that is pushed/popped repeatedly
class ProductPage extends StatefulWidget { ... }
@override void initState() { LinkRunner().init(token: TOKEN); }

// ⚠️ didChangeDependencies runs more than once by design
@override void didChangeDependencies() { LinkRunner().init(token: TOKEN); }

// ✅ once, before the app runs
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LinkRunner().init(token: TOKEN);
  runApp(const MyApp());
}
```

`build()` placement is the single worst defect available in Flutter and it is easy to miss because the
line looks identical to a correct one. Check the enclosing method name for every Dart call site.
`initState` of the **root** widget is acceptable; `initState` of a routed page is not.

### Native Android (Kotlin/Java)

```kotlin
// ❌ Activity.onCreate - fires on every activity creation AND every rotation/config change
class MainActivity : AppCompatActivity() {
  override fun onCreate(b: Bundle?) { LinkRunner.getInstance().init(this, TOKEN) }
}

// ✅ Application.onCreate - exactly once per process
class MyApp : Application() {
  override fun onCreate() {
    super.onCreate()
    CoroutineScope(Dispatchers.IO).launch { LinkRunner.getInstance().init(applicationContext, TOKEN) }
  }
}
```

- Confirm the `Application` subclass is actually registered: `android:name=".MyApp"` in the manifest.
  An `Application` class that isn't wired up never runs.
- **Rotation** re-runs `Activity.onCreate` - a per-activity init doubles on every screen turn.
- Deep links need **`onNewIntent`** as well as `onCreate`; and if `launchMode` is `singleTask`/`singleTop`,
  the intent arrives at `onNewIntent` only. An app that reads the intent in `onCreate` alone handles cold
  start and silently drops warm-start deep links.
- Watch for a second init from a **ContentProvider** or an SDK-initializer library alongside the
  `Application` one.

### Native iOS (Swift)

```swift
// ✅ once at app construction
@main struct MyApp: App {
  init() { Task { await LinkrunnerSDK.shared.initialize(token: TOKEN) } }
}

// ✅ or the AppDelegate equivalent
func application(_ app: UIApplication, didFinishLaunchingWithOptions …) -> Bool {
  Task { await LinkrunnerSDK.shared.initialize(token: TOKEN) }; return true
}

// ❌ onAppear fires again on every tab switch and every pop back to this view
ContentView().onAppear { Task { await LinkrunnerSDK.shared.initialize(token: TOKEN) } }

// ❌ inside `body` - recomputed on every state change
var body: some View { let _ = LinkrunnerSDK.shared.trackEvent(...); return VStack { ... } }
```

- Remember iOS spells it **`initialize`**.
- Deep links arrive in two places: `continueUserActivity` (Universal Links) and `open url` / SceneDelegate
  (custom schemes). Both need `handleDeeplink`.
- `Task { }` in `init` is fire-and-forget: anything that depends on init completing must await it
  explicitly, or it races.

### Capacitor / Cordova

- **Cordova:** SDK calls before the `deviceready` event silently do nothing. Confirm `init` is inside the
  `deviceready` handler, not at module scope.
- **Capacitor / any WebView app:** a full page reload re-runs bootstrap code. If `init` sits in a module
  that reloads on SPA route changes or on resume, it re-fires. Check the router configuration.
- Both wrap the native SDK, so native config (`AndroidManifest`, `Info.plist`) is still in scope.

### Unity

- `Initialize` in `Start()` on a scene GameObject re-runs on **every scene load** unless the object is
  `DontDestroyOnLoad` (or it's a bootstrap scene loaded once). Check the object's lifetime.
- Unity's API is callback-based: `GetAttributionData` / `HandleDeeplink` deliver results through
  `OnAttributionData` / `OnDeeplinkHandled`. **A call with no subscribed handler is a dead chain** - the
  request goes out, the result lands nowhere, and no deferred deep link is ever routed.

### Web

Different model: the CDN script tracks the first page view and SPA navigation automatically. Check that
the script is loaded **once** in the root layout/`_app` (not `_document`, not per-page), that the token is
the right one, and that `lr.identify()` is called with a stable internal id - never an email or phone.

## 4. Anti-pattern catalogue

Each entry: what it looks like, why it matters in behaviour terms, and the fix to propose.

**Guarded out of production.**
```ts
if (__DEV__) { await linkrunner.init(TOKEN); }          // never runs in a release build
if (Platform.OS === 'ios') { linkrunner.trackEvent(…) } // Android users generate no events
if (remoteConfig.getBool('analytics_v2')) { … }         // depends on a server value - say so
```
Behaviourally identical to no integration, and invisible to traffic capture (there's simply no traffic).
Report the branch, name the condition, and say which users are affected. For a remote flag, state that the
repo cannot tell you its live value and the team must confirm.

**Fire-and-forget ordering.**
```ts
linkrunner.init(TOKEN);              // not awaited
await linkrunner.signup({ user_data }); // may reach the SDK before init finished
```
Produces intermittent, device-dependent loss that looks like a backend problem. Fix: await, or chain the
dependent calls inside the init continuation.

**Swallowed failure.** `try { await linkrunner.init(TOKEN) } catch (e) {}` - an empty catch. Wrapping SDK
calls so they can't crash the app is *good practice*; the finding is only that a permanent misconfiguration
(bad token, no network permission) is now silent forever. Propose logging in the catch, and keep the
severity low. Do not flag a catch that already logs.

**Unstable `paymentId`.**
```ts
paymentId: `${Date.now()}`            // ❌ new id on every retry
paymentId: uuid()                     // ❌ same
paymentId: order.paymentId            // ✅ the provider's / backend's id
```
The server deduplicates payments on this value. An unstable id turns one payment retried three times into
three payments - inflated revenue, wrong ROAS. This is usually the highest-severity finding in a repo that
has one.

**`amount` as a string.** `amount: "149.99"` or `amount: total.toFixed(2)` - ad-network revenue sharing
needs a number. Check the type at the call site *and* where the value came from.

**Dynamic event names.**
```ts
linkrunner.trackEvent(`${category}_viewed`, …)   // unbounded, unqueryable in the dashboard
```
Fix: a fixed name plus the variable part as event data -
`trackEvent('content_viewed', { category })`.

**PII in event payloads.** Emails, phone numbers, or full names inside `eventData`. `signup`/`setUserData`
have dedicated fields for those; event properties should carry ids, not identities. Flag it as a privacy
finding, quote the key names, **never the values**.

**`setAdditionalData` / `setUserData` on a render path.** These carry identity/config, not activity. On a
screen view or every launch with an unchanged payload they are pure duplicate traffic, and each one lands
as another record downstream. Fix: call once when the value first becomes available, or diff against the last
value sent before calling.

**`capturePayment` on the wrong event.** In the checkout screen body, on "Pay" tap, or in a `finally` -
instead of in the success callback / verified-webhook path. Look for the payment SDK's own success handler
and check whether the Linkrunner call is inside it.

**Double init.** Two entry points both initializing (native `Application` *and* the JS layer; two
`Application` classes; a bootstrap module imported twice). Grep for every init site and confirm exactly one
runs per process.

**Dead call site.** An exported wrapper method with no callers; a screen removed from the navigator; a
build variant that isn't shipped. Report as "present in code, never executed" and say how you determined it.

**Hardcoded config.** A token literal, a staging token in a release path, `debug: true` not driven by the
build type. Check that the release build actually reads the production value:
```bash
grep -rn "TOKEN\|LINKRUNNER" .env* 2>/dev/null           # and whether .env is committed
grep -rn "debug" <the init call site>                     # is it kDebugMode / BuildConfig.DEBUG / __DEV__?
```
A `secretKey`/`keyId` literal in a repo is a **credential-exposure finding**: report the location, never
the value, and tell the user directly so it can be rotated.

## 5. Proving a negative

"The app never calls `getAttributionData`" is a strong claim. Earn it:

1. Search the whole workspace, not one package, for **every** naming variant (`getAttributionData`,
   `GetAttributionData`, and any wrapper name that could front it).
2. Confirm which files import the SDK at all - if only one file imports it, the surface is bounded and you
   can enumerate it exhaustively.
3. Check the platform bridge layers in hybrid apps (a Kotlin/Swift file may call the native SDK directly,
   bypassing the JS/Dart layer entirely).
4. State what you searched in the report: *"searched all of `apps/mobile` and `packages/*` for the method
   and for wrapper aliases; the SDK is imported in exactly one file, `LinkrunnerService.ts`, which does not
   expose it."*

If you also have runtime evidence (debug-mode logs, the dashboard's Events page), cite it alongside - code
plus a runtime zero is airtight.
