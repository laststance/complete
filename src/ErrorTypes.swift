import Foundation

// MARK: - Accessibility Errors

/// Errors related to macOS Accessibility API operations
enum AccessibilityError: Error, Equatable {
    /// Accessibility permissions not granted
    case permissionDenied

    /// No focused UI element found
    case noFocusedElement

    /// Failed to get element at cursor position
    case elementNotFoundAtPosition(x: Double, y: Double)

    /// Failed to extract text from element
    case textExtractionFailed(reason: String)

    /// Failed to get cursor position
    case cursorPositionUnavailable

    /// AXUIElement API call failed
    case axApiFailed(attribute: String, code: Int32)

    /// Text insertion failed
    case insertionFailed(reason: String)

    /// Invalid text context
    case invalidTextContext
}

extension AccessibilityError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Accessibility permissions not granted"
        case .noFocusedElement:
            return "No focused text element found"
        case .elementNotFoundAtPosition(let x, let y):
            return "No element found at position (\(x), \(y))"
        case .textExtractionFailed(let reason):
            return "Failed to extract text: \(reason)"
        case .cursorPositionUnavailable:
            return "Could not determine cursor position"
        case .axApiFailed(let attribute, let code):
            return "Accessibility API failed for '\(attribute)' (code: \(code))"
        case .insertionFailed(let reason):
            return "Text insertion failed: \(reason)"
        case .invalidTextContext:
            return "Text context is invalid or incomplete"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .permissionDenied:
            return "Grant accessibility permissions in System Settings → Privacy & Security → Accessibility"
        case .noFocusedElement:
            return "Click in a text field and try again"
        case .elementNotFoundAtPosition:
            return "Try clicking in the text field again"
        case .textExtractionFailed:
            return "This application may not support text extraction"
        case .cursorPositionUnavailable:
            return "Try moving your cursor and press the hotkey again"
        case .axApiFailed:
            return "The application may not support this operation"
        case .insertionFailed:
            return "This application may not support text insertion"
        case .invalidTextContext:
            return "Try extracting text context again"
        }
    }
}

// MARK: - Completion Errors

/// Errors related to text completion generation
enum CompletionError: Error, Equatable {
    /// Input text is empty or invalid
    case emptyInput

    /// Word at cursor is empty (nothing to complete)
    case noWordAtCursor

    /// No completions found for the given input
    case noCompletionsFound(for: String)

    /// Completion engine initialization failed
    case engineInitializationFailed

    /// Dictionary/language resource unavailable
    case dictionaryUnavailable
}

extension CompletionError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .emptyInput:
            return "No text to complete"
        case .noWordAtCursor:
            return "No word at cursor position"
        case .noCompletionsFound(let word):
            return "No completions found for '\(word)'"
        case .engineInitializationFailed:
            return "Completion engine failed to initialize"
        case .dictionaryUnavailable:
            return "System dictionary unavailable"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .emptyInput, .noWordAtCursor:
            return "Type at least one character and try again"
        case .noCompletionsFound:
            return "The word may be complete or not in the dictionary"
        case .engineInitializationFailed, .dictionaryUnavailable:
            return "Restart the application"
        }
    }
}

// MARK: - Error Helper Extensions

extension Error {
    /// Get user-friendly error message
    var userFriendlyMessage: String {
        if let localizedError = self as? LocalizedError {
            return localizedError.errorDescription ?? "An unknown error occurred"
        }
        return localizedDescription
    }

    /// Get recovery suggestion if available
    var recoverySuggestionMessage: String? {
        return (self as? LocalizedError)?.recoverySuggestion
    }
}
