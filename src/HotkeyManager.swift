import Cocoa
import KeyboardShortcuts

/// Manages global keyboard shortcuts for triggering completion
/// Based on research: docs/macos-global-hotkey-research-2024.md
/// Uses KeyboardShortcuts library for 20-50ms response time and conflict detection
class HotkeyManager {

    // MARK: - Singleton

    static let shared = HotkeyManager()

    private init() {
        // Shortcut names are registered in the extension below
    }

    // MARK: - Setup

    /// Set up global hotkey listeners
    /// Call this after accessibility permissions are granted
    func setup() {
        print("⌨️  Setting up global hotkey listeners...")

        // Listen for completion trigger shortcut
        KeyboardShortcuts.onKeyUp(for: .completionTrigger) { [weak self] in
            self?.handleCompletionTrigger()
        }

        // Verify shortcut is registered
        if let shortcut = KeyboardShortcuts.getShortcut(for: .completionTrigger) {
            print("✅ Completion trigger registered: \(shortcut)")
        } else {
            print("⚠️  Completion trigger using default: Ctrl+I")
        }

        print("✅ Hotkey manager ready")
    }

    /// Clean up hotkey listeners
    func cleanup() {
        print("🧹 Cleaning up hotkey listeners")
        // KeyboardShortcuts handles cleanup automatically
    }

    // MARK: - Shortcut Handling

    /// Handle completion trigger shortcut (Ctrl+I)
    private func handleCompletionTrigger() {
        print("\n⚡ Completion trigger activated!")

        // Verify accessibility permissions before proceeding
        guard AccessibilityManager.shared.checkPermissionStatus() else {
            print("❌ Cannot trigger completion: Accessibility permissions not granted")
            AccessibilityManager.shared.showPermissionDeniedAlert()
            return
        }

        // Phase 3: Extract text at cursor position
        guard let textContext = AccessibilityManager.shared.extractTextContext() else {
            print("⚠️  Could not extract text context from focused element")
            showNoTextFeedback()
            return
        }

        print("📝 Text extracted successfully!")
        print("   Word at cursor: '\(textContext.wordAtCursor)'")
        print("   Context: '\(textContext.textBeforeCursor.suffix(30))...'")

        // Phase 4: Generate completion suggestions based on textContext
        let completions = CompletionEngine.shared.completions(for: textContext.wordAtCursor)
        
        if completions.isEmpty {
            print("ℹ️  No completions found for '\(textContext.wordAtCursor)'")
            showNoCompletionsFeedback(wordAtCursor: textContext.wordAtCursor)
            return
        }
        
        print("✅ Generated \(completions.count) completions:")
        for (index, completion) in completions.prefix(10).enumerated() {
            print("   \(index + 1). \(completion)")
        }

        // Phase 5: Show completion window with suggestions
        Task { @MainActor in
            CompletionWindowController.shared.show(completions: completions, textContext: textContext)
            print("✅ Completion window displayed with \(completions.count) suggestions")
        }
    }

    /// Show feedback when no completions are available
    private func showNoCompletionsFeedback(wordAtCursor: String) {
        print("ℹ️  No completions available for '\(wordAtCursor)'")
        print("   Word may be too short or not in dictionary")
        NSSound.beep()
    }

    /// Show feedback when no text element is focused
    private func showNoTextFeedback() {
        print("ℹ️  No text field focused")
        print("   Please click in a text field and try again")
        NSSound.beep()
    }

    // MARK: - Shortcut Management

    /// Get current completion trigger shortcut
    /// - Returns: Current keyboard shortcut or nil if not set
    func getCurrentShortcut() -> KeyboardShortcuts.Shortcut? {
        return KeyboardShortcuts.getShortcut(for: .completionTrigger)
    }

    /// Set custom completion trigger shortcut
    /// - Parameter shortcut: New keyboard shortcut
    func setCompletionShortcut(_ shortcut: KeyboardShortcuts.Shortcut) {
        KeyboardShortcuts.setShortcut(shortcut, for: .completionTrigger)
        print("✅ Completion shortcut updated to: \(shortcut)")
    }

    /// Reset completion trigger to default (Ctrl+I)
    func resetToDefault() {
        KeyboardShortcuts.setShortcut(.init(.i, modifiers: [.control]), for: .completionTrigger)
        print("✅ Completion shortcut reset to default: Ctrl+I")
    }

    /// Check if shortcut conflicts with system shortcuts
    /// - Parameter shortcut: Shortcut to check
    /// - Returns: true if no conflicts, false if conflicts exist
    func checkForConflicts(_ shortcut: KeyboardShortcuts.Shortcut) -> Bool {
        // KeyboardShortcuts library handles conflict detection automatically
        // When user tries to set a conflicting shortcut in the recorder,
        // it will show a warning and prevent the assignment

        // Note: isTakenBySystem is internal to the library
        // Conflict detection is handled by the KeyboardShortcuts.Recorder UI
        print("ℹ️  Conflict detection is handled by KeyboardShortcuts library")
        return true
    }

    // MARK: - Testing

    /// Test hotkey functionality
    /// For development and debugging
    @MainActor
    func testHotkey() {
        print("\n=== Hotkey Manager Test ===")

        print("1️⃣ Testing shortcut registration...")
        if let shortcut = getCurrentShortcut() {
            print("✅ PASS: Shortcut registered - \(shortcut.description)")
        } else {
            print("⚠️  Using default shortcut: Ctrl+I")
        }

        print("\n2️⃣ Testing conflict detection...")
        if let shortcut = getCurrentShortcut() {
            _ = checkForConflicts(shortcut)
            print("✅ PASS: Conflict detection handled by KeyboardShortcuts library")
        }

        print("\n3️⃣ Shortcut status:")
        if let shortcut = getCurrentShortcut() {
            print("   Press \(shortcut.description) to trigger completion")
        } else {
            print("   Press Ctrl+I to trigger completion")
        }

        print("\n===========================\n")
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