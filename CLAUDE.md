# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Complete is a macOS system-wide spell autocomplete application triggered by global hotkey (Ctrl+I). It runs as a background agent (LSUIElement) without dock icon, providing TextEdit-style completions in any application.

**Critical Constraint**: Background agent app - all UI must be explicitly shown (no automatic window management).

## Build & Run Commands

### Development
```bash
# Build and run (for testing)
swift run

# Build only
swift build

# Run tests
swift test

# Run specific test
swift test --filter CompletionEngineTests

# Build for release
swift build -c release
```

### Local Installation
```bash
# Install to /Applications (recommended for development)
./Scripts/install-local.sh

# Build and install in debug mode
./Scripts/install-local.sh --debug

# Create .app bundle without installing
./Scripts/install-local.sh --no-install
```

### Distribution
```bash
# Full notarization workflow (requires Apple Developer ID)
./notarize.sh

# Manual steps documented in docs/distribution-guide.md
```

## Architecture Overview

### Core Flow: Hotkey → Extract → Complete → Insert

1. **Global Hotkey Trigger** (`HotkeyManager.swift`)
   - Uses KeyboardShortcuts library (NOT CGEvent directly)
   - Registered as `.triggerCompletion` shortcut name
   - Calls AppDelegate's `triggerCompletion()` on activation

2. **Text Extraction** (`AccessibilityManager.swift`)
   - AXUIElement API to get text at cursor
   - Returns `TextContext` struct (full text + cursor position)
   - 10-25ms typical performance

3. **Completion Generation** (`CompletionEngine.swift`)
   - NSSpellChecker with aggressive NSCache (1000 entries, 10MB)
   - Preloads dictionary on init for 5-15ms cached lookups
   - Thread-safe via `cacheQueue` serial DispatchQueue

4. **UI Display** (`CompletionWindowController.swift` + `CompletionViewModel.swift`)
   - AppKit NSPanel (level: .floating) with SwiftUI content
   - MUST call `showWindow(nil)` explicitly (LSUIElement = no auto-show)
   - ViewModel manages state + keyboard navigation

5. **Text Insertion** (`AccessibilityManager.swift`)
   - Dual-strategy: AXUIElement API (preferred) fallback to CGEvent simulation
   - Deletes partial word, inserts completion via paste buffer

### Component Dependencies

```
AppDelegate (coordinator, dependency injection)
├── SettingsManager (UserDefaults persistence)
├── CompletionEngine (NSSpellChecker with caching)
├── AccessibilityManager (text extraction/insertion)
│   ├── AccessibilityPermissionManager (permission checks)
│   ├── AccessibilityAlertManager (permission alerts)
│   ├── AccessibilityElementExtractor (text extraction)
│   └── AccessibilityTextInserter (text insertion)
├── HotkeyManager (global shortcuts via KeyboardShortcuts)
├── CompletionWindowController → CompletionViewModel → CompletionListView
└── SettingsWindowController → SettingsView
```

**Key Pattern**: AppDelegate owns all managers as instance properties, coordinates lifecycle via dependency injection (all managers injected into AppDelegate constructor).

## Critical Implementation Details

### LSUIElement Behavior

**Info.plist**: `LSUIElement = true` means:
- No dock icon
- No automatic menu bar
- Windows do NOT show automatically - must call `window.makeKeyAndOrderFront(nil)` or `showWindow(nil)`
- Status bar menu icon is the only UI entry point

### Accessibility Permissions

App REQUIRES accessibility permissions to:
- Read text at cursor position (AXUIElementCopyAttributeValue)
- Insert completion text (AXUIElementSetAttributeValue or CGEvent)

**Permission flow** (AppDelegate.swift):
1. Check `AXIsProcessTrusted()` on launch
2. If denied, show alert with "Open System Settings" button
3. Poll for permission grant, re-enable features when granted

**Development Testing with swift run**: For development and visual testing, use `swift run` directly instead of installing the .app bundle. When running via `swift run`, the accessibility permissions are inherited from Terminal.app (or your terminal emulator), which typically already has accessibility permissions granted. This avoids the TCC database issues that occur when rebuilding .app bundles.

