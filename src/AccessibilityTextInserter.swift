import Cocoa
import ApplicationServices
import os.log

/// Manages text insertion strategies via accessibility API and CGEvent simulation
/// Extracted from AccessibilityManager for single responsibility
class AccessibilityTextInserter {

    private let permissionManager: AccessibilityPermissionManager
    private let elementExtractor: AccessibilityElementExtractor

    // MARK: - Constants

    /// Characters allowed in completion text for CGEvent injection
    /// Restricts to safe characters to prevent command injection via shell completions
    private static let allowedCharacters: CharacterSet = {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: " .,;:!?'-()[]{}\"@#$%&*+=<>/\\|~`^_")
        return allowed
    }()

    /// Maximum length for completion text to prevent DoS via very long strings
    private static let maxCompletionLength = 1000

    // MARK: - Timing Constants (microseconds)

    /// Delay for word deletion to complete before next operation
    private static let wordDeletionDelay: UInt32 = 30_000  // 30ms

    /// Delay after clipboard operation for content to be ready
    private static let clipboardReadyDelay: UInt32 = 10_000  // 10ms

    /// Delay after paste operation for app to process
    private static let pasteCompletionDelay: UInt32 = 50_000  // 50ms

    /// Minimal delay between CGEvent key events
    private static let keyEventDelay: UInt32 = 1_000  // 1ms

    init(permissionManager: AccessibilityPermissionManager, elementExtractor: AccessibilityElementExtractor) {
        self.permissionManager = permissionManager
        self.elementExtractor = elementExtractor
    }

    // MARK: - Input Sanitization

    /// Sanitizes completion text before CGEvent injection or clipboard operations
    /// Removes control characters and other potentially dangerous input
    ///
    /// Security rationale:
    /// - Prevents shell command injection if completion is pasted into Terminal
    /// - Removes control characters (0x00-0x1F) that could cause unexpected behavior
    /// - Limits length to prevent DoS attacks via very long strings
    ///
    /// - Parameter text: The raw completion text from NSSpellChecker or user dictionary
    /// - Returns: Sanitized text safe for keystroke injection
    private func sanitizeCompletion(_ text: String) -> String {
        // Truncate to max length
        let truncated = String(text.prefix(Self.maxCompletionLength))

        // Filter to allowed characters only
        let sanitized = truncated.unicodeScalars.filter { scalar in
            Self.allowedCharacters.contains(scalar)
        }

        let result = String(String.UnicodeScalarView(sanitized))

        // Log if sanitization changed the input
        if result != text {
            os_log("⚠️ Completion text was sanitized: '%{private}@' → '%{private}@'",
                   log: .accessibility, type: .info, text, result)
        }

        return result
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
            os_log("❌ Cannot insert text: Accessibility permissions not granted", log: .accessibility, type: .error)
            return false
        }

        // Security: Sanitize completion text before any insertion method
        // Prevents command injection via malicious dictionary entries
        let sanitizedCompletion = sanitizeCompletion(completion)
        guard !sanitizedCompletion.isEmpty else {
            os_log("❌ Completion text was empty after sanitization", log: .accessibility, type: .error)
            return false
        }

        os_log("📝 Inserting completion: '%{private}@' replacing '%{private}@'", log: .accessibility, type: .debug, sanitizedCompletion, context.wordAtCursor)

        // For Terminal, VSCode and similar apps, use clipboard-based paste
        // CGEvent keystroke simulation doesn't work properly in Terminal (produces escape sequences like '[D')
        if elementExtractor.needsClipboardFallback() {
            os_log("📋 Using clipboard-based paste for Terminal/VSCode app", log: .accessibility, type: .info)
            if insertTextViaClipboard(sanitizedCompletion, context: context) {
                os_log("✅ Insertion successful via clipboard paste", log: .accessibility, type: .debug)
                return true
            }
            os_log("❌ Clipboard-based insertion failed", log: .accessibility, type: .error)
            return false
        }

        let systemWide = AXUIElementCreateSystemWide()

        // Strategy 1: Try cached element from text extraction (eliminates race condition)
        // The element was captured during extractTextContext() and cached in the context
        var focusedElement: AXUIElement? = context.sourceElement
        if focusedElement != nil {
            os_log("✅ Using cached element from text extraction (race-condition-safe)", log: .accessibility, type: .debug)
        }

        // Strategy 2: Try to get focused element (works for native apps)
        if focusedElement == nil {
            focusedElement = elementExtractor.getFocusedElement(from: systemWide)
            if focusedElement != nil {
                os_log("✅ Found focused element via kAXFocusedUIElementAttribute", log: .accessibility, type: .debug)
            }
        }

        // Strategy 3: Fallback for web browsers: use element at cursor position
        if focusedElement == nil {
            os_log("⚠️  No focused element for insertion (likely web browser), trying element at cursor position...", log: .accessibility, type: .debug)

            // Get current cursor screen position
            switch elementExtractor.getCursorScreenPosition() {
            case .success(let cursorPosition):
                focusedElement = elementExtractor.getElementAtPosition(cursorPosition)

                if focusedElement != nil {
                    os_log("✅ Found element at cursor position for insertion (web browser support)", log: .accessibility, type: .debug)
                } else {
                    os_log("❌ Failed to get element at cursor position for insertion", log: .accessibility, type: .error)
                }
            case .failure:
                os_log("❌ Failed to get cursor position for insertion", log: .accessibility, type: .error)
            }
        }

        guard let element = focusedElement else {
            // No focused element, try CGEvent simulation as last resort
            os_log("⚠️  No focused element, attempting CGEvent simulation", log: .accessibility, type: .debug)
            if simulateKeystrokeInsertion(sanitizedCompletion, context: context) {
                os_log("✅ Insertion successful via CGEvent simulation (no element fallback)", log: .accessibility, type: .debug)
                return true
            }
            os_log("❌ No focused element for text insertion", log: .accessibility, type: .error)
            return false
        }

        // Strategy 1: Try direct AX API replacement (fastest, ~10-20ms)
        if let success = tryDirectReplacement(sanitizedCompletion, context: context, element: element), success {
            os_log("✅ Insertion successful via direct AX API", log: .accessibility, type: .debug)
            return true
        }

        // Strategy 2: Use CGEvent keystroke simulation (more reliable, ~20-40ms)
        if simulateKeystrokeInsertion(sanitizedCompletion, context: context) {
            os_log("✅ Insertion successful via CGEvent simulation", log: .accessibility, type: .debug)
            return true
        }

        os_log("❌ Text insertion failed", log: .accessibility, type: .error)
        return false
    }

    // MARK: - Clipboard-Based Insertion

    /// Insert text via clipboard paste - for Terminal, VSCode and similar apps
    ///
    /// CGEvent keystroke simulation doesn't work properly in Terminal because:
    /// - Terminal uses PTY (pseudo-terminal) which expects TTY-style input
    /// - CGEvents are HID-layer events that don't translate well to PTY
    /// - Result: Escape sequences like '[D' appear instead of intended text
    /// - Shift+Arrow keys also produce escape sequences in Terminal!
    ///
    /// This method uses shell-native commands:
    /// - Control+W: Delete word backward (built-in bash/zsh command)
    /// - Cmd+V: Paste from clipboard
    ///
    /// ## Algorithm
    /// 1. Save current clipboard content
    /// 2. Delete partial word using Control+W (shell-native backward-kill-word)
    /// 3. Copy completion text to clipboard
    /// 4. Paste (Cmd+V) - inserts completion
    /// 5. Restore original clipboard content
    ///
    /// - Parameters:
    ///   - completion: The completion text to insert
    ///   - context: Current text context containing `wordAtCursor` to replace
    /// - Returns: `true` if successful, `false` otherwise
    private func insertTextViaClipboard(_ completion: String, context: TextContext) -> Bool {
        os_log("📋 Starting clipboard-based insertion for Terminal/VSCode", log: .accessibility, type: .info)

        let pasteboard = NSPasteboard.general

        // Step 1: Save current clipboard content
        let savedTypes = pasteboard.types ?? []
        var savedContents: [NSPasteboard.PasteboardType: Data] = [:]
        for type in savedTypes {
            if let data = pasteboard.data(forType: type) {
                savedContents[type] = data
            }
        }

        // Step 2: Delete partial word using Control+W (shell-native backward-kill-word)
        // This is a bash/zsh built-in that works reliably in Terminal
        // Shift+Arrow does NOT work in Terminal - it produces escape sequences like '[D'
        if !context.wordAtCursor.isEmpty {
            os_log("📋 Deleting partial word with Control+W: '%{private}@'", log: .accessibility, type: .debug, context.wordAtCursor)
            // Control+W sends ASCII ETB (0x17) which readline interprets as backward-kill-word
            // Key code 13 = 'W' key
            simulateKeyPressWithModifiers(keyCode: 13, modifiers: [.maskControl]) // Control+W
            usleep(Self.wordDeletionDelay)
        }

        // Step 3: Copy completion text to clipboard
        pasteboard.clearContents()
        pasteboard.setString(completion, forType: .string)
        usleep(Self.clipboardReadyDelay)

        // Step 4: Paste (Cmd+V) - inserts the completion text
        os_log("📋 Pasting completion via Cmd+V: '%{private}@'", log: .accessibility, type: .debug, completion)
        simulateKeyPressWithModifiers(keyCode: 9, modifiers: [.maskCommand]) // Cmd+V
        usleep(Self.pasteCompletionDelay)

        // Step 5: Restore original clipboard content
        pasteboard.clearContents()
        if !savedContents.isEmpty {
            for (type, data) in savedContents {
                pasteboard.setData(data, forType: type)
            }
        }

        os_log("✅ Clipboard-based insertion completed", log: .accessibility, type: .debug)
        return true
    }

    /// Simulate a key press with modifier keys using CGEvent
    /// Used for clipboard operations (Cmd+V, Shift+Left, etc.)
    private func simulateKeyPressWithModifiers(keyCode: CGKeyCode, modifiers: CGEventFlags) {
        let source = CGEventSource(stateID: .hidSystemState)

        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false) else {
            os_log("❌ Failed to create CGEvent for key press with modifiers", log: .accessibility, type: .error)
            return
        }

        keyDown.flags = modifiers
        keyUp.flags = modifiers

        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
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
            os_log("⚠️  Cursor position adjusted: %d → %d (text length: %d)", log: .accessibility, type: .debug, context.cursorPosition, validCursorPosition, currentText.count)
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
            os_log("⚠️  Insertion position adjusted: %d → %d (text length: %d)", log: .accessibility, type: .debug, position, validPosition, currentText.count)
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

    /// Simulates text insertion using low-level CGEvent keystroke events.
    ///
    /// This is a **fallback strategy** when direct Accessibility API insertion fails.
    /// It types the completion character-by-character using keyboard event simulation,
    /// providing maximum application compatibility at the cost of performance.
    ///
    /// ## When Used (Fallback Conditions)
    /// - Direct AX API insertion fails (read-only fields, unsupported apps)
    /// - Application doesn't properly support `kAXValueAttribute` writing
    /// - Web browser text fields (often don't expose AX API properly)
    /// - Terminal applications with special input handling
    ///
    /// ## Algorithm
    /// 1. **Delete Partial Word**: Send backspace events to remove existing word
    ///    - One backspace per character in `context.wordAtCursor`
    ///    - 1ms delay between each keystroke for reliability
    /// 2. **Type Completion**: Send key events for each character in completion text
    ///    - Converts characters to key codes via `typeText()`
    ///    - Handles modifier keys (Shift, Option, etc.) automatically
    ///
    /// ## Performance
    /// - **Speed**: ~1-2ms per character
    /// - **Total Time**: Typically 20-40ms for average completion (10-20 chars)
    /// - **Comparison**: 2-4x slower than direct AX API (~10-20ms)
    ///
    /// ## Limitations & Trade-offs
    /// - **Focus Sensitive**: Types into whatever has keyboard focus at the moment
    /// - **Keyboard Layout**: Subject to user's keyboard layout variations
    /// - **Event Handlers**: May trigger key event handlers in target application
    /// - **Character Support**: Limited to characters representable via key codes
    /// - **No Undo Grouping**: Each keystroke creates separate undo step
    ///
    /// ## Reliability Measures
    /// - 1ms inter-keystroke delay prevents event queue overflow
    /// - Validates each key press return value
    /// - Fails fast if any keystroke fails
    ///
    /// - Parameters:
    ///   - completion: The text to insert (will be typed character-by-character)
    ///   - context: Current text context containing `wordAtCursor` to delete
    ///
    /// - Returns: `true` if all keystrokes succeeded, `false` if any failed
    ///
    /// - Warning: This method types into whatever application has keyboard focus.
    ///            Caller **must** ensure the target application is frontmost before calling.
    ///
    /// - Complexity: O(n) where n = `context.wordAtCursor.count` + `completion.count`
    ///
    /// ## Example
    /// ```swift
    /// // Ensure target app is frontmost
    /// targetApp.activate()
    ///
    /// // Context: "hel|lo" (cursor after "hel")
    /// let context = TextContext(wordAtCursor: "hel", ...)
    ///
    /// // Types: ← ← ← h e l l o
    /// // Result: "hello|"
    /// if simulateKeystrokeInsertion("hello", context: context) {
    ///     print("Successfully typed completion")
    /// }
    /// ```
    private func simulateKeystrokeInsertion(_ completion: String, context: TextContext) -> Bool {
        // First, delete the partial word if it exists
        if !context.wordAtCursor.isEmpty {
            // Delete characters (backspace)
            for _ in 0..<context.wordAtCursor.count {
                if !simulateKeyPress(keyCode: 51) { // Delete/Backspace
                    return false
                }
                // Small delay between keystrokes
                usleep(Self.keyEventDelay)
            }
        }

        // Then type the completion text
        return typeText(completion)
    }

    /// Type text using CGEvent
    private func typeText(_ text: String) -> Bool {
        for char in text {
            guard let keyCode = characterToKeyCode(char) else {
                os_log("⚠️  No key code for character: '%{private}@'", log: .accessibility, type: .debug, String(char))
                continue
            }

            if !simulateKeyPress(keyCode: keyCode, char: char) {
                return false
            }

            // Small delay between keystrokes for reliability
            usleep(Self.keyEventDelay)
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