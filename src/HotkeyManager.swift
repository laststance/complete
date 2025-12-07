import Cocoa
import KeyboardShortcuts
import os.log

/// Manages global hotkey registration and completion workflow trigger
/// Uses KeyboardShortcuts library for cross-platform hotkey support
class HotkeyManager {

    // MARK: - Properties

    private let accessibilityManager: AccessibilityManaging
    private let completionEngine: CompletionProviding
    private let completionWindowController: CompletionWindowController

    // MARK: - Initialization

    init(
        accessibilityManager: AccessibilityManaging,
        completionEngine: CompletionProviding,
        completionWindowController: CompletionWindowController
    ) {
        self.accessibilityManager = accessibilityManager
        self.completionEngine = completionEngine
        self.completionWindowController = completionWindowController
        setupHotkey()
    }

    // MARK: - Hotkey Setup

    /// Set up global hotkey listener for completion trigger
    private func setupHotkey() {
        // Register handler for primary completion trigger shortcut
        KeyboardShortcuts.onKeyDown(for: .completionTrigger) { [weak self] in
            os_log("Primary hotkey triggered", log: .hotkey, type: .info)
            Task { @MainActor in
                self?.triggerCompletion()
            }
        }
        
        // Register handler for secondary completion trigger shortcut
        KeyboardShortcuts.onKeyDown(for: .completionTrigger2) { [weak self] in
            os_log("Secondary hotkey triggered", log: .hotkey, type: .info)
            Task { @MainActor in
                self?.triggerCompletion()
            }
        }

        os_log("Global hotkeys registered (primary + secondary)", log: .hotkey, type: .info)
    }

    // MARK: - Completion Workflow

    /// Main completion workflow triggered by hotkey
    /// Coordinates: Permission → Text extraction → Completion → Window display → Insertion
    @MainActor
    private func triggerCompletion() {
        os_log("=== Completion Workflow Started ===", log: .hotkey, type: .info)

        // CRITICAL: Capture mouse position IMMEDIATELY at hotkey trigger
        // This is the most reliable position for browsers where accessibility APIs may fail
        // Must be captured BEFORE any async operations or app activation that could change it
        let initialMousePosition = NSEvent.mouseLocation
        os_log("📍 Initial mouse position captured: (%.1f, %.1f)", log: .hotkey, type: .debug, initialMousePosition.x, initialMousePosition.y)

        // Phase 1: Check accessibility permissions
        os_log("Phase 1: Checking accessibility permissions", log: .hotkey, type: .debug)
        guard accessibilityManager.checkPermissionStatus() else {
            os_log("Accessibility permissions not granted", log: .hotkey, type: .error)
            accessibilityManager.showPermissionDeniedAlert()
            return
        }
        os_log("Accessibility permissions verified", log: .hotkey, type: .debug)

        // Phase 2: Get focused application for proper window activation later
        os_log("Phase 2: Getting active application", log: .hotkey, type: .debug)
        guard let activeApp = NSWorkspace.shared.frontmostApplication else {
            os_log("Could not get active application", log: .hotkey, type: .error)
            return
        }
        os_log("Active app: %{public}@", log: .hotkey, type: .debug, activeApp.localizedName ?? "Unknown")

        // Phase 3: Extract text at cursor position
        os_log("Phase 3: Extracting text context", log: .hotkey, type: .debug)
        let textContext: TextContext
        switch accessibilityManager.extractTextContext() {
        case .success(let context):
            textContext = context
        case .failure(let error):
            os_log("Could not extract text context: %{public}@", log: .hotkey, type: .error, error.userFriendlyMessage)
            showNoTextFeedback()
            return
        }

        os_log("Text extracted successfully", log: .hotkey, type: .info)
        os_log("Word at cursor: %{private}@", log: .hotkey, type: .debug, textContext.wordAtCursor)
        os_log("Cursor position: %d", log: .hotkey, type: .debug, textContext.cursorPosition)

        // Phase 4: Generate completion suggestions based on textContext
        os_log("Phase 4: Generating completions", log: .hotkey, type: .debug)
        let completions = completionEngine.completions(for: textContext.wordAtCursor, language: nil)

        if completions.isEmpty {
            os_log("No completions found for: %{private}@", log: .hotkey, type: .info, textContext.wordAtCursor)
            showNoCompletionsFeedback()
            return
        }

        os_log("Generated %d completions", log: .hotkey, type: .info, completions.count)
        for (index, completion) in completions.prefix(3).enumerated() {
            os_log("%d. %{private}@", log: .hotkey, type: .debug, index + 1, completion)
        }

        // Get cursor screen position for accurate window placement
        // getCursorScreenPosition() already implements a 3-strategy fallback:
        // 1. Text range bounds (most accurate, works for TextEdit, Xcode, etc.)
        // 2. Element position (fallback)
        // 3. Mouse position (ultimate fallback for browsers)
        // No additional sanity check needed here - trust the accessibility result
        var cursorPosition: CGPoint
        switch accessibilityManager.getCursorScreenPosition(from: nil) {
        case .success(let position):
            cursorPosition = position
            os_log("Cursor position from accessibility: (%.1f, %.1f)", log: .hotkey, type: .debug, position.x, position.y)
        case .failure(let error):
            os_log("Could not get cursor position: %{public}@, using initial mouse position", log: .hotkey, type: .error, error.userFriendlyMessage)
            cursorPosition = initialMousePosition
        }

        os_log("📍 Final cursor position for window: (%.1f, %.1f)", log: .hotkey, type: .info, cursorPosition.x, cursorPosition.y)

        // Phase 5: Show completion window with suggestions at cursor position
        Task { @MainActor in
            completionWindowController.show(
                completions: completions,
                textContext: textContext,
                near: cursorPosition
            )
            os_log("Completion window displayed with %d suggestions", log: .hotkey, type: .info, completions.count)
        }

        // Phase 6: Handle completion selection and insertion
        // (Handled by CompletionWindowController callbacks)
        os_log("=== Completion Workflow Complete ===", log: .hotkey, type: .info)
    }

    // MARK: - User Feedback

    /// Show brief visual feedback when no text is available
    private func showNoTextFeedback() {
        os_log("Showing no-text feedback to user", log: .ui, type: .debug)
        // Could show a brief notification or beep
        NSSound.beep()
    }

    /// Show brief visual feedback when no completions are found
    private func showNoCompletionsFeedback() {
        os_log("Showing no-completions feedback to user", log: .ui, type: .debug)
        // Could show a brief notification
        NSSound.beep()
    }
}

// MARK: - KeyboardShortcuts Extension

extension KeyboardShortcuts.Name {
    /// Primary completion trigger shortcut name
    /// Default: Shift+Command+I
    static let completionTrigger = Self(
        "completionTrigger",
        default: .init(.i, modifiers: [.shift, .command])
    )
    
    /// Secondary completion trigger shortcut name (optional)
    /// Default: None (user can configure)
    static let completionTrigger2 = Self("completionTrigger2")
}