### Performance Characteristics

Targets (all exceeded 1000x):
- Hotkey response: <100ms (achieved 20-50ms)
- Completion generation: <50ms (achieved 0.005-0.012ms cached)
- Memory usage: <50MB (achieved 13.5-20.6MB)

**Cache hit rate**: 85-95% via NSSpellChecker dictionary preloading + NSCache

### Window Positioning Logic

`CompletionWindowController.swift` positions window relative to cursor:
- Fetches cursor screen coordinates via Accessibility API
- Calculates position based on `windowPosition` setting (`.top` or `.bottom`)
- Adjusts for screen bounds to prevent off-screen rendering
- Updates on every show (cursor may move between triggers)

## Testing Structure

```
tests/
├── CompleteTests.swift              # 54 unit tests (core components)
├── IntegrationTests/
│   ├── CrossAppIntegrationTests.swift    # XCUITest (TextEdit, VSCode, Chrome, etc.)
│   └── AccessibilityAuditTests.swift     # Accessibility compliance
├── Helpers/                          # Page Object pattern utilities
└── visualScreenshotTesting/          # Visual/manual screenshot tests
    ├── expectations/                     # Baseline screenshots for regression testing
    │   ├── top-left.png                  # Expected popup position at top-left
    │   ├── top-right.png                 # Expected popup position at top-right
    │   ├── bottom-left.png               # Expected popup position at bottom-left
    │   ├── bottom-right.png              # Expected popup position at bottom-right
    │   ├── center.png                    # Expected popup position at center
    │   └── README.md                     # Expectations documentation
    ├── test-popup-positions.applescript  # AppleScript automation for popup position testing
    ├── test-browser-addressbar.applescript # Browser address bar testing
    ├── ManualTestingChecklist.md         # Manual testing checklist (30% manual coverage)
    ├── README.md                         # Manual testing documentation
    ├── test_insertion_visual.sh          # Text insertion visual tests
    └── test_focus.sh                     # Focus behavior tests
```

### Running Integration Tests

**Prerequisites**: Grant accessibility permissions to test runner (Xcode.app or terminal)

```bash
# UI tests require running app
swift test --filter IntegrationTests
```

**Note**: Cross-app tests open real applications (TextEdit, VSCode, etc.) - close other apps first.

### Visual Screenshot Testing (HIGHEST PRIORITY)

**🔴 BEFORE STARTING: Claude Code MUST read this entire CLAUDE.md file to understand all verification requirements before running any visual screenshot tests.**

**This is the most important test for this application.** Screenshot-based testing captures the actual visual state of the app as users see it, making it the definitive verification method.

#### Why This Test Has Highest Priority

1. **Real App Behavior**: Screenshots capture actual rendered UI, not simulated states
2. **Visual Verification**: Popup positioning, window appearance, and text display are visually confirmed
3. **Integration Reality**: Tests the complete flow from hotkey trigger to popup display
4. **Catches Coordinate Bugs**: UI positioning issues (like the Accessibility API ↔ NSScreen coordinate mismatch) are only visible in screenshots

#### Test Method: AppleScript Automation + Screenshots

```bash
# Run the visual position test
# 1. Build the app
swift build

# 2. Execute AppleScript test (positions TextEdit at 5 locations, triggers popup, captures screenshots)
osascript tests/visualScreenshotTesting/test-popup-positions.applescript

# 3. Screenshots saved to ~/Desktop/complete-popup-tests/
# Files: top-left.png, top-right.png, bottom-left.png, bottom-right.png, center.png
```

#### Critical: Screenshot Verification Rules

**🔴 MANDATORY PRE-REQUISITES (Claude Code must follow):**
1. **READ CLAUDE.md FIRST**: Before running any visual tests, Claude Code MUST read this CLAUDE.md file to understand the verification requirements
2. **READ TEST README**: Before running visual tests, Claude Code MUST read `tests/visualScreenshotTesting/README.md` to understand the test infrastructure, directory structure, and comparison workflow
3. **RE-ANALYZE 3 TIMES**: After viewing screenshots, Claude Code MUST re-analyze each screenshot AT LEAST 3 times to catch positioning errors that might be overlooked on first glance

