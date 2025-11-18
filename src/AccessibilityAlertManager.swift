import Cocoa

/// Manages user alerts and guidance for accessibility permissions
/// Extracted from AccessibilityManager for single responsibility
class AccessibilityAlertManager {

    /// Show alert when permissions are granted
    func showPermissionGrantedAlert() {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Accessibility Permissions Granted"
            alert.informativeText = """
            Complete now has the necessary permissions to:
            • Read text at cursor position
            • Insert completion text

            You can start using the app with Ctrl+I
            """
            alert.alertStyle = .informational
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }

    /// Show alert with guidance for granting permissions
    func showPermissionGuidanceAlert() {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Accessibility Permissions Required"
            alert.informativeText = """
            Complete needs accessibility access to function.

            To grant permissions:

            1. Open System Settings
            2. Go to Privacy & Security → Accessibility
            3. Find "Complete" in the list
            4. Enable the checkbox next to Complete

            After granting permissions, restart the app.
            """
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Open System Settings")
            alert.addButton(withTitle: "Cancel")

            let response = alert.runModal()

            if response == .alertFirstButtonReturn {
                self.openAccessibilitySettings()
            }
        }
    }

    /// Show alert when permissions are denied during operation
    func showPermissionDeniedAlert() {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Accessibility Permissions Denied"
            alert.informativeText = """
            Complete cannot function without accessibility permissions.

            The app needs these permissions to:
            • Extract text from applications
            • Insert completion suggestions

            Please grant permissions in System Settings.
            """
            alert.alertStyle = .critical
            alert.addButton(withTitle: "Open System Settings")
            alert.addButton(withTitle: "Quit")

            let response = alert.runModal()

            if response == .alertFirstButtonReturn {
                self.openAccessibilitySettings()
            } else {
                NSApplication.shared.terminate(nil)
            }
        }
    }

    /// Open System Settings to Accessibility preferences
    func openAccessibilitySettings() {
        // macOS 13+ uses new Settings app URL scheme
        if #available(macOS 13.0, *) {
            let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
            NSWorkspace.shared.open(url)
        } else {
            // Fallback for older macOS versions
            let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
            NSWorkspace.shared.open(url)
        }

        print("🔧 Opened System Settings → Privacy & Security → Accessibility")
    }
}
