import Cocoa
import ApplicationServices

/// Manages text insertion strategies via accessibility API and CGEvent simulation
/// Extracted from AccessibilityManager for single responsibility
class AccessibilityTextInserter {

    private let permissionManager: AccessibilityPermissionManager
    private let elementExtractor: AccessibilityElementExtractor

    init(permissionManager: AccessibilityPermissionManager, elementExtractor: AccessibilityElementExtractor) {
        self.permissionManager = permissionManager
        self.elementExtractor = elementExtractor
    }

    // MARK: - Text Insertion

    /// Insert completion text at cursor position
    /// Replaces the word at cursor with the selected completion
    /// Performance target: <50ms (typical 20-40ms per research)
    /// - Parameters:
    ///   - completion: The completion text to insert
    ///   - context: Current text context (for smart replacement)
    /// - Returns: true if successful, false otherwise
    func insertCompletion(_ completion: String, replacing context: TextContext) -> Bool {
        guard permissionManager.checkPermissionStatus() else {
            print("❌ Cannot insert text: Accessibility permissions not granted")
            return false
        }

        let systemWide = AXUIElementCreateSystemWide()

        // Try to get focused element (works for native apps)
        var focusedElement = elementExtractor.getFocusedElement(from: systemWide)

        // Fallback for web browsers: use element at cursor position
        if focusedElement == nil {
            print("⚠️  No focused element for insertion (likely web browser), trying element at cursor position...")

            // Get current cursor screen position
            if let cursorPosition = elementExtractor.getCursorScreenPosition() {
                focusedElement = elementExtractor.getElementAtPosition(cursorPosition)

                if focusedElement != nil {
                    print("✅ Found element at cursor position for insertion (web browser support)")
                } else {
                    print("❌ Failed to get element at cursor position for insertion")
                }
            }
        }

        guard let element = focusedElement else {
            print("❌ No focused element for text insertion")
            return false
        }

        print("📝 Inserting completion: '\(completion)' replacing '\(context.wordAtCursor)'")

        // Strategy 1: Try direct AX API replacement (fastest, ~10-20ms)
        if let success = tryDirectReplacement(completion, context: context, element: element), success {
            print("✅ Insertion successful via direct AX API")
            return true
        }

        // Strategy 2: Use CGEvent keystroke simulation (more reliable, ~20-40ms)
        if simulateKeystrokeInsertion(completion, context: context) {
            print("✅ Insertion successful via CGEvent simulation")
            return true
        }

        print("❌ Text insertion failed")
        return false
    }

    // MARK: - Direct AX API Methods

    /// Try direct text replacement via Accessibility API
    /// Fastest method but may not work in all apps
    private func tryDirectReplacement(_ completion: String, context: TextContext, element: AXUIElement) -> Bool? {
        // Calculate replacement range
        let wordLength = context.wordAtCursor.count
        guard wordLength > 0 else {
            // No word to replace, just insert
            return tryDirectInsertion(completion, at: context.cursorPosition, element: element)
        }

        // Get current text
        guard let currentText = elementExtractor.getFullText(from: element) else {
            return nil
        }

        // Defensive bounds checking to prevent crashes
        // Clamp cursor position to valid text range
        let validCursorPosition = min(context.cursorPosition, currentText.count)
        let validStartPosition = max(0, validCursorPosition - wordLength)

        // Log if we had to adjust positions (indicates potential timing/sync issues)
        if validCursorPosition != context.cursorPosition {
            print("⚠️  Cursor position adjusted: \(context.cursorPosition) → \(validCursorPosition) (text length: \(currentText.count))")
        }

        // Create new text with completion (using safe bounds)
        let beforeWord = String(currentText.prefix(validStartPosition))
        let afterCursor = String(currentText.suffix(max(0, currentText.count - validCursorPosition)))
        let newText = beforeWord + completion + afterCursor

        // Try to set new text
        let result = AXUIElementSetAttributeValue(
            element,
            kAXValueAttribute as CFString,
            newText as CFTypeRef
        )

        if result == .success {
            // Move cursor to end of inserted text
            let newCursorPosition = beforeWord.count + completion.count
            _ = setCursorPosition(newCursorPosition, element: element)
            return true
        }

        return nil
    }

