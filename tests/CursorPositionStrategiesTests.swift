import XCTest
import Cocoa
@testable import Complete

// MARK: - Mock Strategy for Testing

/// Mock strategy that returns a predetermined position or nil
final class MockCursorPositionStrategy: CursorPositionStrategy {
    let name: String
    let returnPosition: CGPoint?
    var getCursorPositionCallCount = 0

    init(name: String, returnPosition: CGPoint?) {
        self.name = name
        self.returnPosition = returnPosition
    }

    func getCursorPosition(from element: AXUIElement?) -> CGPoint? {
        getCursorPositionCallCount += 1
        return returnPosition
    }
}

// MARK: - CoordinateConverter Tests

final class CoordinateConverterTests: XCTestCase {

    var converter: CoordinateConverter!

    override func setUp() {
        super.setUp()
        converter = CoordinateConverter()
    }

    // MARK: - accessibilityToNSScreen Tests

    func testAccessibilityToNSScreen_BasicConversion() {
        // Given: A point at (100, 50) in Accessibility coords (top-left origin)
        // On a screen of height 1000 at origin (0, 0)
        guard let screen = NSScreen.main else {
            XCTSkip("No screen available for testing")
            return
        }

        let accessibilityPoint = CGPoint(x: 100, y: 50)

        // When: Converting to NSScreen coordinates
        let nsPoint = converter.accessibilityToNSScreen(accessibilityPoint, containingScreen: screen)

        // Then: X should be unchanged, Y should be flipped
        XCTAssertEqual(nsPoint.x, 100, "X coordinate should remain unchanged")

        // Y conversion: screenOriginY + (screenHeight - accessibilityY)
        let expectedY = screen.frame.origin.y + (screen.frame.height - 50)
        XCTAssertEqual(nsPoint.y, expectedY, accuracy: 0.001, "Y should be converted from top-left to bottom-left origin")
    }

    func testAccessibilityToNSScreen_OriginPoint() {
        guard let screen = NSScreen.main else {
            XCTSkip("No screen available for testing")
            return
        }

        // Given: Origin in Accessibility coords (0, 0) = top-left of screen
        let accessibilityPoint = CGPoint(x: 0, y: 0)

        // When: Converting
        let nsPoint = converter.accessibilityToNSScreen(accessibilityPoint, containingScreen: screen)

        // Then: Should map to bottom-right of screen height
        XCTAssertEqual(nsPoint.x, 0, "X should be 0")
        let expectedY = screen.frame.origin.y + screen.frame.height
        XCTAssertEqual(nsPoint.y, expectedY, accuracy: 0.001, "Y=0 in accessibility should map to screen height in NSScreen")
    }

    func testAccessibilityToNSScreen_BottomOfScreen() {
        guard let screen = NSScreen.main else {
            XCTSkip("No screen available for testing")
            return
        }

        // Given: Point at bottom of screen in Accessibility coords
        let accessibilityPoint = CGPoint(x: 100, y: screen.frame.height)

        // When: Converting
        let nsPoint = converter.accessibilityToNSScreen(accessibilityPoint, containingScreen: screen)

        // Then: Should map to Y=screenOriginY (bottom in NSScreen)
        let expectedY = screen.frame.origin.y
        XCTAssertEqual(nsPoint.y, expectedY, accuracy: 0.001, "Bottom in accessibility should map to screen origin Y in NSScreen")
    }

    // MARK: - nsScreenToAccessibility Tests

    func testNSScreenToAccessibility_BasicConversion() {
        guard let screen = NSScreen.main else {
            XCTSkip("No screen available for testing")
            return
        }

        let nsPoint = CGPoint(x: 100, y: screen.frame.origin.y + 50)

        // When: Converting to Accessibility coordinates
        let accessibilityPoint = converter.nsScreenToAccessibility(nsPoint, containingScreen: screen)

        // Then: X should be unchanged, Y should be flipped
        XCTAssertEqual(accessibilityPoint.x, 100, "X coordinate should remain unchanged")

        // Y conversion: screenHeight - (nsPointY - screenOriginY)
        let expectedY = screen.frame.height - (nsPoint.y - screen.frame.origin.y)
        XCTAssertEqual(accessibilityPoint.y, expectedY, accuracy: 0.001)
    }

