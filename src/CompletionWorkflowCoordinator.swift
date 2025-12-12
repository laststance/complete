import Cocoa
import os.log

/// Coordinates the completion workflow from trigger to display
/// Extracted from HotkeyManager to follow Single Responsibility Principle
///
/// Workflow phases:
/// 1. Capture mouse position (before any async operations)
/// 2. Check accessibility permissions
/// 3. Get active application context
/// 4. Extract text at cursor
/// 5. Generate completions
/// 6. Show completion window
///
/// - Note: This class orchestrates components but doesn't own them
class CompletionWorkflowCoordinator {

    // MARK: - Dependencies

    private let accessibilityManager: AccessibilityManaging
    private let completionEngine: CompletionProviding
    private let completionWindowController: CompletionWindowController

    // MARK: - Initialization

    /// Creates a coordinator with injected dependencies
    ///
    /// - Parameters:
    ///   - accessibilityManager: Handles text extraction and insertion
    ///   - completionEngine: Generates completion suggestions
    ///   - completionWindowController: Displays completion UI
    init(
        accessibilityManager: AccessibilityManaging,
        completionEngine: CompletionProviding,
        completionWindowController: CompletionWindowController
    ) {
        self.accessibilityManager = accessibilityManager
        self.completionEngine = completionEngine
        self.completionWindowController = completionWindowController
    }

    // MARK: - Workflow Execution

    /// Executes the complete completion workflow
    ///
    /// Called when user triggers completion (via hotkey, menu, etc.)
    /// Must be called on MainActor for UI operations
    @MainActor
    func executeWorkflow() {
        os_log("=== Completion Workflow Started ===", log: .hotkey, type: .info)

        // CRITICAL: Capture mouse position IMMEDIATELY at workflow start
        // This is the most reliable position for browsers where accessibility APIs may fail
        // Must be captured BEFORE any async operations or app activation that could change it
        let initialMousePosition = NSEvent.mouseLocation
        os_log("📍 Initial mouse position captured: (%.1f, %.1f)",
               log: .hotkey, type: .debug, initialMousePosition.x, initialMousePosition.y)

        // Phase 1: Check accessibility permissions
        guard executePermissionCheck() else { return }

        // Phase 2: Get focused application context
        guard let activeApp = getActiveApplication() else { return }
        _ = activeApp // Suppress unused warning - kept for future use (window restoration)

        // Phase 3: Extract text at cursor position
        guard let textContext = executeTextExtraction() else { return }

        // Phase 4: Generate completions
        let completions = generateCompletions(for: textContext, initialMousePosition: initialMousePosition)
        guard !completions.isEmpty || TerminalDetector.isCurrentAppTerminal() else {
            showNoCompletionsFeedback()
            return
        }

        // Handle empty completions for Terminal apps (show input mode)
        if completions.isEmpty && TerminalDetector.isCurrentAppTerminal() {
            showTerminalInputMode(initialMousePosition: initialMousePosition)
            return
        }

        // Phase 5: Get cursor position for window placement
        let cursorPosition = getCursorPosition(fallback: initialMousePosition)
        os_log("📍 Final cursor position for window: (%.1f, %.1f)",
               log: .hotkey, type: .info, cursorPosition.x, cursorPosition.y)

        // Phase 6: Show completion window
        showCompletionWindow(completions: completions, textContext: textContext, at: cursorPosition)
        os_log("=== Completion Workflow Complete ===", log: .hotkey, type: .info)
    }

    // MARK: - Workflow Phases (Private)

    /// Phase 1: Verify accessibility permissions
    /// - Returns: true if permissions granted, false otherwise
    private func executePermissionCheck() -> Bool {
        os_log("Phase 1: Checking accessibility permissions", log: .hotkey, type: .debug)

        guard accessibilityManager.checkPermissionStatus() else {
            os_log("Accessibility permissions not granted", log: .hotkey, type: .error)
            accessibilityManager.showPermissionDeniedAlert()
            return false
        }

        os_log("Accessibility permissions verified", log: .hotkey, type: .debug)
        return true
    }

