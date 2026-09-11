# Detecting the stack, the SDK package, and the pinned version

Do this before reading a single call site. The stack decides which SDK guide you cite, which language
your fix diffs must be in, which config files apply, and what "correct placement" even means - a rule
about `Application.onCreate` is meaningless advice to a Flutter team.

## 1. Which framework is this?

Detect from the repo's **own** markers. Do not infer the stack from the presence of `io.linkrunner`
classes or an `android/` folder - cross-platform apps have both.

| Stack | Repo markers (in this priority order) | SDK guide | Fix-snippet language |
|---|---|---|---|
| **Expo** | `app.json`/`app.config.*` with `expo`, `expo` in `package.json`, `expo-linkrunner` | `/sdk/expo` | TS/JS |
| **React Native** | `react-native` in `package.json`, `metro.config.js`, `index.js` with `AppRegistry` | `/sdk/react-native` | TS/JS |
| **Flutter** | `pubspec.yaml`, `lib/main.dart`, `.dart_tool/` | `/sdk/flutter` | Dart |
| **Capacitor** | `capacitor.config.ts/js/json`, `@capacitor/core` in `package.json` | `/sdk/capacitor` | TS/JS |
| **Cordova** | `config.xml` with `<widget xmlns:cdv>`, `plugins/` dir | `/sdk/cordova` | JS |
| **Unity** | `ProjectSettings/` + `Assets/` + `Packages/manifest.json` | `/sdk/unity` | C# |
| **Native Android** | `settings.gradle` + `app/build.gradle`, no cross-platform marker above | `/sdk/android` | Kotlin |
| **Native iOS** | `*.xcodeproj`/`*.xcworkspace` or `Package.swift`, no cross-platform marker | `/sdk/ios` | Swift |
| **Web** | `cdn.linkrunner.io/web/v1/lr.js` script tag, or `@linkrunner/web` | `/sdk/web` | JS/TS |
| **Shopify** | Shopify theme/app structure | `/sdk/shopify` | - |

```bash
ls -a | grep -E "pubspec.yaml|package.json|capacitor.config|config.xml|ProjectSettings|Package.swift"
[ -f package.json ] && grep -E '"(react-native|expo|@capacitor/core|next|@angular/core|vue)"' package.json
[ -f pubspec.yaml ] && head -20 pubspec.yaml
```

**Hybrid is the norm, not the exception.** An RN or Flutter app ships a full `android/` and `ios/`
project, and *its config files are yours to audit* (`references/platform-config.md`) even though the app
code is TS or Dart. Some apps also run the **web SDK on their marketing site and a mobile SDK in the app**
- two integrations, audited separately. Say which one(s) you reviewed.

## 2. Monorepos - find the shipped app first

A hit in `packages/legacy-app/`, `examples/`, or `apps/internal-tools/` is not the integration.

```bash
# every package that declares a Linkrunner dependency
grep -rln --include="package.json" --include="pubspec.yaml" "linkrunner" . 2>/dev/null | grep -v node_modules
# which of them is actually built/shipped? check the release CI config and the workspace root
cat package.json 2>/dev/null | grep -A10 '"workspaces"'
ls .github/workflows/ 2>/dev/null
```

Establish the answer with the user if it's ambiguous - auditing the wrong package wastes the whole pass.
Also check for **git submodules** (`.gitmodules`) and vendored SDK copies before concluding anything is
absent.

## 3. The SDK package and its exact pinned version

Read the version from the **manifest and the lockfile**. A caret range in the manifest (`^2.7.0`) with
`2.13.4` resolved in the lockfile means the team is on 2.13.4 - the lockfile wins.

| Stack | Package | Where the version lives |
|---|---|---|
| React Native | `rn-linkrunner` | `package.json` + `package-lock.json` / `yarn.lock` / `pnpm-lock.yaml` |
| Expo | `expo-linkrunner` (+ `rn-linkrunner`) | same |
| Flutter | `linkrunner` | `pubspec.yaml` + `pubspec.lock` |
| Native Android | `io.linkrunner:android-sdk` | `app/build.gradle(.kts)`, or `gradle/libs.versions.toml` |
| Native iOS | `linkrunner-ios` (module `LinkrunnerKit`) | `Package.swift` / `Package.resolved` / `Podfile.lock` |
| Capacitor | `capacitor-linkrunner` | `package.json` + lockfile |
| Cordova | `cordova-linkrunner` | `config.xml` `<plugin>` + `package.json` |
| Unity | no dedicated SDK - native bridge (`io.linkrunner:android-sdk` + `LinkrunnerKit`) | `Assets/Plugins/Android/mainTemplate.gradle` + the iOS Podfile / Swift package |
| Web | CDN `lr.js` or `@linkrunner/web` | the script tag / `package.json` |

```bash
grep -rnE '"(rn-linkrunner|expo-linkrunner|capacitor-linkrunner|@linkrunner/[a-z-]+)"' package.json
grep -A2 '^  linkrunner:' pubspec.lock         # resolved Flutter version
grep -rn "io.linkrunner" --include="*.gradle" --include="*.gradle.kts" --include="*.toml" .
grep -rn -iE "linkrunner" Podfile.lock Package.resolved 2>/dev/null
```

Native Android/iOS apps sometimes vendor an `.aar`/`.xcframework` with no version anywhere. Say the
version is undeterminable rather than guessing, and ask the team.

## 4. Version gates - "not using it" vs "can't use it"

Before writing "the app never calls X", check whether their pinned version even has X. The fix is then
**upgrade to ≥ the minimum**, followed by the call - a materially different recommendation.

| Capability | React Native | Flutter | Android | iOS | Capacitor | Cordova |
|---|---|---|---|---|---|---|
| `setCustomerUserId` (+ auto `user_id` on events) | ≥ 2.11.0 | ≥ 3.10.0 | ≥ 3.9.1 | ≥ 3.11.0 | ≥ 1.3.0 | ≥ 1.1.0 |
| Ecommerce Event Manager (`eventData` commerce fields) | ≥ 2.7.0 | ≥ 3.7.0 | ≥ 3.6.0 | ≥ 3.8.0 | - | - |
| Encrypted SharedPreferences (automatic, Android side) | ≥ 2.10.1 | ≥ 3.9.1 | ≥ 3.8.1 | n/a | - | - |
| Uninstall tracking | ≥ 2.8.0 | - | - | - | - | - |
| `setConsent` / Google ICM | ≥ 3.1.0 | - | ≥ 4.1.0 | - | - | - |
| AAID collection disable | - | ≥ 3.5.0 | ≥ 3.5.0 | n/a | - | - |

Verify a gate against the live docs (`https://docs.linkrunner.io/sdk/<platform>`) before citing it -
minimums move as SDKs ship. A dash means the doc doesn't state a minimum for that platform, not that the
feature is unavailable; check the platform's page rather than asserting either way.

An old pinned version is worth a low-severity note on its own: encrypted credential storage and reinstall
detection improved in the versions above, so a very old pin is a quiet data-quality risk even when every
call site is correct.

## 5. Record the one-line statement

Carry this into the report's opening:

> **Stack:** React Native 0.73 (bare, not Expo), integrating `rn-linkrunner` **2.10.1** (lockfile-resolved).
> Native Android and iOS projects present and in scope. All references and fix snippets target the React
> Native SDK. Audited at commit `a1b2c3d`.

Naming the commit matters: findings are only true for the tree you read.
