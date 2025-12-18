# Changelog

All notable changes to the "Complete - Spell Autocomplete" extension will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2025-12-18

### Added

- **QuickPick Completion** (`Ctrl+I`): Show spell suggestions via QuickPick UI
  - Word extraction at cursor position
  - Navigate suggestions with arrow keys or `Ctrl+N`/`Ctrl+P`
  - Replace word on selection

- **Inline Completions** (Optional): Real-time suggestions while typing
  - Disabled by default for performance
  - Enable via `complete.enableInlineCompletions` setting
  - Configurable trigger characters

- **Multi-Language Support**: 8 dictionary languages
  - English (US), English (British)
  - German, French, Spanish
  - Italian, Portuguese, Dutch

- **Configuration Options**:
  - `complete.maxSuggestions`: Limit suggestions (1-50)
  - `complete.triggerCharacters`: Characters that trigger inline completion
  - `complete.language`: Select dictionary language

### Technical

- Built with cspell-lib for comprehensive spell checking
- Lazy dictionary loading for fast startup
- Full test suite with 43 integration tests
- Cross-platform CI/CD (Ubuntu, macOS, Windows)

## [Unreleased]

### Planned

- Custom dictionary support
- Workspace-specific settings
- Performance optimizations for large files
