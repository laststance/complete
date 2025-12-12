import Cocoa
import ApplicationServices
import os.log

// MARK: - Coordinate Conversion Utility

/// Handles coordinate system conversion between Accessibility API and NSScreen.
///
/// ## Coordinate Systems
/// - **Accessibility API**: Top-left origin, Y increases downward
/// - **NSScreen**: Bottom-left origin, Y increases upward
///
/// This utility encapsulates the conversion logic that was previously duplicated
/// across multiple locations in getCursorScreenPosition.
///
/// ## Example
/// ```swift
/// let converter = CoordinateConverter()
/// let nsPoint = converter.accessibilityToNSScreen(
///     CGPoint(x: 100, y: 50),
///     containingScreen: NSScreen.main!
/// )
/// ```
struct CoordinateConverter {

    /// Converts a point from Accessibility coordinates to NSScreen coordinates.
    ///
    /// - Parameters:
    ///   - point: Point in Accessibility coordinate system (top-left origin)
    ///   - screen: The screen containing this point
    /// - Returns: Point in NSScreen coordinate system (bottom-left origin)
    func accessibilityToNSScreen(_ point: CGPoint, containingScreen screen: NSScreen) -> CGPoint {
        let screenHeight = screen.frame.height
        let screenOriginY = screen.frame.origin.y
        let nsScreenY = screenOriginY + (screenHeight - point.y)
        return CGPoint(x: point.x, y: nsScreenY)
    }

    /// Converts a point from NSScreen coordinates to Accessibility coordinates.
    ///
    /// - Parameters:
    ///   - point: Point in NSScreen coordinate system (bottom-left origin)
    ///   - screen: The screen containing this point
    /// - Returns: Point in Accessibility coordinate system (top-left origin)
    func nsScreenToAccessibility(_ point: CGPoint, containingScreen screen: NSScreen) -> CGPoint {
        let screenHeight = screen.frame.height
        let accessibilityY = screenHeight - (point.y - screen.frame.origin.y)
        return CGPoint(x: point.x, y: accessibilityY)
    }

    /// Finds the screen containing the given Accessibility coordinate point.
    ///
    /// - Parameter accessibilityPoint: Point in Accessibility coordinates
    /// - Returns: The NSScreen containing this point, or nil if not found
    func findContainingScreen(for accessibilityPoint: CGPoint) -> NSScreen? {
        return NSScreen.screens.first { screen in
            let screenMinX = screen.frame.origin.x
            let screenMaxX = screen.frame.origin.x + screen.frame.width
            let screenMinY: CGFloat = 0
            let screenMaxY = screen.frame.height

            let containsX = accessibilityPoint.x >= screenMinX && accessibilityPoint.x <= screenMaxX
            let containsY = accessibilityPoint.y >= screenMinY && accessibilityPoint.y <= screenMaxY

            return containsX && containsY
        }
    }
}

// MARK: - Strategy Protocol

/// Protocol for cursor position detection strategies.
///
/// Each strategy implements a different approach to finding the cursor's screen position.
/// Strategies are tried in order of accuracy (most accurate first) by the CursorPositionResolver.
///
/// ## Strategy Ordering (by accuracy)
/// 1. BoundsForRangeStrategy - Uses AXBoundsForRange for precise cursor bounds
/// 2. ElementPositionStrategy - Uses element's AXPosition attribute
/// 3. MousePositionStrategy - Falls back to mouse cursor position
protocol CursorPositionStrategy {
    /// Human-readable name for logging and debugging
    var name: String { get }

    /// Attempts to get cursor screen position using this strategy.
    ///
    /// - Parameter element: The focused AXUIElement (may be nil for some strategies)
    /// - Returns: Screen position in NSScreen coordinates, or nil if strategy cannot determine position
    func getCursorPosition(from element: AXUIElement?) -> CGPoint?
}

// MARK: - Strategy Implementations

/// Most accurate strategy: Uses AXBoundsForRange to get precise cursor bounds.
///
/// This strategy reads the selected text range and queries for its screen bounds.
/// Works best with native text fields that fully support Accessibility API.
///
/// ## When This Works
/// - Native macOS apps (TextEdit, Notes, Mail)
/// - Apps with proper Accessibility support
///
/// ## When This Fails
/// - Web browsers (bounds may be incorrect)
/// - Apps with limited Accessibility support
final class BoundsForRangeStrategy: CursorPositionStrategy {
    let name = "BoundsForRange"
    private let converter = CoordinateConverter()

