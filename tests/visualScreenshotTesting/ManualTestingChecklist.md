# Manual Testing Checklist

Integration tests have 70% automation, 30% manual testing requirement.
This checklist covers manual testing scenarios that cannot be fully automated.

## 🎯 Testing Overview

**Total Coverage**:
- ✅ 70% Automated (via XCTest/XCUITest)
- 📋 30% Manual (this checklist)

**Testing Frequency**:
- 🔄 Weekly: VoiceOver testing
- 📦 Before Release: Full cross-app manual test
- 📅 Monthly: Test with latest macOS/app updates

---

## 1. Global Hotkey Validation

### 1.1 Hotkey Triggering
- [ ] Shift+Command+I (⇧⌘I) triggers autocomplete in TextEdit
- [ ] Shift+Command+I (⇧⌘I) triggers autocomplete in Mail
- [ ] Shift+Command+I (⇧⌘I) triggers autocomplete in Safari
- [ ] Shift+Command+I (⇧⌘I) triggers autocomplete in Chrome
- [ ] Shift+Command+I (⇧⌘I) triggers autocomplete in VS Code
- [ ] Hotkey works with external keyboard
- [ ] Hotkey works with laptop built-in keyboard
- [ ] Hotkey works in full-screen apps
- [ ] Hotkey works across multiple desktops/spaces

### 1.2 Hotkey Conflicts
- [ ] No conflicts with system shortcuts
- [ ] No conflicts with TextEdit shortcuts
- [ ] No conflicts with VS Code shortcuts
- [ ] Settings allow hotkey customization

---

## 2. Visual UI Validation

### 2.1 Window Appearance
- [ ] Window appears near cursor position
- [ ] Window has appropriate shadow/border
- [ ] Window doesn't block important content
- [ ] Window styling matches macOS guidelines
- [ ] Dark mode appearance is correct
- [ ] Light mode appearance is correct

### 2.2 Window Positioning
- [ ] Top position works correctly
- [ ] Bottom position works correctly
- [ ] Position persists across app restarts
- [ ] Position switching is smooth (no flicker)
- [ ] Window stays on correct display (multi-monitor)
- [ ] Window adjusts for screen edges

### 2.3 Suggestions Display
- [ ] Suggestions are clearly readable
- [ ] Selected suggestion is highlighted
- [ ] Font size is appropriate
- [ ] Text doesn't clip or truncate unexpectedly
- [ ] Scrolling works for many suggestions

### 2.4 Visual Regression Testing (Expectation-Based)

**Prerequisites**: Run `osascript tests/visualScreenshotTesting/test-popup-positions.applescript`

**Comparison Process**: For each position, compare new screenshot against baseline expectation.

| Position | Expectation | Test Result | Status |
|----------|-------------|-------------|--------|
| top-left | `expectations/top-left.png` | `~/Desktop/complete-popup-tests/top-left.png` | [ ] PASS / FAIL |
| top-right | `expectations/top-right.png` | `~/Desktop/complete-popup-tests/top-right.png` | [ ] PASS / FAIL |
| bottom-left | `expectations/bottom-left.png` | `~/Desktop/complete-popup-tests/bottom-left.png` | [ ] PASS / FAIL |
| bottom-right | `expectations/bottom-right.png` | `~/Desktop/complete-popup-tests/bottom-right.png` | [ ] PASS / FAIL |
| center | `expectations/center.png` | `~/Desktop/complete-popup-tests/center.png` | [ ] PASS / FAIL |

**Per-Screenshot Verification Checklist**:

For each of the 5 positions, complete this 3-iteration verification:

**Iteration 1 - Element Location**:
- [ ] Located TextEdit window position in expectation
- [ ] Located TextEdit window position in test result
- [ ] Located "Hell" text cursor position in expectation
- [ ] Located "Hell" text cursor position in test result
- [ ] Located popup window in expectation
- [ ] Located popup window in test result

**Iteration 2 - Position Comparison**:
- [ ] Popup-to-cursor distance is similar (~50px tolerance)
- [ ] Popup relative position (above/below) matches expectation
- [ ] TextEdit window position matches (screen region)

**Iteration 3 - Final Confirmation**:
- [ ] Re-examined all elements one more time
- [ ] Confirmed positions match expectation
- [ ] No visual anomalies detected

**Pass/Fail Criteria**:
- **PASS**: Popup position relative to cursor matches expectation (within ~50px)
- **FAIL**: Popup appears in different screen region or distance differs >100px

---

## 3. Cross-App Compatibility (Deep Testing)

### 3.1 TextEdit
- [ ] Works in new document
- [ ] Works in existing document
- [ ] Works with different text formats (RTF, plain text)
- [ ] Works in TextEdit search fields
- [ ] Completion inserts correctly
- [ ] Undo/Redo works after insertion

### 3.2 Mail
- [ ] Works in email compose body
- [ ] Works in email subject line
- [ ] Works in search field
- [ ] Works in reply/forward
- [ ] Doesn't interfere with email autocomplete

### 3.3 Safari
- [ ] Works in address bar
- [ ] Works in search field
- [ ] Works in text inputs on web pages
- [ ] Works in textareas on web pages
- [ ] Doesn't conflict with web page autocomplete
- [ ] Works across different websites

