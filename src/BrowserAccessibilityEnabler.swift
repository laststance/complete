import Cocoa
import ApplicationServices
import os.log

// MARK: - Browser Accessibility Enabler

/// Enables accessibility tree access for browsers and Electron apps.
///
/// ## Problem
/// Chrome, Safari, Firefox, and Electron apps (VSCode, Slack) disable their accessibility
/// trees by default for performance. Screen readers trigger them via `AXEnhancedUserInterface`,
/// but regular apps don't get this automatically.
///
/// ## Solution
/// Before querying accessibility attributes, we set:
/// - `AXEnhancedUserInterface = true` for Chrome, Safari, Firefox (native browsers)
/// - `AXManualAccessibility = true` for Electron apps (VSCode, Atom, Slack)
///
/// ## References
/// - Chrome: https://balatero.com/writings/hammerspoon/retrieving-input-field-values-and-cursor-position-with-hammerspoon/
/// - Electron: https://github.com/electron/electron/issues/7206
/// - Mozilla: https://bugzilla.mozilla.org/show_bug.cgi?id=1664992
///
/// ## Example
/// ```swift
/// let enabler = BrowserAccessibilityEnabler()
/// if enabler.enableIfNeeded() {
///     // Now accessibility tree is available
///     let element = getElementAtPosition(point)
/// }
/// ```
final class BrowserAccessibilityEnabler {

    // MARK: - App Categories

    /// Bundle identifiers for browsers that need AXEnhancedUserInterface
    private static let browserApps: Set<String> = [
        "com.google.Chrome",
        "com.google.Chrome.canary",
        "com.google.Chrome.beta",
        "org.chromium.Chromium",
        "com.apple.Safari",
        "com.apple.SafariTechnologyPreview",
        "org.mozilla.firefox",
        "org.mozilla.firefoxdeveloperedition",
        "org.mozilla.nightly",
        "com.brave.Browser",
        "com.microsoft.edgemac",
        "com.microsoft.edgemac.Beta",
        "com.vivaldi.Vivaldi",
        "com.operasoftware.Opera",
        "com.nickvision.niceguy",  // Arc browser
        "company.thebrowser.Browser",  // Arc browser
    ]

    /// Bundle identifiers for Electron apps that need AXManualAccessibility
    private static let electronApps: Set<String> = [
        "com.microsoft.VSCode",
        "com.microsoft.VSCodeInsiders",
        "com.github.atom",
        "com.slack.Slack",
        "com.figma.Desktop",
        "com.discordapp.Discord",
        "com.spotify.client",
        "com.notion.id",
        "com.linear.linear",
        "com.postman.app",
        "com.insomnia.app",
        "com.obsidian.md",
        "md.obsidian",
    ]

    /// Cache of apps we've already enabled accessibility for
    /// Key: Process ID, Value: Whether enabling succeeded
    private var enabledApps: [pid_t: Bool] = [:]

    // MARK: - Public API

    /// Enables accessibility tree for the frontmost app if it's a browser or Electron app.
    ///
    /// This method is idempotent - calling it multiple times for the same app process
    /// is safe and will use cached results.
    ///
    /// - Returns: `true` if accessibility was enabled (or already enabled), `false` if app doesn't need it
    @discardableResult
    func enableIfNeeded() -> Bool {
        guard let frontApp = NSWorkspace.shared.frontmostApplication,
              let bundleId = frontApp.bundleIdentifier else {
            return false
        }

        let pid = frontApp.processIdentifier

        // Check cache first
        if let cached = enabledApps[pid] {
            os_log("🔄 [BrowserAccessibilityEnabler] Using cached result for '%{public}@' (pid=%{public}d): %{public}@",
                   log: .accessibility, type: .debug,
                   bundleId, pid, cached ? "enabled" : "failed")
            return cached
        }

        // Determine which attribute to set
        if Self.browserApps.contains(bundleId) {
            let success = enableBrowserAccessibility(for: pid, bundleId: bundleId)
            enabledApps[pid] = success
            return success
        } else if Self.electronApps.contains(bundleId) {
            let success = enableElectronAccessibility(for: pid, bundleId: bundleId)
            enabledApps[pid] = success
            return success
        }

        // Not a browser or Electron app
        return false
    }