**🟢 EXPECTATION-BASED VERIFICATION (Required Process):**

Baseline expectation screenshots are stored in `tests/visualScreenshotTesting/expectations/`. Use these as reference when verifying new test results:

1. **Load Expectation Images**: Open the corresponding expectation image from `tests/visualScreenshotTesting/expectations/`
2. **Side-by-Side Comparison**: For each test position (top-left, top-right, bottom-left, bottom-right, center):
   - Open both: expectation image AND new test result image
   - Compare the **text input position** ("Hell" text location in TextEdit window)
   - Compare the **popup position** (completion list window relative to cursor)
3. **Pass/Fail Judgment**:
   - **PASS**: Popup position relative to text cursor is (almost) identical to expectation
   - **PASS**: Popup within ~50px of where it appears in expectation
   - **FAIL**: Popup appears in a significantly different screen location
   - **FAIL**: Popup distance from cursor differs by >100px from expectation

**Verification Checklist (Per Screenshot):**
```
[ ] Iteration 1: Locate TextEdit window position in both images
[ ] Iteration 1: Locate "Hell" text cursor position in both images  
[ ] Iteration 1: Locate popup window in both images
[ ] Iteration 2: Compare popup-to-cursor distance (should be ~same)
[ ] Iteration 2: Compare popup relative position (above/below cursor)
[ ] Iteration 3: Final confirmation - positions match expectation?
```

**⚠️ MUST carefully examine each screenshot image to verify:**

1. **Popup Location**: Is the completion popup appearing NEAR the text cursor?
2. **Distance Check**: Popup should be within ~50px of the cursor, not across the screen
3. **All Positions**: Verify ALL 5 test positions - bugs may only appear at certain screen locations
4. **Content Visibility**: Can you see both the text input ("Hell") AND the popup list?
5. **Distinguish App Popup from Browser UI**: Do NOT confuse Chrome's search history dropdown with Complete app's popup

**Common Mistake**: Glancing at screenshots and assuming they pass. Always:
- Look for the TextEdit window location
- Find the text cursor position (where "Hell" text is displayed)
- Verify popup is adjacent to cursor, not in a distant screen area
- Compare popup position across all 5 screenshots
- Re-examine each screenshot 3 times before concluding "no regression"

#### Test Positions

| Position | Window Location | Expected Popup |
|----------|----------------|----------------|
| top-left | Screen top-left corner | Near top-left cursor |
| top-right | Screen top-right corner | Near top-right cursor |
| bottom-left | Screen bottom-left corner | Near bottom-left cursor |
| bottom-right | Screen bottom-right corner | Near bottom-right cursor |
| center | Screen center | Near center cursor |

#### When to Run This Test

- After ANY changes to coordinate calculation logic
- After modifying `AccessibilityElementExtractor.swift` (cursor position detection)
- After modifying `CompletionWindowController.swift` (window positioning)
- Before committing popup-related changes

#### Historical Bug Reference

The coordinate system mismatch bug (Accessibility API uses top-left origin, NSScreen uses bottom-left origin) was only caught through careful screenshot examination. Unit tests passed, but screenshots revealed the popup appearing at the wrong screen location.

## Settings Persistence

`SettingsManager.swift` uses UserDefaults for:
- Hotkey configuration (KeyCombination struct → JSON)
- Window position preference (top/bottom)
- First launch flag

**Keys**: See `SettingsManager.Keys` struct for identifiers.

## Common Development Tasks

### Adding New Completions Source

1. Extend `CompletionEngine.swift`:
   - Add new completion method (e.g., `customCompletions(for:)`)
   - Integrate with existing `completions(for:)` method
   - Maintain cache strategy for performance

2. Update `CompletionEngineTests.swift`:
   - Add tests for new completion source
   - Verify cache behavior
   - Performance benchmark

### Changing Global Hotkey

**User setting**: Settings window allows hotkey customization.

**Code default**: `HotkeyManager.swift` defines `.triggerCompletion` with Ctrl+I default.

