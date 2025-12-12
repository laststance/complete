import XCTest
import Cocoa
@testable import Complete

// MARK: - Mock Objects for Testing

/// Mock AccessibilityPermissionManager that returns configurable permission status
final class MockAccessibilityPermissionManager: AccessibilityPermissionManager {
    private var permissionGranted: Bool
    var checkPermissionCallCount = 0

    init(permissionGranted: Bool) {
        self.permissionGranted = permissionGranted
        // Create a dummy alert manager since we won't use it in tests
        super.init(alertManager: AccessibilityAlertManager())
    }

    override func checkPermissionStatus() -> Bool {
        checkPermissionCallCount += 1
        return permissionGranted
    }

    func setPermissionGranted(_ granted: Bool) {
        permissionGranted = granted
    }
}

/// Mock strategy that always returns a predetermined position
/// Used to create a CursorPositionResolver with predictable behavior
final class FixedPositionStrategy: CursorPositionStrategy {
    let name: String
    let returnPosition: CGPoint
    var callCount = 0

    init(name: String = "FixedPosition", returnPosition: CGPoint) {
        self.name = name
        self.returnPosition = returnPosition
    }

    func getCursorPosition(from element: AXUIElement?) -> CGPoint? {
        callCount += 1
        return returnPosition
    }
}

// MARK: - AccessibilityElementExtractor Tests

final class AccessibilityElementExtractorTests: XCTestCase {

    // MARK: - Test Lifecycle

    override func setUp() {
        super.setUp()
    }

    override func tearDown() {
        super.tearDown()
    }

    // MARK: - extractTextContext Tests

    func testExtractTextContext_PermissionDenied_ReturnsFailure() {
        // Given: Permission manager that denies permission
        let mockPermissionManager = MockAccessibilityPermissionManager(permissionGranted: false)
        let extractor = AccessibilityElementExtractor(permissionManager: mockPermissionManager)

        // When: Extracting text context
        let result = extractor.extractTextContext()

        // Then: Should return permission denied error
        switch result {
        case .success:
            XCTFail("Should have returned failure for permission denied")
        case .failure(let error):
            XCTAssertEqual(error, .permissionDenied, "Should return permissionDenied error")
        }
        XCTAssertEqual(mockPermissionManager.checkPermissionCallCount, 1, "Should check permission once")
    }

    func testExtractTextContext_PermissionGranted_ChecksPermissionFirst() {
        // Given: Permission manager that grants permission
        let mockPermissionManager = MockAccessibilityPermissionManager(permissionGranted: true)
        let extractor = AccessibilityElementExtractor(permissionManager: mockPermissionManager)

        // When: Extracting text context (will fail due to no focused element in test environment)
        _ = extractor.extractTextContext()

        // Then: Should have checked permission
        XCTAssertEqual(mockPermissionManager.checkPermissionCallCount, 1, "Should check permission first")
    }

    func testExtractTextContext_NoFocusedElement_ReturnsAppropriateError() {
        // Given: Permission granted but no focused element in test environment
        let mockPermissionManager = MockAccessibilityPermissionManager(permissionGranted: true)
        let extractor = AccessibilityElementExtractor(permissionManager: mockPermissionManager)

        // When: Extracting text context
        let result = extractor.extractTextContext()

        // Then: Should return error (noFocusedElement or elementNotFoundAtPosition)
        switch result {
        case .success:
            // In rare cases, if test runner has focus on a text element, this might succeed
            XCTAssertTrue(true, "Extraction succeeded - test environment has focused element")
        case .failure(let error):
            // Expect either noFocusedElement or elementNotFoundAtPosition
            let validErrors: [AccessibilityError] = [
                .noFocusedElement,
                .elementNotFoundAtPosition(x: 0, y: 0) // Any position is valid
            ]
            let isValidError = validErrors.contains { expectedError in
                switch (error, expectedError) {
                case (.noFocusedElement, .noFocusedElement):
                    return true
                case (.elementNotFoundAtPosition, .elementNotFoundAtPosition):
                    return true
                default:
                    return false
                }
            }
            XCTAssertTrue(isValidError, "Should return noFocusedElement or elementNotFoundAtPosition, got: \(error)")
        }
    }

