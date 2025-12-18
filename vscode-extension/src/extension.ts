/**
 * Complete VSCode Extension - Entry Point
 *
 * This extension provides spell completion functionality triggered by Ctrl+I.
 * It replicates the macOS Complete app's functionality for VSCode.
 *
 * @module extension
 */

import * as vscode from 'vscode';
import { SpellEngine } from './services/spellEngine';
import { QuickPickProvider, createTriggerCommand } from './providers/quickPickProvider';
import { getConfig, onConfigChange } from './utils/config';

/**
 * Global spell engine instance
 */
let spellEngine: SpellEngine | null = null;

/**
 * Global QuickPick provider instance
 */
let quickPickProvider: QuickPickProvider | null = null;

/**
 * Extension activation handler
 *
 * Called when the extension is activated. Sets up:
 * - Spell engine initialization
 * - QuickPick provider for completion UI
 * - Ctrl+I command for spell completion
 * - Configuration change listener
 *
 * @param context - Extension context for managing subscriptions
 */
export async function activate(
  context: vscode.ExtensionContext
): Promise<void> {
  console.log('Complete extension is now active');

  // Initialize spell engine with current configuration
  const config = getConfig();
  spellEngine = new SpellEngine({
    maxSuggestions: config.maxSuggestions,
    language: config.language,
  });
  await spellEngine.initialize();

  // Create QuickPick provider
  quickPickProvider = new QuickPickProvider(spellEngine);

  // Register the trigger completion command
  const triggerCommand = createTriggerCommand(quickPickProvider);

  // Listen for configuration changes
  const configListener = onConfigChange((newConfig) => {
    if (spellEngine) {
      spellEngine.updateConfig({
        maxSuggestions: newConfig.maxSuggestions,
        language: newConfig.language,
      });
    }
  });

  context.subscriptions.push(triggerCommand, configListener);
}

/**
 * Extension deactivation handler
 *
 * Called when the extension is deactivated.
 * Cleans up spell engine resources.
 */
export function deactivate(): void {
  if (spellEngine) {
    spellEngine.dispose();
    spellEngine = null;
  }
  quickPickProvider = null;
  console.log('Complete extension deactivated');
}
