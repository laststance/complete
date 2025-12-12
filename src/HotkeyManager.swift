import Cocoa
import KeyboardShortcuts
import os.log

/// Manages global hotkey registration for completion trigger
/// Uses KeyboardShortcuts library for cross-platform hotkey support
///
/// Responsibilities:
/// - Register global keyboard shortcuts
/// - Delegate workflow execution to CompletionWorkflowCoordinator
///
/// - Note: Follows Single Responsibility Principle - only handles hotkey registration
class HotkeyManager {

    // MARK: - Properties

    /// Coordinator that handles the completion workflow
    private let workflowCoordinator: CompletionWorkflowCoordinator

    // MARK: - Initialization

    /// Creates a HotkeyManager with dependencies
    ///
    /// - Parameters:
    ///   - accessibilityManager: For text extraction/insertion
    ///   - completionEngine: For generating completions
    ///   - completionWindowController: For displaying completion UI
    init(
        accessibilityManager: AccessibilityManaging,
        completionEngine: CompletionProviding,
        completionWindowController: CompletionWindowController
    ) {
        // Create the workflow coordinator with injected dependencies
        self.workflowCoordinator = CompletionWorkflowCoordinator(
            accessibilityManager: accessibilityManager,
            completionEngine: completionEngine,
            completionWindowController: completionWindowController
        )

        setupHotkey()
    }

    // MARK: - Hotkey Setup

    /// Set up global hotkey listeners for completion trigger
    private func setupHotkey() {
        // Register handler for primary completion trigger shortcut
        KeyboardShortcuts.onKeyDown(for: .completionTrigger) { [weak self] in
            os_log("Primary hotkey triggered", log: .hotkey, type: .info)
            Task { @MainActor in
                self?.workflowCoordinator.executeWorkflow()
            }
        }

        // Register handler for secondary completion trigger shortcut
        KeyboardShortcuts.onKeyDown(for: .completionTrigger2) { [weak self] in
            os_log("Secondary hotkey triggered", log: .hotkey, type: .info)
            Task { @MainActor in
                self?.workflowCoordinator.executeWorkflow()
            }
        }

        os_log("Global hotkeys registered (primary + secondary)", log: .hotkey, type: .info)
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
