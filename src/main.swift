// macOS Autocomplete App
// Main entry point

import Cocoa

// Create application instance
let app = NSApplication.shared

// Set activation policy to accessory (LSUIElement equivalent)
// This prevents dock icon even before Info.plist is loaded
app.setActivationPolicy(.accessory)

// Create and set app delegate
let delegate = AppDelegate()
app.delegate = delegate

// Run the application
app.run()