### 3.4 Chrome
- [ ] Works in address bar
- [ ] Works in search field
- [ ] Works in text inputs on web pages
- [ ] Works in textareas on web pages
- [ ] Works with Chrome DevTools console
- [ ] Doesn't conflict with Chrome autocomplete

### 3.5 VS Code
- [ ] Works in code editor
- [ ] Works in integrated terminal
- [ ] Works in search field
- [ ] Works in settings
- [ ] Doesn't conflict with VS Code IntelliSense
- [ ] Works across different file types

### 3.6 Other Common Apps (Bonus)
- [ ] Slack (if installed)
- [ ] Terminal (native macOS)
- [ ] Notes
- [ ] Pages
- [ ] Microsoft Word (if installed)

---

## 4. VoiceOver Testing (Accessibility)

**Prerequisites**: Enable VoiceOver (Cmd+F5)

### 4.1 Basic Navigation
- [ ] Window appearance is announced
- [ ] Window role is announced correctly
- [ ] Suggestions are announced when navigating
- [ ] Selected suggestion is clearly indicated
- [ ] Suggestion count is announced
- [ ] Window dismissal is announced

### 4.2 Interaction
- [ ] VO+Right Arrow navigates suggestions
- [ ] VO+Left Arrow navigates backward
- [ ] VO+Space selects suggestion
- [ ] Escape dismissal is announced
- [ ] No conflicting VO hints

### 4.3 Context
- [ ] Current text context is announced
- [ ] Completion result is announced after insertion
- [ ] Error states are announced (if any)

---

## 5. Performance & Responsiveness

### 5.1 Response Times (Subjective)
- [ ] Hotkey feels instant (<100ms perceived)
- [ ] Window appears quickly
- [ ] Suggestions load without noticeable delay
- [ ] Navigation is smooth (60fps feel)
- [ ] Selection/insertion is instant
- [ ] No UI freezing or stuttering

### 5.2 Resource Usage
- [ ] Low CPU usage when idle
- [ ] Memory usage remains stable
- [ ] No memory leaks over extended use
- [ ] Doesn't slow down target apps

---

## 6. Edge Cases & Error Handling

### 6.1 System States
- [ ] Works after waking from sleep
- [ ] Works after display sleep
- [ ] Works after screen lock/unlock
- [ ] Works when switching users
- [ ] Works with multiple displays
- [ ] Works when display is disconnected/reconnected

### 6.2 Permission States
- [ ] Prompts for accessibility permission if needed
- [ ] Graceful handling if permission denied
- [ ] Re-requests permission appropriately
- [ ] Clear error messages for permission issues

### 6.3 Unusual Scenarios
- [ ] Works with empty text
- [ ] Works with very long text
- [ ] Works with Unicode/emoji
- [ ] Works with RTL languages (if supported)
- [ ] Handles rapid hotkey triggering
- [ ] Handles suggestion selection spam

---

## 7. Settings & Preferences

### 7.1 Hotkey Customization
- [ ] Can change hotkey in settings
- [ ] New hotkey takes effect immediately
- [ ] Invalid hotkeys are rejected
- [ ] Hotkey conflicts are detected

### 7.2 Window Position
- [ ] Can switch between top/bottom
- [ ] Position persists
- [ ] Switch is visually smooth

### 7.3 Preferences Persistence
- [ ] Settings survive app restart
- [ ] Settings survive system restart
- [ ] Settings export/import works (if available)
- [ ] Reset to defaults works

---

## 8. Multi-Monitor Testing

- [ ] Window appears on correct monitor
- [ ] Position adjusts for screen edges
- [ ] Works when moving between monitors
- [ ] Works with different display arrangements
- [ ] Works with different resolution displays
- [ ] Works with Retina and non-Retina displays

---

## 9. Stress Testing

### 9.1 Longevity
- [ ] Works after 1 hour of use
- [ ] Works after 8 hours of use
- [ ] Works after multiple days uptime
- [ ] No performance degradation over time

### 9.2 Heavy Usage
- [ ] 100+ consecutive hotkey triggers
- [ ] Rapid app switching
- [ ] Many suggestions loaded
- [ ] Extended period with window open

---

## 10. User Experience

### 10.1 Intuitiveness
- [ ] First-time use is clear
- [ ] Hotkey is easy to remember
- [ ] Window is easy to dismiss
- [ ] Suggestions are clearly presented
- [ ] Settings are discoverable

### 10.2 Satisfaction
- [ ] Feels faster than typing full words
- [ ] Doesn't feel intrusive
- [ ] Suggestions are relevant
- [ ] Keyboard navigation is smooth
- [ ] Overall experience is pleasant

---

## 📊 Testing Results Template

**Date**: _______________
**Tester**: _______________
**macOS Version**: _______________
**App Version**: _______________

**Summary**:
- Total Items: _____
- Passed: _____
- Failed: _____
- Skipped: _____

**Issues Found**:
1. _______________________________________________
2. _______________________________________________
3. _______________________________________________

**Notes**:
_______________________________________________
_______________________________________________
_______________________________________________

**Sign-off**: _______________________________________________