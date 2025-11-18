import Cocoa
import ApplicationServices

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
        print(trusted ? "✅ Accessibility permissions granted" : "⚠️  Accessibility permissions not granted")
        return trusted
    }

    /// Check permission status with prompt option
    /// - Parameter showPrompt: If true, shows system permission dialog
    /// - Returns: true if permissions granted, false otherwise
    func checkPermissionStatus(showPrompt: Bool) -> Bool {
        // Create options dictionary for AXIsProcessTrustedWithOptions
        let options: NSDictionary = [
            kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: showPrompt
        ]

        let trusted = AXIsProcessTrustedWithOptions(options)

        if showPrompt && !trusted {
            print("📋 System permission dialog displayed")
        }

        return trusted
    }

    // MARK: - Permission Request Flow

    /// Request accessibility permissions with user guidance
    /// Shows system dialog and provides instructions
    func requestPermissions() {
        print("🔐 Requesting accessibility permissions...")

        // Check if already granted
        if checkPermissionStatus() {
            print("✅ Permissions already granted")
            alertManager.showPermissionGrantedAlert()
            return
        }

        // Show system prompt
        let granted = checkPermissionStatus(showPrompt: true)

        if granted {
            alertManager.showPermissionGrantedAlert()
        } else {
            // Permissions not granted, show guidance
            alertManager.showPermissionGuidanceAlert()
        }
    }

    /// Verify permissions and handle denied scenario
    /// - Returns: true if ready to use, false if permissions needed
    func verifyAndRequestIfNeeded() -> Bool {
        let granted = checkPermissionStatus()

        if !granted {
            print("⚠️  Accessibility permissions required")
            requestPermissions()
            return false
        }

        return true
    }

    // MARK: - Testing Helpers

    /// Test accessibility permissions with detailed output
    /// For development and debugging
    func testPermissions() {
        print("\n=== Accessibility Permission Test ===")

        print("1️⃣ Checking permission status...")
        let granted = checkPermissionStatus()

        if granted {
            print("✅ PASS: Accessibility permissions are granted")
            print("   App can read and manipulate UI elements")
        } else {
            print("❌ FAIL: Accessibility permissions not granted")
            print("   App cannot access UI elements")
        }

        print("\n2️⃣ Testing AXUIElement access...")
        if granted {
            testAXUIElementAccess()
        } else {
            print("⏭️  Skipped (permissions not granted)")
        }

        print("\n=====================================\n")
    }

    /// Test basic AXUIElement access
    private func testAXUIElementAccess() {
        // Get system-wide accessibility element
        let systemWide = AXUIElementCreateSystemWide()

        // Try to get focused element
        var focusedElement: AnyObject?
        let result = AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedUIElementAttribute as CFString,
            &focusedElement
        )

        if result == .success {
            print("✅ PASS: Can access focused UI element")

            // Try to get role
            if let element = focusedElement {
                var role: AnyObject?
                let roleResult = AXUIElementCopyAttributeValue(
                    element as! AXUIElement,
                    kAXRoleAttribute as CFString,
                    &role
                )

                if roleResult == .success, let roleString = role as? String {
                    print("   Focused element role: \(roleString)")
                }
            }
        } else {
            print("⚠️  WARNING: Could not access focused element")
            print("   Error code: \(result.rawValue)")
        }
    }
}
