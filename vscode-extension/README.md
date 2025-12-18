# Complete - Spell Autocomplete for VSCode

A VSCode extension that provides system-wide spell autocomplete triggered by `Ctrl+I`.

## Features

- **Manual Trigger** (`Ctrl+I`): Shows spell completion suggestions via QuickPick UI
- **Optional Inline Completions**: Enable inline suggestions while typing (disabled by default)
- **Multiple Languages**: Support for English, German, French, Spanish, Italian, Portuguese, and Dutch

## Installation

### From Marketplace (Coming Soon)

Search for "Complete - Spell Autocomplete" in the VSCode Extensions marketplace.

### From VSIX

1. Download the `.vsix` file from [GitHub Releases](https://github.com/laststance/complete/releases)
2. In VSCode, go to Extensions → `...` menu → "Install from VSIX..."
3. Select the downloaded file

### From Source

```bash
# Clone the repository
git clone https://github.com/laststance/complete.git
cd complete/vscode-extension

# Install dependencies
npm install

# Build the extension
npm run build

# Package the extension
npm run package
```

## Usage

1. Place your cursor on or after a word
2. Press `Ctrl+I` (or `Cmd+I` on macOS)
3. Select a completion from the QuickPick menu
4. The word will be replaced with your selection

## Configuration

Open VSCode Settings (`Ctrl+,` or `Cmd+,`) and search for "Complete" to configure.

| Setting | Type | Default | Description |
|---------|------|---------|-------------|
| `complete.enableInlineCompletions` | boolean | `false` | Enable inline completion suggestions while typing |
| `complete.maxSuggestions` | number | `10` | Maximum suggestions to show (1-50) |
| `complete.triggerCharacters` | string[] | `[]` | Characters that trigger inline completion (empty = manual only) |
| `complete.language` | enum | `"en"` | Dictionary language for spell suggestions |

### Supported Languages

| Code | Language |
|------|----------|
| `en` | English (US) |
| `en-GB` | English (British) |
| `de` | German |
| `fr` | French |
| `es` | Spanish |
| `it` | Italian |
| `pt` | Portuguese |
| `nl` | Dutch |

### Example settings.json

```json
{
  "complete.enableInlineCompletions": true,
  "complete.maxSuggestions": 5,
  "complete.triggerCharacters": [" "],
  "complete.language": "en-GB"
}
```

## Development

### Prerequisites

- Node.js 20.x or later
- npm 10.x or later

### Setup

```bash
# Install dependencies
npm install

# Start development mode (watches for changes)
npm run watch
```

### Testing

```bash
# Run extension tests
npm test

# Run linting
npm run lint
```

### Building

```bash
# Build for production
npm run build

# Create VSIX package
npm run package
```

## Architecture

```
src/
├── extension.ts          # Entry point
├── providers/
│   ├── quickPickProvider.ts    # Ctrl+I completion UI
│   └── completionProvider.ts   # Inline completions
├── services/
│   ├── spellEngine.ts          # cspell-lib wrapper
│   └── wordExtractor.ts        # Word extraction utilities
└── utils/
    └── config.ts               # Configuration management
```

## Related Projects

- [Complete (macOS)](https://github.com/laststance/complete) - Native macOS spell autocomplete app
- [cspell](https://github.com/streetsidesoftware/cspell) - Spell checking library

## License

MIT License - see [LICENSE](../LICENSE) for details.

## Contributing

Contributions are welcome! Please read our contributing guidelines before submitting a pull request.

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request
