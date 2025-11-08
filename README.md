# Complete - macOS System-Wide Autocomplete

System-wide spell autocomplete for macOS triggered by global hotkey (Ctrl+I).

## Project Status

**Current Phase**: Phase 1 - Foundation Setup
**Version**: 0.1.0 (Development)

### Completed
- ✅ Project architecture designed (8 components)
- ✅ Research: macOS Accessibility API best practices
- ✅ Research: Global hotkey registration approaches
- ✅ Xcode project initialization with LSUIElement configuration

### In Progress
- 🔄 Phase 1: Foundation setup

## Build Instructions

### Prerequisites
- macOS 14.0 (Sonoma) or later
- Xcode 15.0 or later
- Swift 5.9 or later

### Building with Swift Package Manager

```bash
# Build the project
swift build

# Run the application
swift run

# Build for release
swift build -c release
```

### Building with Xcode

```bash
# Generate Xcode project
swift package generate-xcodeproj

# Open in Xcode
open Complete.xcodeproj
```

## Project Structure

```
complete/
├── Package.swift                  # Swift Package Manager configuration
├── src/
│   ├── main.swift                # Application entry point
│   ├── AppDelegate.swift         # App lifecycle management
│   └── Resources/
│       └── Info.plist            # LSUIElement configuration
├── tests/                        # Unit and integration tests
├── docs/                         # Research and documentation
└── backlog/                      # Task management
```

## Configuration

### LSUIElement (Background Agent)

The app runs as a background agent without dock icon:
- `Info.plist`: LSUIElement = YES
- Access via status bar menu icon
- No visible app window in dock or app switcher

### Permissions Required

- **Accessibility**: Required for text extraction and insertion
- Requested on first launch
- Can be granted in System Settings → Privacy & Security → Accessibility

## Development

### Task Management

Tasks are tracked in `/backlog/tasks/` using Backlog.md system.

View current tasks:
```bash
# List all tasks
ls -la backlog/tasks/

# View specific task
cat "backlog/tasks/task-1 - ..."
```

### Architecture

8 core components:
1. AppDelegate - LSUIElement configuration
2. HotkeyManager - Global hotkey registration
3. AccessibilityManager - Text extraction/insertion
4. CompletionEngine - NSSpellChecker wrapper
5. CompletionWindowController - Floating NSPanel
6. CompletionViewModel - State management
7. SettingsManager - Preferences persistence
8. SettingsWindowController - Settings UI

### Performance Targets

- Hotkey response: <100ms
- Completion generation: <50ms
- UI rendering: 60fps
- Memory usage: <50MB

## Technical Decisions

See `docs/` for detailed research:
- Accessibility API: `claudedocs/macOS_Accessibility_API_Research_2024-2025.md`
- Global Hotkeys: `docs/macos-global-hotkey-research-2024.md`

### Key Technologies

- **UI Framework**: AppKit NSPanel + SwiftUI hybrid
- **Hotkey System**: KeyboardShortcuts library (20-50ms response)
- **Completion**: NSSpellChecker with caching (5-15ms cached)
- **Distribution**: Direct download with notarization

## License

TBD

## Contact

TBD