**Library**: KeyboardShortcuts 2.0+ - see docs at github.com/sindresorhus/KeyboardShortcuts

### Modifying UI Appearance

**Window style**: `CompletionWindowController.swift` - NSPanel configuration
**Content**: `CompletionListView.swift` - SwiftUI List with custom row styling
**Theme**: Automatic dark mode support (NSRequiresAquaSystemAppearance = false in Info.plist)

## Debugging Tips

### Accessibility Issues

```bash
# Check if accessibility enabled
# In Swift code:
AXIsProcessTrusted()

# System Preferences:
# System Settings → Privacy & Security → Accessibility
# Add Terminal.app (for swift run) or Xcode.app
```

### Window Not Showing

**LSUIElement caveat**: Windows don't auto-show. Always call:
```swift
window.makeKeyAndOrderFront(nil)
// OR
showWindow(nil)  // NSWindowController
```

### Hotkey Not Triggering

1. Check KeyboardShortcuts library registration
2. Verify no conflicts with system shortcuts
3. Enable hotkey recording debug logging in `HotkeyManager.swift`

### Performance Profiling

Use built-in metrics in `CompletionEngineTests.swift`:
```bash
swift test --filter CompletionEnginePerformanceTests
```

Check cache hit rate via `CompletionEngine.cacheStatistics()` (private method - expose for debugging if needed).

## Project-Specific Conventions

### Swift Style

- Follow standard Swift API design guidelines
- Use explicit types for public interfaces
- Private properties prefixed with underscore (e.g., `_cache`)
- Async methods suffixed with `Async` (if added)

### Error Handling

- No force unwraps (`!`) in production code
- Use `guard` for early returns
- Accessibility errors logged via `print()` (no logging framework yet)

### Testing

- Test file names match source file: `CompletionEngine.swift` → `CompletionEngineTests.swift`
- Performance tests use `XCTMetric` (see `CompleteTests.swift` for examples)
- Integration tests use Page Object pattern (see `tests/Helpers/`)

## Dependencies

- **KeyboardShortcuts 2.4.0**: Global hotkey registration
  - Docs: github.com/sindresorhus/KeyboardShortcuts
  - Manages shortcut conflicts, user customization UI

**No other external dependencies** - uses system frameworks:
- AppKit (NSPanel, NSSpellChecker)
- SwiftUI (UI components)
- Accessibility (AXUIElement)
- Carbon (CGEvent for fallback text insertion)

## Documentation Locations

- **Accessibility API Research**: `claudedocs/macOS_Accessibility_API_Research_2024-2025.md`
- **Global Hotkey Research**: `docs/macos-global-hotkey-research-2024.md`
- **Distribution Guide**: `docs/distribution-guide.md` (400+ lines, covers code signing + notarization)
- **Performance Report**: `docs/performance-testing-report.md`

## Architecture Notes

### Dependency Injection Pattern
All core components use constructor injection for testability:
- `AppDelegate` constructor receives all managers
- `AccessibilityManager` receives sub-components (PermissionManager, AlertManager, ElementExtractor, TextInserter)
- `CompletionWindowController` receives ViewModel
- Makes testing easier via protocol-based mocking (see `Protocols.swift`)

### Protocol-Based Design
Key protocols in `Protocols.swift`:
- `AccessibilityPermissionChecking`: Permission verification
- `AccessibilityAlertPresenting`: Permission alert UI
- `AccessibilityElementExtracting`: Text extraction from focused element
- `AccessibilityTextInserting`: Text insertion into focused element
- Enables dependency injection and test mocking

### Error Handling Strategy
Custom error types in `ErrorTypes.swift`:
- `AccessibilityError`: Permission denied, element not found, extraction/insertion failures
- `CompletionError`: No completions, invalid input
- All errors logged via `Logger.swift` (standardized logging with categories)

## Serena Memory System

This project uses Serena MCP for session persistence. Available memories:
- `project-overview`: Architecture and requirements
- `technical-decisions`: Key technology choices and rationale
- `project-completion-2025-11-08`: Final delivery summary
- Session-specific memories: Phase completion checkpoints

