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
import { getConfig, onConfigChange } from './utils/config';

/**
 * Global spell engine instance
 */
let spellEngine: SpellEngine | null = null;

/**
 * Extension activation handler
 *
 * Called when the extension is activated. Sets up:
 * - Spell engine initialization
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

  // Register the trigger completion command
  const triggerCommand = vscode.commands.registerCommand(
    'complete.triggerCompletion',
    () => {
      void triggerCompletion();
    }
  );

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
 * Triggers the spell completion workflow
 *
 * 1. Gets the word at cursor position
 * 2. Fetches spell suggestions from SpellEngine
 * 3. Shows QuickPick UI for selection
 * 4. Replaces word with selected completion
 */
async function triggerCompletion(): Promise<void> {
  const editor = vscode.window.activeTextEditor;
  if (!editor) {
    void vscode.window.showWarningMessage('No active editor');
    return;
  }

  if (!spellEngine) {
    void vscode.window.showErrorMessage('Spell engine not initialized');
    return;
  }

  // Get word at cursor position
  const wordInfo = getWordAtCursor(editor);
  if (!wordInfo || wordInfo.word.length === 0) {
    void vscode.window.showInformationMessage('No word at cursor');
    return;
  }

  // Get suggestions from spell engine
  const suggestions = await spellEngine.getSuggestions(wordInfo.word);
  if (suggestions.length === 0) {
    void vscode.window.showInformationMessage(
      `No suggestions for "${wordInfo.word}"`
    );
    return;
  }

  // Show QuickPick UI for selection
  const selected = await vscode.window.showQuickPick(suggestions, {
    placeHolder: `Suggestions for "${wordInfo.word}"`,
    title: 'Complete - Spell Suggestions',
  });

  // Replace word with selected completion
  if (selected) {
    await editor.edit((editBuilder) => {
      editBuilder.replace(wordInfo.range, selected);
    });
  }
}

/**
 * Word information at cursor position
 */
interface WordInfo {
  word: string;
  range: vscode.Range;
}

/**
 * Gets the word at the current cursor position
 *
 * @param editor - The active text editor
 * @returns Word info with the word text and range, or null if no word found
 */
function getWordAtCursor(editor: vscode.TextEditor): WordInfo | null {
  const position = editor.selection.active;
  const wordRange = editor.document.getWordRangeAtPosition(position, /[a-zA-Z]+/);

  if (!wordRange) {
    return null;
  }

  const word = editor.document.getText(wordRange);
  return { word, range: wordRange };
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
  console.log('Complete extension deactivated');
}
