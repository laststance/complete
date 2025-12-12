import Cocoa
import os.log

/// Utility class for clipboard operations with save/restore capability
///
/// Provides a clean interface for clipboard operations while preserving
/// the original clipboard content. Used by both text extraction and insertion.
///
/// ## Usage
/// ```swift
/// ClipboardUtility.performWithSavedClipboard {
///     // Your clipboard operations here
///     pasteboard.setString("text", forType: .string)
///     return pasteboard.string(forType: .string)
/// }
/// // Original clipboard content is restored
/// ```
final class ClipboardUtility {

    // MARK: - Constants

    /// Default delay for clipboard operations (microseconds)
    static let defaultClipboardDelay: UInt32 = 10_000  // 10ms

    /// Extended delay for reading clipboard after external app operations
    static let extendedClipboardDelay: UInt32 = 50_000  // 50ms

    // MARK: - Clipboard Operations

    /// Perform an operation with the clipboard, automatically saving and restoring content
    ///
    /// - Parameter operation: Closure that performs clipboard operations
    /// - Returns: Result of the operation
    @discardableResult
    static func performWithSavedClipboard<T>(_ operation: () -> T) -> T {
        let pasteboard = NSPasteboard.general

        // Save current clipboard content
        let savedContent = saveClipboardContent(pasteboard)

        // Perform the operation
        let result = operation()

        // Restore original clipboard content
        restoreClipboardContent(savedContent, to: pasteboard)

        return result
    }

    /// Perform an async operation with the clipboard, automatically saving and restoring content
    ///
    /// - Parameter operation: Async closure that performs clipboard operations
    /// - Returns: Result of the operation
    @discardableResult
    static func performWithSavedClipboardAsync<T>(_ operation: () async -> T) async -> T {
        let pasteboard = NSPasteboard.general

        // Save current clipboard content
        let savedContent = saveClipboardContent(pasteboard)

        // Perform the operation
        let result = await operation()

        // Restore original clipboard content
        restoreClipboardContent(savedContent, to: pasteboard)

        return result
    }

    // MARK: - Helper Methods

    /// Save all clipboard content
    ///
    /// - Parameter pasteboard: The pasteboard to save from
    /// - Returns: Dictionary of saved content by type
    static func saveClipboardContent(_ pasteboard: NSPasteboard = .general) -> [NSPasteboard.PasteboardType: Data] {
        let savedTypes = pasteboard.types ?? []
        var savedContents: [NSPasteboard.PasteboardType: Data] = [:]

        for type in savedTypes {
            if let data = pasteboard.data(forType: type) {
                savedContents[type] = data
            }
        }

        os_log("📋 Saved %d clipboard types", log: .accessibility, type: .debug, savedContents.count)
        return savedContents
    }

    /// Restore clipboard content from saved data
    ///
    /// - Parameters:
    ///   - content: Previously saved clipboard content
    ///   - pasteboard: The pasteboard to restore to
    static func restoreClipboardContent(
        _ content: [NSPasteboard.PasteboardType: Data],
        to pasteboard: NSPasteboard = .general
    ) {
        pasteboard.clearContents()

        for (type, data) in content {
            if !data.isEmpty {
                pasteboard.setData(data, forType: type)
            }
        }

        os_log("📋 Restored %d clipboard types", log: .accessibility, type: .debug, content.count)
    }

    /// Set string content to clipboard
    ///
    /// - Parameters:
    ///   - string: String to set
    ///   - pasteboard: The pasteboard to use (defaults to general)
    static func setString(_ string: String, to pasteboard: NSPasteboard = .general) {
        pasteboard.clearContents()
        pasteboard.setString(string, forType: .string)
    }

    /// Get string content from clipboard
    ///
    /// - Parameter pasteboard: The pasteboard to read from (defaults to general)
    /// - Returns: String content or nil if not available
    static func getString(from pasteboard: NSPasteboard = .general) -> String? {
        return pasteboard.string(forType: .string)
    }

    /// Clear the clipboard
    ///
    /// - Parameter pasteboard: The pasteboard to clear (defaults to general)
    static func clear(_ pasteboard: NSPasteboard = .general) {
        pasteboard.clearContents()
    }

    /// Wait for clipboard to be ready
    ///
    /// - Parameter microseconds: Delay in microseconds (default: 10ms)
    static func waitForClipboard(microseconds: UInt32 = defaultClipboardDelay) {
        usleep(microseconds)
    }
}