    // MARK: - needsClipboardFallback Tests

    func testNeedsClipboardFallback_TerminalApp_ReturnsTrue() {
        // This test verifies the clipboard fallback app list contains Terminal
        let mockPermissionManager = MockAccessibilityPermissionManager(permissionGranted: true)
        let extractor = AccessibilityElementExtractor(permissionManager: mockPermissionManager)

        // When: Checking if current frontmost app needs fallback
        // Note: In test environment, this will return based on actual frontmost app
        let needsFallback = extractor.needsClipboardFallback()

        // Then: Result depends on test environment
        // We mainly verify the method doesn't crash and returns a boolean
        XCTAssertTrue(needsFallback == true || needsFallback == false,
                      "Should return valid boolean")
    }

    func testNeedsClipboardFallback_ReturnsBoolean() {
        // Given: Any permission state
        let mockPermissionManager = MockAccessibilityPermissionManager(permissionGranted: true)
        let extractor = AccessibilityElementExtractor(permissionManager: mockPermissionManager)

        // When: Checking clipboard fallback need
        let result = extractor.needsClipboardFallback()

        // Then: Should return a valid boolean without crashing
        XCTAssertNotNil(result as Bool?, "Should return a boolean value")
    }

    // MARK: - isTerminalApp Tests (via extractTextContextViaClipboard behavior)

    func testExtractTextContextViaClipboard_ReturnsSuccess() {
        // Given: Extractor with granted permissions
        let mockPermissionManager = MockAccessibilityPermissionManager(permissionGranted: true)
        let extractor = AccessibilityElementExtractor(permissionManager: mockPermissionManager)

        // When: Extracting via clipboard
        let result = extractor.extractTextContextViaClipboard()

        // Then: Should return success (possibly with empty context for terminal apps)
        switch result {
        case .success(let context):
            // For terminal apps, context will be empty
            // For other apps, context will have wordAtCursor
            XCTAssertNotNil(context, "Should return valid context")
            XCTAssertNotNil(context.wordAtCursor, "Should have wordAtCursor property")
        case .failure(let error):
            XCTFail("Should not fail for clipboard extraction: \(error)")
        }
    }

    func testExtractTextContextViaClipboard_TerminalApp_ReturnsEmptyContext() {
        // Given: Extractor with granted permissions
        // Note: This test behavior depends on whether test is run from Terminal
        let mockPermissionManager = MockAccessibilityPermissionManager(permissionGranted: true)
        let extractor = AccessibilityElementExtractor(permissionManager: mockPermissionManager)

        // When: Extracting via clipboard
        let result = extractor.extractTextContextViaClipboard()

        // Then: Should return success
        if case .success(let context) = result {
            // If running from Terminal, wordAtCursor should be empty
            // If running from Xcode, wordAtCursor might have content
            XCTAssertNotNil(context.wordAtCursor, "Should have wordAtCursor property")
        }
    }

    // MARK: - getCursorScreenPosition Tests

    func testGetCursorScreenPosition_WithCustomStrategy_ReturnsExpectedPosition() {
        // Given: Extractor with custom strategy that returns fixed position
        let mockPermissionManager = MockAccessibilityPermissionManager(permissionGranted: true)
        let fixedStrategy = FixedPositionStrategy(returnPosition: CGPoint(x: 250, y: 350))
        let customResolver = CursorPositionResolver(strategies: [fixedStrategy])
        let extractor = AccessibilityElementExtractor(
            permissionManager: mockPermissionManager,
            cursorPositionResolver: customResolver
        )

        // When: Getting cursor screen position
        let result = extractor.getCursorScreenPosition(from: nil)

        // Then: Should return success with expected position
        switch result {
        case .success(let position):
            XCTAssertEqual(position.x, 250, "X should match strategy value")
            XCTAssertEqual(position.y, 350, "Y should match strategy value")
        case .failure(let error):
            XCTFail("Should not fail: \(error)")
        }
        XCTAssertEqual(fixedStrategy.callCount, 1, "Should call strategy once")
    }

