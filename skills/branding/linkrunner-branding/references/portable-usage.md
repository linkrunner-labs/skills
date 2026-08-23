# Portable Usage

This skill is self-contained and uses relative paths so it can move between agent runtimes and repositories.

## Hermes User Skill

Install the entire `linkrunner-branding` folder under a Hermes skill directory. A common user-level location is:

```text
~/.hermes/skills/linkrunner/linkrunner-branding/
```

Hermes discovers the skill automatically. No registration entry is required.

## Linkrunner Skills Installer

From another project, install the published skill with:

```text
npx @linkrunner/skills add branding
```

Use `--agent claude-code`, `--agent cursor`, `--agent windsurf`,
`--agent copilot`, or `--agent agents-md` to force a target. Use `--dry-run` to
preview every file before writing.

## Hermes Repository Skill

For a repository that should carry the skill with its code, use:

```text
.agents/skills/linkrunner-branding/
```

or:

```text
.hermes/skills/linkrunner-branding/
```

Trust the repository through the normal Hermes project-skill flow before loading repo-local skills.

## Claude Code, Codex, and Other Coding Agents

Place the skill folder in the agent's supported repository skill directory. If the runtime does not discover skills automatically, add the content of `templates/AGENTS-snippet.md` to its project instruction file and adjust the relative path.

Keep the directory intact. The skill expects its `references/`, `templates/`, and `assets/` siblings.

## Design Tools and Human Handoffs

The package can also be used without an agent:

- `references/brand-system.md`: concise brand manual
- `references/surface-playbooks.md`: surface-specific design guidance
- `references/logo-assets.md`: logo rules and official URLs
- `references/tokens.css`: direct CSS starter
- `references/tokens.json`: design-token import source
- `assets/canonical/`: current approved logo files
- `templates/design-brief.md`: review checklist

## Update Procedure

When the official site changes:

1. Review https://linkrunner.io/press.
2. Download https://linkrunner.io/brand/linkrunner-press-kit.zip.
3. Compare the official file hashes with `references/asset-manifest.json`.
4. Update canonical assets, URLs, hashes, and the audit timestamp together.
5. Keep replaced assets under `assets/reference-only/` only when they have migration or audit value.
6. Bump the skill version.
7. Re-run the Hermes skill audit and verify every referenced file exists.