**Load on session start**: Activate project with Serena tools to access memories.

## Release Workflow (Complete End-to-End)

### Overview

Complete release involves 5 phases:
1. **Pre-release** → Version bump, testing, changelog
2. **Build & Notarize** → `./notarize.sh` creates signed DMG
3. **GitHub Release** → Create release with DMG asset
4. **Website Update** → Update version on landing page
5. **Verification** → Confirm all artifacts are correct

### Phase 1: Pre-release Preparation

#### 1.1 Run All Tests
```bash
# Unit tests (must pass)
swift test --filter "CompleteTests"

# Visual screenshot tests (manual verification required)
swift build
osascript tests/visualScreenshotTesting/test-popup-positions.applescript
# Verify screenshots in ~/Desktop/complete-popup-tests/
```

#### 1.2 Update Version (if needed)
Version is embedded in:
- `src/Resources/Info.plist` - `CFBundleShortVersionString` and `CFBundleVersion`

```bash
# Check current version
grep -A1 "CFBundleShortVersionString" src/Resources/Info.plist
```

#### 1.3 Prepare Changelog
Document changes for release notes:
- Bug fixes
- New features
- Breaking changes
- Known issues

### Phase 2: Build & Notarization

#### 2.1 Prerequisites (One-time Setup)
```bash
# Store notarization credentials in Keychain
xcrun notarytool store-credentials "Complete-Notarization" \
  --apple-id "your-apple-id@example.com" \
  --team-id "YOUR_TEAM_ID" \
  --password "app-specific-password"

# Set environment variable
export DEVELOPER_ID="Developer ID Application: Your Name (TEAM_ID)"
```

#### 2.2 Run Notarization Script
```bash
# Full automated workflow (5-30 minutes)
./notarize.sh 2>&1 | tee /tmp/notarize-output.log

# Output: ./dist/Complete-YYYYMMDD.dmg (signed and notarized)
```

**What `./notarize.sh` does:**
1. ✅ Validates prerequisites (certificate, entitlements)
2. ✅ Builds release binary (`swift build -c release`)
3. ✅ Creates `.app` bundle with Info.plist and resources
4. ✅ Copies SPM resource bundles (KeyboardShortcuts localization)
5. ✅ Signs with hardened runtime and entitlements
6. ✅ Creates DMG package
7. ✅ Submits to Apple for notarization (5-30 min wait)
8. ✅ Staples notarization ticket
9. ✅ Verifies Gatekeeper acceptance

#### 2.3 Verify Build Output
```bash
# Check DMG exists
ls -la dist/Complete-*.dmg

# Verify notarization
spctl -a -vv -t install dist/Complete-*.dmg
# Expected: "accepted" and "source=Notarized Developer ID"
```

### Phase 3: GitHub Release

#### 3.1 Create Git Tag
```bash
# Format: vX.Y.Z (semantic versioning)
VERSION="v0.1.4"
git tag -a "$VERSION" -m "Release $VERSION"
git push origin "$VERSION"
```

#### 3.2 Create GitHub Release
```bash
# Get the DMG filename
DMG_FILE=$(ls dist/Complete-*.dmg | head -1)
DMG_NAME=$(basename "$DMG_FILE")

# Create release with DMG
gh release create "$VERSION" \
  --title "Complete $VERSION - [Brief Description]" \
  --notes "## Changes
- [List major changes]
- [Bug fixes]

## Installation
1. Download \`$DMG_NAME\`
2. Open DMG and drag Complete to Applications
3. Launch Complete
4. Grant Accessibility permissions when prompted

## Requirements
- macOS 14.0 Sonoma or later" \
  "$DMG_FILE"
```

#### 3.3 Verify Release
```bash
# List releases
gh release list --limit 3

# View release details
gh release view "$VERSION"
```

### Phase 4: Website Update

#### 4.1 Update Landing Page Version
```bash
# Edit website/index.html
# Update these locations:
# - Line 16: Hero version badge
# - Line 161: Download link URL
# - Line 163: Download button version
# - Line 187: Footer version

# Example: v0.1.3 → v0.1.4
sed -i '' 's/v0\.1\.3/v0.1.4/g' website/index.html
sed -i '' 's/Complete-20251214/Complete-20251220/g' website/index.html
```

