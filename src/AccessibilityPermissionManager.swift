import Cocoa
import ApplicationServices
import os.log

/// Manages accessibility permission checking and requesting
/// Extracted from AccessibilityManager for single responsibility
class AccessibilityPermissionManager {

    private let alertManager: AccessibilityAlertManager

    init(alertManager: AccessibilityAlertManager) {
        self.alertManager = alertManager
    }

    // MARK: - Permission Status

    /// Check if accessibility permissions are granted
    /// - Returns: true if permissions granted, false otherwise
    func checkPermissionStatus() -> Bool {
        let trusted = AXIsProcessTrusted()
        os_log("%{public}@ Accessibility permissions %{public}@", log: .accessibility, type: trusted ? .info : .error, 
               trusted ? "✅" : "⚠️", trusted ? "granted" : "not granted")
        return trusted
    }

    /// Check permission status with prompt option
    /// - Parameter showPrompt: If true, shows system permission dialog
    /// - Returns: true if permissions granted, false otherwise
    func checkPermissionStatus(showPrompt: Bool) -> Bool {
        let options: NSDictionary = [
            kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: showPrompt
        ]

        let trusted = AXIsProcessTrustedWithOptions(options)

        if showPrompt && !trusted {
            os_log("System permission dialog displayed", log: .accessibility, type: .info)
        }

        return trusted
    }

    // MARK: - Permission Request Flow

    /// Request accessibility permissions with user guidance
    /// Shows system dialog and provides instructions
    func requestPermissions() {
        os_log("Requesting accessibility permissions", log: .accessibility, type: .info)

        if checkPermissionStatus() {
            os_log("Permissions already granted", log: .accessibility, type: .info)
            alertManager.showPermissionGrantedAlert()
            return
        }

        let granted = checkPermissionStatus(showPrompt: true)

        if granted {
            alertManager.showPermissionGrantedAlert()
        } else {
            alertManager.showPermissionGuidanceAlert()
        }
    }

    /// Verify permissions and handle denied scenario
    /// - Returns: true if ready to use, false if permissions needed
    func verifyAndRequestIfNeeded() -> Bool {
        let granted = checkPermissionStatus()

        if !granted {
            os_log("Accessibility permissions required", log: .accessibility, type: .error)
            requestPermissions()
            return false
        }

        return true
    }

    // MARK: - Testing Helpers

    /// Test accessibility permissions with detailed output
    /// For development and debugging
    func testPermissions() {
        os_log("=== Accessibility Permission Test ===", log: .accessibility, type: .info)

        os_log("1️⃣ Checking permission status...", log: .accessibility, type: .debug)
        let granted = checkPermissionStatus()

        if granted {
            os_log("✅ PASS: Accessibility permissions are granted", log: .accessibility, type: .info)
            os_log("App can read and manipulate UI elements", log: .accessibility, type: .debug)
        } else {
            os_log("❌ FAIL: Accessibility permissions not granted", log: .accessibility, type: .error)
            os_log("App cannot access UI elements", log: .accessibility, type: .error)
        }

        os_log("2️⃣ Testing AXUIElement access...", log: .accessibility, type: .debug)
        if granted {
            testAXUIElementAccess()
        } else {
            os_log("Skipped (permissions not granted)", log: .accessibility, type: .debug)
        }

        os_log("=====================================", log: .accessibility, type: .info)
    }

    /// Test basic AXUIElement access
    private func testAXUIElementAccess() {
        let systemWide = AXUIElementCreateSystemWide()

        var focusedElement: AnyObject?
        let result = AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedUIElementAttribute as CFString,
            &focusedElement
        )

        if result == .success {
            os_log("✅ PASS: Can access focused UI element", log: .accessibility, type: .info)

            if let element = focusedElement {
                var role: AnyObject?
                let roleResult = AXUIElementCopyAttributeValue(
                    element as! AXUIElement,
                    kAXRoleAttribute as CFString,
                    &role
                )

                if roleResult == .success, let roleString = role as? String {
                    os_log("Focused element role: %{public}@", log: .accessibility, type: .debug, roleString)
                }
            }
        } else {
            os_log("⚠️ WARNING: Could not access focused element", log: .accessibility, type: .error)
            os_log("Error code: %d", log: .accessibility, type: .error, result.rawValue)
        }
    }
}