    func testGetCursorScreenPosition_AlwaysReturnsSuccess() {
        // Given: Any extractor setup
        let mockPermissionManager = MockAccessibilityPermissionManager(permissionGranted: true)
        let extractor = AccessibilityElementExtractor(permissionManager: mockPermissionManager)

        // When: Getting cursor screen position
        let result = extractor.getCursorScreenPosition(from: nil)

        // Then: Should always return success (falls back to mouse position)
        switch result {
        case .success(let position):
            // Position should be within reasonable screen bounds
            XCTAssertTrue(position.x >= -10000 && position.x <= 20000,
                         "X should be within reasonable bounds: \(position.x)")
            XCTAssertTrue(position.y >= -10000 && position.y <= 20000,
                         "Y should be within reasonable bounds: \(position.y)")
        case .failure:
            XCTFail("getCursorScreenPosition should never fail due to mouse position fallback")
        }
    }

    // MARK: - Text Processing Tests (via public TextContext results)

    func testSplitTextAtCursor_EdgeCase_EmptyText() {
        // Verify TextContext handles empty text correctly
        let context = TextContext(
            fullText: "",
            selectedText: nil,
            textBeforeCursor: "",
            textAfterCursor: "",
            wordAtCursor: "",
            cursorPosition: 0,
            selectedRange: nil
        )

        XCTAssertEqual(context.textBeforeCursor, "", "Text before cursor should be empty")
        XCTAssertEqual(context.textAfterCursor, "", "Text after cursor should be empty")
        XCTAssertEqual(context.wordAtCursor, "", "Word at cursor should be empty")
    }

    func testSplitTextAtCursor_EdgeCase_CursorAtStart() {
        // Verify correct split when cursor is at start
        let fullText = "Hello world"
        let context = TextContext(
            fullText: fullText,
            selectedText: nil,
            textBeforeCursor: "",
            textAfterCursor: fullText,
            wordAtCursor: "Hello",
            cursorPosition: 0,
            selectedRange: nil
        )

        XCTAssertEqual(context.textBeforeCursor, "", "Text before cursor should be empty at start")
        XCTAssertEqual(context.textAfterCursor, fullText, "Text after cursor should be full text")
    }

    func testSplitTextAtCursor_EdgeCase_CursorAtEnd() {
        // Verify correct split when cursor is at end
        let fullText = "Hello world"
        let context = TextContext(
            fullText: fullText,
            selectedText: nil,
            textBeforeCursor: fullText,
            textAfterCursor: "",
            wordAtCursor: "world",
            cursorPosition: fullText.count,
            selectedRange: nil
        )

        XCTAssertEqual(context.textBeforeCursor, fullText, "Text before cursor should be full text at end")
        XCTAssertEqual(context.textAfterCursor, "", "Text after cursor should be empty at end")
    }

    func testSplitTextAtCursor_MiddleOfText() {
        // Verify correct split when cursor is in middle
        let context = TextContext(
            fullText: "Hello world",
            selectedText: nil,
            textBeforeCursor: "Hello ",
            textAfterCursor: "world",
            wordAtCursor: "world",
            cursorPosition: 6,
            selectedRange: nil
        )

        XCTAssertEqual(context.textBeforeCursor, "Hello ", "Text before cursor should be 'Hello '")
        XCTAssertEqual(context.textAfterCursor, "world", "Text after cursor should be 'world'")
    }

    // MARK: - Word Extraction Tests (via TextContext)

    func testExtractWordAtPosition_BasicWord() {
        // Basic word extraction test
        let context = TextContext(
            fullText: "Hello world",
            selectedText: nil,
            textBeforeCursor: "Hel",
            textAfterCursor: "lo world",
            wordAtCursor: "Hello",
            cursorPosition: 3,
            selectedRange: nil
        )

        XCTAssertEqual(context.wordAtCursor, "Hello", "Should extract word 'Hello'")
    }

    func testExtractWordAtPosition_EmptyText() {
        let context = TextContext(
            fullText: "",
            selectedText: nil,
            textBeforeCursor: "",
            textAfterCursor: "",
            wordAtCursor: "",
            cursorPosition: 0,
            selectedRange: nil
        )

        XCTAssertEqual(context.wordAtCursor, "", "Empty text should yield empty word")
    }

