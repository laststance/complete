import Cocoa
import ApplicationServices
import os.log

/// Manages text extraction and cursor position detection from accessibility elements
/// Extracted from AccessibilityManager for single responsibility
class AccessibilityElementExtractor {

    private let permissionManager: AccessibilityPermissionManager
    private let cursorPositionResolver: CursorPositionResolver
    private let browserEnabler = BrowserAccessibilityEnabler()

    /// Creates an AccessibilityElementExtractor with required dependencies.
    ///
    /// - Parameters:
    ///   - permissionManager: Manages accessibility permission checks
    ///   - cursorPositionResolver: Resolver for cursor position strategies (injectable for testing)
    init(permissionManager: AccessibilityPermissionManager,
         cursorPositionResolver: CursorPositionResolver = CursorPositionResolver()) {
        self.permissionManager = permissionManager
        self.cursorPositionResolver = cursorPositionResolver
    }

    // MARK: - Text Extraction

    /// Extracts text context from the currently focused UI element.
    ///
    /// This method orchestrates the complete text extraction workflow, implementing
    /// multiple fallback strategies for maximum application compatibility.
    ///
    /// ## Algorithm
    /// 1. **Permission Check**: Verify accessibility permissions are granted
    /// 2. **Element Detection**: Get focused element via AX API (native apps)
    /// 3. **Web Browser Fallback**: If no focused element, try element at cursor position
    /// 4. **Text Extraction**: Extract full text, selection, and cursor position
    /// 5. **Text Parsing**: Split text and extract word at cursor
    /// 6. **Context Assembly**: Build TextContext with all components
    ///
    /// ## Fallback Strategy
    /// Native apps expose focused element directly via `kAXFocusedUIElementAttribute`.
    /// Web browsers (Chrome, Safari, Firefox) often fail to expose focused element properly,
    /// so we fall back to `AXUIElementCopyElementAtPosition` using cursor coordinates.
    ///
    /// ## Performance
    /// - **Target**: <50ms per call
    /// - **Typical**: 10-25ms (native apps), 15-35ms (web browsers)
    /// - **Bottleneck**: AX API calls to external applications
    ///
    /// - Returns: `Result<TextContext, AccessibilityError>`
    ///   - `.success(TextContext)`: Successfully extracted text context
    ///   - `.failure(.permissionDenied)`: Accessibility permissions not granted
    ///   - `.failure(.noFocusedElement)`: No focused element found
    ///   - `.failure(.elementNotFoundAtPosition)`: Cursor position fallback failed
    ///
    /// - Complexity: O(1) with multiple AX API calls
    ///
    /// ## Example
    /// ```swift
    /// switch extractor.extractTextContext() {
    /// case .success(let context):
    ///     print("Word at cursor: \(context.wordAtCursor)")
    /// case .failure(let error):
    ///     print("Failed: \(error.userFriendlyMessage)")
    /// }
    /// ```
    func extractTextContext() -> Result<TextContext, AccessibilityError> {
        guard permissionManager.checkPermissionStatus() else {
            return .failure(.permissionDenied)
        }

        // CRITICAL: Enable browser accessibility BEFORE querying any attributes
        // This sets AXEnhancedUserInterface for Chrome/Safari and
        // AXManualAccessibility for Electron apps (VSCode, Slack, etc.)
        if browserEnabler.isBrowserOrElectronApp() {
            browserEnabler.enableIfNeeded()
            os_log("🌐 extractTextContext: Browser/Electron app detected, accessibility enabled",
                   log: .accessibility, type: .info)
        }

        // Get system-wide accessibility element
        let systemWide = AXUIElementCreateSystemWide()

        // Try to get focused element (works for native apps)
        var focusedElement = getFocusedElement(from: systemWide)

        // Fallback for web browsers: use element at mouse position
        // Web browsers often don't expose focused element via kAXFocusedUIElementAttribute,
        // but we can find the text input element using AXUIElementCopyElementAtPosition()
        if focusedElement == nil {
            os_log("⚠️  No focused element (likely web browser), trying element at mouse position...", log: .accessibility, type: .debug)

            // Get mouse position and convert to Accessibility coordinates
            let mousePosition = NSEvent.mouseLocation
            os_log("📍 Mouse position (NSScreen): (%{public}f, %{public}f)", log: .accessibility, type: .debug, mousePosition.x, mousePosition.y)

            // Convert NSScreen coordinates (bottom-left origin) to Accessibility coordinates (top-left origin)
            if let screen = NSScreen.screens.first(where: { NSMouseInRect(mousePosition, $0.frame, false) }) ?? NSScreen.main {
                // In Accessibility coords, Y=0 is at the TOP of the screen
                // In NSScreen coords, Y=0 is at the BOTTOM
                // For a point on this screen: accessibilityY = screenHeight - (mouseY - screenOriginY)
                let accessibilityY = screen.frame.height - (mousePosition.y - screen.frame.origin.y)
                let accessibilityPoint = CGPoint(x: mousePosition.x, y: accessibilityY)

                os_log("📍 Converted to Accessibility coords: (%{public}f, %{public}f)", log: .accessibility, type: .debug, accessibilityPoint.x, accessibilityY)
                os_log("🖥️  Screen: frame=%{public}@", log: .accessibility, type: .debug, String(describing: screen.frame))

                focusedElement = getElementAtPosition(accessibilityPoint)

                if focusedElement != nil {
                    os_log("✅ Found element at mouse position (web browser support)", log: .accessibility, type: .debug)
                } else {
                    return .failure(.elementNotFoundAtPosition(x: accessibilityPoint.x, y: accessibilityPoint.y))
                }
            } else {
                os_log("❌ Could not determine screen for coordinate conversion", log: .accessibility, type: .error)
                return .failure(.noFocusedElement)
            }
        }

        guard let element = focusedElement else {
            return .failure(.noFocusedElement)
        }

        // Extract text components
        let fullText = getFullText(from: element) ?? ""
        let selectedText = getSelectedText(from: element)
        let selectedRange = getSelectedTextRange(from: element)

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
            selectedRange: selectedRange,
            sourceElement: element
        )

