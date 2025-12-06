# Complete v0.1.0 - Initial Release

System-wide spell autocomplete for macOS, triggered by global hotkey.

## Features

- **Global Hotkey Trigger**: Shift+Command+I (⇧⌘I) activates completions in any app
- **Smart Positioning**: Floating window appears near cursor (top or bottom, configurable)
- **TextEdit-Quality Completions**: Powered by NSSpellChecker with aggressive caching
- **Keyboard Navigation**: Arrow keys to navigate, Enter to select, Escape to dismiss
- **Background Agent**: Runs quietly in status bar (no dock icon)
- **Dark Mode Support**: Automatic theme switching
- **Dual Shortcut Support**: Configure primary and secondary hotkeys
- **Cross-App Compatible**: Works in TextEdit, VSCode, Chrome, Safari, Mail, and more

## Performance

| Metric | Achieved |
|--------|----------|
| Hotkey Response | 20-50ms |
| Completion Generation | <1ms (cached) |
| Memory Usage | ~15MB |
| Cache Hit Rate | 85-95% |

## Requirements

- macOS 14.0 (Sonoma) or later
- Accessibility permissions (requested on first launch)

## Installation

1. Download `Complete-YYYYMMDD.dmg` below
2. Open DMG and drag Complete to Applications
3. Launch Complete from Applications
4. Grant Accessibility permissions when prompted
5. Press ⇧⌘I (Shift+Command+I) in any text field to activate

## Keyboard Shortcuts

| Action | Shortcut |
|--------|----------|
| Trigger Completion | ⇧⌘I (customizable) |
| Navigate List | ↑ / ↓ |
| Select Completion | Enter |
| Dismiss Window | Escape |

## Source Code

Open source: https://github.com/laststance/complete

## License

MIT License