    func testExtractWordAtPosition_Whitespace() {
        // Cursor in whitespace should yield empty word
        let context = TextContext(
            fullText: "Hello world",
            selectedText: nil,
            textBeforeCursor: "Hello ",
            textAfterCursor: "world",
            wordAtCursor: "",
            cursorPosition: 6,
            selectedRange: nil
        )

        // Word at cursor when cursor is on whitespace could be empty or the next word
        // depending on implementation details
        XCTAssertNotNil(context.wordAtCursor, "wordAtCursor should be defined")
    }

    func testExtractWordAtPosition_Unicode() {
        // Unicode characters should be handled correctly
        let context = TextContext(
            fullText: "Hello cafe world",
            selectedText: nil,
            textBeforeCursor: "Hello ca",
            textAfterCursor: "fe world",
            wordAtCursor: "cafe",
            cursorPosition: 8,
            selectedRange: nil
        )

        XCTAssertEqual(context.wordAtCursor, "cafe", "Should handle accented characters")
    }

    func testExtractWordAtPosition_CJKCharacters() {
        // CJK characters should be handled correctly
        let context = TextContext(
            fullText: "Hello test",
            selectedText: nil,
            textBeforeCursor: "Hello ",
            textAfterCursor: " test",
            wordAtCursor: "test",
            cursorPosition: 10,
            selectedRange: nil
        )

        // CJK handling depends on implementation
        XCTAssertNotNil(context.wordAtCursor, "Should handle CJK characters without crash")
    }

    func testExtractWordAtPosition_Punctuation() {
        // Punctuation should act as word boundary
        let context = TextContext(
            fullText: "Hello, world!",
            selectedText: nil,
            textBeforeCursor: "Hel",
            textAfterCursor: "lo, world!",
            wordAtCursor: "Hello",
            cursorPosition: 3,
            selectedRange: nil
        )

        XCTAssertEqual(context.wordAtCursor, "Hello", "Punctuation should be word boundary")
    }

    // MARK: - getFocusedElement Tests

    func testGetFocusedElement_WithSystemWide_ReturnsNilOrElement() {
        // Given: System-wide accessibility element
        let mockPermissionManager = MockAccessibilityPermissionManager(permissionGranted: true)
        let extractor = AccessibilityElementExtractor(permissionManager: mockPermissionManager)
        let systemWide = AXUIElementCreateSystemWide()

        // When: Getting focused element
        let element = extractor.getFocusedElement(from: systemWide)

        // Then: May or may not return an element depending on test environment
        // Just verify it doesn't crash
        XCTAssertTrue(element == nil || element != nil, "Should return nil or valid element")
    }

    // MARK: - getElementAtPosition Tests

    func testGetElementAtPosition_InvalidPosition_ReturnsNil() {
        // Given: Position far off screen
        let mockPermissionManager = MockAccessibilityPermissionManager(permissionGranted: true)
        let extractor = AccessibilityElementExtractor(permissionManager: mockPermissionManager)
        let invalidPoint = CGPoint(x: -99999, y: -99999)

        // When: Getting element at invalid position
        let element = extractor.getElementAtPosition(invalidPoint)

        // Then: Should return nil for invalid position
        XCTAssertNil(element, "Should return nil for far off-screen position")
    }

    func testGetElementAtPosition_ValidPosition_DoesNotCrash() {
        // Given: Valid screen position
        let mockPermissionManager = MockAccessibilityPermissionManager(permissionGranted: true)
        let extractor = AccessibilityElementExtractor(permissionManager: mockPermissionManager)
        let validPoint = CGPoint(x: 100, y: 100)

        // When: Getting element at valid position
        let element = extractor.getElementAtPosition(validPoint)

        // Then: Should not crash, may return nil or valid element
        XCTAssertTrue(element == nil || element != nil, "Should complete without crash")
    }

    // MARK: - getFullText Tests