    func getCursorPosition(from element: AXUIElement?) -> CGPoint? {
        guard let element = element else {
            os_log("⚠️  [%{public}@] No element provided", log: .accessibility, type: .debug, name)
            return nil
        }

        // Get selected text range
        var selectedRangeValue: CFTypeRef?
        let rangeResult = AXUIElementCopyAttributeValue(
            element,
            kAXSelectedTextRangeAttribute as CFString,
            &selectedRangeValue
        )

        guard rangeResult == .success,
              let rangeValue = selectedRangeValue else {
            os_log("⚠️  [%{public}@] Could not get selected text range", log: .accessibility, type: .debug, name)
            return nil
        }

        // kAXSelectedTextRangeAttribute returns AXValue per API contract
        // AXValueGetValue validates the type internally
        let axValue = rangeValue as! AXValue
        var range = CFRange()
        guard AXValueGetValue(axValue, .cfRange, &range) else {
            os_log("⚠️  [%{public}@] Could not extract CFRange", log: .accessibility, type: .debug, name)
            return nil
        }

        os_log("📍 [%{public}@] Selected range: location=%{public}d, length=%{public}d",
               log: .accessibility, type: .debug, name, range.location, range.length)

        // Create AXValue for the range parameter
        var mutableRange = range
        guard let rangeAXValue = AXValueCreate(.cfRange, &mutableRange) else {
            os_log("⚠️  [%{public}@] Could not create AXValue for range", log: .accessibility, type: .debug, name)
            return nil
        }

        // Get bounds for this range
        var boundsValue: CFTypeRef?
        let boundsResult = AXUIElementCopyParameterizedAttributeValue(
            element,
            kAXBoundsForRangeParameterizedAttribute as CFString,
            rangeAXValue,
            &boundsValue
        )

        guard boundsResult == .success,
              let bounds = boundsValue else {
            os_log("⚠️  [%{public}@] Could not get bounds for range", log: .accessibility, type: .debug, name)
            return nil
        }

        // kAXBoundsForRangeParameterizedAttribute returns AXValue per API contract
        // AXValueGetValue validates the type internally
        let boundsAXValue = bounds as! AXValue
        var rect = CGRect.zero
        guard AXValueGetValue(boundsAXValue, .cgRect, &rect) else {
            os_log("⚠️  [%{public}@] Could not extract CGRect from bounds", log: .accessibility, type: .debug, name)
            return nil
        }

        os_log("📍 [%{public}@] Cursor bounds (Accessibility): origin(%{public}f, %{public}f) size(%{public}f × %{public}f)",
               log: .accessibility, type: .debug, name, rect.origin.x, rect.origin.y, rect.width, rect.height)

        // Validate bounds - browsers often return invalid coordinates
        if !isValidCursorBounds(rect) {
            os_log("⚠️  [%{public}@] Invalid cursor bounds detected, rejecting", log: .accessibility, type: .debug, name)
            return nil
        }

        // Find the screen containing this cursor position
        let cursorAccessibilityPoint = CGPoint(x: rect.origin.x, y: rect.maxY)
        guard let containingScreen = converter.findContainingScreen(for: cursorAccessibilityPoint)
                ?? NSScreen.main else {
            os_log("⚠️  [%{public}@] Could not find containing screen", log: .accessibility, type: .error, name)
            return nil
        }

        // Convert to NSScreen coordinates
        let cursorPosition = converter.accessibilityToNSScreen(cursorAccessibilityPoint, containingScreen: containingScreen)

        os_log("✅ [%{public}@] Cursor position (NSScreen): (%{public}f, %{public}f)",
               log: .accessibility, type: .debug, name, cursorPosition.x, cursorPosition.y)

        return cursorPosition
    }

    /// Validates cursor bounds to detect browser-specific failures.
    ///
    /// Web browsers often return invalid coordinates for AXBoundsForRange:
    /// - Chrome/Electron may return (0,0) origin
    /// - Some apps return element bounds instead of cursor bounds
    /// - Bounds larger than screen indicate failure
    ///
    /// - Parameter bounds: The CGRect returned by AXBoundsForRange
    /// - Returns: `true` if bounds appear valid, `false` if they should be rejected
    private func isValidCursorBounds(_ bounds: CGRect) -> Bool {
        // Reject if at origin (common failure case for browsers)
        if bounds.origin == .zero && bounds.size.width > 100 {
            os_log("🔍 BoundsForRange: Rejecting bounds at origin with large width (likely element bounds, not cursor)",
                   log: .accessibility, type: .debug)
            return false
        }

        // Reject negative coordinates (should never happen)
        if bounds.origin.x < -10000 || bounds.origin.y < -10000 {
            return false
        }

        // Reject if bounds are unreasonably large (larger than any reasonable screen)
        if bounds.width > 10000 || bounds.height > 10000 {
            return false
        }

        // Reject if bounds are too small to be meaningful
        // A cursor should have at least 1x1 pixel bounds
        if bounds.width < 0.5 && bounds.height < 0.5 {
            return false
        }

        return true
    }
}

