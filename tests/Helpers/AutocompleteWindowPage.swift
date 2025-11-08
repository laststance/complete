// AutocompleteWindowPage.swift
// Page Object Model for CompletionWindow UI testing
// Provides clean interface for interacting with autocomplete window in tests

import XCTest

/// Page Object representing the autocomplete window
/// Encapsulates window element access and common interactions
class AutocompleteWindowPage {
    private let app: XCUIApplication

    // MARK: - Initialization

    init(app: XCUIApplication = XCUIApplication()) {
        self.app = app
    }

    // MARK: - Element Access

    /// Main autocomplete window element
    var window: XCUIElement {
        app.windows.matching(identifier: "CompletionWindow").firstMatch
    }

    /// Suggestion list table view
    var suggestionList: XCUIElement {
        window.tables.firstMatch
    }

    /// Get specific suggestion by index
    /// - Parameter index: Zero-based index of suggestion
    /// - Returns: XCUIElement for the suggestion cell
    func suggestion(at index: Int) -> XCUIElement {
        suggestionList.cells.element(boundBy: index)
    }

    /// Get suggestion by text content
    /// - Parameter text: Expected suggestion text
    /// - Returns: XCUIElement matching the text, or nil
    func suggestion(withText text: String) -> XCUIElement? {
        suggestionList.cells.containing(.staticText, identifier: text).firstMatch
    }

    /// Number of visible suggestions
    var suggestionCount: Int {
        suggestionList.cells.count
    }

    // MARK: - Actions

    /// Select suggestion at specific index
    /// - Parameter index: Zero-based index to select
    func selectSuggestion(at index: Int) {
        let cell = suggestion(at: index)
        if cell.exists {
            cell.click()
        }
    }

    /// Select suggestion by text
    /// - Parameter text: Suggestion text to select
    func selectSuggestion(withText text: String) {
        if let cell = suggestion(withText: text), cell.exists {
            cell.click()
        }
    }

    /// Navigate suggestions using arrow keys
    /// - Parameter direction: "up" or "down"
    func navigate(_ direction: String) {
        switch direction.lowercased() {
        case "up":
            window.typeKey(.upArrow, modifierFlags: [])
        case "down":
            window.typeKey(.downArrow, modifierFlags: [])
        default:
            break
        }
    }

    /// Dismiss autocomplete window
    func dismiss() {
        window.typeKey(.escape, modifierFlags: [])
    }

    // MARK: - Waiting & Verification

    /// Wait for autocomplete window to appear
    /// - Parameter timeout: Maximum wait time in seconds (default: 2.0)
    /// - Returns: true if window appeared within timeout
    @discardableResult
    func waitForAppearance(timeout: TimeInterval = 2.0) -> Bool {
        window.waitForExistence(timeout: timeout)
    }

    /// Wait for autocomplete window to disappear
    /// - Parameter timeout: Maximum wait time in seconds (default: 2.0)
    /// - Returns: true if window disappeared within timeout
    @discardableResult
    func waitForDisappearance(timeout: TimeInterval = 2.0) -> Bool {
        let predicate = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: window)
        let result = XCTWaiter().wait(for: [expectation], timeout: timeout)
        return result == .completed
    }

    /// Verify window is visible
    var isVisible: Bool {
        window.exists && window.isHittable
    }

    /// Verify window has suggestions
    var hasSuggestions: Bool {
        suggestionList.exists && suggestionCount > 0
    }

    // MARK: - Accessibility

    /// Verify accessibility labels are present
    var hasAccessibilityLabels: Bool {
        !window.label.isEmpty && !suggestionList.label.isEmpty
    }

    /// Get accessibility description for window
    var accessibilityDescription: String {
        window.value as? String ?? ""
    }
}
