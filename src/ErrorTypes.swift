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

// MARK: - Settings Errors

/// Errors related to user preferences and settings
enum SettingsError: Error, Equatable {
    /// Failed to read setting from UserDefaults
    case readFailed(key: String)

    /// Failed to write setting to UserDefaults
    case writeFailed(key: String)

    /// Setting value has invalid format
    case invalidFormat(key: String, expectedType: String)

    /// Setting validation failed
    case validationFailed(key: String, reason: String)
}

extension SettingsError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .readFailed(let key):
            return "Failed to read setting '\(key)'"
        case .writeFailed(let key):
            return "Failed to save setting '\(key)'"
        case .invalidFormat(let key, let type):
            return "Setting '\(key)' has invalid format (expected: \(type))"
        case .validationFailed(let key, let reason):
            return "Setting '\(key)' validation failed: \(reason)"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .readFailed:
            return "Settings will be reset to defaults"
        case .writeFailed:
            return "Check disk space and permissions"
        case .invalidFormat, .validationFailed:
            return "The setting will be reset to its default value"
        }
    }
}

// MARK: - Hotkey Errors

/// Errors related to global hotkey registration
enum HotkeyError: Error, Equatable {
    /// Failed to register global hotkey
    case registrationFailed(reason: String)

    /// Hotkey already in use by system or another app
    case alreadyInUse

    /// Invalid hotkey configuration
    case invalidConfiguration(reason: String)

    /// Failed to unregister hotkey
    case unregistrationFailed
}

extension HotkeyError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .registrationFailed(let reason):
            return "Failed to register hotkey: \(reason)"
        case .alreadyInUse:
            return "Hotkey is already in use"
        case .invalidConfiguration(let reason):
            return "Invalid hotkey configuration: \(reason)"
        case .unregistrationFailed:
            return "Failed to unregister hotkey"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .registrationFailed, .unregistrationFailed:
            return "Try restarting the application"
        case .alreadyInUse:
            return "Choose a different hotkey in Settings"
        case .invalidConfiguration:
            return "Reset hotkey to default in Settings"
        }
    }
}

// MARK: - Window Errors

/// Errors related to window management
enum WindowError: Error, Equatable {
    /// Failed to position window
    case positioningFailed(reason: String)

    /// Failed to show window
    case displayFailed(reason: String)

    /// Invalid window configuration
    case invalidConfiguration(reason: String)
}

extension WindowError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .positioningFailed(let reason):
            return "Failed to position window: \(reason)"
        case .displayFailed(let reason):
            return "Failed to display window: \(reason)"
        case .invalidConfiguration(let reason):
            return "Invalid window configuration: \(reason)"
        }
    }

    var recoverySuggestion: String? {
        return "Try triggering the completion again"
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
