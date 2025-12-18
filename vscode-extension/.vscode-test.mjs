// @ts-check
import { defineConfig } from '@vscode/test-cli';

/**
 * VSCode Test Configuration
 *
 * Uses @vscode/test-electron for integration testing
 * Tests run in a real VSCode instance with extension loaded
 */
export default defineConfig({
  files: 'dist/test/**/*.test.js',
  version: 'stable',
  workspaceFolder: './test-workspace',
  mocha: {
    ui: 'tdd',
    timeout: 20000,
    color: true,
  },
  // Increase timeout for extension activation
  launchArgs: [
    '--disable-extensions',
    '--skip-welcome',
    '--skip-release-notes',
  ],
});