#### 4.2 Commit and Push to Main
```bash
git add website/index.html
git commit -m "docs: update landing page to $VERSION with download link"
git push origin main
```

#### 4.3 Deploy to GitHub Pages
```bash
# Switch to gh-pages branch
git checkout gh-pages
git pull origin gh-pages

# Copy updated files from main
git show main:website/index.html > index.html
git show main:website/styles.css > styles.css
git show main:website/script.js > script.js

# Commit and push
git add index.html styles.css script.js
git commit -m "docs: update landing page to $VERSION with download link"
git push origin gh-pages

# Return to main branch
git checkout main
```

#### 4.4 Verify Deployment
```bash
# Check GitHub Pages build status
gh api repos/laststance/complete/pages/builds --jq '.[0] | {status, created_at}'

# Verify live site (after ~1 minute)
curl -s "https://laststance.github.io/complete/" | grep -o 'v[0-9]\+\.[0-9]\+\.[0-9]\+'
```

### Phase 5: Post-release Verification

#### 5.1 Download Test
```bash
# Download from GitHub release
DOWNLOAD_URL=$(gh release view "$VERSION" --json assets --jq '.assets[0].url')
curl -L -o /tmp/test-download.dmg "$DOWNLOAD_URL"

# Verify Gatekeeper
spctl -a -vv -t install /tmp/test-download.dmg
```

#### 5.2 Installation Test (Clean Environment)
1. Open downloaded DMG
2. Drag Complete.app to /Applications
3. Launch Complete
4. Verify accessibility permission prompt appears
5. Grant permission and test hotkey (Ctrl+I)

#### 5.3 Website Verification
- [ ] Version number correct on landing page
- [ ] Download link works and downloads correct DMG
- [ ] Footer shows correct version

### Quick Release Checklist

```markdown
## Pre-release
- [ ] All tests pass (`swift test`)
- [ ] Visual tests verified (screenshots match expectations)
- [ ] Version updated in Info.plist (if needed)
- [ ] Changelog prepared

## Build & Notarize
- [ ] `./notarize.sh` completed successfully
- [ ] DMG exists in `./dist/`
- [ ] Gatekeeper verification passed

## GitHub Release
- [ ] Git tag created and pushed
- [ ] GitHub release created with DMG
- [ ] Release notes written

## Website
- [ ] Landing page updated (4 version locations)
- [ ] Changes pushed to main
- [ ] gh-pages branch updated
- [ ] Live site shows new version

## Verification
- [ ] Download from release works
- [ ] Installation on clean system works
- [ ] App functions correctly
```

### Troubleshooting

#### Notarization Fails
```bash
# Check detailed log
xcrun notarytool log <submission-id> --keychain-profile "Complete-Notarization"

# Common fixes:
# - Ensure hardened runtime enabled
# - Verify entitlements file exists
# - Check timestamp flag included in codesign
```

#### Website Not Updating
```bash
# Force cache refresh
curl -I "https://laststance.github.io/complete/" | grep -i cache

# Check raw file (updates faster than CDN)
curl -s "https://raw.githubusercontent.com/laststance/complete/gh-pages/index.html" | grep -o 'v[0-9]\+\.[0-9]\+\.[0-9]\+'
```

#### SPM Resource Bundles Missing
If app crashes on launch with localization errors:
```bash
# Verify bundles copied
ls -la dist/Complete.app/Contents/Resources/*.bundle

# If missing, check .build/release/ for .bundle directories
ls -la .build/release/*.bundle
```

### File Locations Reference

| Purpose | Location |
|---------|----------|
| Notarization script | `./notarize.sh` |
| Distribution guide | `docs/distribution-guide.md` |
| Entitlements | `Complete.entitlements` |
| Info.plist | `src/Resources/Info.plist` |
| App icon | `src/Resources/AppIcon.icns` |
| Website source | `website/` |
| Build output | `./dist/` |
| GitHub Pages branch | `gh-pages` |