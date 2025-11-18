import Cocoa
import ApplicationServices

/// Manages text extraction and cursor position detection from accessibility elements
/// Extracted from AccessibilityManager for single responsibility
class AccessibilityElementExtractor {

    private let permissionManager: AccessibilityPermissionManager

    init(permissionManager: AccessibilityPermissionManager) {
        self.permissionManager = permissionManager
    }

    // MARK: - Text Extraction

    /// Extract text context from currently focused UI element
    /// Performance target: <50ms (typical 10-25ms per research)
    /// - Returns: Result with TextContext or AccessibilityError
    func extractTextContext() -> Result<TextContext, AccessibilityError> {
        guard permissionManager.checkPermissionStatus() else {
            return .failure(.permissionDenied)
        }

        // Get system-wide accessibility element
        let systemWide = AXUIElementCreateSystemWide()

        // Try to get focused element (works for native apps)
        var focusedElement = getFocusedElement(from: systemWide)

        // Fallback for web browsers: use element at cursor position
        if focusedElement == nil {
            print("⚠️  No focused element (likely web browser), trying element at cursor position...")

            // Get current cursor screen position
            switch getCursorScreenPosition() {
            case .success(let cursorPosition):
                print("📍 Cursor position: (\(cursorPosition.x), \(cursorPosition.y))")
                focusedElement = getElementAtPosition(cursorPosition)

                if focusedElement != nil {
                    print("✅ Found element at cursor position (web browser support)")
                } else {
                    return .failure(.elementNotFoundAtPosition(x: cursorPosition.x, y: cursorPosition.y))
                }
            case .failure(let error):
                return .failure(error)
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

        print("📝 Text context extracted:")
        print("   Word at cursor: '\(wordAtCursor)'")
        print("   Cursor position: \(cursorPosition)")
        print("   Text before: '\(textBefore.suffix(20))'")

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
            print("⚠️  Failed to get element at position (\(point.x), \(point.y))")
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
    /// - Parameter element: Optional AX element to use (if nil, will try to get focused element)
    /// - Returns: Result with CGPoint or AccessibilityError
    func getCursorScreenPosition(from element: AXUIElement? = nil) -> Result<CGPoint, AccessibilityError> {
        // Use provided element, or try to get focused element
        let focusedElement = element ?? getFocusedElement(from: AXUIElementCreateSystemWide())

        guard let focusedElement = focusedElement else {
            print("⚠️  No focused element for cursor position, using mouse position")
            // Fallback to mouse cursor position for web browsers
            let mousePosition = NSEvent.mouseLocation
            print("📍 Using mouse position: (\(mousePosition.x), \(mousePosition.y))")
            return .success(mousePosition)
        }

        // Strategy 1: Get bounds for selected text range (most accurate)
        if let selectedRangeValue = getAttributeValue(focusedElement, attribute: kAXSelectedTextRangeAttribute as CFString) {
            // Extract CFRange from AXValue
            let axValue = selectedRangeValue as! AXValue
            var range = CFRange()
            let rangeSuccess = AXValueGetValue(axValue, .cfRange, &range)

            if rangeSuccess {
                print("📍 Selected range: location=\(range.location), length=\(range.length)")

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
                        print("📍 Cursor bounds rect: \(bounds)")
                        print("   - origin: (\(bounds.origin.x), \(bounds.origin.y))")
                        print("   - size: (\(bounds.width) × \(bounds.height))")

                        let cursorBottomY = bounds.maxY
                        let cursorX = bounds.origin.x

                        let cursorPosition = CGPoint(x: cursorX, y: cursorBottomY)
                        print("📍 Cursor position (bottom of cursor): (\(cursorPosition.x), \(cursorPosition.y))")
                        return .success(cursorPosition)
                    }
                }
            }
        }

        // Strategy 2: Get element position as fallback
        if let positionValue = getAttributeValue(focusedElement, attribute: kAXPositionAttribute as CFString) {
            let axValue = positionValue as! AXValue
            var point = CGPoint.zero
            let success = AXValueGetValue(axValue, .cgPoint, &point)

            if success {
                print("📍 Cursor position from element bounds: (\(point.x), \(point.y))")
                print("⚠️  Using element position as fallback")
                return .success(point)
            }
        }

        // Strategy 3: Ultimate fallback to mouse cursor position
        let mousePosition = NSEvent.mouseLocation
        print("📍 Using mouse position as fallback: (\(mousePosition.x), \(mousePosition.y))")
        return .success(mousePosition)
    }
}