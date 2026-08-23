# Surface Playbooks

Use the shared brand system, then apply the playbook that matches the output. Consistency means a shared identity with surface-appropriate density and behavior.

## Decision Table

| Surface | Default font | Theme | Density | Primary structure |
|---|---|---|---|---|
| Public marketing website | Geist Sans and Mono | Light only unless strategy changes | Spacious | 1300px framed sections, strong narrative hierarchy |
| Customer product dashboard | Repository contract, currently Inter plus mono | Light and dark where supported | Dense | Canonical product primitives, tables, filters, charts |
| Internal operations tool | Repository contract; Geist for new standalone tools | Light and dark when useful | Medium to dense | Task-first layouts, compact forms, tables, audit detail |
| Documentation | Geist Sans and Mono for new standalone docs | Light by default | Medium | Readable prose, code, callouts, restrained navigation |
| Report or PDF | Geist Sans and Mono | Usually white canvas | Medium | Executive hierarchy, evidence, charts, page rhythm |
| Deck | Geist Sans and Mono | White, ink, or brand blue | Spacious | One idea per slide, large data, strong contrast |
| Social or campaign creative | Geist Sans | Chosen per campaign | Spacious | One message, controlled logo, minimal visual vocabulary |

## Public Marketing

### Goal

Explain value clearly and move a qualified reader to a direct next step.

### Use

- Current marketing repository tokens and primitives
- Geist Sans and Geist Mono
- One `h1` per page
- 1300px outer section frame
- Quiet vertical borders and dividers
- Small blue-square eyebrow labels
- Tight heading tracking and restrained body width
- Primary blue CTA and quiet secondary CTA
- Twelve-column bento layouts for feature storytelling
- Minimal, purposeful motion

### Avoid

- Dark mode in the current marketing cycle
- Unapproved section widths
- Heavy drop shadows
- Blue text or border changes on hover
- New gradients unless the approved design explicitly calls for one
- Generic AI visual metaphors
- Giant pill CTAs
- Dense product controls in a marketing narrative

### Review

- Exactly one `h1`
- Sections align to the same outer frame
- Visible child borders meet the frame cleanly
- Mobile and desktop composition both work
- Metadata, schema, and alternate content remain aligned when code changes affect discoverability

## Customer Product Dashboard

### Goal

Help customers inspect data, make decisions, and complete recurring work quickly.

### Use

- Repository semantic tokens only
- Existing type scale tokens
- Existing shared primitives and CVA variants
- Phosphor icons through the repository's approved import path
- Product's light and dark token mappings
- Dense but readable tables, filters, charts, drawers, and dialogs
- Consistent page headers, search, pagination, empty states, and tabs
- Direct status labels with text and color

### Canonical component rule

Before creating a control, check the product's component decision table. Existing Linkrunner dashboard patterns currently standardize buttons, icon buttons, tooltips, search, filters, selects, empty states, pagination, page headers, segmented controls, tabs, inputs, and dialogs.

If a primitive lacks a reusable variant, add the variant to the primitive. Do not fake it with call-site classes.

### Avoid

- Raw hex values where a semantic token exists
- Raw pixel typography where a type token exists
- Hand-rolled controls
- Multiple icon libraries in one file
- Decorative animation in core workflows
- Marketing-sized headings and whitespace
- Removing dark mode because the public site is light only

### Review

- Empty, loading, error, disabled, hover, focus, and selected states
- Keyboard access and screen-reader labels
- 375 to 414px mobile widths when the product supports mobile
- Horizontal table overflow and readable column minimums
- Charts distinguish series without color alone

## Internal Operations Tools

### Goal

Optimize for speed, confidence, auditability, and low error rates.

### Use

- Shared palette, semantic roles, spacing, and radii
- Compact controls with clear labels
- Strong destructive-action separation
- Tables with persistent context, filters, and audit metadata
- Mono for IDs, timestamps, query values, and system state
- Clear success, warning, error, and neutral states
- Responsive behavior if operators use phones or tablets

### New standalone tools

For a new tool without an existing design system:

- Start from `references/tokens.css`
- Use Geist Sans and Geist Mono
- Use Phosphor icons
- Use 14 to 16px body text
- Use 8px standard control radius and 12px cards
- Use one-pixel quiet borders
- Use blue 500 for primary and selected states
- Add dark mode only if it supports the operator workflow and can be completed properly

### Avoid

- Marketing decoration in operational screens
- Hidden status or destructive actions
- Color-only severity
- Dense tables without search, filters, sticky context, or overflow handling
- One-off design tokens

## Documentation and Technical Guides

### Goal

Make setup, concepts, and troubleshooting easy to scan and execute.

### Use

- Geist Sans for prose and Geist Mono for code
- Clear heading hierarchy
- Short paragraphs and actionable steps
- Quiet code blocks and callouts
- Brand blue for links and focused emphasis
- Real product screenshots where they materially help
- Logo lockup in the header when space allows

### Avoid

- Promotional language inside technical instructions
- Decorative screenshots with no explanatory value
- Long lines of text
- Unlabeled diagrams
- Using the mark repeatedly as a bullet or ornament

## Reports and PDFs

### Goal

Present decisions, evidence, and performance clearly.

### Use

- White canvas, ink text, blue accent
- Full lockup on cover or title page
- Clear executive summary
- Mono for exact metrics and identifiers
- Direct chart labeling
- Source notes and caveats near the data they qualify
- Consistent page grid, margins, headers, and footers

### Suggested hierarchy

- Cover title: 32 to 48px
- Section title: 22 to 32px
- Body: 10.5 to 12pt
- Caption/source: 8.5 to 10pt
- Tables: 9 to 11pt

### Avoid

- Logo on every page at large size
- Full-bleed blue behind long-form text
- Dense charts with tiny legends
- Decorative gradients and stock imagery

## Decks

### Goal

Communicate one idea per slide at presentation distance.

### Use

- Full lockup on opening and closing slides
- Mark on section dividers or compact branded corners
- White, ink, and blue as primary slide fields
- Large direct metrics
- One chart or one argument per slide
- Consistent alignment and generous margins

### Avoid

- Repeating the large logo on every slide
- More than one primary message per slide
- Long paragraphs
- Legacy `#403DE8` blue
- Tiny footnotes without a readable handout version

## Social and Campaign Creative

### Goal

Deliver one message quickly while preserving recognition.

### Use

- One dominant field: white, ink, or brand blue
- White logo on brand blue or dark fields
- Color or ink logo on white fields
- Short headline and one supporting line at most
- Clear safe area for platform cropping
- Mark for avatars, full lockup when the layout allows

### Avoid

- Stretching the logo to fill the canvas
- Placing the logo against busy imagery without a plate
- Several accent colors
- Effects applied to the logo
- Dense product screenshots at unreadable size

## Partner and Co-branding

- Give each brand its required clear space.
- Match visual weight, not arbitrary pixel height.
- Separate logos with whitespace or a quiet divider.
- Do not recolor the Linkrunner logo to match a partner.
- Use the full lockup when the partnership context is not already obvious.
- Never combine marks into a new composite logo without approval.
