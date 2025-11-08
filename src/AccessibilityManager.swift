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

class AccessibilityManager {

    // MARK: - Singleton

    static let shared = AccessibilityManager()

    private init() {}

    // MARK: - Permission Status

    /// Check if accessibility permissions are granted
    /// - Returns: true if permissions granted, false otherwise
    func checkPermissionStatus() -> Bool {
        let trusted = AXIsProcessTrusted()
        print(trusted ? "✅ Accessibility permissions granted" : "⚠️  Accessibility permissions not granted")
        return trusted
    }

    /// Check permission status with prompt option
    /// - Parameter showPrompt: If true, shows system permission dialog
    /// - Returns: true if permissions granted, false otherwise
    func checkPermissionStatus(showPrompt: Bool) -> Bool {
        // Create options dictionary for AXIsProcessTrustedWithOptions
        let options: NSDictionary = [
            kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: showPrompt
        ]

        let trusted = AXIsProcessTrustedWithOptions(options)

        if showPrompt && !trusted {
            print("📋 System permission dialog displayed")
        }

        return trusted
    }

    // MARK: - Permission Request Flow

    /// Request accessibility permissions with user guidance
    /// Shows system dialog and provides instructions
    func requestPermissions() {
        print("🔐 Requesting accessibility permissions...")

        // Check if already granted
        if checkPermissionStatus() {
            print("✅ Permissions already granted")
            showPermissionGrantedAlert()
            return
        }

        // Show system prompt
        let granted = checkPermissionStatus(showPrompt: true)

        if granted {
            showPermissionGrantedAlert()
        } else {
            // Permissions not granted, show guidance
            showPermissionGuidanceAlert()
        }
    }

    /// Verify permissions and handle denied scenario
    /// - Returns: true if ready to use, false if permissions needed
    func verifyAndRequestIfNeeded() -> Bool {
        let granted = checkPermissionStatus()

        if !granted {
            print("⚠️  Accessibility permissions required")
            requestPermissions()
            return false
        }

        return true
    }

    // MARK: - User Guidance

    /// Show alert when permissions are granted
    private func showPermissionGrantedAlert() {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Accessibility Permissions Granted"
            alert.informativeText = """
            Complete now has the necessary permissions to:
            • Read text at cursor position
            • Insert completion text

            You can start using the app with Ctrl+I
            """
            alert.alertStyle = .informational
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }

