import Cocoa
import os.log

/// Utility for detecting terminal emulator applications
/// Terminal apps require special handling because arrow keys produce escape sequences
enum TerminalDetector {

    /// Bundle identifiers for terminal emulators
    private static let terminalBundleIds: Set<String> = [
        "com.apple.Terminal",           // Terminal.app
        "com.googlecode.iterm2",         // iTerm2
        "dev.warp.Warp-Stable",          // Warp Terminal
        "io.alacritty",                  // Alacritty
        "org.alacritty",                 // Alacritty (alternative)
        "com.github.wez.wezterm",        // WezTerm
        "co.zeit.hyper",                 // Hyper
        "com.qvacua.VimR",               // VimR
        "org.vim.MacVim",                // MacVim
    ]

    /// Check if the frontmost app is a terminal emulator
    /// - Returns: true if current app is a terminal where arrow keys produce escape sequences
    static func isCurrentAppTerminal() -> Bool {
        guard let frontApp = NSWorkspace.shared.frontmostApplication,
              let bundleId = frontApp.bundleIdentifier else {
            return false
        }

        let isTerminal = terminalBundleIds.contains(bundleId)
        if isTerminal {
            os_log("🖥️ Terminal app detected: %{public}@", log: .accessibility, type: .debug, bundleId)
        }
        return isTerminal
    }

    /// Check if a specific bundle identifier is a terminal app
    /// - Parameter bundleId: Bundle identifier to check
    /// - Returns: true if the bundle ID is a known terminal emulator
    static func isTerminal(bundleId: String) -> Bool {
        return terminalBundleIds.contains(bundleId)
    }
}