/// Fallback strategy: Uses element's AXPosition attribute.
///
/// This strategy reads the top-left corner position of the focused element.
/// Less accurate than BoundsForRange but works with more apps.
///
/// ## Limitation
/// Returns the element's top-left corner, not the actual cursor position.
/// For text fields, this is usually close enough for popup positioning.
final class ElementPositionStrategy: CursorPositionStrategy {
    let name = "ElementPosition"
    private let converter = CoordinateConverter()

    func getCursorPosition(from element: AXUIElement?) -> CGPoint? {
        guard let element = element else {
            os_log("⚠️  [%{public}@] No element provided", log: .accessibility, type: .debug, name)
            return nil
        }

        // Get element position
        var positionValue: CFTypeRef?
        let positionResult = AXUIElementCopyAttributeValue(
            element,
            kAXPositionAttribute as CFString,
            &positionValue
        )

        guard positionResult == .success,
              let position = positionValue else {
            os_log("⚠️  [%{public}@] Could not get element position", log: .accessibility, type: .debug, name)
            return nil
        }

        // Extract CGPoint from AXValue
        let axValue = position as! AXValue
        var point = CGPoint.zero
        guard AXValueGetValue(axValue, .cgPoint, &point) else {
            os_log("⚠️  [%{public}@] Could not extract CGPoint", log: .accessibility, type: .debug, name)
            return nil
        }

        os_log("📍 [%{public}@] Element position (Accessibility): (%{public}f, %{public}f)",
               log: .accessibility, type: .debug, name, point.x, point.y)

        // Find the screen containing this element
        guard let containingScreen = converter.findContainingScreen(for: point)
                ?? NSScreen.main else {
            os_log("⚠️  [%{public}@] Could not find containing screen", log: .accessibility, type: .error, name)
            return nil
        }

        // Convert to NSScreen coordinates
        let convertedPoint = converter.accessibilityToNSScreen(point, containingScreen: containingScreen)

        os_log("✅ [%{public}@] Element position (NSScreen): (%{public}f, %{public}f)",
               log: .accessibility, type: .debug, name, convertedPoint.x, convertedPoint.y)

        return convertedPoint
    }
}

/// Ultimate fallback strategy: Uses mouse cursor position.
///
/// This strategy returns the current mouse position as the cursor position.
/// Works universally but is least accurate for text cursor positioning.
///
/// ## When This Is Used
/// - Web browsers where other strategies fail
/// - Apps with broken Accessibility support
/// - When no focused element is found
final class MousePositionStrategy: CursorPositionStrategy {
    let name = "MousePosition"

    func getCursorPosition(from element: AXUIElement?) -> CGPoint? {
        // Mouse position is already in NSScreen coordinates
        let mousePosition = NSEvent.mouseLocation

        os_log("📍 [%{public}@] Mouse position: (%{public}f, %{public}f)",
               log: .accessibility, type: .debug, name, mousePosition.x, mousePosition.y)

        return mousePosition
    }
}

// MARK: - Strategy Resolver

/// Coordinates multiple cursor position strategies, trying each in order of accuracy.
///
/// The resolver maintains a prioritized list of strategies and returns the first
/// successful result. This implements the Chain of Responsibility pattern.
///
/// ## Browser Support Enhancement
/// Before trying strategies, the resolver enables browser accessibility trees
/// via `BrowserAccessibilityEnabler`. This sets `AXEnhancedUserInterface` for
/// Chrome/Safari and `AXManualAccessibility` for Electron apps, which unlocks
/// their accessibility APIs.
///
/// ## Default Strategy Order
/// 1. BoundsForRangeStrategy (most accurate)
/// 2. ElementPositionStrategy (fallback)
/// 3. MousePositionStrategy (ultimate fallback)
///
/// ## Example
/// ```swift
/// let resolver = CursorPositionResolver()
/// if let position = resolver.resolve(from: focusedElement) {
///     positionPopupWindow(at: position)
/// }
/// ```
final class CursorPositionResolver {
    private let strategies: [CursorPositionStrategy]
    private let converter = CoordinateConverter()
    private let browserEnabler = BrowserAccessibilityEnabler()