    /// Show alert with guidance for granting permissions
    private func showPermissionGuidanceAlert() {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Accessibility Permissions Required"
            alert.informativeText = """
            Complete needs accessibility access to function.

            To grant permissions:

            1. Open System Settings
            2. Go to Privacy & Security → Accessibility
            3. Find "Complete" in the list
            4. Enable the checkbox next to Complete

            After granting permissions, restart the app.
            """
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Open System Settings")
            alert.addButton(withTitle: "Cancel")

            let response = alert.runModal()

            if response == .alertFirstButtonReturn {
                self.openAccessibilitySettings()
            }
        }
    }

    /// Show alert when permissions are denied during operation
    func showPermissionDeniedAlert() {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Accessibility Permissions Denied"
            alert.informativeText = """
            Complete cannot function without accessibility permissions.

            The app needs these permissions to:
            • Extract text from applications
            • Insert completion suggestions

            Please grant permissions in System Settings.
            """
            alert.alertStyle = .critical
            alert.addButton(withTitle: "Open System Settings")
            alert.addButton(withTitle: "Quit")

            let response = alert.runModal()

            if response == .alertFirstButtonReturn {
                self.openAccessibilitySettings()
            } else {
                NSApplication.shared.terminate(nil)
            }
        }
    }

    /// Open System Settings to Accessibility preferences
    private func openAccessibilitySettings() {
        // macOS 13+ uses new Settings app URL scheme
        if #available(macOS 13.0, *) {
            let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
            NSWorkspace.shared.open(url)
        } else {
            // Fallback for older macOS versions
            let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
            NSWorkspace.shared.open(url)
        }

        print("🔧 Opened System Settings → Privacy & Security → Accessibility")
    }

    // MARK: - Testing Helpers

    /// Test accessibility permissions with detailed output
    /// For development and debugging
    func testPermissions() {
        print("\n=== Accessibility Permission Test ===")

        print("1️⃣ Checking permission status...")
        let granted = checkPermissionStatus()

        if granted {
            print("✅ PASS: Accessibility permissions are granted")
            print("   App can read and manipulate UI elements")
        } else {
            print("❌ FAIL: Accessibility permissions not granted")
            print("   App cannot access UI elements")
        }

        print("\n2️⃣ Testing AXUIElement access...")
        if granted {
            testAXUIElementAccess()
        } else {
            print("⏭️  Skipped (permissions not granted)")
        }

        print("\n=====================================\n")
    }

    /// Test basic AXUIElement access
    private func testAXUIElementAccess() {
        // Get system-wide accessibility element
        let systemWide = AXUIElementCreateSystemWide()

        // Try to get focused element
        var focusedElement: AnyObject?
        let result = AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedUIElementAttribute as CFString,
            &focusedElement
        )

        if result == .success {
            print("✅ PASS: Can access focused UI element")

            // Try to get role
            if let element = focusedElement {
                var role: AnyObject?
                let roleResult = AXUIElementCopyAttributeValue(
                    element as! AXUIElement,
                    kAXRoleAttribute as CFString,
                    &role
                )

                if roleResult == .success, let roleString = role as? String {
                    print("   Focused element role: \(roleString)")
                }
            }
        } else {
            print("⚠️  WARNING: Could not access focused element")
            print("   Error code: \(result.rawValue)")
        }
    }

    // MARK: - Text Extraction (Phase 3)

    /// Extract text context from currently focused UI element
    /// Performance target: <50ms (typical 10-25ms per research)
    /// - Returns: TextContext if successful, nil otherwise
    func extractTextContext() -> TextContext? {
        guard checkPermissionStatus() else {
            print("❌ Cannot extract text: Accessibility permissions not granted")
            return nil
        }

        // Get system-wide accessibility element
        let systemWide = AXUIElementCreateSystemWide()

        // Get focused UI element
        guard let focusedElement = getFocusedElement(from: systemWide) else {
            print("⚠️  No focused text element found")
            return nil
        }

        // Extract text components
        let fullText = getFullText(from: focusedElement) ?? ""
        let selectedText = getSelectedText(from: focusedElement)
        let selectedRange = getSelectedTextRange(from: focusedElement)

        // Calculate cursor position
        let cursorPosition = selectedRange?.location ?? 0

        // Extract text before and after cursor
        let (textBefore, textAfter) = splitTextAtCursor(fullText, position: cursorPosition)

        // Extract word at cursor
        let wordAtCursor = extractWordAtPosition(fullText, position: cursorPosition)

        let context = TextContext(
            fullText: fullText,
            selectedText: selectedText,
            textBeforeCursor: textBefore,
            textAfterCursor: textAfter,
            wordAtCursor: wordAtCursor,
            cursorPosition: cursorPosition,
            selectedRange: selectedRange
        )

        print("📝 Text context extracted:")
        print("   Word at cursor: '\(wordAtCursor)'")
        print("   Cursor position: \(cursorPosition)")
        print("   Text before: '\(textBefore.suffix(20))'")

        return context
    }

    /// Get focused UI element from system-wide element
    private func getFocusedElement(from systemWide: AXUIElement) -> AXUIElement? {
        var focusedElement: AnyObject?
        let result = AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedUIElementAttribute as CFString,
            &focusedElement
        )

        guard result == .success else {
            return nil
        }

        return (focusedElement as! AXUIElement)
    }

    /// Get full text from UI element
    /// Tries multiple attributes for compatibility across different apps
    private func getFullText(from element: AXUIElement) -> String? {
        // Try AXValue first (most common)
        if let text = getAttributeValue(element, attribute: kAXValueAttribute as CFString) as? String {
            return text
        }

        // Try AXSelectedText as fallback
        if let text = getAttributeValue(element, attribute: kAXSelectedTextAttribute as CFString) as? String {
            return text
        }

        // Try AXTitle for non-editable text
        if let text = getAttributeValue(element, attribute: kAXTitleAttribute as CFString) as? String {
            return text
        }

        return nil
    }

    /// Get selected text from UI element
    private func getSelectedText(from element: AXUIElement) -> String? {
        return getAttributeValue(element, attribute: kAXSelectedTextAttribute as CFString) as? String
    }

    /// Get selected text range from UI element
    private func getSelectedTextRange(from element: AXUIElement) -> CFRange? {
        guard let rangeValue = getAttributeValue(element, attribute: kAXSelectedTextRangeAttribute as CFString) else {
            return nil
        }

        let axValue = rangeValue as! AXValue
        var range = CFRange(location: 0, length: 0)
        let success = AXValueGetValue(axValue, .cfRange, &range)

        return success ? range : nil
    }

    /// Get attribute value from UI element
    /// Generic helper for all attribute queries
    private func getAttributeValue(_ element: AXUIElement, attribute: CFString) -> AnyObject? {
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(element, attribute, &value)

        if result == .success {
            return value
        }

        return nil
    }

    /// Split text at cursor position
    private func splitTextAtCursor(_ text: String, position: Int) -> (before: String, after: String) {
        let safePosition = min(max(0, position), text.count)
        let index = text.index(text.startIndex, offsetBy: safePosition)

        let before = String(text[..<index])
        let after = String(text[index...])

        return (before, after)
    }

    /// Extract word at cursor position
    /// Returns the word currently being typed (for completion matching)
    private func extractWordAtPosition(_ text: String, position: Int) -> String {
        guard !text.isEmpty else { return "" }

        let safePosition = min(max(0, position), text.count)
        let index = text.index(text.startIndex, offsetBy: safePosition)

        // Find word boundaries
        var start = index
        var end = index

        // Move start backward to beginning of word
        while start > text.startIndex {
            let prev = text.index(before: start)
            let char = text[prev]
            if char.isWhitespace || char.isPunctuation {
                break
            }
            start = prev
        }

        // Move end forward to end of word
        while end < text.endIndex {
            let char = text[end]
            if char.isWhitespace || char.isPunctuation {
                break
            }
            end = text.index(after: end)
        }

        return String(text[start..<end])
    }

    // MARK: - Cursor Position Detection

    /// Get cursor screen coordinates for window positioning
    /// - Returns: CGPoint with cursor screen position, or nil if unavailable
    func getCursorScreenPosition() -> CGPoint? {
        guard let focusedElement = getFocusedElement(from: AXUIElementCreateSystemWide()) else {
            return nil
        }

        // Try to get insertion point bounds
        if let positionValue = getAttributeValue(focusedElement, attribute: kAXInsertionPointLineNumberAttribute as CFString) {
            print("📍 Insertion point available: \(positionValue)")
        }

        // Get bounds of focused element as fallback
        if let boundsValue = getAttributeValue(focusedElement, attribute: kAXPositionAttribute as CFString) {
            let axValue = boundsValue as! AXValue
            var point = CGPoint.zero
            let success = AXValueGetValue(axValue, .cgPoint, &point)

            if success {
                return point
            }
        }

        // Ultimate fallback: use mouse cursor position
        return NSEvent.mouseLocation
    }

    // MARK: - Text Insertion (Phase 3)

    /// Insert completion text at cursor position
    /// Replaces the word at cursor with the selected completion
    /// Performance target: <50ms (typical 20-40ms per research)
    /// - Parameters:
    ///   - completion: The completion text to insert
    ///   - context: Current text context (for smart replacement)
    /// - Returns: true if successful, false otherwise
    func insertCompletion(_ completion: String, replacing context: TextContext) -> Bool {
        guard checkPermissionStatus() else {
            print("❌ Cannot insert text: Accessibility permissions not granted")
            return false
        }

        guard let focusedElement = getFocusedElement(from: AXUIElementCreateSystemWide()) else {
            print("❌ No focused element for text insertion")
            return false
        }

        print("📝 Inserting completion: '\(completion)' replacing '\(context.wordAtCursor)'")

        // Strategy 1: Try direct AX API replacement (fastest, ~10-20ms)
        if let success = tryDirectReplacement(completion, context: context, element: focusedElement), success {
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
        guard let currentText = getFullText(from: element) else {
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
        guard let currentText = getFullText(from: element) else {
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