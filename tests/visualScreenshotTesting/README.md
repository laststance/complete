# Manual Test Scripts

This directory contains manual test scripts used during development and debugging. These scripts complement the automated test suite when visual verification or specific system interaction patterns are needed.

## Directory Structure

```
visualScreenshotTesting/
├── expectations/                    # Baseline screenshots for regression testing
│   ├── top-left.png
│   ├── top-right.png
│   ├── bottom-left.png
│   ├── bottom-right.png
│   ├── center.png
│   └── README.md
├── test-popup-positions.applescript # Main visual position test
├── test-browser-addressbar.applescript
├── ManualTestingChecklist.md
├── README.md
├── test_insertion_visual.sh
└── test_focus.sh
```

## Visual Regression Testing (Recommended Workflow)

### Running Tests

```bash
# 1. Build the app
swift build

# 2. Run the visual position test
osascript tests/visualScreenshotTesting/test-popup-positions.applescript

# 3. Screenshots saved to ~/Desktop/complete-popup-tests/
```

### Comparing Against Expectations

The `expectations/` directory contains baseline screenshots showing correct popup positioning. After running tests:

1. Open expectation image: `tests/visualScreenshotTesting/expectations/[position].png`
2. Open test result image: `~/Desktop/complete-popup-tests/[position].png`
3. Compare side-by-side focusing on:
   - Text cursor position (where "Hell" appears)
   - Popup window position relative to cursor
   - Distance between cursor and popup (~50px expected)

See `expectations/README.md` for detailed comparison criteria.

## Scripts

### test-popup-positions.applescript
- **Purpose**: Automated popup position testing at 5 screen locations
- **Output**: Screenshots in ~/Desktop/complete-popup-tests/
- **Use case**: Visual regression testing for popup positioning
- **Comparison**: Compare results against `expectations/` baseline images

### test-browser-addressbar.applescript
- **Purpose**: Test popup behavior in browser address bars
- **Use case**: Verifying fallback to mouse position when accessibility API fails

### test_focus.sh
- **Purpose**: Debug keyboard focus issues
- **Use case**: Testing window activation and keyboard event handling
- **When to use**: When debugging focus-related issues that automated tests can't reproduce

### test_insertion_visual.sh
- **Purpose**: Visual validation of text insertion with screenshots
- **Use case**: End-to-end testing with real applications (TextEdit)
- **When to use**: Before releases, or when debugging insertion behavior in specific apps

## Running Manual Tests

These scripts are not part of the automated CI/CD pipeline. Run them manually when:
- Debugging platform-specific focus or insertion issues
- Verifying behavior in real applications
- Creating visual documentation for bug reports
- **Performing visual regression testing against expectations**

## Note

Automated tests (in `tests/`) should be preferred when possible. These manual scripts are kept for scenarios that require human visual verification or complex system interactions that are difficult to automate.