import Foundation
import SwiftUI

/// View model for managing completion window state
/// Handles completion data and selection state
@MainActor
class CompletionViewModel: ObservableObject {

    // MARK: - Singleton

    static let shared = CompletionViewModel()

    // MARK: - Published Properties

    /// Array of completion strings to display
    @Published var completions: [String] = []

    /// Currently selected completion index
    @Published var selectedIndex: Int = 0

    /// Text context for the current completion session
    var textContext: TextContext?

    // MARK: - Initialization

    private init() {
        // Private initializer for singleton
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
