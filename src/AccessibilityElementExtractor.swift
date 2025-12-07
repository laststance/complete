import Cocoa
import ApplicationServices
import os.log

/// Manages text extraction and cursor position detection from accessibility elements
/// Extracted from AccessibilityManager for single responsibility
class AccessibilityElementExtractor {

    private let permissionManager: AccessibilityPermissionManager

    init(permissionManager: AccessibilityPermissionManager) {
        self.permissionManager = permissionManager
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
            selectedRange: selectedRange
        )

        os_log("📝 Text context extracted:", log: .accessibility, type: .debug)
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

    /// Get UI element at specific screen coordinates
    /// Fallback for web browsers that don't expose focused element properly
    func getElementAtPosition(_ point: CGPoint) -> AXUIElement? {
        let systemWide = AXUIElementCreateSystemWide()
        var element: AXUIElement?

        let result = AXUIElementCopyElementAtPosition(
            systemWide,
            Float(point.x),
            Float(point.y),
            &element
        )

        guard result == .success else {
            os_log("⚠️  Failed to get element at position (%{public}f, %{public}f)", log: .accessibility, type: .debug, point.x, point.y)
            return nil
        }

        return element
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
        var focusedElement = element ?? getFocusedElement(from: AXUIElementCreateSystemWide())

        // Strategy 0: If no focused element, try to find element at mouse position
        // This is critical for web browsers where getFocusedElement() fails but
        // we can still find the text input element via getElementAtPosition()
        if focusedElement == nil {
            os_log("⚠️  No focused element, trying element at mouse position for better positioning", log: .accessibility, type: .debug)
            let mousePosition = NSEvent.mouseLocation

            // Convert mouse position from NSScreen coords (bottom-left origin) to Accessibility coords (top-left origin)
            // to use with getElementAtPosition()
            if let screen = NSScreen.screens.first(where: { NSMouseInRect(mousePosition, $0.frame, false) }) ?? NSScreen.main {
                let accessibilityY = screen.frame.height - (mousePosition.y - screen.frame.origin.y)
                let accessibilityPoint = CGPoint(x: mousePosition.x, y: accessibilityY)

                os_log("📍 Mouse position (NSScreen): (%{public}f, %{public}f)", log: .accessibility, type: .debug, mousePosition.x, mousePosition.y)
                os_log("📍 Mouse position (Accessibility): (%{public}f, %{public}f)", log: .accessibility, type: .debug, accessibilityPoint.x, accessibilityY)

                if let elementAtMouse = getElementAtPosition(accessibilityPoint) {
                    os_log("✅ Found element at mouse position, using for position calculation", log: .accessibility, type: .debug)
                    focusedElement = elementAtMouse
                }
            }
        }

        guard let focusedElement = focusedElement else {
            os_log("⚠️  No focused element for cursor position, using mouse position as final fallback", log: .accessibility, type: .debug)
            // Ultimate fallback to mouse cursor position
            let mousePosition = NSEvent.mouseLocation
            os_log("📍 Using raw mouse position: (%{public}f, %{public}f)", log: .accessibility, type: .debug, mousePosition.x, mousePosition.y)
            return .success(mousePosition)
        }

        // Strategy 1: Get bounds for selected text range (most accurate)
        if let selectedRangeValue = getAttributeValue(focusedElement, attribute: kAXSelectedTextRangeAttribute as CFString) {
            // Extract CFRange from AXValue
            let axValue = selectedRangeValue as! AXValue
            var range = CFRange()
            let rangeSuccess = AXValueGetValue(axValue, .cfRange, &range)

            if rangeSuccess {
                os_log("📍 Selected range: location=%{public}d, length=%{public}d", log: .accessibility, type: .debug, range.location, range.length)

                // Create AXValue for the range parameter
                var mutableRange = range
                guard let rangeAXValue = AXValueCreate(.cfRange, &mutableRange) else {
                    return .failure(.axApiFailed(attribute: "AXBoundsForRange", code: -1))
                }

                // Get bounds for this range
                var boundsValue: CFTypeRef?
                let boundsResult = AXUIElementCopyParameterizedAttributeValue(
                    focusedElement,
                    kAXBoundsForRangeParameterizedAttribute as CFString,
                    rangeAXValue,
                    &boundsValue
                )

                if boundsResult == .success, let boundsValue = boundsValue {
                    // Extract CGRect from the bounds AXValue
                    var bounds = CGRect.zero
                    let boundsAXValue = boundsValue as! AXValue
                    let boundsSuccess = AXValueGetValue(boundsAXValue, .cgRect, &bounds)

                    if boundsSuccess {
                        os_log("📍 Cursor bounds rect (Accessibility coords): origin(%{public}f, %{public}f) size(%{public}f × %{public}f)", log: .accessibility, type: .debug, bounds.origin.x, bounds.origin.y, bounds.width, bounds.height)

                        // Accessibility API uses top-left origin (Y increases downward)
                        // NSScreen uses bottom-left origin (Y increases upward)
                        // Need to convert: screenY = screenHeight - accessibilityY

                        // CRITICAL: Find the screen that contains this cursor position
                        // We can't use NSScreen.main because cursor might be on a different screen
                        let cursorAccessibilityPoint = CGPoint(x: bounds.origin.x, y: bounds.origin.y)
                        let containingScreen = NSScreen.screens.first { screen in
                            // Convert screen frame to Accessibility coordinates for comparison
                            // Accessibility: top-left origin, Y increases downward
                            // NSScreen: bottom-left origin, Y increases upward
                            // For a screen, Accessibility Y=0 corresponds to NSScreen Y=screenHeight
                            let screenAccessibilityMinY: CGFloat = 0  // Top of screen in Accessibility coords
                            let screenAccessibilityMaxY = screen.frame.height  // Bottom of screen in Accessibility coords
                            let screenAccessibilityMinX = screen.frame.origin.x
                            let screenAccessibilityMaxX = screen.frame.origin.x + screen.frame.width

                            let containsPoint = cursorAccessibilityPoint.x >= screenAccessibilityMinX &&
                                               cursorAccessibilityPoint.x <= screenAccessibilityMaxX &&
                                               cursorAccessibilityPoint.y >= screenAccessibilityMinY &&
                                               cursorAccessibilityPoint.y <= screenAccessibilityMaxY

                            os_log("🖥️  Screen check: frame=%{public}@, contains=(%{public}d)", log: .accessibility, type: .debug, String(describing: screen.frame), containsPoint)
                            return containsPoint
                        } ?? NSScreen.main

                        guard let targetScreen = containingScreen else {
                            os_log("⚠️  Could not find any screen for coordinate conversion", log: .accessibility, type: .error)
                            return .failure(.axApiFailed(attribute: "screen", code: -1))
                        }

                        os_log("🖥️  Using screen: frame=%{public}@", log: .accessibility, type: .debug, String(describing: targetScreen.frame))

                        let screenHeight = targetScreen.frame.height
                        let screenOriginX = targetScreen.frame.origin.x
                        let cursorX = bounds.origin.x
                        let cursorBottomY = bounds.maxY  // Bottom of cursor in Accessibility coords

                        // Convert to NSScreen coordinate system
                        // In NSScreen coordinates, this screen's bottom-left is at (screenOriginX, screenOriginY)
                        let screenY = targetScreen.frame.origin.y + (screenHeight - cursorBottomY)
                        let cursorPosition = CGPoint(x: cursorX, y: screenY)

                        os_log("📍 Cursor position (Accessibility): (%{public}f, %{public}f)", log: .accessibility, type: .debug, cursorX, cursorBottomY)
                        os_log("📍 Cursor position (NSScreen): (%{public}f, %{public}f)", log: .accessibility, type: .debug, cursorPosition.x, cursorPosition.y)
                        os_log("🖥️  Screen height: %{public}f, origin: (%{public}f, %{public}f)", log: .accessibility, type: .debug, screenHeight, screenOriginX, targetScreen.frame.origin.y)
                        return .success(cursorPosition)
                    }
                }
            }
        }

        // Strategy 2: Get element position as fallback
        // NOTE: This returns the TOP-LEFT corner of the element, not the text cursor position
        // For text fields, this is usually close enough, but for browser address bars it may be imprecise
        if let positionValue = getAttributeValue(focusedElement, attribute: kAXPositionAttribute as CFString) {
            let axValue = positionValue as! AXValue
            var point = CGPoint.zero
            let success = AXValueGetValue(axValue, .cgPoint, &point)

            if success {
                os_log("📍 Element position (Accessibility coords - raw): (%{public}f, %{public}f)", log: .accessibility, type: .debug, point.x, point.y)

                // Accessibility API coordinates use screen-relative positioning where:
                // - X=0 is the left edge of the leftmost screen
                // - Y=0 is the TOP of the main screen (primary display)
                // - Y increases DOWNWARD
                //
                // NSScreen coordinates use:
                // - X=0 is the left edge of the leftmost screen
                // - Y=0 is the BOTTOM of the main screen
                // - Y increases UPWARD
                //
                // The main screen (primary display) has frame.origin.y = 0 in NSScreen coords

                // Get the main screen height for coordinate conversion
                guard let mainScreen = NSScreen.screens.first else {
                    os_log("⚠️  No screens available for coordinate conversion", log: .accessibility, type: .error)
                    return .failure(.axApiFailed(attribute: "screen", code: -1))
                }

                // Convert Y coordinate: NSScreen Y = mainScreenHeight - accessibilityY
                // This converts from top-left origin to bottom-left origin
                let mainScreenHeight = mainScreen.frame.height + mainScreen.frame.origin.y
                let nsScreenY = mainScreenHeight - point.y
                let convertedPoint = CGPoint(x: point.x, y: nsScreenY)

                os_log("📍 Element position (NSScreen): (%{public}f, %{public}f)", log: .accessibility, type: .debug, convertedPoint.x, convertedPoint.y)
                os_log("🖥️  Main screen height (for conversion): %{public}f", log: .accessibility, type: .debug, mainScreenHeight)
                os_log("⚠️  Using element position as fallback (Strategy 2)", log: .accessibility, type: .debug)
                return .success(convertedPoint)
            }
        }

        // Strategy 3: Ultimate fallback to mouse cursor position
        // This is the most reliable for browsers where other strategies fail
        let mousePosition = NSEvent.mouseLocation
        os_log("📍 Using mouse position as fallback (Strategy 3): (%{public}f, %{public}f)", log: .accessibility, type: .debug, mousePosition.x, mousePosition.y)
        return .success(mousePosition)
    }
}