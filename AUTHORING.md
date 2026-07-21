# Authoring a Linkrunner skill

Each platform is one skill folder under `skills/sdk/<platform>/`. The Flutter
skill (`skills/sdk/flutter/`) is the reference implementation - copy its shape.

## Rules

1. **Ground every claim in the live docs.** The source of truth is
   `docs.linkrunner.io` (repo `linkrunner-labs/docs`, per-platform page at
   `sdk/<platform>.mdx`, plus `features/deep-linking-setup.mdx`). Do not invent
   API names, package names, or config - read the page and mirror it. If the doc
   doesn't cover something, link out to it rather than guessing.
2. **Inspect before edit, verify after.** The SKILL.md must tell the agent to
   read the project state first (framework version, existing router, existing
   deep-link config) and to run the validator at the end. No blind snippet
   pasting - that is what generates support tickets.
3. **Keep `SKILL.md` lean.** It is the always-loaded entry point: trigger
   description, a decision table (what the user wants → which reference), golden
   rules, and a "finish/verify" step. Push detail into `references/`.
4. **`description` frontmatter is the trigger.** Write it so the agent loads the
   skill on the real phrasings a developer uses ("add Linkrunner to my Flutter
   app", "Linkrunner deep link not opening app"). Keep it in sync with the same
   skill's entry in `registry.json`.
5. **No em dashes in customer-facing copy.** Use hyphens.

## Files

| File | Contents |
| --- | --- |
| `SKILL.md` | frontmatter (`name`, `description`, `metadata`) + entry point |
| `references/install.md` | package add, native config, initialization |
| `references/deep-linking.md` | HTTP/HTTPS (App Links / Universal Links) + custom schemes + debugging |
| `references/events.md` | identify/signup, events, revenue, attribution read |
| `scripts/verify-deeplinks.sh` | deep-link verification check (shared, framework-agnostic) |

The `verify-deeplinks.sh` validator is identical across the mobile platforms
(verification is native to Android/iOS), so copy it verbatim from Flutter. Web
does not need it.

## After authoring

1. Add/confirm the skill's entry in `registry.json` (id, platform, aliases,
   description, package, docs, agentCompat).
2. `node bin/cli.mjs add <platform> --dry-run` and confirm the file plan.
3. `bash -n skills/sdk/<platform>/scripts/verify-deeplinks.sh` for scripts.
