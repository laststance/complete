# 6. Partial Dependency Injection Strategy

**Date:** 2025-11-19
**Status:** Accepted
**Deciders:** Project team

## Context

The original codebase used the singleton pattern for all four manager classes:

```swift
SettingsManager.shared
CompletionEngine.shared
AccessibilityManager.shared
HotkeyManager.shared
```

This approach had several problems:
- **Tight Coupling**: Every component directly depends on global state
- **Testing Difficulty**: Cannot inject mocks or test doubles
- **Global Mutable State**: Multiple access points make state tracking difficult
- **Unclear Dependencies**: Object relationships hidden behind .shared calls
- **No Lifecycle Control**: Singletons persist for entire app lifetime

We needed a dependency injection strategy that:
- Reduces singleton coupling where beneficial
- Maintains testability
- Preserves existing functionality
- Allows gradual migration without breaking changes
- Works within existing architecture constraints

## Decision

Implement **partial dependency injection** using protocol-based abstraction for 3 of 4 managers:

1. **Protocol Definitions**: Create protocols for manager interfaces
   - `SettingsManaging` (settings persistence)
   - `CompletionProviding` (completion generation)
   - `AccessibilityManaging` (accessibility operations)

2. **AppDelegate Ownership**: AppDelegate owns protocol-typed instances
   ```swift
   private let settingsManager: SettingsManaging
   private let completionEngine: CompletionProviding
   private let accessibilityManager: AccessibilityManaging
   ```

3. **Bridge Pattern**: Temporarily initialize from .shared during migration
   ```swift
   self.settingsManager = SettingsManager.shared  // Temporary bridge
   ```

4. **HotkeyManager Exception**: Keep HotkeyManager as singleton due to library constraint

## Alternatives Considered

### Option 1: Full Dependency Injection (All 4 Managers)
- **Pros:**
  - Complete elimination of singleton pattern
  - Maximum testability
  - Clean architecture compliance
- **Cons:**
  - KeyboardShortcuts library uses global callback registration
  - Requires wrapper layer for HotkeyManager (~2-3 hours additional work)
  - Complexity not justified by testing benefit (hotkeys tested manually)
- **Why rejected:** HotkeyManager singleton is acceptable given library constraint and manual testing approach

### Option 2: Keep All Singletons (No Changes)
- **Pros:**
  - Zero migration effort
  - No risk of breaking changes
  - Familiar pattern
- **Cons:**
  - Testing remains difficult
  - Tight coupling persists
  - Global mutable state issues continue
- **Why rejected:** Insufficient testing capability, violates SOLID principles

### Option 3: Custom Dependency Injection Framework
- **Pros:**
  - Enterprise-grade DI capabilities
  - Automatic dependency resolution
  - Sophisticated lifecycle management
- **Cons:**
  - Massive overkill for 3 managers
  - External dependency (Swinject, Needle, etc.)
  - 1-2 weeks implementation time
  - Increased complexity and maintenance burden
- **Why rejected:** Simple protocol-based approach sufficient for this scale

### Option 4: Service Locator Pattern
- **Pros:**
  - Centralized dependency management
  - Easy to swap implementations
- **Cons:**
  - Still global state (ServiceLocator.shared)
  - Compile-time safety lost
  - Dependencies hidden from call sites
- **Why rejected:** Protocol-based DI provides better compile-time safety

## Consequences

### Positive
- **Testability**: Can inject mocks for SettingsManager, CompletionEngine, AccessibilityManager
- **Explicit Dependencies**: AppDelegate constructor shows all dependencies clearly
- **SOLID Compliance**: Dependency Inversion Principle satisfied via protocols
- **Gradual Migration**: Bridge pattern allows incremental adoption
- **Type Safety**: Protocol conformance verified at compile time
- **Future Flexibility**: Easy to create new instances when needed

### Negative
- **Bridge Pattern Overhead**: Temporary use of .shared in init() adds cognitive load
- **Partial Solution**: Still has one singleton (HotkeyManager)
- **Migration Effort**: Required updating 3 protocol definitions and AppDelegate (~3 hours)
- **Protocol Maintenance**: Must keep protocols in sync with concrete implementations

