import Cocoa
import ApplicationServices

/// Manages macOS Accessibility API permissions and access
/// Based on research: claudedocs/macOS_Accessibility_API_Research_2024-2025.md
/// Text context extracted from focused element
struct TextContext {
    /// Full text content of the focused element
    let fullText: String

    /// Selected/highlighted text (if any)
    let selectedText: String?

    /// Text before cursor (for context analysis)
    let textBeforeCursor: String

    /// Text after cursor (for context analysis)
    let textAfterCursor: String

    /// Word at cursor position (for completion matching)
    let wordAtCursor: String

    /// Cursor position (character index)
    let cursorPosition: Int

    /// Selected text range
    let selectedRange: CFRange?
}

/// Facade for accessibility operations
/// Delegates to specialized managers for single responsibility
class AccessibilityManager {

    // MARK: - Specialized Managers

    private let alertManager: AccessibilityAlertManager
    private let permissionManager: AccessibilityPermissionManager
    private let elementExtractor: AccessibilityElementExtractor
    private let textInserter: AccessibilityTextInserter

    // MARK: - Initialization

    init() {
        // Initialize in dependency order
        self.alertManager = AccessibilityAlertManager()
        self.permissionManager = AccessibilityPermissionManager(alertManager: alertManager)
        self.elementExtractor = AccessibilityElementExtractor(permissionManager: permissionManager)
        self.textInserter = AccessibilityTextInserter(
            permissionManager: permissionManager,
            elementExtractor: elementExtractor
        )
    }

    // MARK: - Permission Status (delegate to PermissionManager)

    /// Check if accessibility permissions are granted
    /// - Returns: true if permissions granted, false otherwise
    func checkPermissionStatus() -> Bool {
        return permissionManager.checkPermissionStatus()
    }

    /// Check permission status with prompt option
    /// - Parameter showPrompt: If true, shows system permission dialog
    /// - Returns: true if permissions granted, false otherwise
    func checkPermissionStatus(showPrompt: Bool) -> Bool {
        return permissionManager.checkPermissionStatus(showPrompt: showPrompt)
    }

    // MARK: - Permission Request Flow (delegate to PermissionManager)

    /// Request accessibility permissions with user guidance
    /// Shows system dialog and provides instructions
    func requestPermissions() {
        permissionManager.requestPermissions()
    }

    /// Verify permissions and handle denied scenario
    /// - Returns: true if ready to use, false if permissions needed
    func verifyAndRequestIfNeeded() -> Bool {
        return permissionManager.verifyAndRequestIfNeeded()
    }

    // MARK: - User Guidance (delegate to AlertManager)

    /// Show alert when permissions are denied during operation
    func showPermissionDeniedAlert() {
        alertManager.showPermissionDeniedAlert()
    }

    // MARK: - Testing Helpers

    /// Test accessibility permissions with detailed output
    /// For development and debugging
    func testPermissions() {
        permissionManager.testPermissions()
    }

    // MARK: - Text Extraction (delegate to ElementExtractor)

    /// Extract text context from currently focused UI element
    /// Performance target: <50ms (typical 10-25ms per research)
    /// - Returns: Result with TextContext or AccessibilityError
    func extractTextContext() -> Result<TextContext, AccessibilityError> {
        return elementExtractor.extractTextContext()
    }

    // MARK: - Cursor Position Detection (delegate to ElementExtractor)

    /// Get cursor screen coordinates for window positioning
    /// - Parameter element: Optional AX element to use (if nil, will try to get focused element)
    /// - Returns: Result with CGPoint or AccessibilityError
    func getCursorScreenPosition(from element: AXUIElement? = nil) -> Result<CGPoint, AccessibilityError> {
        return elementExtractor.getCursorScreenPosition(from: element)
    }

    // MARK: - Text Insertion (delegate to TextInserter)

    /// Insert completion text at cursor position
    /// Replaces the word at cursor with the selected completion
    /// Performance target: <50ms (typical 20-40ms per research)
    /// - Parameters:
    ///   - completion: The completion text to insert
    ///   - context: Current text context (for smart replacement)
    /// - Returns: true if successful, false otherwise
    func insertCompletion(_ completion: String, replacing context: TextContext) -> Bool {
        return textInserter.insertCompletion(completion, replacing: context)
    }
}