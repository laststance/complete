// CrossAppTestHelper.swift
// Utilities for cross-application integration testing
// Handles launching apps, finding text inputs, and simulating hotkeys

import XCTest
import CoreGraphics

/// Helper for testing autocomplete across different applications
class CrossAppTestHelper {

    // MARK: - Target Applications

    /// Supported applications for integration testing
    enum TargetApp: String, CaseIterable {
        case textEdit = "TextEdit"
        case mail = "Mail"
        case safari = "Safari"
        case chrome = "Chrome"
        case vsCode = "VS Code"

        /// Bundle identifier for the application
        var bundleIdentifier: String {
            switch self {
            case .textEdit: return "com.apple.TextEdit"
            case .mail: return "com.apple.mail"
            case .safari: return "com.apple.Safari"
            case .chrome: return "com.google.Chrome"
            case .vsCode: return "com.microsoft.VSCode"
            }
        }

        /// Accessibility support level (for test planning)
        var accessibilitySupport: String {
            switch self {
            case .textEdit, .mail: return "⭐⭐⭐⭐⭐ Excellent"
            case .safari, .vsCode: return "⭐⭐⭐⭐ Good"
            case .chrome: return "⭐⭐⭐ Moderate"
            }
        }

        /// Expected test complexity
        var complexity: String {
            switch self {
            case .textEdit, .mail: return "Low"
            case .vsCode: return "Low-Medium"
            case .safari, .chrome: return "Medium"
            }
        }
    }

    // MARK: - App Launching

    /// Launch target application for testing
    /// - Parameter app: Target application to launch
    /// - Returns: XCUIApplication instance
    static func launch(_ app: TargetApp) -> XCUIApplication {
        let application = XCUIApplication(bundleIdentifier: app.bundleIdentifier)
        application.launch()
        return application
    }

    /// Terminate target application
    /// - Parameter app: XCUIApplication instance to terminate
    static func terminate(_ app: XCUIApplication) {
        if app.state == .runningForeground || app.state == .runningBackground {
            app.terminate()
        }
    }

    // MARK: - Text Input Detection

    /// Find text input element in application using multiple strategies
    /// - Parameter app: XCUIApplication to search in
    /// - Returns: First found text input element, or nil
    static func findTextInput(in app: XCUIApplication) -> XCUIElement? {
        // Strategy 1: Text fields (single-line inputs)
        let textField = app.textFields.firstMatch
        if textField.exists {
            return textField
        }

        // Strategy 2: Text views (multi-line inputs)
        let textView = app.textViews.firstMatch
        if textView.exists {
            return textView
        }

        // Strategy 3: Search for editable elements via accessibility
        let editableElements = app.descendants(matching: .any).matching(
            NSPredicate(format: "isEnabled == true")
        )
        for i in 0..<editableElements.count {
            let element = editableElements.element(boundBy: i)
            if element.elementType == .textField || element.elementType == .textView {
                return element
            }
        }

        return nil
    }

    /// Find text input with specific identifier
    /// - Parameters:
    ///   - app: XCUIApplication to search in
    ///   - identifier: Accessibility identifier
    /// - Returns: Matching text input element, or nil
    static func findTextInput(in app: XCUIApplication, identifier: String) -> XCUIElement? {
        let textField = app.textFields[identifier]
        if textField.exists {
            return textField
        }

        let textView = app.textViews[identifier]
        if textView.exists {
            return textView
        }

        return nil
    }

    // MARK: - Hotkey Simulation

    /// Trigger autocomplete hotkey using CGEvent
    /// Note: Simulates Ctrl+I (default autocomplete trigger)
    static func triggerAutocompleteHotkey() {
        // Ctrl+I = Control + I key
        // Virtual key code for 'I' is 0x22
        let keyCode: CGKeyCode = 0x22

        // Key down with Control modifier
        if let eventDown = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true) {
            eventDown.flags = .maskControl
            eventDown.post(tap: .cghidEventTap)
        }

        // Small delay to simulate realistic key press
        usleep(50_000) // 50ms

        // Key up
        if let eventUp = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false) {
            eventUp.post(tap: .cghidEventTap)
        }
    }

    /// Trigger custom hotkey combination
    /// - Parameters:
    ///   - keyCode: Virtual key code
    ///   - modifiers: CGEventFlags for modifiers (e.g., .maskCommand)
    static func triggerHotkey(keyCode: CGKeyCode, modifiers: CGEventFlags) {
        if let eventDown = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true) {
            eventDown.flags = modifiers
            eventDown.post(tap: .cghidEventTap)
        }

        usleep(50_000)

        if let eventUp = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false) {
            eventUp.post(tap: .cghidEventTap)
        }
    }

    // MARK: - Test Preparation

    /// Prepare application for testing
    /// - Parameter app: Target application
    /// - Returns: Ready text input element, or nil if preparation failed
    @discardableResult
    static func prepareForTesting(_ app: TargetApp) -> XCUIElement? {
        let application = launch(app)

        // Wait for app to be ready
        sleep(1)

        // Find and focus text input
        guard let textInput = findTextInput(in: application) else {
            return nil
        }

        // Click to focus
        textInput.click()

        return textInput
    }

    // MARK: - Verification Helpers

    /// Verify application is installed
    /// - Parameter app: Target application
    /// - Returns: true if app exists on system
    static func isInstalled(_ app: TargetApp) -> Bool {
        let application = XCUIApplication(bundleIdentifier: app.bundleIdentifier)
        return application.exists
    }

    /// Get application state
    /// - Parameter app: XCUIApplication instance
    /// - Returns: Human-readable state description
    static func stateDescription(for app: XCUIApplication) -> String {
        switch app.state {
        case .unknown: return "Unknown"
        case .notRunning: return "Not Running"
        case .runningBackground: return "Running (Background)"
        case .runningForeground: return "Running (Foreground)"
        @unknown default: return "Unknown State"
        }
    }

    // MARK: - Cleanup

    /// Clean up after testing
    /// - Parameter apps: Applications to terminate
    static func cleanup(_ apps: [XCUIApplication]) {
        apps.forEach { terminate($0) }
    }
}
