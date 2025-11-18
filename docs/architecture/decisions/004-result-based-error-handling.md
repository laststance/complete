# 4. Result-Based Error Handling Strategy

**Date:** 2024-11-08
**Status:** Accepted
**Deciders:** Project team
**Supersedes:** Initial optional-based error handling (implicit)

## Context

The original codebase used optional return types (`T?`) and print() statements for error handling:

```swift
func extractTextContext() -> TextContext? {
    // Returns nil on failure
    // Errors printed to console
}
```

This approach had several problems:
- **Silent Failures**: No error context when nil returned
- **Poor Debugging**: print() statements lost in production
- **No Error Recovery**: Callers can't distinguish between error types
- **Lost Information**: Why did it fail? Permission denied? No element? API error?

We needed a type-safe error handling strategy that provides:
- Clear error types and context
- User-friendly error messages
- Recovery suggestions
- Structured logging integration
- Compile-time safety

## Decision

Use **Swift's Result type** with custom error enums and LocalizedError protocol:

1. **Result<Success, Failure>**: Type-safe error handling
2. **Custom Error Enums**: Domain-specific error types (AccessibilityError, CompletionError, etc.)
3. **LocalizedError Protocol**: User-friendly error messages
4. **os_log Integration**: Structured logging instead of print()

This replaces all optional returns and print() calls with type-safe error propagation.

## Alternatives Considered

### Option 1: Swift throws/try/catch
- **Pros:**
  - Standard Swift error handling
  - Familiar to Swift developers
  - Compiler-enforced error handling
- **Cons:**
  - Forces synchronous call chains
  - Breaks at async boundaries
  - Requires try keyword everywhere
  - Less explicit about errors in signatures
- **Why rejected:** Async completion flow would require extensive refactoring, less explicit error types

### Option 2: Keep Optional Returns
- **Pros:**
  - Simple, minimal code
  - No ceremony
  - Swift-native pattern
- **Cons:**
  - No error context
  - Silent failures
  - Poor debugging
  - Can't distinguish error types
- **Why rejected:** Insufficient for production debugging, loses critical error information

### Option 3: NSError Pattern
- **Pros:**
  - Objective-C compatible
  - Rich error information
- **Cons:**
  - Verbose (inout NSError? parameters)
  - Not type-safe
  - Requires nil checks + error checks
  - Outdated Objective-C pattern
- **Why rejected:** Not idiomatic Swift, verbosity, type safety issues

### Option 4: Custom Error Wrapper
- **Pros:**
  - Full customization
  - Can add app-specific metadata
- **Cons:**
  - Reinventing the wheel
  - More code to maintain
  - Not standard Swift
- **Why rejected:** Result<T, Error> already provides everything needed

## Consequences

### Positive
- **Type Safety**: Compiler enforces error handling at call sites
- **Error Context**: Full error information preserved (type, reason, recovery)
- **User-Friendly**: LocalizedError provides localized error messages
- **Debugging**: Structured os_log with error details
- **Recovery**: Callers can handle specific error types differently
- **Documentation**: Error cases self-document in function signatures

### Negative
- **Verbosity**: More code than optional returns (switch statements vs if-let)
- **Migration Effort**: Required updating all call sites (1-2 hours)
- **Learning Curve**: Team must understand Result type pattern

### Neutral
- **Pattern Consistency**: Requires team discipline to use Result everywhere
- **Error Exhaustiveness**: Must define all possible error cases upfront

## Implementation Notes

**Error Enum Definition:**
```swift
enum AccessibilityError: Error, Equatable {
    case permissionDenied
    case noFocusedElement
    case elementNotFoundAtPosition(x: Double, y: Double)
    case textExtractionFailed(reason: String)
    case cursorPositionUnavailable
    case axApiFailed(attribute: String, code: Int32)
    case insertionFailed(reason: String)
    case invalidTextContext
}
```

**LocalizedError Protocol:**
```swift
extension AccessibilityError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Accessibility permissions not granted"
        case .noFocusedElement:
            return "No focused text element found"
        // ...
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .permissionDenied:
            return "Open System Settings → Privacy & Security → Accessibility and enable Complete"
        // ...
        }
    }
}
```

**Function Signature:**
```swift
// Before (implicit failure)
func extractTextContext() -> TextContext? { }

// After (explicit error handling)
func extractTextContext() -> Result<TextContext, AccessibilityError> { }
```

**Call Site Pattern:**
```swift
switch AccessibilityManager.shared.extractTextContext() {
case .success(let context):
    // Handle success
case .failure(let error):
    os_log("Failed: %{public}@", log: .accessibility, type: .error, error.userFriendlyMessage)
    // Handle specific error types
}
```

**Error Types by Domain:**
- AccessibilityError (8 cases)
- CompletionError (4 cases)
- SettingsError (3 cases)
- HotkeyError (2 cases)
- WindowError (2 cases)

## References

- Swift Result type: https://developer.apple.com/documentation/swift/result
- LocalizedError: https://developer.apple.com/documentation/foundation/localizederror
- Error types implementation: `src/ErrorTypes.swift`
- os_log integration: See ADR-005
- Related issue: GitHub #4 (Error handling architecture)