    /// Phase 2: Get the currently active application
    /// - Returns: Active NSRunningApplication or nil
    private func getActiveApplication() -> NSRunningApplication? {
        os_log("Phase 2: Getting active application", log: .hotkey, type: .debug)

        guard let activeApp = NSWorkspace.shared.frontmostApplication else {
            os_log("Could not get active application", log: .hotkey, type: .error)
            return nil
        }

        os_log("Active app: %{public}@",
               log: .hotkey, type: .debug, activeApp.localizedName ?? "Unknown")
        return activeApp
    }

    /// Phase 3: Extract text context at cursor position
    /// - Returns: TextContext or nil if extraction failed
    private func executeTextExtraction() -> TextContext? {
        os_log("Phase 3: Extracting text context", log: .hotkey, type: .debug)

        switch accessibilityManager.extractTextContext() {
        case .success(let context):
            os_log("Text extracted successfully", log: .hotkey, type: .info)
            os_log("Word at cursor: %{private}@", log: .hotkey, type: .debug, context.wordAtCursor)
            os_log("Cursor position: %d", log: .hotkey, type: .debug, context.cursorPosition)
            return context

        case .failure(let error):
            os_log("Could not extract text context: %{public}@",
                   log: .hotkey, type: .error, error.userFriendlyMessage)
            showNoTextFeedback()
            return nil
        }
    }

    /// Phase 4: Generate completion suggestions
    ///
    /// - Parameters:
    ///   - textContext: The extracted text context
    ///   - initialMousePosition: Fallback position if cursor detection fails
    /// - Returns: Array of completion suggestions
    private func generateCompletions(for textContext: TextContext, initialMousePosition: CGPoint) -> [String] {
        os_log("Phase 4: Generating completions", log: .hotkey, type: .debug)

        let completions = completionEngine.completions(for: textContext.wordAtCursor, language: nil)

        if completions.isEmpty {
            os_log("No completions found for: %{private}@",
                   log: .hotkey, type: .info, textContext.wordAtCursor)
        } else {
            os_log("Generated %d completions", log: .hotkey, type: .info, completions.count)
            for (index, completion) in completions.prefix(3).enumerated() {
                os_log("%d. %{private}@", log: .hotkey, type: .debug, index + 1, completion)
            }
        }

        return completions
    }

    /// Get cursor screen position with fallback
    ///
    /// - Parameter fallback: Position to use if accessibility lookup fails
    /// - Returns: Best available cursor position
    private func getCursorPosition(fallback: CGPoint) -> CGPoint {
        switch accessibilityManager.getCursorScreenPosition(from: nil) {
        case .success(let position):
            os_log("Cursor position from accessibility: (%.1f, %.1f)",
                   log: .hotkey, type: .debug, position.x, position.y)
            return position

        case .failure(let error):
            os_log("Could not get cursor position: %{public}@, using initial mouse position",
                   log: .hotkey, type: .error, error.userFriendlyMessage)
            return fallback
        }
    }

    /// Show Terminal input mode for apps where text extraction doesn't work
    ///
    /// - Parameter initialMousePosition: Fallback position for window placement
    @MainActor
    private func showTerminalInputMode(initialMousePosition: CGPoint) {
        os_log("🖥️ Terminal detected with no word - showing input mode", log: .hotkey, type: .info)

        let cursorPosition = getCursorPosition(fallback: initialMousePosition)

        completionWindowController.showTerminalInputMode(
            near: cursorPosition,
            completionEngine: completionEngine
        )
    }

    /// Phase 6: Display the completion window
    ///
    /// - Parameters:
    ///   - completions: Suggestions to display
    ///   - textContext: Context for text insertion
    ///   - position: Screen position for window
    @MainActor
    private func showCompletionWindow(
        completions: [String],
        textContext: TextContext,
        at position: CGPoint
    ) {
        completionWindowController.show(
            completions: completions,
            textContext: textContext,
            near: position
        )
        os_log("Completion window displayed with %d suggestions",
               log: .hotkey, type: .info, completions.count)
    }

    // MARK: - User Feedback

    /// Show brief feedback when no text is available
    private func showNoTextFeedback() {
        os_log("Showing no-text feedback to user", log: .ui, type: .debug)
        NSSound.beep()
    }

    /// Show brief feedback when no completions are found
    private func showNoCompletionsFeedback() {
        os_log("Showing no-completions feedback to user", log: .ui, type: .debug)
        NSSound.beep()
    }
}
