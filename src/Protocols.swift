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

// MARK: - Protocol Conformance

extension SettingsManager: SettingsManaging {}
extension CompletionEngine: CompletionProviding {}
extension AccessibilityManager: AccessibilityManaging {}
