# Linkrunner Agent Skills

Installable **Agent Skills** that teach your AI coding agent how to integrate the
[Linkrunner](https://linkrunner.io) attribution SDK and set up deep linking -
correctly, and with self-verifying checks - instead of following the docs by hand.

Works with Claude Code, Cursor, Windsurf, GitHub Copilot, or any agent that reads
`AGENTS.md`.

## Quick start

```bash
# in your app's repo
npx @linkrunner/skills list
npx @linkrunner/skills add flutter
```

The installer detects which agent your repo is set up for and writes the skill in
that agent's native format. Then ask your agent: *"integrate Linkrunner"* or
*"set up Linkrunner deep links"* and it will pick up the skill.

Force a specific target, or install for several at once:

```bash
npx @linkrunner/skills add ios --agent cursor
npx @linkrunner/skills add react-native --dir ./apps/mobile
npx @linkrunner/skills add flutter --dry-run   # preview, write nothing
```

## Supported platforms

| Platform | Skill id | Package |
| --- | --- | --- |
| Flutter | `linkrunner-flutter` | `linkrunner` |
| React Native | `linkrunner-react-native` | `rn-linkrunner` |
| Expo | `linkrunner-expo` | `expo-linkrunner` |
| iOS (native) | `linkrunner-ios` | `linkrunner-ios` |
| Android (native) | `linkrunner-android` | `io.linkrunner:android-sdk` |
| Capacitor | `linkrunner-capacitor` | `capacitor-linkrunner` |
| Cordova | `linkrunner-cordova` | `cordova-linkrunner` |
| Unity | `linkrunner-unity` | native bridge (Android + iOS SDKs) |

## What each skill contains

```
skills/sdk/<platform>/
  SKILL.md                 # trigger + decision tree + golden rules (the entry point)
  references/
    install.md             # add package + native config + init
    deep-linking.md        # Universal Links / App Links / custom schemes + debugging
    events.md              # identify, events, revenue, attribution
  scripts/
    verify-deeplinks.sh    # checks hosted AASA/assetlinks + native wiring
```

Skills are authored to **inspect the project before editing and verify after** -
the deep-link validator is what turns "I pasted the config" into "the link
actually opens the app".

## How agent targets are written

| Agent | Written to |
| --- | --- |
| Claude Code | `.claude/skills/<id>/` (SKILL.md + references + scripts, verbatim) |
| Cursor | `.cursor/rules/<id>.mdc` |
| Windsurf | `.windsurf/rules/<id>.md` |
| Copilot | `.github/instructions/<id>.instructions.md` |
| Generic | `AGENTS.md` (idempotent section) |

Single-file targets get the references inlined and the validator scripts dropped
under `.linkrunner/<id>/scripts/`.

## Contributing / adding a platform

See [`AUTHORING.md`](./AUTHORING.md). The canonical content lives here; keep it in
sync with [docs.linkrunner.io](https://docs.linkrunner.io).

## License

MIT