    /// Checks if the frontmost app is a browser or Electron app.
    ///
    /// - Returns: `true` if the app is a browser or Electron app
    func isBrowserOrElectronApp() -> Bool {
        guard let frontApp = NSWorkspace.shared.frontmostApplication,
              let bundleId = frontApp.bundleIdentifier else {
            return false
        }

        return Self.browserApps.contains(bundleId) || Self.electronApps.contains(bundleId)
    }

    /// Gets the app element for a process.
    ///
    /// - Parameter pid: Process identifier
    /// - Returns: AXUIElement for the application
    func getAppElement(for pid: pid_t) -> AXUIElement {
        return AXUIElementCreateApplication(pid)
    }

    // MARK: - Private Implementation

    /// Enables accessibility for native browsers via AXEnhancedUserInterface.
    ///
    /// Chrome and other browsers only expose their accessibility tree when this
    /// attribute is set to `true`. This is normally done by screen readers.
    private func enableBrowserAccessibility(for pid: pid_t, bundleId: String) -> Bool {
        let appElement = AXUIElementCreateApplication(pid)

        os_log("🌐 [BrowserAccessibilityEnabler] Enabling AXEnhancedUserInterface for '%{public}@' (pid=%{public}d)",
               log: .accessibility, type: .info, bundleId, pid)

        // Set AXEnhancedUserInterface = true
        let result = AXUIElementSetAttributeValue(
            appElement,
            "AXEnhancedUserInterface" as CFString,
            kCFBooleanTrue
        )

        if result == .success {
            os_log("✅ [BrowserAccessibilityEnabler] AXEnhancedUserInterface enabled for '%{public}@'",
                   log: .accessibility, type: .info, bundleId)
            return true
        } else {
            os_log("⚠️  [BrowserAccessibilityEnabler] Failed to set AXEnhancedUserInterface for '%{public}@': %{public}d",
                   log: .accessibility, type: .error, bundleId, result.rawValue)
            // Even if setting fails, the app might still work - some apps don't support this attribute
            return false
        }
    }

    /// Enables accessibility for Electron apps via AXManualAccessibility.
    ///
    /// Electron apps use a different attribute than native browsers.
    /// See: https://github.com/electron/electron/issues/7206
    private func enableElectronAccessibility(for pid: pid_t, bundleId: String) -> Bool {
        let appElement = AXUIElementCreateApplication(pid)

        os_log("⚡️ [BrowserAccessibilityEnabler] Enabling AXManualAccessibility for Electron app '%{public}@' (pid=%{public}d)",
               log: .accessibility, type: .info, bundleId, pid)

        // Set AXManualAccessibility = true (Electron-specific)
        let result = AXUIElementSetAttributeValue(
            appElement,
            "AXManualAccessibility" as CFString,
            kCFBooleanTrue
        )

        if result == .success {
            os_log("✅ [BrowserAccessibilityEnabler] AXManualAccessibility enabled for '%{public}@'",
                   log: .accessibility, type: .info, bundleId)
            return true
        } else {
            // Electron apps often return attributeUnsupported but still work
            // See: https://github.com/electron/electron/issues/30644
            os_log("⚠️  [BrowserAccessibilityEnabler] AXManualAccessibility returned %{public}d for '%{public}@' (may still work)",
                   log: .accessibility, type: .debug, result.rawValue, bundleId)

            // Try AXEnhancedUserInterface as fallback for some Electron apps
            let fallbackResult = AXUIElementSetAttributeValue(
                appElement,
                "AXEnhancedUserInterface" as CFString,
                kCFBooleanTrue
            )

            if fallbackResult == .success {
                os_log("✅ [BrowserAccessibilityEnabler] Fallback AXEnhancedUserInterface worked for '%{public}@'",
                       log: .accessibility, type: .info, bundleId)
                return true
            }

            return false
        }
    }

    /// Clears the cache of enabled apps.
    ///
    /// Call this when accessibility permissions change or when debugging.
    func clearCache() {
        enabledApps.removeAll()
        os_log("🧹 [BrowserAccessibilityEnabler] Cache cleared", log: .accessibility, type: .debug)
    }
}