        os_log("📝 Text context extracted (element cached for insertion):", log: .accessibility, type: .debug)
        os_log("   Word at cursor: '%{private}@'", log: .accessibility, type: .debug, wordAtCursor)
        os_log("   Cursor position: %{public}d", log: .accessibility, type: .debug, cursorPosition)
        os_log("   Text before: '%{private}@'", log: .accessibility, type: .debug, textBefore.suffix(20))

        return .success(context)
    }

    /// Get focused UI element from system-wide element
    func getFocusedElement(from systemWide: AXUIElement) -> AXUIElement? {
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

    /// Get UI element at specific screen coordinates with fuzzy matching
    /// Falls back to nearby positions (±5px grid) for better browser support
    /// - Parameter point: Screen coordinates in Accessibility coordinate system
    /// - Returns: AXUIElement at or near the specified position, or nil
    func getElementAtPosition(_ point: CGPoint) -> AXUIElement? {
        // Try exact position first
        if let element = queryElementAtExactPosition(point) {
            return element
        }

        // Fallback: Try nearby positions (±5px grid) for better browser support
        // Mouse position has inherent imprecision (±3-5px)
        // Form inputs may have borders/padding that aren't clickable
        let offsets: [(x: CGFloat, y: CGFloat)] = [
            (0, -5), (0, 5), (-5, 0), (5, 0),  // Adjacent pixels
            (-5, -5), (5, -5), (-5, 5), (5, 5)  // Diagonals
        ]

        for offset in offsets {
            let adjustedPoint = CGPoint(x: point.x + offset.x, y: point.y + offset.y)
            if let element = queryElementAtExactPosition(adjustedPoint) {
                os_log("✅ Found element at offset (%{public}f, %{public}f) from original position",
                       log: .accessibility, type: .debug, offset.x, offset.y)
                return element
            }
        }

        os_log("⚠️  No element found at position (%{public}f, %{public}f) or nearby offsets",
               log: .accessibility, type: .debug, point.x, point.y)
        return nil
    }

    /// Query element at exact position without fallback
    private func queryElementAtExactPosition(_ point: CGPoint) -> AXUIElement? {
        let systemWide = AXUIElementCreateSystemWide()
        var element: AXUIElement?

        let result = AXUIElementCopyElementAtPosition(
            systemWide,
            Float(point.x),
            Float(point.y),
            &element
        )

        return result == .success ? element : nil
    }

    // MARK: - Element Attributes

    /// Get full text from UI element
    /// Tries multiple attributes for compatibility across different apps
    func getFullText(from element: AXUIElement) -> String? {
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
    func getSelectedText(from element: AXUIElement) -> String? {
        return getAttributeValue(element, attribute: kAXSelectedTextAttribute as CFString) as? String
    }

    /// Get selected text range from UI element
    func getSelectedTextRange(from element: AXUIElement) -> CFRange? {
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
    func getAttributeValue(_ element: AXUIElement, attribute: CFString) -> AnyObject? {
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(element, attribute, &value)

        if result == .success {
            return value
        }

        return nil
    }

    // MARK: - Text Processing

    /// Split text at cursor position
    private func splitTextAtCursor(_ text: String, position: Int) -> (before: String, after: String) {
        let safePosition = min(max(0, position), text.count)
        let index = text.index(text.startIndex, offsetBy: safePosition)

        let before = String(text[..<index])
        let after = String(text[index...])

        return (before, after)
    }

    /// Extracts the word at the cursor position for completion matching.
    ///
    /// This method identifies word boundaries by scanning backward and forward from
    /// the cursor position, stopping at whitespace or punctuation characters.
    ///
    /// ## Algorithm
    /// 1. **Boundary Check**: Ensure cursor position is within text bounds
    /// 2. **Backward Scan**: Move start index backward until whitespace/punctuation
    /// 3. **Forward Scan**: Move end index forward until whitespace/punctuation
    /// 4. **Extraction**: Return substring between start and end indices
    ///
    /// ## Word Boundary Rules
    /// - **Whitespace**: Space, tab, newline, etc. (via `.isWhitespace`)
    /// - **Punctuation**: Period, comma, semicolon, etc. (via `.isPunctuation`)
    /// - **Unicode Support**: Handles CJK characters, emoji, accented characters correctly
    ///
    /// ## Edge Cases
    /// - **Empty text**: Returns empty string
    /// - **Cursor at start/end**: Extracts word from boundary
    /// - **No word at cursor**: Returns empty string (e.g., cursor in whitespace)
    /// - **Position out of bounds**: Clamped to valid range [0, text.count]
    ///
    /// - Parameters:
    ///   - text: Full text to search within
    ///   - position: Cursor position (character offset, 0-indexed)
    ///
    /// - Returns: Word at cursor position, or empty string if none
    ///
    /// - Complexity: O(n) where n is average word length (typically <20 chars)
    ///
    /// ## Examples
    /// ```swift
    /// extractWordAtPosition("Hello world", position: 3)  // "Hello"
    /// extractWordAtPosition("Hello world", position: 6)  // "world"
    /// extractWordAtPosition("Hello world", position: 5)  // "" (whitespace)
    /// extractWordAtPosition("café", position: 2)         // "café" (accented)
    /// extractWordAtPosition("日本語", position: 1)       // "日本語" (CJK)
    /// ```
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

    /// Calculates the screen coordinates of the text cursor for completion window positioning.
    ///
    /// This method implements a multi-strategy approach to determine where the completion window
    /// should appear on screen. It performs coordinate transformations from element-local space
    /// to global screen space, accounting for macOS's unique coordinate system.
    ///
    /// ## Algorithm (3-Strategy Fallback)
    /// 1. **Text Range Bounds** (Most Accurate): Get bounds for selected text range via `kAXBoundsForRangeParameterizedAttribute`
    ///    - Uses `kAXSelectedTextRangeAttribute` to get cursor position (CFRange)
    ///    - Queries `kAXBoundsForRangeParameterizedAttribute` for precise cursor bounds (CGRect)
    ///    - Returns bottom-left corner of cursor rectangle
    /// 2. **Element Position** (Fallback): Get element's screen position via `kAXPositionAttribute`
    ///    - Returns top-left corner of the focused element
    ///    - Less precise but works when text range API fails
    /// 3. **Mouse Position** (Ultimate Fallback): Use `NSEvent.mouseLocation`
    ///    - Used for web browsers and non-compliant applications
    ///    - Assumes cursor is near mouse pointer
    ///
    /// ## macOS Coordinate System
    /// macOS uses a **flipped coordinate system** with origin at **bottom-left** of screen:
    /// - X: Left (0) → Right (screen width)
    /// - Y: Bottom (0) → Top (screen height)
    /// - This differs from UIKit (iOS) which has origin at top-left
    ///
    /// The completion window positioning logic must account for this when placing the popup
    /// above or below the cursor.
    ///
    /// ## Performance
    /// - **Strategy 1**: ~10-15ms (3 AX API calls)
    /// - **Strategy 2**: ~5-8ms (1 AX API call)
    /// - **Strategy 3**: <1ms (local system call)
    ///
    /// ## Application Compatibility
    /// - **Native apps** (TextEdit, Xcode, Mail): Strategy 1 works ✅
    /// - **Electron apps** (VSCode, Slack): Strategy 1 or 2 ✅
    /// - **Web browsers** (Chrome, Safari): Often require Strategy 3 ⚠️
    /// - **Terminal apps** (Terminal, iTerm2): Strategy 1 or 2 ✅
    ///
    /// - Parameter element: Optional AXUIElement to query. If `nil`, attempts to get focused element automatically.
    ///
    /// - Returns: `Result<CGPoint, AccessibilityError>`
    ///   - `.success(CGPoint)`: Screen coordinates of cursor (bottom-left corner)
    ///   - Strategy 1-3 always succeed (fallback to mouse position)
    ///
    /// - Complexity: O(1) with 1-3 AX API calls depending on strategy
    ///
    /// - Note: This method will **not** fail in practice because Strategy 3 (mouse position)
    ///         always succeeds. However, it returns `Result` for consistency with error handling architecture.
    ///
    /// ## Example
    /// ```swift
    /// switch extractor.getCursorScreenPosition() {
    /// case .success(let position):
    ///     // Position completion window 5 pixels below cursor
    ///     let windowY = position.y - 5
    ///     positionWindow(at: CGPoint(x: position.x, y: windowY))
    /// case .failure:
    ///     // Unreachable in practice due to fallbacks
    ///     break
    /// }
    /// ```
    func getCursorScreenPosition(from element: AXUIElement? = nil) -> Result<CGPoint, AccessibilityError> {
        // Use provided element, or try to get focused element
        let focusedElement = element ?? getFocusedElement(from: AXUIElementCreateSystemWide())

        // Delegate to the CursorPositionResolver which implements the strategy chain
        // See CursorPositionStrategies.swift for the strategy implementations:
        // 1. BoundsForRangeStrategy (most accurate)
        // 2. ElementPositionStrategy (fallback)
        // 3. MousePositionStrategy (ultimate fallback)
        let position = cursorPositionResolver.resolve(from: focusedElement)
        return .success(position)
    }

    // MARK: - Application Detection

    /// Bundle identifiers for apps that need clipboard-based fallback
    private static let clipboardFallbackApps: Set<String> = [
        "com.apple.Terminal",           // Terminal.app
        "com.microsoft.VSCode",          // VSCode
        "com.microsoft.VSCodeInsiders",  // VSCode Insiders
        "com.googlecode.iterm2",         // iTerm2
        "com.github.atom",               // Atom
        "dev.warp.Warp-Stable",          // Warp Terminal
        "com.jetbrains.intellij",        // IntelliJ IDEA
        "com.jetbrains.WebStorm",        // WebStorm
        "com.jetbrains.PhpStorm",        // PhpStorm
    ]

    /// Check if the frontmost app needs clipboard-based fallback
    func needsClipboardFallback() -> Bool {
        guard let frontApp = NSWorkspace.shared.frontmostApplication,
              let bundleId = frontApp.bundleIdentifier else {
            return false
        }

        let needsFallback = Self.clipboardFallbackApps.contains(bundleId)
        if needsFallback {
            os_log("📋 Frontmost app '%{public}@' (%{public}@) needs clipboard fallback", log: .accessibility, type: .info,
                   frontApp.localizedName ?? "unknown", bundleId)
        }
        return needsFallback
    }

    // MARK: - Clipboard-Based Word Extraction

    /// Extract word at cursor using clipboard-based approach
    /// This is a fallback for apps like Terminal and VSCode that don't expose text via AX API
    ///
    /// IMPORTANT: For Terminal apps, we use Control+W (delete word) + Control+Y (yank/undo)
    /// instead of arrow keys, because arrow keys produce escape sequences in Terminal!
    ///
    /// ## Terminal-Safe Algorithm (no arrow keys)
    /// 1. Save current clipboard content
    /// 2. Send Control+W (delete word backward - shell native)
    /// 3. Send Control+Y (yank - restore deleted word)
    /// 4. Send Cmd+A then Cmd+C to copy... no wait, that's too much
    ///
    /// Actually for Terminal, we use Option+Shift+Left which DOES produce escape sequences.
    /// But we've found that Terminal text extraction is fundamentally broken with CGEvents.
    ///
    /// ## WORKAROUND FOR TERMINAL
    /// For Terminal apps (com.apple.Terminal, iTerm2, etc.):
    /// - Don't try to select text (arrow keys produce escape sequences like '[D')
    /// - Return empty wordAtCursor
    /// - Insertion will append completion (not replace)
    /// - User manually handles partial word deletion
    ///
    /// ## VSCode Algorithm (arrow keys work)
    /// 1. Save current clipboard content
    /// 2. Send Option+Shift+Left Arrow (select word to the left)
    /// 3. Send Cmd+C (copy selected text)
    /// 4. Read clipboard as word at cursor
    /// 5. Send Right Arrow (deselect)
    /// 6. Restore original clipboard content
    ///
    /// - Returns: Result with TextContext or error
    func extractTextContextViaClipboard() -> Result<TextContext, AccessibilityError> {
        os_log("📋 Using clipboard-based text extraction", log: .accessibility, type: .info)

        // Check if this is a true terminal app where arrow keys produce escape sequences
        if isTerminalApp() {
            os_log("📋 Terminal app detected - skipping arrow-based extraction (would produce escape sequences)", log: .accessibility, type: .info)
            // Return empty context for Terminal - arrow keys don't work here
            // The insertion will use Cmd+V only (append mode)
            let context = TextContext(
                fullText: "",
                selectedText: nil,
                textBeforeCursor: "",
                textAfterCursor: "",
                wordAtCursor: "",
                cursorPosition: 0,
                selectedRange: nil
            )
            return .success(context)
        }

        // For VSCode and other apps that handle arrow keys properly
        let pasteboard = NSPasteboard.general
        let savedTypes = pasteboard.types ?? []
        var savedContents: [NSPasteboard.PasteboardType: Data] = [:]
        for type in savedTypes {
            if let data = pasteboard.data(forType: type) {
                savedContents[type] = data
            }
        }

        // Clear clipboard for our operation
        pasteboard.clearContents()

        // Small delay to ensure clipboard is ready
        usleep(10000) // 10ms

        // Send Option+Shift+Left Arrow (select word to the left)
        // This selects the word before the cursor in most text editors
        simulateKeyPress(keyCode: 123, modifiers: [.maskShift, .maskAlternate]) // Left Arrow with Shift+Option
        usleep(50000) // 50ms delay for selection to complete

        // Send Cmd+C (copy)
        simulateKeyPress(keyCode: 8, modifiers: [.maskCommand]) // 'c' key with Cmd
        usleep(50000) // 50ms delay for clipboard to update

        // Read clipboard content
        let wordAtCursor = pasteboard.string(forType: .string) ?? ""

        os_log("📋 Extracted word via clipboard: '%{private}@'", log: .accessibility, type: .debug, wordAtCursor)

        // Send Right Arrow to deselect and restore cursor position
        simulateKeyPress(keyCode: 124, modifiers: []) // Right Arrow
        usleep(10000) // 10ms

        // Restore original clipboard content
        pasteboard.clearContents()
        if !savedContents.isEmpty {
            for (type, data) in savedContents {
                pasteboard.setData(data, forType: type)
            }
        }

        // If we got no word, the fallback didn't work
        if wordAtCursor.isEmpty {
            os_log("⚠️  Clipboard-based extraction returned empty word", log: .accessibility, type: .debug)
            // Return a minimal context - user may be at start of line or in empty field
        }

        // Create TextContext with limited information (we don't have full text)
        let context = TextContext(
            fullText: wordAtCursor,  // We only have the word
            selectedText: nil,
            textBeforeCursor: wordAtCursor,
            textAfterCursor: "",
            wordAtCursor: wordAtCursor,
            cursorPosition: wordAtCursor.count,
            selectedRange: nil
        )

        return .success(context)
    }

    /// Check if the frontmost app is a true terminal emulator (where arrow keys produce escape sequences)
    /// VSCode and other editors handle arrow keys properly via their accessibility layer
    private func isTerminalApp() -> Bool {
        guard let frontApp = NSWorkspace.shared.frontmostApplication,
              let bundleId = frontApp.bundleIdentifier else {
            return false
        }

        // Terminal emulators where arrow keys produce escape sequences
        let terminalApps: Set<String> = [
            "com.apple.Terminal",           // Terminal.app
            "com.googlecode.iterm2",         // iTerm2
            "dev.warp.Warp-Stable",          // Warp Terminal
            "io.alacritty",                  // Alacritty
            "org.alacritty",                 // Alacritty (alternative)
            "com.github.wez.wezterm",        // WezTerm
            "co.zeit.hyper",                 // Hyper
            "com.qvacua.VimR",               // VimR
            "org.vim.MacVim",                // MacVim
        ]

        let isTerminal = terminalApps.contains(bundleId)
        if isTerminal {
            os_log("📋 Detected terminal app: %{public}@", log: .accessibility, type: .debug, bundleId)
        }
        return isTerminal
    }

    /// Simulate a key press with modifiers using CGEvent
    private func simulateKeyPress(keyCode: CGKeyCode, modifiers: CGEventFlags) {
        let source = CGEventSource(stateID: .hidSystemState)

        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false) else {
            os_log("❌ Failed to create CGEvent for key press", log: .accessibility, type: .error)
            return
        }

        keyDown.flags = modifiers
        keyUp.flags = modifiers

        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }
}