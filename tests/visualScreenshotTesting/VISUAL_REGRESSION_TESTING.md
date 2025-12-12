# Visual Regression Testing Quality Gate

Automated visual testing system for the Complete app using AppleScript-based screenshot capture and image comparison.

## Overview

This quality gate ensures the Complete popup appears correctly at all screen positions with consistent visual output across builds.

## Test Criteria

| Criteria | Value | Description |
|----------|-------|-------------|
| **SSIM Threshold** | 0.95 | Structural Similarity Index (95% match required) |
| **Test Positions** | 5 | top-left, top-right, bottom-left, bottom-right, center |
| **Pass Requirement** | ALL | All 5 positions must pass |
| **Popup Detection** | Required | Popup must be visible in screenshot |

## Directory Structure

```
tests/visualScreenshotTesting/
├── expectations/           # Baseline images (committed to git)
│   ├── top-left.png
│   ├── top-right.png
│   ├── bottom-left.png
│   ├── bottom-right.png
│   ├── center.png
│   └── README.md
├── captures/               # Test run screenshots (gitignored)
├── diffs/                  # Visual diff images (gitignored)
├── reports/                # Test results JSON/HTML (gitignored)
├── capture-screenshots.applescript    # Screenshot capture script
├── compare-screenshots.sh             # Image comparison utility
├── run-visual-tests.sh               # Quality gate orchestrator
└── VISUAL_REGRESSION_TESTING.md      # This documentation
```

## Quick Start

### Prerequisites

1. **macOS** with accessibility permissions
2. **ImageMagick** for image comparison:
   ```bash
   brew install imagemagick
   ```
3. **Complete app** built:
   ```bash
   swift build
   ```

### Run Quality Gate

```bash
# Full visual regression test
./tests/visualScreenshotTesting/run-visual-tests.sh

# Exit code: 0 = PASS, 1 = FAIL
```

### Manual Screenshot Capture

```bash
# Capture screenshots to default directory
osascript tests/visualScreenshotTesting/capture-screenshots.applescript

# Capture to custom directory
osascript tests/visualScreenshotTesting/capture-screenshots.applescript /path/to/output/
```

### Manual Image Comparison

```bash
# Compare two images
./tests/visualScreenshotTesting/compare-screenshots.sh \
    expectations/top-left.png \
    captures/top-left.png \
    diffs/top-left-diff.png

# Returns SSIM score (0.0 to 1.0)
```

## Quality Gate Workflow

```
┌─────────────────────────────────────────────────────────┐
│                   run-visual-tests.sh                    │
├─────────────────────────────────────────────────────────┤
│  1. Build Complete app (swift build)                    │
│  2. Start Complete app in background                    │
│  3. Run capture-screenshots.applescript                 │
│  4. For each position:                                  │
│     ├─ Compare captures/X.png vs expectations/X.png    │
│     ├─ Calculate SSIM score                            │
│     └─ Generate diff image if score < threshold        │
│  5. Generate JSON report                                │
│  6. Generate HTML report with visual comparison         │
│  7. Return exit code (0=pass, 1=fail)                   │
└─────────────────────────────────────────────────────────┘
```

## Understanding SSIM

**Structural Similarity Index (SSIM)** measures perceived visual similarity between two images.

| Score | Meaning |
|-------|---------|
| 1.0 | Identical |
| 0.95+ | Minor differences (anti-aliasing, font rendering) |
| 0.90-0.95 | Noticeable differences |
| < 0.90 | Significant differences |

**Why 0.95 threshold?**
- Tolerates minor rendering variations across macOS versions
- Catches real visual regressions (wrong position, missing popup)
- Aligns with human perception of "same" vs "different"

## Updating Expectations

When intentional UI changes are made:

```bash
# 1. Run capture to get new screenshots
osascript tests/visualScreenshotTesting/capture-screenshots.applescript

# 2. Review captures visually
open tests/visualScreenshotTesting/captures/

# 3. If correct, copy to expectations
cp tests/visualScreenshotTesting/captures/*.png \
   tests/visualScreenshotTesting/expectations/

# 4. Commit new expectations
git add tests/visualScreenshotTesting/expectations/
git commit -m "Update visual test expectations"
```

## CI Integration

### GitHub Actions Example

```yaml
name: Visual Regression Tests

on: [push, pull_request]

jobs:
  visual-tests:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4

      - name: Install ImageMagick
        run: brew install imagemagick

      - name: Build Complete
        run: swift build

      - name: Run Visual Tests
        run: ./tests/visualScreenshotTesting/run-visual-tests.sh

      - name: Upload Test Report
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: visual-test-report
          path: tests/visualScreenshotTesting/reports/
```

## Troubleshooting

### Common Issues

| Issue | Solution |
|-------|----------|
| "ImageMagick not installed" | `brew install imagemagick` |
| "Accessibility permission denied" | Grant permissions in System Settings > Privacy & Security > Accessibility |
| "Complete app not running" | Run `swift run` or start Complete.app |
| "SSIM score too low" | Check if popup is actually visible; verify positioning logic |

### Debugging

```bash
# View captured screenshots
open tests/visualScreenshotTesting/captures/

# View diff images (highlights differences in red)
open tests/visualScreenshotTesting/diffs/

# Check JSON report
cat tests/visualScreenshotTesting/reports/test-results.json | jq .

# View HTML report
open tests/visualScreenshotTesting/reports/test-results.html
```

## Test Report Format

### JSON Schema

```json
{
  "timestamp": "2025-12-12T16:30:00Z",
  "passed": true,
  "threshold": 0.95,
  "total_tests": 5,
  "passed_tests": 5,
  "failed_tests": 0,
  "tests": [
    {
      "position": "top-left",
      "expected": "expectations/top-left.png",
      "actual": "captures/top-left.png",
      "diff": "diffs/top-left-diff.png",
      "ssim": 0.98,
      "passed": true
    }
  ]
}
```

### Exit Codes

| Code | Meaning |
|------|---------|
| 0 | All tests passed |
| 1 | One or more tests failed |
| 2 | Script error (missing dependencies, etc.) |

## Best Practices

1. **Run before commits** affecting UI positioning
2. **Review diff images** when tests fail to understand changes
3. **Update expectations** only after visual verification
4. **Keep expectations in git** for team consistency
5. **Ignore captures/diffs/reports** in .gitignore