    func testRoundTripConversion() {
        guard let screen = NSScreen.main else {
            XCTSkip("No screen available for testing")
            return
        }

        // Given: An arbitrary point
        let originalAccessibilityPoint = CGPoint(x: 250, y: 300)

        // When: Converting accessibility → NSScreen → accessibility
        let nsPoint = converter.accessibilityToNSScreen(originalAccessibilityPoint, containingScreen: screen)
        let roundTripPoint = converter.nsScreenToAccessibility(nsPoint, containingScreen: screen)

        // Then: Should get back the original point
        XCTAssertEqual(roundTripPoint.x, originalAccessibilityPoint.x, accuracy: 0.001)
        XCTAssertEqual(roundTripPoint.y, originalAccessibilityPoint.y, accuracy: 0.001)
    }

    // MARK: - findContainingScreen Tests

    func testFindContainingScreen_PointOnMainScreen() {
        guard let mainScreen = NSScreen.main else {
            XCTSkip("No main screen available")
            return
        }

        // Given: A point within the main screen bounds (in accessibility coords)
        let point = CGPoint(x: mainScreen.frame.midX, y: mainScreen.frame.height / 2)

        // When: Finding containing screen
        let containingScreen = converter.findContainingScreen(for: point)

        // Then: Should find the main screen
        XCTAssertNotNil(containingScreen, "Should find a screen for point within bounds")
    }

    func testFindContainingScreen_PointOutsideAllScreens() {
        // Given: A point far outside any screen bounds
        let point = CGPoint(x: -99999, y: -99999)

        // When: Finding containing screen
        let containingScreen = converter.findContainingScreen(for: point)

        // Then: Should return nil
        XCTAssertNil(containingScreen, "Should return nil for point outside all screens")
    }

    func testFindContainingScreen_PointAtOrigin() {
        // Given: Point at origin (might be on screen or not depending on setup)
        let point = CGPoint(x: 0, y: 0)

        // When: Finding containing screen
        let containingScreen = converter.findContainingScreen(for: point)

        // Then: May or may not find a screen - just verify no crash
        // If there's a screen at origin, it should be found
        if let screen = containingScreen {
            XCTAssertTrue(screen.frame.origin.x <= 0, "Found screen should contain origin")
        }
    }
}

// MARK: - Strategy Tests

final class CursorPositionStrategyTests: XCTestCase {

    // MARK: - MousePositionStrategy Tests

    func testMousePositionStrategy_Name() {
        let strategy = MousePositionStrategy()
        XCTAssertEqual(strategy.name, "MousePosition")
    }

    func testMousePositionStrategy_AlwaysReturnsPosition() {
        let strategy = MousePositionStrategy()

        // When: Getting cursor position (element is ignored)
        let position = strategy.getCursorPosition(from: nil)

        // Then: Should always return a valid position (mouse location)
        XCTAssertNotNil(position, "MousePositionStrategy should always return a position")
    }

    func testMousePositionStrategy_ReturnsValidCoordinates() {
        let strategy = MousePositionStrategy()

        let position = strategy.getCursorPosition(from: nil)

        XCTAssertNotNil(position)
        // Mouse position should be within reasonable screen bounds
        // (allowing for negative values on multi-monitor setups)
        XCTAssertTrue(position!.x >= -10000 && position!.x <= 10000, "X should be within reasonable bounds")
        XCTAssertTrue(position!.y >= -10000 && position!.y <= 10000, "Y should be within reasonable bounds")
    }

    // MARK: - BoundsForRangeStrategy Tests

