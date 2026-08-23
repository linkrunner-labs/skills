# Linkrunner Brand System

Audited against the official press page and live site on 2026-08-23. Repository-local rules remain the implementation source of truth.

## Identity

Linkrunner should feel:

- Minimal and clean
- Structured and border-contained
- Lightly technical, not playful
- Polished, not ornamental
- Calm and precise
- Data-oriented and trustworthy

The design should still read as Linkrunner when the logo is removed. Achieve that through one blue accent, near-neutral grays, compact typography, measured spacing, sharp information hierarchy, thin borders, orderly grids, and restrained motion.

Avoid startup-generic AI styling, noisy gradients, glossy depth, heavy shadows, oversized blobs, decorative clutter, and novelty layouts.

## Official Brand Palette

These four values come from the official press page:

| Role | Hex | RGB | Use |
|---|---:|---:|---|
| Brand blue | `#4D4BF7` | 77, 75, 247 | Primary actions, selected states, logo color, controlled accents |
| Ink | `#2B2C2F` | 43, 44, 47 | Logo ink treatment and editorial dark text |
| Muted | `#8B8D98` | 139, 141, 152 | Press and editorial supporting text |
| Canvas | `#FFFFFF` | 255, 255, 255 | Primary light canvas |

Do not use legacy blue `#403DE8` for new work. It appears in older supplied exports but is not the current brand token.

## Interface Color System

Product and website repositories share the following scales. Use semantic aliases where the target codebase exposes them.

### Gray

| Step | Hex |
|---:|---:|
| 0 | `#FFFFFF` |
| 25 | `#F8F8F8` |
| 50 | `#F9F9FB` |
| 75 | `#F3F3F6` |
| 100 | `#E8E8ED` |
| 200 | `#CDCDD7` |
| 300 | `#AFAFB9` |
| 400 | `#8F8F96` |
| 500 | `#5D5D64` |
| 600 | `#41414B` |
| 700 | `#303037` |
| 800 | `#212128` |
| 900 | `#18181E` |
| 1000 | `#0D0D14` |

### Blue

| Step | Hex |
|---:|---:|
| 25 | `#F5FBFF` |
| 50 | `#DBF0FF` |
| 100 | `#C0D1FF` |
| 200 | `#97ABFF` |
| 300 | `#7382FF` |
| 400 | `#585CFF` |
| 500 | `#4D4BF7` |
| 600 | `#2D2B9F` |
| 700 | `#1B1C62` |
| 800 | `#0A0C2F` |
| 900 | `#010109` |

### Status colors

Use the existing green, orange, red, yellow, and pink scales from the target repository. Status colors communicate state only. Do not use them as competing brand accents.

### Semantic roles

| Role | Light value |
|---|---|
| Primary background | white |
| Secondary background | gray 50 |
| Tertiary background | gray 100 |
| Elevated background | gray 75 or gray 50 |
| Primary text | gray 700 |
| Secondary text | gray 600 |
| Tertiary text | gray 400 |
| Default border | gray 100 or black at 10% alpha |
| Primary interaction | blue 500 |
| Hover interaction | blue 400 |
| Pressed interaction | blue 300 |
| Focus ring | blue 500 |

Use the target project's semantic classes or variables. Never replace `text-primary`, `bg-secondary`, or `border-default` with local raw hex values inside an established application.

## Typography

### New standalone branded surfaces

- Primary: Geist Sans
- Technical: Geist Mono
- Display and body tracking: typically `-0.02em`
- Headings: weight 400 by default
- Body: weight 400
- UI labels: weight 500 only when emphasis is needed
- Avoid 700 and 800 weights except where an approved asset or existing component requires them

### Existing product surfaces

Do not opportunistically migrate fonts. Follow the repository contract.

- The marketing website uses Geist Sans and Geist Mono.
- The customer dashboard currently uses Inter with a mono face for technical data.
- Existing admin consoles may follow the shared product token system and their own typography scale.

Brand consistency across existing products comes from shared palette, hierarchy, density, spacing, borders, components, and motion, not from an unapproved font migration.

### Type hierarchy

- One clear page title
- Compact headings with slightly tight tracking
- Readable body copy, never oversized by default
- Mono only for IDs, metrics, timestamps, code, commands, and other data-like content
- Use type scale tokens where provided, never arbitrary pixel sizes in established product code
- Keep line lengths disciplined

## Spacing and Geometry

Use a 4px base. Preferred spacing values:

`4, 8, 12, 16, 20, 24, 32, 40, 48, 64, 80, 96, 128px`

