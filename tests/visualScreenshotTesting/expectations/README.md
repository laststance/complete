# Visual Test Expectations (Baseline Screenshots)

This directory contains **baseline expectation screenshots** for visual regression testing of the Complete app's popup positioning across multiple applications.

## Directory Structure

```
expectations/
├── README.md           # This file
├── textedit/           # TextEdit baseline screenshots (5 positions)
├── chrome-canary/      # Chrome Canary baselines (5 test cases)
├── vscode/             # VSCode baselines (3 positions)
└── terminal/           # Terminal.app baselines (3 positions)
```

## Application Test Coverage

### TextEdit (Primary Test - Full Accessibility API)
| File | Description |
|------|-------------|
| `textedit/top-left.png` | Window at screen top-left |
| `textedit/top-right.png` | Window at screen top-right |
| `textedit/bottom-left.png` | Window at screen bottom-left |
| `textedit/bottom-right.png` | Window at screen bottom-right |
| `textedit/center.png` | Window at screen center |

### Chrome Canary (Browser + Address Bar)
| File | Description |
|------|-------------|
| `chrome-canary/textarea-center.png` | Textarea element, center position |
| `chrome-canary/textarea-top-left.png` | Textarea element, top-left position |
| `chrome-canary/textarea-bottom-right.png` | Textarea element, bottom-right position |
| `chrome-canary/input-center.png` | Input[type=text] element, center position |
| `chrome-canary/addressbar.png` | Browser address bar |

### VSCode (Electron Editor)
| File | Description |
|------|-------------|
| `vscode/editor-center.png` | Editor at screen center |
| `vscode/editor-top-left.png` | Editor at top-left |
| `vscode/editor-bottom-right.png` | Editor at bottom-right |

### Terminal.app (Clipboard Fallback Mode)
| File | Description |
|------|-------------|
| `terminal/terminal-center.png` | Terminal at screen center |
| `terminal/terminal-top-left.png` | Terminal at top-left |
| `terminal/terminal-bottom-right.png` | Terminal at bottom-right |

## Baseline Creation

- **Date**: 2025-12-07 (TextEdit), 2025-12-12 (Multi-app)
- **Hotkey**: Shift+Command+I
- **Test Text**: "Hell" (triggers spell completions)
- **Commit Reference**: e7ce0f3 (original popup positioning fix)

## Usage

### Running All Tests

```bash
# Run all app tests with comparison
./tests/visualScreenshotTesting/run-visual-tests.sh --verbose

# Run specific app tests
./tests/visualScreenshotTesting/run-visual-tests.sh --app textedit --verbose
./tests/visualScreenshotTesting/run-visual-tests.sh --app chrome-canary --verbose
./tests/visualScreenshotTesting/run-visual-tests.sh --app vscode --verbose
./tests/visualScreenshotTesting/run-visual-tests.sh --app terminal --verbose
```

### Updating Baselines

```bash
# Update all baselines
./tests/visualScreenshotTesting/run-visual-tests.sh --update-baseline

# Update specific app baselines
./tests/visualScreenshotTesting/run-visual-tests.sh --app textedit --update-baseline
```

### Verification Criteria

**PASS** if the new screenshot shows:
- Popup positioned within ~50px of the text cursor
- Same relative positioning as the expectation
- Both test text ("Hell") and popup completion list visible

**FAIL** if:
- Popup appears far from cursor (wrong screen area)
- Popup at different relative position than expectation
- Missing popup or text content

## Notes

- TextEdit uses full Accessibility API (primary reference)
- Chrome/VSCode (Electron) use browser accessibility enablement
- Terminal uses clipboard-based fallback mode
- Screen resolution may vary; compare **relative** positioning
- Multi-monitor setups: primary display is the reference