    func testBoundsForRangeStrategy_Name() {
        let strategy = BoundsForRangeStrategy()
        XCTAssertEqual(strategy.name, "BoundsForRange")
    }

    func testBoundsForRangeStrategy_ReturnsNilForNilElement() {
        let strategy = BoundsForRangeStrategy()

        // When: Calling with nil element
        let position = strategy.getCursorPosition(from: nil)

        // Then: Should return nil (graceful handling)
        XCTAssertNil(position, "Should return nil when element is nil")
    }

    // MARK: - ElementPositionStrategy Tests

    func testElementPositionStrategy_Name() {
        let strategy = ElementPositionStrategy()
        XCTAssertEqual(strategy.name, "ElementPosition")
    }

    func testElementPositionStrategy_ReturnsNilForNilElement() {
        let strategy = ElementPositionStrategy()

        // When: Calling with nil element
        let position = strategy.getCursorPosition(from: nil)

        // Then: Should return nil (graceful handling)
        XCTAssertNil(position, "Should return nil when element is nil")
    }
}

// MARK: - CursorPositionResolver Tests

final class CursorPositionResolverTests: XCTestCase {

    func testDefaultInitialization() {
        // When: Creating resolver with default init
        let resolver = CursorPositionResolver()

        // Then: Should resolve to mouse position when no element provided
        // (since we can't provide a real AXUIElement in tests)
        let position = resolver.resolve(from: nil)

        // Verify we got a valid position (will be mouse position as fallback)
        XCTAssertTrue(position.x >= -10000 && position.x <= 10000)
        XCTAssertTrue(position.y >= -10000 && position.y <= 10000)
    }

    func testCustomStrategies_FirstSuccessfulWins() {
        // Given: Custom strategies where first succeeds
        let successStrategy = MockCursorPositionStrategy(name: "Success", returnPosition: CGPoint(x: 100, y: 200))
        let failStrategy = MockCursorPositionStrategy(name: "Fail", returnPosition: nil)

        let resolver = CursorPositionResolver(strategies: [successStrategy, failStrategy])

        // When: Resolving
        let position = resolver.resolve(from: nil)

        // Then: Should use first strategy's result
        XCTAssertEqual(position.x, 100)
        XCTAssertEqual(position.y, 200)
        XCTAssertEqual(successStrategy.getCursorPositionCallCount, 1)
        XCTAssertEqual(failStrategy.getCursorPositionCallCount, 0, "Second strategy should not be called")
    }

    func testCustomStrategies_FallsBackOnFailure() {
        // Given: First strategy fails, second succeeds
        let failStrategy = MockCursorPositionStrategy(name: "Fail", returnPosition: nil)
        let successStrategy = MockCursorPositionStrategy(name: "Success", returnPosition: CGPoint(x: 300, y: 400))

        let resolver = CursorPositionResolver(strategies: [failStrategy, successStrategy])

        // When: Resolving
        let position = resolver.resolve(from: nil)

        // Then: Should fall back to second strategy
        XCTAssertEqual(position.x, 300)
        XCTAssertEqual(position.y, 400)
        XCTAssertEqual(failStrategy.getCursorPositionCallCount, 1)
        XCTAssertEqual(successStrategy.getCursorPositionCallCount, 1)
    }

    func testCustomStrategies_AllFailFallsBackToMouse() {
        // Given: All custom strategies fail
        let fail1 = MockCursorPositionStrategy(name: "Fail1", returnPosition: nil)
        let fail2 = MockCursorPositionStrategy(name: "Fail2", returnPosition: nil)

        let resolver = CursorPositionResolver(strategies: [fail1, fail2])

        // When: Resolving
        let position = resolver.resolve(from: nil)

        // Then: Should return mouse position as ultimate fallback
        // (hardcoded fallback in resolve method)
        XCTAssertTrue(position.x >= -10000 && position.x <= 10000)
        XCTAssertTrue(position.y >= -10000 && position.y <= 10000)
        XCTAssertEqual(fail1.getCursorPositionCallCount, 1)
        XCTAssertEqual(fail2.getCursorPositionCallCount, 1)
    }

