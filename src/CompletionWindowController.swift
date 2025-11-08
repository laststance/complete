import Cocoa
import SwiftUI

/// Window position preference
enum WindowPosition {
    case top    // Above cursor
    case bottom // Below cursor
}

/// Window controller for the floating completion panel
/// Manages an always-on-top, borderless NSPanel for displaying completions
class CompletionWindowController: NSWindowController {

    // MARK: - Singleton

    static let shared = CompletionWindowController()

    // MARK: - Properties

    /// View model managing completion state
    private let viewModel = CompletionViewModel.shared

    /// Hosting controller for SwiftUI content
    private var hostingController: NSHostingController<CompletionListView>?

    /// Current window position preference (top or bottom of cursor)
    var positionPreference: WindowPosition = .bottom

    // MARK: - Initialization

    private init() {
        // Create borderless, floating panel with narrow width for vertical list
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 220, height: 400),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        // Configure panel behavior
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .floating  // Always on top
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        // Panel should not activate the application
        panel.hidesOnDeactivate = false

        super.init(window: panel)

        // Set up SwiftUI content
        setupSwiftUIContent()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup

    /// Set up SwiftUI hosting controller
    private func setupSwiftUIContent() {
        let completionListView = CompletionListView(viewModel: viewModel)
        let hosting = NSHostingController(rootView: completionListView)

        // Configure hosting controller
        hosting.view.wantsLayer = true

        // Set as window content
        window?.contentViewController = hosting
        hostingController = hosting
    }

    // MARK: - Public API

    /// Show completion window with suggestions
    ///
    /// - Parameters:
    ///   - completions: Array of completion strings to display
    ///   - textContext: Text context for the completion session
    ///   - selectedIndex: Initially selected index (default: 0)
    ///   - cursorPosition: Screen position to display near (optional)
    func show(completions: [String], textContext: TextContext, selectedIndex: Int = 0, near cursorPosition: CGPoint? = nil) {
        guard !completions.isEmpty else {
            hide()
            return
        }

        // Update view model
        viewModel.completions = completions
        viewModel.textContext = textContext
        viewModel.selectedIndex = min(selectedIndex, completions.count - 1)

        // Calculate dynamic window size based on completion count
        let itemHeight: CGFloat = 22
        let padding: CGFloat = 8  // top + bottom padding
        let shadowSpace: CGFloat = 20
        let minHeight: CGFloat = 60
        let maxHeight: CGFloat = 600
        let windowWidth: CGFloat = 220

        // Calculate required height for all items
        let calculatedHeight = CGFloat(completions.count) * itemHeight + padding * 2 + shadowSpace
        let finalHeight = min(maxHeight, max(minHeight, calculatedHeight))

        // Resize window to fit content
        if let window = window {
            var frame = window.frame
            frame.size = NSSize(width: windowWidth, height: finalHeight)
            window.setFrame(frame, display: false)
        }

        // Position window
        if let position = cursorPosition {
            positionWindow(near: position)
        } else {
            positionWindowAtCursor()
        }

        // Show window
        window?.orderFrontRegardless()

        // Set up keyboard monitoring
        setupKeyboardMonitoring()
    }

    /// Hide completion window
    func hide() {
        window?.orderOut(nil)
        removeKeyboardMonitoring()

        // Clear view model
        viewModel.completions = []
        viewModel.selectedIndex = 0
    }

    /// Check if window is currently visible
    var isVisible: Bool {
        return window?.isVisible ?? false
    }

    /// Get currently selected completion
    var selectedCompletion: String? {
        guard viewModel.selectedIndex < viewModel.completions.count else {
            return nil
        }
        return viewModel.completions[viewModel.selectedIndex]
    }

    // MARK: - Positioning

    /// Position window near the cursor
    private func positionWindowAtCursor() {
        guard let window = window else {
            return
        }

        // Get current mouse location
        let mouseLocation = NSEvent.mouseLocation

        // Calculate and set position
        calculatePosition(for: window, relativeTo: mouseLocation)
    }

    /// Position window near a specific point
    ///
    /// - Parameter position: Screen coordinates
    private func positionWindow(near position: CGPoint) {
        guard let window = window else {
            return
        }

        calculatePosition(for: window, relativeTo: position)
    }