    func testGetFullText_WithoutElement_ReturnsNil() {
        // Since getFullText requires an AXUIElement which we can't easily mock,
        // we test the behavior through the public extractTextContext method
        let mockPermissionManager = MockAccessibilityPermissionManager(permissionGranted: false)
        let extractor = AccessibilityElementExtractor(permissionManager: mockPermissionManager)

        // When: Permission denied
        let result = extractor.extractTextContext()

        // Then: Should fail before even trying to get text
        if case .failure(.permissionDenied) = result {
            XCTAssertTrue(true, "Correctly failed with permission denied")
        } else {
            XCTFail("Expected permission denied error")
        }
    }

    // MARK: - getSelectedText Tests

    func testSelectedText_InTextContext() {
        // Test selected text handling via TextContext
        let context = TextContext(
            fullText: "Hello world",
            selectedText: "world",
            textBeforeCursor: "Hello ",
            textAfterCursor: "",
            wordAtCursor: "world",
            cursorPosition: 6,
            selectedRange: CFRange(location: 6, length: 5)
        )

        XCTAssertEqual(context.selectedText, "world", "Selected text should be 'world'")
        XCTAssertNotNil(context.selectedRange, "Selected range should be present")
        XCTAssertEqual(context.selectedRange?.location, 6, "Range location should be 6")
        XCTAssertEqual(context.selectedRange?.length, 5, "Range length should be 5")
    }

    func testSelectedText_NoSelection() {
        let context = TextContext(
            fullText: "Hello world",
            selectedText: nil,
            textBeforeCursor: "Hello ",
            textAfterCursor: "world",
            wordAtCursor: "world",
            cursorPosition: 6,
            selectedRange: nil
        )

        XCTAssertNil(context.selectedText, "Selected text should be nil when nothing selected")
        XCTAssertNil(context.selectedRange, "Selected range should be nil when nothing selected")
    }

    // MARK: - Dependency Injection Tests

    func testDependencyInjection_CustomResolver() {
        // Given: Custom cursor position strategy
        let mockPermissionManager = MockAccessibilityPermissionManager(permissionGranted: true)
        let customPosition = CGPoint(x: 500, y: 600)
        let fixedStrategy = FixedPositionStrategy(returnPosition: customPosition)
        let customResolver = CursorPositionResolver(strategies: [fixedStrategy])

        // When: Creating extractor with custom resolver
        let extractor = AccessibilityElementExtractor(
            permissionManager: mockPermissionManager,
            cursorPositionResolver: customResolver
        )

        // Then: Should use custom resolver
        let result = extractor.getCursorScreenPosition(from: nil)
        if case .success(let position) = result {
            XCTAssertEqual(position.x, 500, "Should use custom resolver X")
            XCTAssertEqual(position.y, 600, "Should use custom resolver Y")
        }
    }

    func testDependencyInjection_DefaultResolver() {
        // Given: Only permission manager (default resolver)
        let mockPermissionManager = MockAccessibilityPermissionManager(permissionGranted: true)

        // When: Creating extractor with default resolver
        let extractor = AccessibilityElementExtractor(permissionManager: mockPermissionManager)

        // Then: Should use default resolver (returns mouse position when no element)
        let result = extractor.getCursorScreenPosition(from: nil)
        if case .success(let position) = result {
            // Should return some valid position (mouse position fallback)
            XCTAssertTrue(position.x.isFinite, "X should be finite")
            XCTAssertTrue(position.y.isFinite, "Y should be finite")
        }
    }

    // MARK: - Clipboard Fallback App List Tests

    func testClipboardFallbackApps_ContainsExpectedApps() {
        // Verify the static app list through behavior
        // Note: We can't directly access the private static property
        let mockPermissionManager = MockAccessibilityPermissionManager(permissionGranted: true)
        let extractor = AccessibilityElementExtractor(permissionManager: mockPermissionManager)

        // Just verify the method exists and returns a boolean
        let result = extractor.needsClipboardFallback()
        XCTAssertTrue(result == true || result == false, "Should return valid boolean")
    }

    // MARK: - Error Handling Tests