    func testStrategyExecutionOrder() {
        // Given: Multiple strategies to verify execution order
        var executionOrder: [String] = []

        class OrderTrackingStrategy: CursorPositionStrategy {
            let name: String
            let returnPosition: CGPoint?
            let orderTracker: (String) -> Void

            init(name: String, returnPosition: CGPoint?, orderTracker: @escaping (String) -> Void) {
                self.name = name
                self.returnPosition = returnPosition
                self.orderTracker = orderTracker
            }

            func getCursorPosition(from element: AXUIElement?) -> CGPoint? {
                orderTracker(name)
                return returnPosition
            }
        }

        let strategy1 = OrderTrackingStrategy(name: "First", returnPosition: nil) { executionOrder.append($0) }
        let strategy2 = OrderTrackingStrategy(name: "Second", returnPosition: nil) { executionOrder.append($0) }
        let strategy3 = OrderTrackingStrategy(name: "Third", returnPosition: CGPoint(x: 1, y: 1)) { executionOrder.append($0) }

        let resolver = CursorPositionResolver(strategies: [strategy1, strategy2, strategy3])

        // When: Resolving
        _ = resolver.resolve(from: nil)

        // Then: Should execute in order until one succeeds
        XCTAssertEqual(executionOrder, ["First", "Second", "Third"])
    }

    func testResolverStopsAfterFirstSuccess() {
        var executionOrder: [String] = []

        class OrderTrackingStrategy: CursorPositionStrategy {
            let name: String
            let returnPosition: CGPoint?
            let orderTracker: (String) -> Void

            init(name: String, returnPosition: CGPoint?, orderTracker: @escaping (String) -> Void) {
                self.name = name
                self.returnPosition = returnPosition
                self.orderTracker = orderTracker
            }

            func getCursorPosition(from element: AXUIElement?) -> CGPoint? {
                orderTracker(name)
                return returnPosition
            }
        }

        // First strategy succeeds - others should not be called
        let strategy1 = OrderTrackingStrategy(name: "First", returnPosition: CGPoint(x: 0, y: 0)) { executionOrder.append($0) }
        let strategy2 = OrderTrackingStrategy(name: "Second", returnPosition: nil) { executionOrder.append($0) }

        let resolver = CursorPositionResolver(strategies: [strategy1, strategy2])

        // When: Resolving
        _ = resolver.resolve(from: nil)

        // Then: Should stop after first success
        XCTAssertEqual(executionOrder, ["First"])
    }
}

// MARK: - Integration Tests

final class CursorPositionIntegrationTests: XCTestCase {

    func testDefaultResolverWithNilElement() {
        // Given: Default resolver
        let resolver = CursorPositionResolver()

        // When: Resolving with no element
        let position = resolver.resolve(from: nil)

        // Then: Should return a valid position (mouse fallback)
        XCTAssertNotNil(position)
    }

    func testCoordinateConverterRoundTrip() {
        guard let screen = NSScreen.main else {
            XCTSkip("No screen available")
            return
        }

        let converter = CoordinateConverter()

        // Test multiple points
        let testPoints = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 100, y: 100),
            CGPoint(x: screen.frame.width / 2, y: screen.frame.height / 2),
            CGPoint(x: screen.frame.width - 1, y: screen.frame.height - 1)
        ]

        for originalPoint in testPoints {
            // Convert and back
            let nsPoint = converter.accessibilityToNSScreen(originalPoint, containingScreen: screen)
            let roundTrip = converter.nsScreenToAccessibility(nsPoint, containingScreen: screen)

            XCTAssertEqual(roundTrip.x, originalPoint.x, accuracy: 0.001, "X should survive round trip for \(originalPoint)")
            XCTAssertEqual(roundTrip.y, originalPoint.y, accuracy: 0.001, "Y should survive round trip for \(originalPoint)")
        }
    }
}
