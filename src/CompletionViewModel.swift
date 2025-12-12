import Foundation
import SwiftUI

/// View model for managing completion window state
/// Handles completion data and selection state
@MainActor
class CompletionViewModel: ObservableObject {

    // MARK: - Published Properties

    /// Array of completion strings to display
    @Published var completions: [String] = []

    /// Currently selected completion index
    @Published var selectedIndex: Int = 0

    /// Text context for the current completion session
    var textContext: TextContext?

    /// Whether we're in Terminal input mode (user types word to complete)
    @Published var isTerminalInputMode: Bool = false

    /// User-entered text in Terminal input mode
    @Published var terminalInputText: String = ""

    // MARK: - Initialization

    init() {
        // Public initializer for dependency injection
    }

    // MARK: - Selection Methods

    /// Select the next completion in the list
    func selectNext() {
        guard !completions.isEmpty else { return }

        selectedIndex = (selectedIndex + 1) % completions.count
    }

    /// Select the previous completion in the list
    func selectPrevious() {
        guard !completions.isEmpty else { return }

        if selectedIndex == 0 {
            selectedIndex = completions.count - 1
        } else {
            selectedIndex -= 1
        }
    }

    /// Select a specific completion by index
    ///
    /// - Parameter index: Index to select (will be clamped to valid range)
    func select(at index: Int) {
        guard !completions.isEmpty else { return }

        selectedIndex = max(0, min(index, completions.count - 1))
    }

    /// Get the currently selected completion
    var selectedCompletion: String? {
        guard selectedIndex < completions.count else {
            return nil
        }
        return completions[selectedIndex]
    }

    // MARK: - State Management

    /// Clear all completions and reset selection
    func clear() {
        completions = []
        selectedIndex = 0
        textContext = nil
        isTerminalInputMode = false
        terminalInputText = ""
    }

    // MARK: - Terminal Input Mode

    /// Enter Terminal input mode (for apps where text extraction doesn't work)
    func enterTerminalInputMode() {
        isTerminalInputMode = true
        terminalInputText = ""
        completions = []
        selectedIndex = 0
    }

    /// Exit Terminal input mode and show completions
    func exitTerminalInputMode(with completions: [String], textContext: TextContext) {
        self.completions = completions
        self.textContext = textContext
        self.isTerminalInputMode = false
        self.selectedIndex = 0
    }

    /// Check if there are any completions
    var hasCompletions: Bool {
        return !completions.isEmpty
    }

    /// Number of completions available
    var completionCount: Int {
        return completions.count
    }
}
