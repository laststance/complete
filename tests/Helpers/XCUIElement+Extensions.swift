// XCUIElement+Extensions.swift
// Convenience extensions for XCUIElement in testing
// Provides cleaner syntax and common testing patterns

import XCTest

extension XCUIElement {

    // MARK: - Waiting Extensions

    /// Wait for element to become hittable (visible and clickable)
    /// - Parameter timeout: Maximum wait time in seconds
    /// - Returns: true if element became hittable within timeout
    @discardableResult
    func waitForHittable(timeout: TimeInterval = 5.0) -> Bool {
        let predicate = NSPredicate(format: "isHittable == true")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: self)
        let result = XCTWaiter().wait(for: [expectation], timeout: timeout)
        return result == .completed
    }

    /// Wait for element to have specific value
    /// - Parameters:
    ///   - value: Expected value
    ///   - timeout: Maximum wait time in seconds
    /// - Returns: true if value matched within timeout
    @discardableResult
    func waitForValue(_ value: String, timeout: TimeInterval = 5.0) -> Bool {
        let predicate = NSPredicate(format: "value == %@", value)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: self)
        let result = XCTWaiter().wait(for: [expectation], timeout: timeout)
        return result == .completed
    }

    /// Wait for element to disappear
    /// - Parameter timeout: Maximum wait time in seconds
    /// - Returns: true if element disappeared within timeout
    @discardableResult
    func waitForDisappearance(timeout: TimeInterval = 5.0) -> Bool {
        let predicate = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: self)
        let result = XCTWaiter().wait(for: [expectation], timeout: timeout)
        return result == .completed
    }

    // MARK: - Text Interaction

    /// Clear text from element and type new text
    /// - Parameter text: New text to type
    func clearAndType(_ text: String) {
        // Select all existing text
        click()
        typeKey("a", modifierFlags: .command)

        // Type new text (replaces selection)
        typeText(text)
    }

    /// Type text and press Return
    /// - Parameter text: Text to type
    func typeTextAndReturn(_ text: String) {
        typeText(text)
        typeText("\n")
    }

    // MARK: - Verification Helpers

    /// Check if element contains specific text
    /// - Parameter text: Text to search for
    /// - Returns: true if element label or value contains text
    func contains(_ text: String) -> Bool {
        let labelMatches = (label as NSString).contains(text)
        let valueMatches = (value as? String as NSString?)?.contains(text) ?? false
        return labelMatches || valueMatches
    }

    /// Check if element is fully visible (exists and hittable)
    var isFullyVisible: Bool {
        exists && isHittable
    }

    // MARK: - Accessibility Helpers

    /// Get accessibility description (label or value)
    var accessibilityText: String {
        if !label.isEmpty {
            return label
        }
        return value as? String ?? ""
    }

    /// Check if element has proper accessibility labels
    var hasAccessibility: Bool {
        !label.isEmpty || value != nil
    }
}

extension XCUIElementQuery {

    // MARK: - Query Helpers

    /// Get first element that contains specific text
    /// - Parameter text: Text to search for
    /// - Returns: First matching element, or nil
    func firstContaining(_ text: String) -> XCUIElement? {
        for i in 0..<count {
            let element = element(boundBy: i)
            if element.contains(text) {
                return element
            }
        }
        return nil
    }

    /// Get all elements that contain specific text
    /// - Parameter text: Text to search for
    /// - Returns: Array of matching elements
    func allContaining(_ text: String) -> [XCUIElement] {
        var results: [XCUIElement] = []
        for i in 0..<count {
            let element = element(boundBy: i)
            if element.contains(text) {
                results.append(element)
            }
        }
        return results
    }
}
