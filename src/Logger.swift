import Foundation
import os.log

/// Centralized logging for Complete app using Apple's Unified Logging System
/// Provides structured logging with categories and log levels for better debugging and performance
extension OSLog {
    /// Bundle identifier for the app's logging subsystem
    private static var subsystem = Bundle.main.bundleIdentifier ?? "io.laststance.complete"

    /// Accessibility operations log category
    /// Used for: Permission checks, text extraction, cursor detection, element access
    static let accessibility = OSLog(subsystem: subsystem, category: "accessibility")

    /// Completion engine log category
    /// Used for: Spell checking, suggestion generation, caching
    static let completion = OSLog(subsystem: subsystem, category: "completion")

    /// Global hotkey log category
    /// Used for: Hotkey registration, trigger events, shortcut conflicts
    static let hotkey = OSLog(subsystem: subsystem, category: "hotkey")

    /// User interface log category
    /// Used for: Window positioning, UI events, view lifecycle
    static let ui = OSLog(subsystem: subsystem, category: "ui")

    /// Settings and preferences log category
    /// Used for: UserDefaults operations, configuration changes
    static let settings = OSLog(subsystem: subsystem, category: "settings")

    /// Application lifecycle log category
    /// Used for: App launch, termination, state transitions
    static let app = OSLog(subsystem: subsystem, category: "app")
}

/// Logging Helper Functions
/// Convenience methods for common logging patterns
enum Logger {
    /// Log an informational message
    static func info(_ message: StaticString, log: OSLog = .default, _ args: CVarArg...) {
        os_log(message, log: log, type: .info, args)
    }

    /// Log a debug message (filtered out in production builds)
    static func debug(_ message: StaticString, log: OSLog = .default, _ args: CVarArg...) {
        os_log(message, log: log, type: .debug, args)
    }

    /// Log an error message
    static func error(_ message: StaticString, log: OSLog = .default, _ args: CVarArg...) {
        os_log(message, log: log, type: .error, args)
    }

    /// Log a fault (critical error requiring immediate attention)
    static func fault(_ message: StaticString, log: OSLog = .default, _ args: CVarArg...) {
        os_log(message, log: log, type: .fault, args)
    }
}