    /// Try direct insertion at cursor position
    private func tryDirectInsertion(_ text: String, at position: Int, element: AXUIElement) -> Bool {
        guard let currentText = elementExtractor.getFullText(from: element) else {
            return false
        }

        // Defensive bounds checking to prevent crashes
        let validPosition = min(position, currentText.count)

        // Log if we had to adjust position
        if validPosition != position {
            print("⚠️  Insertion position adjusted: \(position) → \(validPosition) (text length: \(currentText.count))")
        }

        let beforeCursor = String(currentText.prefix(validPosition))
        let afterCursor = String(currentText.suffix(max(0, currentText.count - validPosition)))
        let newText = beforeCursor + text + afterCursor

        let result = AXUIElementSetAttributeValue(
            element,
            kAXValueAttribute as CFString,
            newText as CFTypeRef
        )

        if result == .success {
            _ = setCursorPosition(position + text.count, element: element)
            return true
        }

        return false
    }

    /// Set cursor position in element
    private func setCursorPosition(_ position: Int, element: AXUIElement) -> Bool {
        var range = CFRange(location: position, length: 0)
        guard let axValue = AXValueCreate(.cfRange, &range) else {
            return false
        }

        let result = AXUIElementSetAttributeValue(
            element,
            kAXSelectedTextRangeAttribute as CFString,
            axValue
        )

        return result == .success
    }

    // MARK: - CGEvent Simulation Methods

    /// Simulate keystroke insertion via CGEvent
    /// More reliable across different apps but slightly slower
    private func simulateKeystrokeInsertion(_ completion: String, context: TextContext) -> Bool {
        // First, delete the partial word if it exists
        if !context.wordAtCursor.isEmpty {
            // Delete characters (backspace)
            for _ in 0..<context.wordAtCursor.count {
                if !simulateKeyPress(keyCode: 51) { // Delete/Backspace
                    return false
                }
                // Small delay between keystrokes
                usleep(1000) // 1ms
            }
        }

        // Then type the completion text
        return typeText(completion)
    }

    /// Type text using CGEvent
    private func typeText(_ text: String) -> Bool {
        for char in text {
            guard let keyCode = characterToKeyCode(char) else {
                print("⚠️  No key code for character: '\(char)'")
                continue
            }

            if !simulateKeyPress(keyCode: keyCode, char: char) {
                return false
            }

            // Small delay between keystrokes for reliability
            usleep(1000) // 1ms
        }

        return true
    }

    /// Simulate a single key press
    private func simulateKeyPress(keyCode: CGKeyCode, char: Character? = nil) -> Bool {
        // Create key down event
        guard let keyDown = CGEvent(
            keyboardEventSource: nil,
            virtualKey: keyCode,
            keyDown: true
        ) else {
            return false
        }

        // If we have a character, set it
        if let char = char {
            let unicodeString = String(char)
            let unicodeChars = Array(unicodeString.utf16)
            keyDown.keyboardSetUnicodeString(stringLength: unicodeChars.count, unicodeString: unicodeChars)
        }

        // Create key up event
        guard let keyUp = CGEvent(
            keyboardEventSource: nil,
            virtualKey: keyCode,
            keyDown: false
        ) else {
            return false
        }

        // Post events
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)

        return true
    }

    /// Map character to macOS key code
    /// Basic implementation for common characters
    private func characterToKeyCode(_ char: Character) -> CGKeyCode? {
        // This is a simplified mapping
        // For production, would need complete keyboard layout handling
        let lowercaseChar = char.lowercased().first ?? char

        let keyMap: [Character: CGKeyCode] = [
            "a": 0, "b": 11, "c": 8, "d": 2, "e": 14, "f": 3, "g": 5,
            "h": 4, "i": 34, "j": 38, "k": 40, "l": 37, "m": 46,
            "n": 45, "o": 31, "p": 35, "q": 12, "r": 15, "s": 1,
            "t": 17, "u": 32, "v": 9, "w": 13, "x": 7, "y": 16, "z": 6,
            "0": 29, "1": 18, "2": 19, "3": 20, "4": 21, "5": 23,
            "6": 22, "7": 26, "8": 28, "9": 25,
            " ": 49, ".": 47, ",": 43, "-": 27, "\'": 39,
            "/": 44, ";": 41, "=": 24, "[": 33, "]": 30, "\\": 42
        ]

        return keyMap[lowercaseChar]
    }
}