    /// Creates a resolver with the default strategy chain.
    init() {
        self.strategies = [
            BoundsForRangeStrategy(),
            ElementPositionStrategy(),
            MousePositionStrategy()
        ]
    }

    /// Creates a resolver with custom strategies (useful for testing).
    ///
    /// - Parameter strategies: Ordered list of strategies to try
    init(strategies: [CursorPositionStrategy]) {
        self.strategies = strategies
    }

    /// Resolves cursor position by trying strategies in order.
    ///
    /// Before trying strategies, enables browser accessibility if the frontmost
    /// app is a browser or Electron app. This is critical for Chrome/Safari/VSCode
    /// which don't expose their accessibility tree by default.
    ///
    /// ## Browser-Specific Handling
    /// For browsers, `ElementPositionStrategy` is skipped because it returns the
    /// element's top-left corner, not the actual cursor position within the text.
    /// This causes popups to appear at the wrong location (e.g., start of textarea
    /// instead of where the cursor is). For browsers, we go directly from
    /// `BoundsForRangeStrategy` to `MousePositionStrategy`.
    ///
    /// If the provided element is nil, attempts to find an element at the mouse position
    /// before falling back to the mouse position strategy.
    ///
    /// - Parameter element: The focused AXUIElement, or nil
    /// - Returns: Cursor position in NSScreen coordinates
    func resolve(from element: AXUIElement?) -> CGPoint {
        var workingElement = element
        let isBrowser = browserEnabler.isBrowserOrElectronApp()

        // CRITICAL: Enable browser accessibility BEFORE querying any attributes
        // This sets AXEnhancedUserInterface for Chrome/Safari and
        // AXManualAccessibility for Electron apps (VSCode, Slack, etc.)
        if isBrowser {
            browserEnabler.enableIfNeeded()
            os_log("🌐 CursorPositionResolver: Browser/Electron app detected, accessibility enabled",
                   log: .accessibility, type: .info)
        }

        // If no element provided, try to find element at mouse position
        if workingElement == nil {
            workingElement = findElementAtMousePosition()
        }

        // For browsers, use a modified strategy order:
        // BoundsForRange → Mouse (skip ElementPosition)
        // ElementPositionStrategy returns the element's corner, not cursor position,
        // which causes popup to appear at wrong location in form inputs/textareas.
        let effectiveStrategies: [CursorPositionStrategy]
        if isBrowser {
            effectiveStrategies = strategies.filter { strategy in
                // Skip ElementPositionStrategy for browsers - it returns wrong position
                !(strategy is ElementPositionStrategy)
            }
            os_log("🌐 CursorPositionResolver: Using browser strategy chain (skipping ElementPosition)",
                   log: .accessibility, type: .debug)
        } else {
            effectiveStrategies = strategies
        }

        // Try each strategy in order
        for strategy in effectiveStrategies {
            if let position = strategy.getCursorPosition(from: workingElement) {
                os_log("🎯 CursorPositionResolver: %{public}@ succeeded",
                       log: .accessibility, type: .info, strategy.name)
                return position
            }
        }

        // This should never happen since MousePositionStrategy always succeeds
        os_log("⚠️  CursorPositionResolver: All strategies failed, using mouse position",
               log: .accessibility, type: .error)
        return NSEvent.mouseLocation
    }

    /// Finds the UI element at the current mouse position.
    ///
    /// Used as a pre-step when no focused element is provided.
    /// Particularly useful for web browsers that don't expose focused elements.
    private func findElementAtMousePosition() -> AXUIElement? {
        let mousePosition = NSEvent.mouseLocation

        // Find the screen containing the mouse
        guard let screen = NSScreen.screens.first(where: {
            NSMouseInRect(mousePosition, $0.frame, false)
        }) ?? NSScreen.main else {
            return nil
        }

        // Convert to Accessibility coordinates
        let accessibilityPoint = converter.nsScreenToAccessibility(mousePosition, containingScreen: screen)

        os_log("📍 CursorPositionResolver: Finding element at mouse position (%{public}f, %{public}f)",
               log: .accessibility, type: .debug, accessibilityPoint.x, accessibilityPoint.y)

        // Query for element at position
        var elementRef: AXUIElement?
        let systemWide = AXUIElementCreateSystemWide()
        let result = AXUIElementCopyElementAtPosition(
            systemWide,
            Float(accessibilityPoint.x),
            Float(accessibilityPoint.y),
            &elementRef
        )

        if result == .success, let element = elementRef {
            os_log("✅ CursorPositionResolver: Found element at mouse position",
                   log: .accessibility, type: .debug)
            return element
        }

        return nil
    }
}
