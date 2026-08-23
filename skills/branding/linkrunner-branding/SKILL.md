---
name: linkrunner-branding
description: >-
  Design or review consistent Linkrunner interfaces and brand materials across
  public marketing, customer product, internal tools, documents, reports,
  decks, social, and partner surfaces. Use when asked to create
  Linkrunner-branded UI, choose logo assets, apply brand colors or typography,
  review brand consistency, or make any Linkrunner-facing visual artifact.
metadata:
  category: branding
  slug: branding
  docs: https://linkrunner.io/press
---

# Linkrunner Branding

Use this skill to design or review any Linkrunner surface: product UI, internal tool, website, document, report, deck, social graphic, event material, or partner asset. It preserves one visual identity while respecting the implementation conventions of each repository.

## When to Use

Use for:

- New or changed Linkrunner interfaces, components, pages, and flows
- Customer-facing and internal-facing visual work
- Reports, decks, PDFs, docs, social graphics, email visuals, and partner materials
- Logo selection, typography, color, spacing, motion, imagery, and copy
- Brand consistency reviews of existing work

Do not use to redesign the logo, invent a new palette, or override a repository's approved component system.

## Required References

Read only what the task needs, but always read `references/brand-system.md` and `references/logo-assets.md` before producing branded visuals.

- `references/brand-system.md`: identity, palette, typography, layout, motion, accessibility, and voice
- `references/surface-playbooks.md`: external marketing, product UI, internal tools, documents, decks, and social
- `references/logo-assets.md`: selection rules, hosted URLs, clear space, minimum sizes, and asset status
- `references/asset-manifest.json`: file dimensions, hashes, provenance, and live URLs
- `references/tokens.css`: portable CSS variables
- `references/tokens.json`: machine-readable tokens
- `references/portable-usage.md`: installation and reuse in Hermes and other agents
- `templates/design-brief.md`: brief and review template
- `templates/AGENTS-snippet.md`: project instruction snippet for other agent runtimes
- `assets/canonical/`: approved current SVG and PNG logo files
- `assets/reference-only/`: retained supplied material that is not approved for default use

## Source Order

Use this precedence:

1. The target repository's `AGENTS.md`, `CLAUDE.md`, `DESIGN.md`, design tokens, and canonical components
2. The latest implemented component pattern in that repository
3. This skill's shared Linkrunner baseline
4. The official press page at `https://linkrunner.io/press`
5. Visual inference from screenshots

Repository rules may refine implementation, typography, dark mode, and component APIs. They must not change the logo geometry, official brand blue, or core identity without explicit approval.

## Procedure

### 1. Inspect before designing

- Read the target repository's context files and existing design-system source.
- Identify the surface class: external marketing, customer product, internal operations, editorial/document, or campaign/social.
- Reuse existing tokens and primitives before creating anything new.
- Record the intended audience, primary job, viewport or physical size, and accessibility constraints.

Completion criterion: the surface class and local source of truth are known.

### 2. Establish the shared visual DNA

Every Linkrunner surface should feel minimal, structured, lightly technical, calm, and precise.

- Use Linkrunner blue as the only primary accent.
- Build hierarchy with near-neutral grays, spacing, typography, and thin borders.
- Prefer rectangular structure, orderly grids, and measured radii.
- Prefer borders over shadows.
- Keep decoration subordinate to information.
- Use status colors only for status meaning.

Completion criterion: the design reads as Linkrunner without relying on a large logo.

### 3. Apply the correct surface playbook

Read `references/surface-playbooks.md` and follow the matching section. Do not force marketing-page composition into a dense product table, or product-dashboard density into a public landing page.

Completion criterion: density, typography, components, and theme behavior match the surface class.

### 4. Choose logo assets deliberately

- Default to the full lockup when there is enough horizontal space.
- Use the mark for square slots, favicons, app icons, and avatars.
- Use the wordmark only when the mark already appears nearby or the slot is short and horizontal.
- Prefer SVG. Use PNG only where the destination cannot render SVG.
- Use color on light, quiet backgrounds; white on dark or brand-blue backgrounds; ink on light monochrome layouts.
- Keep required clear space and minimum size.
- Never redraw, recolor, stretch, rotate, crop, outline, shadow, or rearrange the logo.

Completion criterion: the asset is from `assets/canonical/` or an exact official URL listed in `references/logo-assets.md`.

### 5. Write in the Linkrunner voice

- Be direct, specific, practical, and human.
- Name concrete jobs and stakes: installs, postbacks, campaign reviews, deep links, revenue, cohorts, ad spend, and customer outcomes.
- Prefer persona-first positioning over generic category slogans.
- Make ease concrete with a time, moment, or workflow.
- Keep calls to action short and outcome-aware.
- Use “customers”, never “clients”.
- Do not use em dashes.
- Avoid empty words such as “powerful”, “seamless”, “supercharge”, “innovative”, and generic “AI-powered”.

Completion criterion: every sentence says something a specific reader can understand or act on.

### 6. Check responsive and state behavior

For interfaces, verify:

- Mobile first behavior and readable wrapping
- Empty, loading, error, disabled, hover, focus, selected, and success states
- Keyboard access and visible focus
- Reduced-motion behavior
- Light and dark themes only where the target product already supports them
- Tables, charts, and dense controls at narrow widths

Completion criterion: no required state relies on color alone or breaks at the target sizes.

### 7. Run the brand review

Use the checklist in `templates/design-brief.md` and report:

- Surface class and local source of truth
- Tokens and components reused
- Logo asset and variant selected
- Any exception and why it is required
- Responsive and accessibility checks performed

Completion criterion: every exception is explicit and approved, not accidental drift.

## Fast Rules

- Canonical blue: `#4D4BF7`
- Canonical ink: `#2B2C2F`
- Brand canvas: `#FFFFFF`
- Press muted: `#8B8D98`; interface muted values come from the target design tokens
- Shared spacing base: 4px
- Standard radii: 4, 8, 12, 16, and 24px
- Default motion: 150 to 300ms, purposeful, reduced-motion safe
- Default icon family in Linkrunner React surfaces: Phosphor, unless the target repository explicitly says otherwise
- No unapproved gradients, heavy shadows, glossy effects, oversized blobs, or generic AI imagery
- Never use legacy blue `#403DE8` for new work

## Pitfalls

- Treating “consistent” as “identical”. Marketing, product, and internal tools share identity but use different density and composition.
- Ignoring repository-local primitives. Existing product surfaces stay coherent by reusing their components.
- Using raw hex values inside an app that already exposes semantic tokens.
- Using the supplied reference-only exports because they look plausible. Several are old or custom and are intentionally quarantined.
- Calling the ink logo “black” and then recreating it as `#000000`. Use the supplied asset.
- Using the public marketing site's light-only rule to remove dark mode from an existing internal product.
- Making a one-off hero, card, button, tooltip, or table when a canonical primitive already exists.
- Copying a press-kit typography statement into an existing product without checking its repository font contract.

## Verification

Before delivery, confirm all of the following:

- [ ] Target repository rules were read
- [ ] Correct surface playbook was used
- [ ] Brand blue is `#4D4BF7`, not a legacy approximation
- [ ] Logo comes from a canonical file or official URL
- [ ] Clear space and minimum size are respected
- [ ] Semantic tokens and existing components were reused
- [ ] Type, spacing, borders, radii, and motion form one hierarchy
- [ ] Copy is concrete and contains no em dashes
- [ ] Responsive, keyboard, focus, contrast, and reduced-motion behavior were checked
- [ ] Any exception is documented and approved
