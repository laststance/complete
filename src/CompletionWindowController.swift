import Cocoa
import SwiftUI
import os.log

/// Custom NSPanel subclass that can become key window to receive keyboard events
class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool {
        return true
    }
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

    /// Reference to the app that was active before we showed the popup
    /// Used to restore focus when inserting text
    private var previouslyActiveApp: NSRunningApplication?

    // MARK: - Initialization

    private init() {
        // Create borderless, floating panel with narrow width for vertical list
        let panel = KeyablePanel(
            contentRect: NSRect(x: 0, y: 0, width: 220, height: 400),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        // Configure panel behavior
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .floating  // Always on top
        panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]

        // Panel should not activate the application but can receive key events
        panel.hidesOnDeactivate = false

        super.init(window: panel)

        // Set up SwiftUI content
        setupSwiftUIContent()

        // Set up window notifications
        setupWindowNotifications()

        // Set up workspace notifications for space changes
        setupWorkspaceNotifications()
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
        window?.delegate = self
        hostingController = hosting
    }

    // MARK: - Notification Setup

    /// Set up window lifecycle notifications
    private func setupWindowNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidResignKey(_:)),
            name: NSWindow.didResignKeyNotification,
            object: window
        )
    }

    /// Set up workspace notifications for desktop/space changes
    private func setupWorkspaceNotifications() {
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(activeSpaceDidChange),
            name: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil
        )
    }

    // MARK: - Notification Handlers

    @objc func windowDidResignKey(_ notification: Notification) {
        // Don't hide if we're in the middle of inserting text
        guard !isInsertingText else {
            os_log("⏳ Deferring hide - text insertion in progress", log: .ui, type: .debug)
            return
        }
        
        // Hide popup when window loses key status
        os_log("ℹ️  Window resigned key status - hiding popup", log: .ui, type: .info)
        hide()
    }

    @objc private func activeSpaceDidChange(_ notification: Notification) {
        // Hide popup when user switches spaces/desktops
        os_log("ℹ️  Active space changed - hiding popup", log: .ui, type: .info)
        hide()
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

        // Save reference to currently active app (TextEdit, CotEditor, etc.)
        // We'll need to restore focus to this app when inserting text
        previouslyActiveApp = NSWorkspace.shared.frontmostApplication
        os_log("💾 Saved previously active app: %{public}@", log: .ui, type: .info, previouslyActiveApp?.localizedName ?? "unknown")

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

        // Activate app to receive keyboard events (required for LSUIElement background agents)
        os_log("🎯 Activating app for keyboard focus", log: .ui, type: .info)
        NSApp.activate(ignoringOtherApps: true)
        os_log("🎯 App activated: %{public}@", log: .ui, type: .info, NSApp.isActive ? "true" : "false")

        // Show window and establish keyboard focus
        window?.makeKeyAndOrderFront(nil)
        os_log("🎯 Window is key: %{public}@", log: .ui, type: .info, window?.isKeyWindow ?? false ? "true" : "false")

        // Ensure window accepts keyboard input
        window?.makeFirstResponder(window?.contentView)
        os_log("🎯 First responder set: %{public}@", log: .ui, type: .info, window?.firstResponder != nil ? "true" : "false")

        // Set up keyboard monitoring
        setupKeyboardMonitoring()

        // Set up global click monitoring to detect clicks outside
        setupClickMonitoring()
    }

    /// Hide completion window
    func hide() {
        window?.orderOut(nil)
        removeKeyboardMonitoring()
        removeClickMonitoring()

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
        os_log("\n🎯 POSITIONING WINDOW", log: .ui, type: .info)
        os_log("   Input point (cursor position): (%{public}f, %{public}f)", log: .ui, type: .info, point.x, point.y)
        
        // Find the screen containing the point (multi-monitor support)
        let screen = NSScreen.screens.first { screen in
            NSMouseInRect(point, screen.frame, false)
        } ?? NSScreen.main ?? NSScreen.screens.first!

        let visibleFrame = screen.visibleFrame
        let windowSize = window.frame.size
        
        os_log("   Screen frame: %{public}@", log: .ui, type: .info, String(describing: screen.frame))
        os_log("   Screen visible frame: %{public}@", log: .ui, type: .info, String(describing: visibleFrame))
        os_log("   Window size: %{public}@", log: .ui, type: .info, String(describing: windowSize))

        // Vertical offset from cursor (no horizontal offset - align directly like TextEdit)
        let offsetY: CGFloat = 20

        // Always position above cursor for stable behavior
        var origin = CGPoint(
            x: point.x,
            y: point.y + offsetY
        )
        os_log("   Position: ABOVE cursor", log: .ui, type: .info)
        os_log("   Initial calculated origin: (%{public}f, %{public}f)", log: .ui, type: .info, origin.x, origin.y)

        // Adjust horizontally if off-screen
        if origin.x + windowSize.width > visibleFrame.maxX {
            let oldX = origin.x
            // Shift left to keep on screen
            origin.x = visibleFrame.maxX - windowSize.width - 10
            os_log("   ⚠️  Adjusted X (off right edge): %{public}f → %{public}f", log: .ui, type: .info, oldX, origin.x)
        }

        // Ensure not off left edge
        if origin.x < visibleFrame.minX {
            let oldX = origin.x
            origin.x = visibleFrame.minX + 10
            os_log("   ⚠️  Adjusted X (off left edge): %{public}f → %{public}f", log: .ui, type: .info, oldX, origin.x)
        }

        // Clamp horizontally to visible frame
        let clampedX = max(visibleFrame.minX + 10, min(origin.x, visibleFrame.maxX - windowSize.width - 10))
        if clampedX != origin.x {
            os_log("   ⚠️  Clamped X: %{public}f → %{public}f", log: .ui, type: .info, origin.x, clampedX)
            origin.x = clampedX
        }

        // No vertical flipping - just clamp to screen bounds if needed
        // (Above cursor positioning is stable and rarely needs adjustment)

        // Clamp vertically to visible frame
        let clampedY = max(visibleFrame.minY + 10, min(origin.y, visibleFrame.maxY - windowSize.height - 10))
        if clampedY != origin.y {
            os_log("   ⚠️  Clamped Y: %{public}f → %{public}f", log: .ui, type: .info, origin.y, clampedY)
            origin.y = clampedY
        }
        
        os_log("   FINAL window origin: (%{public}f, %{public}f)", log: .ui, type: .info, origin.x, origin.y)
        os_log("   Window will cover: Y from %{public}f to %{public}f", log: .ui, type: .info, origin.y, origin.y + windowSize.height)

        window.setFrameOrigin(origin)
    }

    // MARK: - Click Monitoring

    private var clickMonitor: Any?

    /// Set up global click monitoring to detect clicks outside the window
    private func setupClickMonitoring() {
        removeClickMonitoring()
        
        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self, self.isVisible else { return }
            
            // Check if click is outside our window
            if let window = self.window {
                let clickLocation = event.locationInWindow
                let windowFrame = window.frame
                let screenClickLocation = NSPoint(
                    x: clickLocation.x + window.frame.origin.x,
                    y: clickLocation.y + window.frame.origin.y
                )
                
                if !windowFrame.contains(screenClickLocation) {
                    os_log("ℹ️  Click outside popup detected - hiding", log: .ui, type: .info)
                    self.hide()
                }
            }
        }
    }

    /// Remove click monitoring
    private func removeClickMonitoring() {
        if let monitor = clickMonitor {
            NSEvent.removeMonitor(monitor)
            clickMonitor = nil
        }
    }

    // MARK: - Keyboard Monitoring

    private var keyboardMonitor: Any?
    
    /// Flag to track if text insertion is in progress
    private var isInsertingText = false

    /// Set up global keyboard event monitoring
    private func setupKeyboardMonitoring() {
        // Remove existing monitor if any
        removeKeyboardMonitoring()

        // Use both local and global monitors for better coverage
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

        os_log("📝 Starting text insertion: '%{private}@'", log: .ui, type: .info, selectedText)
        isInsertingText = true

        // Restore focus to the previously active app (TextEdit, CotEditor, etc.)
        // This is critical: NSApp.activate() in show() makes Complete active,
        // but we need to restore focus to the original app before inserting text
        guard let targetApp = previouslyActiveApp else {
            os_log("❌ No previously active app saved - cannot insert text", log: .ui, type: .error)
            self.isInsertingText = false
            self.hide()
            return
        }

        os_log("🔄 Restoring focus to: \(targetApp.localizedName ?? "unknown")")

        // Explicitly activate the target app
        targetApp.activate(options: .activateIgnoringOtherApps)

        // Wait for the app to become active and for focus to stabilize
        // macOS needs time for app activation and focus transition
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self else { return }

            // Verify the target app is now active
            if targetApp.isActive {
                os_log("✅ Target app is active, inserting text...", log: .ui, type: .info)
            } else {
                os_log("⚠️  Target app not yet active, proceeding anyway...", log: .ui, type: .info)
            }

            let success = AccessibilityManager.shared.insertCompletion(
                selectedText,
                replacing: context
            )

            self.isInsertingText = false

            if success {
                os_log("✅ Inserted completion: '%{private}@'", log: .ui, type: .info, selectedText)
            } else {
                os_log("❌ Failed to insert completion", log: .ui, type: .error)
            }

            // Hide window after insertion attempt
            self.hide()
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
        removeClickMonitoring()
        NotificationCenter.default.removeObserver(self)
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }
}

// MARK: - NSWindowDelegate

extension CompletionWindowController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        removeKeyboardMonitoring()
        removeClickMonitoring()
    }
}