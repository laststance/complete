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
import {
  SpellCompletionProvider,
  createCompletionProviderRegistration,
} from './providers/completionProvider';
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
 * Global inline completion provider instance
 */
let completionProvider: SpellCompletionProvider | null = null;

/**
 * Disposable for the completion provider registration
 */
let completionProviderRegistration: vscode.Disposable | null = null;

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

  // Create inline completion provider
  completionProvider = new SpellCompletionProvider(spellEngine, {
    maxSuggestions: config.maxSuggestions,
  });

  // Register inline completion provider if enabled
  if (config.enableInlineCompletions) {
    completionProviderRegistration = createCompletionProviderRegistration(
      completionProvider,
      config.triggerCharacters
    );
    context.subscriptions.push(completionProviderRegistration);
  }

  // Listen for configuration changes
  const configListener = onConfigChange((newConfig) => {
    if (spellEngine) {
      spellEngine.updateConfig({
        maxSuggestions: newConfig.maxSuggestions,
        language: newConfig.language,
      });
    }

    // Update completion provider config
    if (completionProvider) {
      completionProvider.updateConfig({
        maxSuggestions: newConfig.maxSuggestions,
      });
    }

    // Handle enabling/disabling inline completions
    if (newConfig.enableInlineCompletions && !completionProviderRegistration) {
      // Enable: register provider
      if (completionProvider) {
        completionProviderRegistration = createCompletionProviderRegistration(
          completionProvider,
          newConfig.triggerCharacters
        );
        context.subscriptions.push(completionProviderRegistration);
      }
    } else if (!newConfig.enableInlineCompletions && completionProviderRegistration) {
      // Disable: dispose registration
      completionProviderRegistration.dispose();
      completionProviderRegistration = null;
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
  completionProvider = null;
  if (completionProviderRegistration) {
    completionProviderRegistration.dispose();
    completionProviderRegistration = null;
  }
  console.log('Complete extension deactivated');
}
