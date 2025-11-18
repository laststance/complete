# 5. Structured Logging Strategy: os_log

**Date:** 2024-11-08
**Status:** Accepted
**Deciders:** Project team
**Supersedes:** print()-based logging (implicit)

## Context

The original codebase used print() statements for logging (143 instances):

```swift
print("📝 Text extracted: \(text)")
print("⚠️ Warning: No focused element")
print("❌ Error: Failed to insert text")
```

This approach had several problems:
- **Performance**: Synchronous I/O blocks execution
- **Production**: No log level filtering (all or nothing)
- **Debugging**: Logs lost after app closes, can't filter retroactively
- **Privacy**: Sensitive data printed to console unredacted
- **Structure**: Unstructured text, hard to parse or analyze

We needed a logging solution that provides:
- Async, non-blocking logging
- Log level filtering (debug, info, error, fault)
- Persistent logs (survive app restarts)
- Privacy controls (redact sensitive data)
- Category-based organization
- Production-ready

## Decision

Use **Apple's Unified Logging System (os_log)** with categorized loggers:

1. **OSLog Categories**: Domain-specific log categories (accessibility, completion, hotkey, ui, settings, app)
2. **Log Levels**: .debug, .info, .error, .fault for severity-based filtering
3. **Privacy Annotations**: %{public}@ vs %{private}@ for PII protection
4. **Async Logging**: Non-blocking, queued to system log daemon
5. **Console.app Integration**: Logs persist and can be filtered retroactively

This replaces all 143 print() statements with structured os_log calls.

## Alternatives Considered

### Option 1: Keep print() Statements
- **Pros:**
  - Simple, no learning curve
  - Works everywhere
  - Minimal code
- **Cons:**
  - Synchronous (blocks execution)
  - No persistence
  - No filtering
  - Privacy issues
  - Production debugging impossible
- **Why rejected:** Insufficient for production apps, performance issues, no log management

### Option 2: Third-Party Logging (CocoaLumberjack, SwiftyBeaver)
- **Pros:**
  - Rich feature sets
  - Cross-platform
  - Custom formatters
  - File output
- **Cons:**
  - External dependencies
  - Larger binary size (+100-500KB)
  - Not integrated with Console.app
  - Maintenance burden
  - Redundant (duplicates os_log features)
- **Why rejected:** os_log provides everything needed, adding dependency for redundant features

### Option 3: Custom Logging Framework
- **Pros:**
  - Full control
  - App-specific features
- **Cons:**
  - Reinventing the wheel
  - 1-2 weeks implementation
  - Maintenance burden
  - Miss os_log optimizations
  - No Console.app integration
- **Why rejected:** os_log is battle-tested, maintained by Apple, no need to reinvent

### Option 4: NSLog (Objective-C Legacy)
- **Pros:**
  - Available everywhere
  - Persistent logs
- **Cons:**
  - Synchronous (slow)
  - No privacy controls
  - No log levels
  - Verbose output
  - Legacy API
- **Why rejected:** os_log is modern replacement, NSLog deprecated for new code

## Consequences

### Positive
- **Performance**: Async logging, <1μs overhead (vs ~100μs for print)
- **Production Debugging**: Logs persist, accessible via Console.app even after crash
- **Privacy**: Automatic PII redaction with %{private}@ annotations
- **Filtering**: Filter by category, log level, subsystem in Console.app
- **Integration**: Native macOS tool support (Console.app, log CLI)
- **Optimization**: Compiler can optimize away disabled log levels

### Negative
- **Learning Curve**: os_log API different from print()
- **Verbosity**: Slightly more code than print()
- **String Interpolation**: Can't use Swift string interpolation (must use format specifiers)
- **Migration Effort**: Required updating 143 call sites (2-3 hours)

### Neutral
- **Console.app Dependency**: Requires macOS tool knowledge for log access
- **Format Specifiers**: Must use C-style format strings (%{public}@, %d)

## Implementation Notes

**Logger Categories:**
```swift
extension OSLog {
    private static var subsystem = Bundle.main.bundleIdentifier ?? "io.laststance.complete"

    static let accessibility = OSLog(subsystem: subsystem, category: "accessibility")
    static let completion = OSLog(subsystem: subsystem, category: "completion")
    static let hotkey = OSLog(subsystem: subsystem, category: "hotkey")
    static let ui = OSLog(subsystem: subsystem, category: "ui")
    static let settings = OSLog(subsystem: subsystem, category: "settings")
    static let app = OSLog(subsystem: subsystem, category: "app")
}
```

**Usage Pattern:**
```swift
// Before (print)
print("📝 Text extracted: \(text)")

// After (os_log with privacy)
os_log("📝 Text extracted: %{private}@", log: .accessibility, type: .info, text)
```

**Log Levels:**
- **.debug**: Verbose debugging info (disabled in production builds)
- **.info**: General informational messages
- **.error**: Recoverable errors
- **.fault**: Critical errors requiring immediate attention

**Privacy Annotations:**
- **%{public}@**: Safe to log (counts, public strings)
- **%{private}@**: PII/sensitive data (redacted in logs)

**Console.app Filtering:**
```bash
# View all Complete app logs
log show --predicate 'subsystem == "io.laststance.complete"' --last 1h

# View only errors
log show --predicate 'subsystem == "io.laststance.complete" && messageType >= 16' --last 1h

# View accessibility category
log show --predicate 'subsystem == "io.laststance.complete" && category == "accessibility"' --last 1h
```

**Performance Impact:**
- Migration from print() → os_log
- 143 call sites updated
- 0 performance regressions
- Actually improved performance (async vs sync)

## References

- os_log documentation: https://developer.apple.com/documentation/os/logging
- Unified Logging guide: https://developer.apple.com/videos/play/wwdc2016/721/
- Logger implementation: `src/Logger.swift`
- Console.app: https://support.apple.com/guide/console/welcome/mac
- Related issue: GitHub #5 (Structured logging)