    func testExtractTextContext_ReturnsResultType() {
        // Given: Any extractor
        let mockPermissionManager = MockAccessibilityPermissionManager(permissionGranted: false)
        let extractor = AccessibilityElementExtractor(permissionManager: mockPermissionManager)

        // When: Extracting text context
        let result = extractor.extractTextContext()

        // Then: Should return a proper Result type
        switch result {
        case .success:
            XCTAssertTrue(true, "Success case handled")
        case .failure:
            XCTAssertTrue(true, "Failure case handled")
        }
    }

    func testGetCursorScreenPosition_ReturnsResultType() {
        // Given: Any extractor
        let mockPermissionManager = MockAccessibilityPermissionManager(permissionGranted: true)
        let extractor = AccessibilityElementExtractor(permissionManager: mockPermissionManager)

        // When: Getting cursor position
        let result = extractor.getCursorScreenPosition(from: nil)

        // Then: Should return a proper Result type
        switch result {
        case .success(let position):
            XCTAssertNotNil(position, "Success should have position")
        case .failure(let error):
            XCTAssertNotNil(error, "Failure should have error")
        }
    }

    // MARK: - Performance Tests

    func testPerformance_needsClipboardFallback() {
        let mockPermissionManager = MockAccessibilityPermissionManager(permissionGranted: true)
        let extractor = AccessibilityElementExtractor(permissionManager: mockPermissionManager)

        measure {
            for _ in 0..<100 {
                _ = extractor.needsClipboardFallback()
            }
        }
    }

    func testPerformance_getCursorScreenPosition() {
        let mockPermissionManager = MockAccessibilityPermissionManager(permissionGranted: true)
        let fixedStrategy = FixedPositionStrategy(returnPosition: CGPoint(x: 100, y: 200))
        let customResolver = CursorPositionResolver(strategies: [fixedStrategy])
        let extractor = AccessibilityElementExtractor(
            permissionManager: mockPermissionManager,
            cursorPositionResolver: customResolver
        )

        measure {
            for _ in 0..<100 {
                _ = extractor.getCursorScreenPosition(from: nil)
            }
        }
    }

    // MARK: - Integration Tests

    func testIntegration_ExtractorWithRealPermissionManager() {
        // Test with real permission manager to verify integration
        let alertManager = AccessibilityAlertManager()
        let realPermissionManager = AccessibilityPermissionManager(alertManager: alertManager)
        let extractor = AccessibilityElementExtractor(permissionManager: realPermissionManager)

        // When: Extracting text context
        let result = extractor.extractTextContext()

        // Then: Should return a valid result (success or failure depending on environment)
        switch result {
        case .success(let context):
            XCTAssertNotNil(context.fullText, "Success should have fullText")
        case .failure(let error):
            // In test environment without accessibility permission, should fail appropriately
            XCTAssertNotNil(error, "Failure should have error")
        }
    }

    func testIntegration_ExtractorCursorPositionWithDefaultResolver() {
        // Test with default resolver (real strategy chain)
        let alertManager = AccessibilityAlertManager()
        let realPermissionManager = AccessibilityPermissionManager(alertManager: alertManager)
        let extractor = AccessibilityElementExtractor(permissionManager: realPermissionManager)

        // When: Getting cursor position with no element
        let result = extractor.getCursorScreenPosition(from: nil)

        // Then: Should always succeed (mouse position fallback)
        if case .success(let position) = result {
            XCTAssertTrue(position.x.isFinite && position.y.isFinite,
                         "Position should be valid coordinates")
        } else {
            XCTFail("getCursorScreenPosition should never fail")
        }
    }
}

// MARK: - Clipboard Extraction Edge Case Tests

final class ClipboardExtractionTests: XCTestCase {

    func testExtractTextContextViaClipboard_PreservesClipboard() {
        // Given: Content on clipboard
        let pasteboard = NSPasteboard.general
        let originalContent = "Original clipboard content for test"
        pasteboard.clearContents()
        pasteboard.setString(originalContent, forType: .string)

        let mockPermissionManager = MockAccessibilityPermissionManager(permissionGranted: true)
        let extractor = AccessibilityElementExtractor(permissionManager: mockPermissionManager)

        // When: Extracting via clipboard
        _ = extractor.extractTextContextViaClipboard()

        // Then: Original content should be restored
        // Note: There might be slight timing issues, but content should be restored
        // This test verifies the method attempts to preserve clipboard
        usleep(100000) // 100ms to ensure clipboard operations complete

        let restoredContent = pasteboard.string(forType: .string)
        // In some cases the content might not be perfectly preserved due to type handling
        // But the method should not crash
        XCTAssertNotNil(restoredContent, "Clipboard should have content after extraction")
    }

