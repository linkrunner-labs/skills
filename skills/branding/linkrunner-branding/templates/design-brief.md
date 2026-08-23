# Linkrunner Design Brief and Review

## Brief

- **Artifact:**
- **Surface class:** public marketing / customer product / internal operations / documentation / report / deck / social / partner
- **Audience:**
- **Primary job:**
- **Primary action:**
- **Required sizes or viewports:**
- **Target repository or tool:**
- **Local source of truth:**
- **Existing components to reuse:**
- **Accessibility constraints:**
- **Approval owner:**

## Design Decisions

- **Font contract:**
- **Theme behavior:**
- **Primary tokens:**
- **Layout system:**
- **Logo variant and file:**
- **Icon system:**
- **Motion approach:**
- **Imagery approach:**
- **Copy direction:**

## Review Checklist

### Identity

- [ ] Feels minimal, structured, lightly technical, calm, and precise
- [ ] Uses `#4D4BF7` as the primary accent
- [ ] Does not use legacy `#403DE8`
- [ ] Uses status colors only for status meaning
- [ ] Uses borders and spacing before shadows
- [ ] Avoids unapproved gradients, glossy effects, blobs, and generic AI imagery

### Logo

- [ ] Uses a file from `assets/canonical/` or an official URL
- [ ] Correct lockup chosen for the space
- [ ] SVG used where supported
- [ ] Clear space of at least 1x maintained
- [ ] Minimum width respected: lockup 120px, mark 24px, wordmark 80px
- [ ] No recolor, crop, rotation, stretch, stroke, shadow, or rearrangement
- [ ] White treatment used on dark or brand-blue backgrounds

### Typography and Copy

- [ ] Font follows the surface playbook and target repository
- [ ] Type hierarchy uses approved scale tokens or documented sizes
- [ ] Mono is reserved for technical data
- [ ] Copy is concrete, direct, and outcome-aware
- [ ] Uses “customers”, not “clients”
- [ ] Contains no em dashes
- [ ] Avoids empty marketing adjectives and generic AI claims

### Components and Layout

- [ ] Existing primitives reused
- [ ] Semantic tokens used instead of one-off values
- [ ] Spacing follows the 4px system
- [ ] Radii are measured and consistent
- [ ] Alignment and outer insets are consistent
- [ ] Hover feedback does not introduce noisy blue text or border changes
- [ ] Data density matches the surface class

### Responsive and Accessibility

- [ ] Mobile or narrow layout verified where applicable
- [ ] Loading, empty, error, disabled, hover, focus, selected, and success states covered
- [ ] Keyboard navigation works
- [ ] Focus is visible
- [ ] Text and control contrast meets WCAG AA
- [ ] Status does not rely on color alone
- [ ] Reduced motion is respected
- [ ] Images have appropriate alt text
- [ ] Public pages use exactly one `h1`

### Delivery

- [ ] Final artifact rendered or run, not only described
- [ ] Relevant sizes or viewports captured
- [ ] Logo source and token source recorded
- [ ] Any exception documented with rationale and approval

## Review Output

Use this format:

```markdown
## Brand review

**Surface:**
**Local source of truth:**
**Result:** pass / pass with exceptions / revise

### Reused
- Tokens:
- Components:
- Assets:

### Checks
- Responsive:
- Accessibility:
- Copy:
- Logo:

### Exceptions
- None, or list each approved exception with owner and reason.
```
