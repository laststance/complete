# Visual Regression Testing Suite

Comprehensive visual regression testing for the Complete app across multiple applications.

## Test Coverage

| Application | Test Cases | Description |
|-------------|------------|-------------|
| **TextEdit** | 5 | Native macOS app with full Accessibility API |
| **Chrome Canary** | 5 | Browser textarea, input, and address bar |
| **VSCode** | 3 | Electron-based editor |
| **Terminal.app** | 3 | CLI with clipboard fallback mode |
| **Total** | 16 | Comprehensive multi-app coverage |

## Quick Start

```bash
# Run all visual tests
./tests/visualScreenshotTesting/run-visual-tests.sh --verbose

# Run specific app tests
./tests/visualScreenshotTesting/run-visual-tests.sh --app textedit --verbose
./tests/visualScreenshotTesting/run-visual-tests.sh --app chrome --verbose
./tests/visualScreenshotTesting/run-visual-tests.sh --app vscode --verbose
./tests/visualScreenshotTesting/run-visual-tests.sh --app terminal --verbose

# Update baselines after verified changes
./tests/visualScreenshotTesting/run-visual-tests.sh --update-baseline
```

## Directory Structure

```
visualScreenshotTesting/
├── run-visual-tests.sh              # Main orchestrator script
├── modules/                          # AppleScript test modules
│   ├── test-textedit.applescript    # TextEdit tests (5 positions)
│   ├── test-chrome-canary.applescript # Chrome tests (5 cases)
│   ├── test-vscode.applescript      # VSCode tests (3 positions)
│   └── test-terminal.applescript    # Terminal tests (3 positions)
├── test-apps/                        # Test assets
│   └── test-page.html               # HTML page for browser tests
├── expectations/                     # Baseline screenshots
│   ├── textedit/                    # TextEdit baselines
│   ├── chrome-canary/               # Chrome baselines
│   ├── vscode/                      # VSCode baselines
│   └── terminal/                    # Terminal baselines
├── captures/                         # Test run screenshots
├── diffs/                            # Comparison diff images
└── reports/                          # JSON and HTML reports
```

## Test Applications

### TextEdit (Primary Test)
- **Type**: Native macOS Cocoa app
- **Accessibility**: Full AXUIElement API support
- **Positions**: top-left, top-right, bottom-left, bottom-right, center
- **Why Primary**: Best-case scenario for accessibility-based positioning

### Chrome Canary (Browser Test)
- **Type**: Chromium browser
- **Accessibility**: Browser accessibility mode + AXFrame coordinates
- **Test Cases**:
  - `textarea-center`: Standard textarea element
  - `textarea-top-left`: Textarea at screen edge
  - `textarea-bottom-right`: Textarea at opposite edge
  - `input-center`: Input type="text" element
  - `addressbar`: Browser address bar (special case)

### VSCode (Electron Test)
- **Type**: Electron-based editor
- **Accessibility**: Requires accessibility enablement
- **Positions**: editor-center, editor-top-left, editor-bottom-right
- **Note**: Tests clipboard fallback for Electron apps

### Terminal.app (CLI Test)
- **Type**: Native terminal emulator
- **Accessibility**: Limited - uses clipboard-based fallback
- **Positions**: terminal-center, terminal-top-left, terminal-bottom-right
- **Note**: Validates "Terminal input mode" feature

## CI/CD Integration

Visual tests run via GitHub Actions:

```yaml
# .github/workflows/visual-regression.yml
- Validates test infrastructure on every push
- Full visual tests require self-hosted runner with accessibility permissions
- Artifacts: screenshots, diff images, HTML reports
```

### Why Self-Hosted Runner?

GitHub-hosted macOS runners lack:
1. GUI session (required for AppleScript)
2. Accessibility permissions (required for System Events)
3. Real display (required for screenshots)

For full automation, use a self-hosted macOS runner with accessibility permissions granted.

## Running Tests Locally

### Prerequisites

1. **Build Complete app**:
   ```bash
   swift build
   ```

2. **Grant accessibility permissions**:
   - System Settings → Privacy & Security → Accessibility
   - Add Terminal.app (or your terminal emulator)

3. **Install test applications** (optional):
   - Chrome Canary (for browser tests)
   - VSCode (for Electron tests)

### Full Test Run

```bash
# Build and run all tests
./tests/visualScreenshotTesting/run-visual-tests.sh --verbose

# Skip build if already built
./tests/visualScreenshotTesting/run-visual-tests.sh --skip-build --verbose
```

### Individual App Tests

```bash
# TextEdit only (fastest, has existing baselines)
./tests/visualScreenshotTesting/run-visual-tests.sh --app textedit --verbose

# Chrome only (requires Chrome Canary installed)
./tests/visualScreenshotTesting/run-visual-tests.sh --app chrome --verbose
```

### Update Baselines

After making **intentional** changes to popup positioning:

```bash
# Update all baselines
./tests/visualScreenshotTesting/run-visual-tests.sh --update-baseline

# Update specific app baselines
./tests/visualScreenshotTesting/run-visual-tests.sh --app textedit --update-baseline
```

## Quality Criteria

| Metric | Threshold | Description |
|--------|-----------|-------------|
| SSIM Score | ≥ 0.95 | 95% structural similarity required |
| Pass Requirement | 100% | All tests must pass |

### What SSIM Measures

- **Structural Similarity**: Compares image structure, not just pixels
- **Tolerance**: Handles minor environmental differences (time, date display)
- **Threshold**: 0.95 allows ~5% variance for non-critical differences

### False Negatives

Environmental factors can cause low SSIM scores even with correct positioning:
- Different desktop wallpaper
- Different time/date in menu bar
- Different windows open in background

**Always manually verify screenshots when SSIM fails** - check popup-to-cursor distance.

## Test Reports

### JSON Report
```
tests/visualScreenshotTesting/reports/test-results.json
```

### HTML Report
```
tests/visualScreenshotTesting/reports/test-results.html
```

Open in browser for visual comparison with pass/fail status.

## Troubleshooting

### "Accessibility permissions required"
Grant accessibility permissions to your terminal app in System Settings.

### Tests interrupted
AppleScript GUI automation takes control of keyboard/mouse. Don't interact with the computer during tests (~2 minutes).

### Chrome/VSCode tests skipped
Install the required applications. Tests gracefully skip if apps are not found.

### Low SSIM but popup looks correct
Environmental differences (background, time). Manually verify popup position relative to cursor.

## Legacy Scripts

These scripts are kept for reference but replaced by the modular system:

| Script | Replaced By |
|--------|-------------|
| `test-popup-positions.applescript` | `modules/test-textedit.applescript` |
| `capture-screenshots.applescript` | `modules/test-textedit.applescript` |
| `test-browser-addressbar.applescript` | `modules/test-chrome-canary.applescript` |