### Neutral
- **Testing Focus Shift**: Unit testing now viable, but still require integration tests
- **Pattern Inconsistency**: 3 DI + 1 singleton creates architectural asymmetry
- **Future Work**: Complete migration requires removing bridge pattern later

## Implementation Notes

**Protocol Definitions** (`src/Protocols.swift`):
```swift
/// Protocol for settings management (UserDefaults persistence)
protocol SettingsManaging: AnyObject {
    var launchAtLogin: Bool { get set }
    func resetToDefaults()
    func restoreSettings()
}

/// Protocol for completion generation
protocol CompletionProviding: AnyObject {
    func completions(for partialWord: String, language: String?) -> [String]
    func completionsAsync(for partialWord: String, language: String?) async -> [String]
    func clearCache()
}

/// Protocol for accessibility operations
protocol AccessibilityManaging: AnyObject {
    func extractTextContext() -> Result<TextContext, AccessibilityError>
    func getCursorScreenPosition(from element: AXUIElement?) -> Result<CGPoint, AccessibilityError>
    func insertCompletion(_ completion: String, replacing context: TextContext) -> Bool
    func checkPermissionStatus() -> Bool
    func requestPermissions()
    func showPermissionDeniedAlert()
    func testPermissions()
    func verifyAndRequestIfNeeded() -> Bool
}

// MARK: - Protocol Conformance

extension SettingsManager: SettingsManaging {}
extension CompletionEngine: CompletionProviding {}
extension AccessibilityManager: AccessibilityManaging {}
```

**AppDelegate Ownership**:
```swift
class AppDelegate: NSObject, NSApplicationDelegate {

    // MARK: - Managed Dependencies (Dependency Injection)

    /// Settings manager (owned instance, not singleton)
    private let settingsManager: SettingsManaging

    /// Completion engine (owned instance, not singleton)
    private let completionEngine: CompletionProviding

    /// Accessibility manager (owned instance, not singleton)
    private let accessibilityManager: AccessibilityManaging

    // MARK: - Initialization

    override init() {
        // Initialize managed dependencies
        // Note: We still use .shared here as a temporary bridge during migration
        // Future work: Create new instances and inject them throughout the app
        self.settingsManager = SettingsManager.shared
        self.completionEngine = CompletionEngine.shared
        self.accessibilityManager = AccessibilityManager.shared

        super.init()
    }
```

**Future Migration Path**:
1. Remove bridge pattern - create new instances instead of using .shared
2. Inject dependencies into child components (CompletionWindowController, etc.)
3. Consider making managers true classes (not singletons) with factory methods
4. Evaluate if HotkeyManager wrapper is justified for testing

**HotkeyManager Singleton Justification**:
```swift
// KeyboardShortcuts library pattern - requires global callback
KeyboardShortcuts.onKeyDown(for: .completionTrigger) { [weak self] in
    self?.triggerCompletion()
}
```
This global callback registration makes traditional DI difficult. A wrapper would add complexity without testing benefit since hotkeys are tested manually.

**Testing Pattern**:
```swift
// Example mock for testing
class MockSettingsManager: SettingsManaging {
    var launchAtLogin: Bool = false
    func resetToDefaults() { /* test implementation */ }
    func restoreSettings() { /* test implementation */ }
}

// Inject mock into AppDelegate for testing
let mockSettings = MockSettingsManager()
let appDelegate = AppDelegate(
    settingsManager: mockSettings,
    completionEngine: mockCompletion,
    accessibilityManager: mockAccessibility
)
```

**Scope**: This refactoring affects:
- `src/Protocols.swift` (created)
- `src/AppDelegate.swift` (modified)
- Future: `src/CompletionWindowController.swift` (when removing bridge pattern)

## References

- Related issue: GitHub #8 (Dependency injection refactoring)
- SOLID principles: https://en.wikipedia.org/wiki/SOLID
- Swift protocols: https://docs.swift.org/swift-book/LanguageGuide/Protocols.html
- KeyboardShortcuts library: https://github.com/sindresorhus/KeyboardShortcuts
- Related ADRs: See ADR-004 (Result-based error handling)