    /// Calculate and apply window position relative to a point
    ///
    /// - Parameters:
    ///   - window: The window to position
    ///   - point: Screen coordinates to position relative to
    private func calculatePosition(for window: NSWindow, relativeTo point: CGPoint) {
        // Find the screen containing the point (multi-monitor support)
        let screen = NSScreen.screens.first { screen in
            NSMouseInRect(point, screen.frame, false)
        } ?? NSScreen.main ?? NSScreen.screens.first!

        let visibleFrame = screen.visibleFrame
        let windowSize = window.frame.size

        // Vertical offset from cursor (no horizontal offset - align directly like TextEdit)
        let offsetY: CGFloat = 20

        // Calculate initial position based on preference
        var origin: CGPoint

        switch positionPreference {
        case .bottom:
            // Position below cursor, aligned directly underneath
            origin = CGPoint(
                x: point.x,
                y: point.y - offsetY - windowSize.height
            )

        case .top:
            // Position above cursor, aligned directly
            origin = CGPoint(
                x: point.x,
                y: point.y + offsetY
            )
        }

        // Adjust horizontally if off-screen
        if origin.x + windowSize.width > visibleFrame.maxX {
            // Shift left to keep on screen
            origin.x = visibleFrame.maxX - windowSize.width - 10
        }

        // Ensure not off left edge
        if origin.x < visibleFrame.minX {
            origin.x = visibleFrame.minX + 10
        }

        // Clamp horizontally to visible frame
        origin.x = max(visibleFrame.minX + 10, min(origin.x, visibleFrame.maxX - windowSize.width - 10))

        // Adjust vertically if off-screen
        if origin.y < visibleFrame.minY {
            // Bottom edge: position above cursor instead
            origin.y = point.y + offsetY
        } else if origin.y + windowSize.height > visibleFrame.maxY {
            // Top edge: position below cursor instead
            origin.y = point.y - offsetY - windowSize.height
        }

        // Clamp vertically to visible frame
        origin.y = max(visibleFrame.minY + 10, min(origin.y, visibleFrame.maxY - windowSize.height - 10))

        window.setFrameOrigin(origin)
    }

    /// Toggle window position preference between top and bottom
    func togglePosition() {
        positionPreference = (positionPreference == .bottom) ? .top : .bottom
        print("ℹ️  Window position toggled to: \(positionPreference)")

        // Reposition window if currently visible
        if isVisible {
            positionWindowAtCursor()
        }
    }

    // MARK: - Keyboard Monitoring

    private var keyboardMonitor: Any?

    /// Set up global keyboard event monitoring
    private func setupKeyboardMonitoring() {
        // Remove existing monitor if any
        removeKeyboardMonitoring()

        // Monitor key down events
        keyboardMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self, self.isVisible else {
                return event
            }

            return self.handleKeyDown(event: event)
        }
    }

    /// Remove keyboard event monitoring
    private func removeKeyboardMonitoring() {
        if let monitor = keyboardMonitor {
            NSEvent.removeMonitor(monitor)
            keyboardMonitor = nil
        }
    }

    /// Handle keyboard events for navigation and selection
    ///
    /// - Parameter event: NSEvent to handle
    /// - Returns: The event if not handled, nil if consumed
    private func handleKeyDown(event: NSEvent) -> NSEvent? {
        switch event.keyCode {
        case 125: // Down arrow
            viewModel.selectNext()
            return nil

        case 126: // Up arrow
            viewModel.selectPrevious()
            return nil

        case 36: // Return/Enter
            handleSelection()
            return nil

        case 53: // Escape
            hide()
            return nil

        default:
            // Other keys: hide window and pass through
            hide()
            return event
        }
    }

    /// Handle completion selection
    private func handleSelection() {
        guard let selectedText = selectedCompletion,
              let context = viewModel.textContext else {
            hide()
            return
        }

        // Insert selected completion
        Task { @MainActor in
            let success = AccessibilityManager.shared.insertCompletion(selectedText, replacing: context)

            if success {
                print("✅ Inserted completion: '\(selectedText)'")
            } else {
                print("❌ Failed to insert completion")
            }

            // Hide window after insertion
            hide()
        }
    }

    /// Handle mouse click selection
    /// Called when user clicks on a completion item
    func handleMouseSelection() {
        handleSelection()
    }

    // MARK: - Cleanup

    deinit {
        removeKeyboardMonitoring()
    }
}