Preferred radii:

- 2px: precise micro-controls
- 4px: labels and compact elements
- 8px: buttons and inputs
- 12px: standard cards and panels
- 16px: larger containers
- 24px: feature cards and branded editorial blocks
- Full pill: badges and controls only when functionally appropriate

Use the smallest radius that suits the surface. The logo mark itself has sharp corners and must not be rounded.

## Layout

### Shared principles

- Use grids and alignment, not floating decoration.
- Use thin borders and spacing as primary separation.
- Use whitespace intentionally.
- Keep related actions and data visually grouped.
- Prefer repeatable section and component anatomy over one-off compositions.
- Maintain consistent side insets and edge alignment across a page.

### Marketing signature

The current marketing site uses:

- 1300px outer section column
- Thin vertical borders at the section frame
- Quiet divider lines
- 16px mobile side padding and 40px desktop side padding
- 24px to 36px common inner insets
- Centered section headers with a small blue square eyebrow
- Ordered 12-column bento grids
- Minimal shadows

This signature is for public marketing pages. Do not apply the full 1300px framed-section pattern to dense internal dashboards.

## Components

- Reuse the target repository's canonical primitives.
- Extend a shared primitive when a missing variant has multiple use cases.
- Never hand-roll a control that already exists.
- Do not override a primitive at the call site to fake a variant.
- Use semantic tokens and canonical type classes.
- Use Phosphor icons in new Linkrunner React surfaces unless the repository explicitly names another library.
- Keep one icon family per file or surface.
- Use brand logo components for platform and partner logos, not generic UI icon libraries.

## Borders, Shadows, and Depth

- Borders do the work, not shadows.
- Standard border is one pixel and low contrast.
- Avoid changing text to blue on hover unless the repository explicitly defines that state.
- Avoid adding or changing border color on hover.
- Use subtle background, opacity, or transform changes for hover feedback.
- Use shadows only for true elevation such as popovers, menus, and overlays.
- Never add a shadow, outline, or stroke to the Linkrunner logo.

## Motion

Motion should be minimal and purposeful.

- Fast feedback: 150ms
- Standard UI transition: 200ms
- Medium reveal: 300ms
- Slow branded reveal: 400 to 500ms
- Use fade, slight translate, or restrained blur transitions
- Use linear easing only for continuous progress or marquees
- Respect `prefers-reduced-motion`
- Never animate core content in a way that delays reading or task completion

## Charts and Data

- Use palette scales to encode series, not arbitrary colors.
- Use blue for primary or selected data, then approved status and visualization scales.
- Do not use color as the only differentiator. Add labels, shapes, patterns, or direct values.
- Use Geist Mono or the product's canonical mono font for metrics and IDs.
- Keep gridlines and axes quiet.
- Prioritize readable values over ornamental chart effects.

## Imagery

- Product graphics should use actual interface language and believable data structure.
- Do not use real customer or team headshots as generic avatars inside illustrative product graphics.
- Reserve real people for editorial content where they are the subject.
- Avoid generic robots, glowing brains, neon networks, and floating AI particles.
- Avoid busy photography behind the logo. Add a quiet plate when needed.

## Accessibility

- Meet WCAG AA contrast for normal text and controls.
- Preserve visible focus rings.
- Make interactive targets comfortably tappable.
- Do not rely on color alone for status.
- Use semantic headings and exactly one `h1` on public pages.
- Provide useful alt text for meaningful images and empty alt text for decorative images.
- Verify keyboard navigation and reduced-motion behavior.

## Voice

Linkrunner writing is concise, contextual, specific, and human.

- Start with the reader's job or problem.
- Use concrete product nouns and measurable outcomes.
- Explain ease through time or workflow.
- Make trust claims specific about what customers trust Linkrunner to measure.
- Use direct calls to action.
- Say “customers”, not “clients”.
- Do not use em dashes.
- Avoid empty adjectives and generic AI claims.

Examples of useful shapes:

- “Attribution for mobile growth teams”
- “Live before your next campaign review”
- “Start measuring free”
- “Create your first link”

## Sources

- Official press and brand page: https://linkrunner.io/press
- Official press archive: https://linkrunner.io/brand/linkrunner-press-kit.zip
- Marketing implementation source: `website/DESIGN.md` and `website/src/app/globals.css`
- Customer dashboard implementation source: `dashboard/AGENTS.md`, `dashboard/.claude/rules/styling.md`, and `dashboard/src/styles/globals.css`
- Internal billing implementation source: `billing-console/CLAUDE.md` and `billing-console/src/index.css`
