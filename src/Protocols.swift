import Foundation
import AppKit

// MARK: - Manager Protocols

/// Protocol for settings management (UserDefaults persistence)
protocol SettingsManaging: AnyObject {
    var launchAtLogin: Bool { get set }
    func resetToDefaults()
    func restoreSettings()
}

/// Protocol for completion generation
protocol CompletionProviding: AnyObject {
    func completions(for partialWord: String, language: String?) -> [String]
    func completionsAsync(for partialWord: String, language: String?) async -> [String]
    func clearCache()
}

/// Protocol for accessibility operations
protocol AccessibilityManaging: AnyObject {
    func extractTextContext() -> Result<TextContext, AccessibilityError>
    func getCursorScreenPosition(from element: AXUIElement?) -> Result<CGPoint, AccessibilityError>
    func insertCompletion(_ completion: String, replacing context: TextContext) -> Bool
    func checkPermissionStatus() -> Bool
    func requestPermissions()
    func showPermissionDeniedAlert()
    func testPermissions()
    func verifyAndRequestIfNeeded() -> Bool
}

// MARK: - Accessibility Sub-Component Protocols

/// Protocol for permission checking operations
/// Enables mocking for unit tests
protocol AccessibilityPermissionChecking: AnyObject {
    /// Check if accessibility permissions are currently granted
    func checkPermissionStatus() -> Bool
    /// Check permissions with optional prompt
    func checkPermissionStatus(showPrompt: Bool) -> Bool
    /// Request accessibility permissions from user
    func requestPermissions()
    /// Verify permissions and request if needed
    func verifyAndRequestIfNeeded() -> Bool
    /// Test detailed permission status
    func testPermissions()
}

/// Protocol for permission alert presentation
/// Enables mocking alert UI in tests
protocol AccessibilityAlertPresenting: AnyObject {
    /// Show alert when accessibility permissions are denied
    func showPermissionDeniedAlert()
    /// Show alert when permissions are granted
    func showPermissionGrantedAlert()
    /// Show guidance alert for enabling permissions
    func showPermissionGuidanceAlert()
}

/// Protocol for text extraction from UI elements
/// Enables mocking text extraction in tests
protocol AccessibilityElementExtracting: AnyObject {
    /// Get the currently focused UI element
    /// - Parameter systemWide: The system-wide accessibility element
    func getFocusedElement(from systemWide: AXUIElement) -> AXUIElement?
    /// Get full text content from a UI element
    func getFullText(from element: AXUIElement) -> String?
    /// Get selected text from a UI element
    func getSelectedText(from element: AXUIElement) -> String?
    /// Get selected text range from a UI element
    func getSelectedTextRange(from element: AXUIElement) -> CFRange?
    /// Get attribute value from a UI element
    func getAttributeValue(_ element: AXUIElement, attribute: CFString) -> AnyObject?
    /// Get UI element at screen position with fuzzy matching
    func getElementAtPosition(_ point: CGPoint) -> AXUIElement?
}

/// Protocol for text insertion into UI elements
/// Enables mocking text insertion in tests
protocol AccessibilityTextInserting: AnyObject {
    /// Insert completion text, replacing partial word based on context
    ///
    /// - Parameters:
    ///   - completion: The full completion text to insert
    ///   - context: The text context containing word and cursor position
    /// - Returns: true if insertion succeeded
    func insertCompletion(_ completion: String, replacing context: TextContext) -> Bool
}

// MARK: - Protocol Conformance

extension SettingsManager: SettingsManaging {}
extension CompletionEngine: CompletionProviding {}
extension AccessibilityManager: AccessibilityManaging {}
extension AccessibilityPermissionManager: AccessibilityPermissionChecking {}
extension AccessibilityAlertManager: AccessibilityAlertPresenting {}
extension AccessibilityElementExtractor: AccessibilityElementExtracting {}
extension AccessibilityTextInserter: AccessibilityTextInserting {}
