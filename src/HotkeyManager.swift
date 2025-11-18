import Cocoa
import KeyboardShortcuts
import os.log

/// Manages global hotkey registration and completion workflow trigger
/// Uses KeyboardShortcuts library for cross-platform hotkey support
class HotkeyManager {

    /// Singleton instance
    static let shared = HotkeyManager()

    private init() {
        setupHotkey()
    }

    // MARK: - Hotkey Setup

    /// Set up global hotkey listener for completion trigger
    private func setupHotkey() {
        // Register handler for completion trigger shortcut
        KeyboardShortcuts.onKeyDown(for: .completionTrigger) { [weak self] in
            os_log("Hotkey triggered", log: .hotkey, type: .info)
            Task { @MainActor in
                self?.triggerCompletion()
            }
        }

        os_log("Global hotkey registered", log: .hotkey, type: .info)
    }

    // MARK: - Completion Workflow

    /// Main completion workflow triggered by hotkey
    /// Coordinates: Permission → Text extraction → Completion → Window display → Insertion
    @MainActor
    private func triggerCompletion() {
        os_log("=== Completion Workflow Started ===", log: .hotkey, type: .info)

        // Phase 1: Check accessibility permissions
        os_log("Phase 1: Checking accessibility permissions", log: .hotkey, type: .debug)
        guard AccessibilityManager.shared.checkPermissionStatus() else {
            os_log("Accessibility permissions not granted", log: .hotkey, type: .error)
            AccessibilityManager.shared.showPermissionDeniedAlert()
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
        switch AccessibilityManager.shared.extractTextContext() {
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
        let completions = CompletionEngine.shared.completions(for: textContext.wordAtCursor)

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
        let cursorPosition: CGPoint
        switch AccessibilityManager.shared.getCursorScreenPosition() {
        case .success(let position):
            cursorPosition = position
            os_log("Cursor position: (%.1f, %.1f)", log: .hotkey, type: .debug, position.x, position.y)
        case .failure(let error):
            os_log("Could not get cursor position: %{public}@, using mouse fallback", log: .hotkey, type: .error, error.userFriendlyMessage)
            cursorPosition = NSEvent.mouseLocation
        }

        // Phase 5: Show completion window with suggestions at cursor position
        Task { @MainActor in
            CompletionWindowController.shared.show(
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
    /// Main completion trigger shortcut name
    /// Default: Ctrl+I
    static let completionTrigger = Self(
        "completionTrigger",
        default: .init(.i, modifiers: [.control])
    )
}