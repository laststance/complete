# Visual Test Expectations (Baseline Screenshots)

This directory contains **baseline expectation screenshots** for visual regression testing of the Complete app's popup positioning.

## Purpose

These screenshots serve as the "golden" reference images showing correct popup positioning behavior. When running visual tests, new screenshots should be compared against these expectations to detect regressions.

## Baseline Screenshots

| File | Description | Key Verification Points |
|------|-------------|------------------------|
| `top-left.png` | TextEdit at screen top-left | Popup appears near top-left text cursor |
| `top-right.png` | TextEdit at screen top-right | Popup appears near top-right text cursor |
| `bottom-left.png` | TextEdit at screen bottom-left | Popup appears near bottom-left text cursor |
| `bottom-right.png` | TextEdit at screen bottom-right | Popup appears near bottom-right text cursor |
| `center.png` | TextEdit at screen center | Popup appears near center text cursor |

## Created

- **Date**: 2025-12-07
- **Hotkey**: Shift+Command+I
- **Test Text**: "Hell" (triggers spell completions like "Hello", "Hell", etc.)
- **Commit Reference**: e7ce0f3 (popup positioning fix)

## Usage

### Comparison Process

1. Run the visual test: `osascript tests/visualScreenshotTesting/test-popup-positions.applescript`
2. New screenshots saved to: `~/Desktop/complete-popup-tests/`
3. Compare each new screenshot against the corresponding expectation in this directory
4. Focus on:
   - **Text cursor position** (where "Hell" text is displayed in TextEdit)
   - **Popup position** (the completion list window)
   - **Relative distance** between cursor and popup (should be ~50px or less)

### What Constitutes a PASS

A test **PASSES** if the new screenshot shows:
- Popup positioned within ~50px of the text cursor
- Same relative positioning as the expectation (above/below, adjacent)
- Both "Hell" text and popup completion list are visible

### What Constitutes a FAIL

A test **FAILS** if the new screenshot shows:
- Popup appearing far from the text cursor (wrong screen area)
- Popup at a different relative position than the expectation
- Missing popup or text content

## Updating Expectations

Only update these baseline images when:
1. A **deliberate** change to popup positioning logic is made
2. The new behavior is **verified as correct**
3. Update commit message should reference the reason for baseline change

```bash
# To update expectations after verified changes:
cp ~/Desktop/complete-popup-tests/*.png tests/visualScreenshotTesting/expectations/
```

## Notes

- These screenshots capture the full screen, not just the popup
- Screen resolution may vary; focus on **relative** positioning, not absolute pixels
- Multi-monitor setups may produce different results; primary display is the reference