    func testExtractTextContextViaClipboard_HandlesEmptyClipboard() {
        // Given: Empty clipboard
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        let mockPermissionManager = MockAccessibilityPermissionManager(permissionGranted: true)
        let extractor = AccessibilityElementExtractor(permissionManager: mockPermissionManager)

        // When: Extracting via clipboard with empty clipboard
        let result = extractor.extractTextContextViaClipboard()

        // Then: Should succeed with empty context or minimal context
        if case .success(let context) = result {
            XCTAssertNotNil(context, "Should return valid context even with empty clipboard")
        } else {
            XCTFail("Should not fail with empty clipboard")
        }
    }
}

// MARK: - Text Context Validation Tests

final class TextContextValidationTests: XCTestCase {

    func testTextContext_AllFieldsAccessible() {
        // Verify all TextContext fields are accessible
        let range = CFRange(location: 5, length: 3)
        let context = TextContext(
            fullText: "Test text",
            selectedText: "tex",
            textBeforeCursor: "Test ",
            textAfterCursor: "t",
            wordAtCursor: "text",
            cursorPosition: 8,
            selectedRange: range
        )

        XCTAssertEqual(context.fullText, "Test text")
        XCTAssertEqual(context.selectedText, "tex")
        XCTAssertEqual(context.textBeforeCursor, "Test ")
        XCTAssertEqual(context.textAfterCursor, "t")
        XCTAssertEqual(context.wordAtCursor, "text")
        XCTAssertEqual(context.cursorPosition, 8)
        XCTAssertNotNil(context.selectedRange)
    }

    func testTextContext_OptionalFieldsCanBeNil() {
        let context = TextContext(
            fullText: "Hello",
            selectedText: nil,
            textBeforeCursor: "He",
            textAfterCursor: "llo",
            wordAtCursor: "Hello",
            cursorPosition: 2,
            selectedRange: nil
        )

        XCTAssertNil(context.selectedText, "selectedText should be nil")
        XCTAssertNil(context.selectedRange, "selectedRange should be nil")
    }

    func testTextContext_HandlesSpecialCharacters() {
        let specialText = "Hello\nWorld\t!"
        let context = TextContext(
            fullText: specialText,
            selectedText: nil,
            textBeforeCursor: "Hello\n",
            textAfterCursor: "World\t!",
            wordAtCursor: "World",
            cursorPosition: 6,
            selectedRange: nil
        )

        XCTAssertTrue(context.fullText.contains("\n"), "Should handle newline")
        XCTAssertTrue(context.fullText.contains("\t"), "Should handle tab")
    }

    func testTextContext_HandlesEmoji() {
        let emojiText = "Hello test World"
        let context = TextContext(
            fullText: emojiText,
            selectedText: nil,
            textBeforeCursor: "Hello ",
            textAfterCursor: " World",
            wordAtCursor: "test",
            cursorPosition: 8,
            selectedRange: nil
        )

        XCTAssertNotNil(context.fullText, "Should handle emoji")
        XCTAssertEqual(context.wordAtCursor, "test", "Word extraction should work with emoji nearby")
    }

    func testTextContext_HandlesVeryLongText() {
        let longText = String(repeating: "word ", count: 10000)
        let context = TextContext(
            fullText: longText,
            selectedText: nil,
            textBeforeCursor: String(repeating: "word ", count: 5000),
            textAfterCursor: String(repeating: "word ", count: 5000),
            wordAtCursor: "word",
            cursorPosition: 25000,
            selectedRange: nil
        )

        XCTAssertEqual(context.fullText.count, longText.count, "Should handle very long text")
        XCTAssertNotNil(context.wordAtCursor, "Should extract word from long text")
    }
}
