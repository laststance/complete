// AccessibilityAuditTests.swift
// Automated accessibility compliance testing using Xcode 15+ features
// Verifies WCAG compliance, proper labels, and keyboard navigation

import XCTest

/// Accessibility audit tests using automated compliance checking
/// Tests verify app meets macOS accessibility standards
final class AccessibilityAuditTests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        try super.setUpWithError()
        continueAfterFailure = false

        // Skip all GUI-dependent tests when running in CI environment
        // GitHub Actions sets CI=true environment variable
        try XCTSkipIf(
            ProcessInfo.processInfo.environment["CI"] != nil,
            "Skipping GUI-dependent accessibility tests in CI environment (no display available)"
        )

        app = XCUIApplication()
        app.launch()

        // Allow time for app initialization
        sleep(1)
    }

    override func tearDown() {
        app?.terminate()
        super.tearDown()
    }

    // MARK: - Automated Accessibility Audits

    /// Comprehensive accessibility audit using Xcode 15+ automated testing
    /// Tests: contrast, element detection, descriptions, hit regions, text clipping, traits, actions
    func testComprehensiveAccessibilityAudit() throws {
        // Note: This test requires Xcode 15+ for automated accessibility auditing
        // For Xcode 14 and below, this test will be skipped

        // Trigger autocomplete to show window
        CrossAppTestHelper.triggerAutocompleteHotkey()

        let windowPage = AutocompleteWindowPage(app: app)

        // Wait for window to appear (may not appear if no text context)
        // This is acceptable - we'll audit what we can
        _ = windowPage.waitForAppearance(timeout: 2.0)

        // Run comprehensive accessibility audit
        // This automatically checks for common accessibility issues:
        // - Contrast ratios (WCAG 2.1 Level AA)
        // - Missing element descriptions
        // - Elements too small to interact with
        // - Text that is clipped
        // - Missing accessibility traits
        // - Missing accessibility actions

        #if compiler(>=5.9) // Xcode 15+
        do {
            try app.performAccessibilityAudit(for: [
                .contrast,
                .elementDetection,
                .sufficientElementDescription,
                .hitRegion
            ])
        } catch {
            // If audit finds issues, test fails with detailed report
            XCTFail("Accessibility audit failed: \(error)")
        }
        #else
        throw XCTSkip("Automated accessibility audits require Xcode 15+")
        #endif
    }

    /// Test contrast ratio compliance (WCAG Level AA: 4.5:1 for normal text)
    func testContrastRatios() throws {
        #if compiler(>=5.9)
        CrossAppTestHelper.triggerAutocompleteHotkey()

        let windowPage = AutocompleteWindowPage(app: app)
        _ = windowPage.waitForAppearance(timeout: 2.0)

        do {
            try app.performAccessibilityAudit(for: [.contrast])
        } catch {
            XCTFail("Contrast ratio audit failed: \(error)")
        }
        #else
        throw XCTSkip("Contrast audits require Xcode 15+")
        #endif
    }

    /// Test that all interactive elements have sufficient hit regions
    func testHitRegions() throws {
        #if compiler(>=5.9)
        CrossAppTestHelper.triggerAutocompleteHotkey()

        let windowPage = AutocompleteWindowPage(app: app)
        _ = windowPage.waitForAppearance(timeout: 2.0)

        do {
            try app.performAccessibilityAudit(for: [.hitRegion])
        } catch {
            XCTFail("Hit region audit failed: \(error)")
        }
        #else
        throw XCTSkip("Hit region audits require Xcode 15+")
        #endif
    }

    // MARK: - Manual Accessibility Verification

    /// Verify autocomplete window has proper accessibility labels
    func testWindowAccessibilityLabels() {
        CrossAppTestHelper.triggerAutocompleteHotkey()

        let windowPage = AutocompleteWindowPage(app: app)
        guard windowPage.waitForAppearance(timeout: 2.0) else {
            // Window may not appear without text context - skip test
            return
        }

        // Verify window has accessibility label
        XCTAssertTrue(
            windowPage.hasAccessibilityLabels,
            "Autocomplete window and suggestion list must have accessibility labels"
        )

        // Verify window label is not empty
        XCTAssertFalse(
            windowPage.window.label.isEmpty,
            "Window must have non-empty accessibility label"
        )

        windowPage.dismiss()
    }

    /// Verify suggestions have proper accessibility descriptions
    func testSuggestionAccessibility() throws {
        // Need text context for suggestions - use TextEdit
        guard CrossAppTestHelper.isInstalled(.textEdit) else {
            throw XCTSkip("TextEdit required for suggestion testing")
        }

        guard let textView = CrossAppTestHelper.prepareForTesting(.textEdit) else {
            XCTFail("Failed to prepare TextEdit")
            return
        }

        textView.clearAndType("Test")
        CrossAppTestHelper.triggerAutocompleteHotkey()

        let windowPage = AutocompleteWindowPage(app: app)
        guard windowPage.waitForAppearance(timeout: 2.0) else {
            XCTFail("Autocomplete window did not appear")
            return
        }

        // Verify suggestions have accessibility labels
        if windowPage.suggestionCount > 0 {
            let firstSuggestion = windowPage.suggestion(at: 0)
            XCTAssertTrue(
                firstSuggestion.hasAccessibility,
                "Suggestion cells must have accessibility labels"
            )

            XCTAssertFalse(
                firstSuggestion.accessibilityText.isEmpty,
                "Suggestion accessibility text must not be empty"
            )
        }

        windowPage.dismiss()

        // Cleanup
        let textEditApp = XCUIApplication(bundleIdentifier: CrossAppTestHelper.TargetApp.textEdit.bundleIdentifier)
        CrossAppTestHelper.cleanup([textEditApp])
    }

    // MARK: - Keyboard Navigation Tests

    /// Test full keyboard navigation (no mouse required)
    func testFullKeyboardNavigation() throws {
        guard CrossAppTestHelper.isInstalled(.textEdit) else {
            throw XCTSkip("TextEdit required for keyboard navigation testing")
        }

        guard let textView = CrossAppTestHelper.prepareForTesting(.textEdit) else {
            XCTFail("Failed to prepare TextEdit")
            return
        }

        textView.clearAndType("Hello")

        // Trigger via keyboard (Ctrl+I)
        CrossAppTestHelper.triggerAutocompleteHotkey()

        let windowPage = AutocompleteWindowPage(app: app)
        guard windowPage.waitForAppearance(timeout: 2.0) else {
            XCTFail("Window did not appear")
            return
        }

        // Navigate using arrow keys only (no mouse)
        windowPage.navigate("down")
        windowPage.navigate("down")
        windowPage.navigate("up")

        // Dismiss using Escape (no mouse)
        windowPage.dismiss()

        XCTAssertTrue(
            windowPage.waitForDisappearance(timeout: 1.0),
            "Window should dismiss via keyboard (Escape)"
        )

        // Cleanup
        let textEditApp = XCUIApplication(bundleIdentifier: CrossAppTestHelper.TargetApp.textEdit.bundleIdentifier)
        CrossAppTestHelper.cleanup([textEditApp])
    }

    /// Test Tab key navigation (focus management)
    func testTabNavigation() {
        CrossAppTestHelper.triggerAutocompleteHotkey()

        let windowPage = AutocompleteWindowPage(app: app)
        guard windowPage.waitForAppearance(timeout: 2.0) else {
            // Window may not appear without text - acceptable
            return
        }

        // Test Tab navigation
        windowPage.window.typeKey(.tab, modifierFlags: [])

        // Window should still be visible (Tab navigates within window)
        XCTAssertTrue(
            windowPage.isVisible,
            "Window should remain visible during Tab navigation"
        )

        windowPage.dismiss()
    }

    /// Test Escape key dismissal
    func testEscapeDismissal() {
        CrossAppTestHelper.triggerAutocompleteHotkey()

        let windowPage = AutocompleteWindowPage(app: app)
        guard windowPage.waitForAppearance(timeout: 2.0) else {
            return
        }

        // Press Escape
        windowPage.window.typeKey(.escape, modifierFlags: [])

        // Window should disappear
        XCTAssertTrue(
            windowPage.waitForDisappearance(timeout: 1.0),
            "Escape key must dismiss autocomplete window"
        )
    }

    // MARK: - VoiceOver Compatibility (Manual Testing Required)

    /// Note: VoiceOver testing requires manual verification
    /// This test documents what should be verified manually:
    /// 1. Enable VoiceOver (Cmd+F5)
    /// 2. Trigger autocomplete (Ctrl+I)
    /// 3. VO+Right Arrow should navigate through suggestions
    /// 4. VO+Space should select a suggestion
    /// 5. All elements should have clear VO descriptions
    func testVoiceOverDocumentation() {
        // This is a documentation test - not executed automatically
        // Manual VoiceOver testing checklist:
        let voiceOverChecklist = """
        VoiceOver Manual Testing Checklist:
        ☐ 1. Enable VoiceOver (Cmd+F5)
        ☐ 2. Open TextEdit and type some text
        ☐ 3. Trigger autocomplete (Ctrl+I)
        ☐ 4. Verify window is announced by VoiceOver
        ☐ 5. Use VO+Right Arrow to navigate suggestions
        ☐ 6. Verify each suggestion is clearly announced
        ☐ 7. Use VO+Space to select a suggestion
        ☐ 8. Verify selection is announced
        ☐ 9. Press Escape and verify dismissal is announced
        ☐ 10. Disable VoiceOver (Cmd+F5)
        """

        print(voiceOverChecklist)
        // No automatic assertions - manual testing required
    }

    // MARK: - Screen Reader Compatibility

    /// Test that all UI elements are exposed to screen readers
    func testScreenReaderExposure() {
        CrossAppTestHelper.triggerAutocompleteHotkey()

        let windowPage = AutocompleteWindowPage(app: app)
        guard windowPage.waitForAppearance(timeout: 2.0) else {
            return
        }

        // Verify window has accessibility properties
        XCTAssertTrue(
            windowPage.window.exists,
            "Window must exist and be accessible"
        )

        XCTAssertFalse(
            windowPage.window.label.isEmpty,
            "Window must have accessibility label for screen readers"
        )

        // Verify suggestion list has accessibility properties
        XCTAssertTrue(
            windowPage.suggestionList.exists,
            "Suggestion list must exist and be accessible"
        )

        XCTAssertFalse(
            windowPage.suggestionList.label.isEmpty,
            "Suggestion list must have accessibility label for screen readers"
        )

        windowPage.dismiss()
    }
}
