/**
 * Complete VSCode Extension - Entry Point
 *
 * This extension provides spell completion functionality triggered by Ctrl+I.
 * It replicates the macOS Complete app's functionality for VSCode.
 *
 * @module extension
 */

import * as vscode from 'vscode';

/**
 * Extension activation handler
 *
 * Called when the extension is activated. Sets up:
 * - Ctrl+I command for spell completion
 * - Optional inline completion provider
 *
 * @param context - Extension context for managing subscriptions
 */
export async function activate(
  context: vscode.ExtensionContext
): Promise<void> {
  console.log('Complete extension is now active');

  // Register the trigger completion command
  const disposable = vscode.commands.registerCommand(
    'complete.triggerCompletion',
    () => {
      void triggerCompletion();
    }
  );

  context.subscriptions.push(disposable);
}

/**
 * Triggers the spell completion workflow
 *
 * 1. Gets the word at cursor position
 * 2. Fetches spell suggestions
 * 3. Shows QuickPick UI for selection
 * 4. Replaces word with selected completion
 */
async function triggerCompletion(): Promise<void> {
  const editor = vscode.window.activeTextEditor;
  if (!editor) {
    void vscode.window.showWarningMessage('No active editor');
    return;
  }

  // Placeholder: Will be implemented in TASK-002 and TASK-003
  void vscode.window.showInformationMessage(
    'Complete: Spell completion triggered! (Implementation pending)'
  );
}

/**
 * Extension deactivation handler
 *
 * Called when the extension is deactivated.
 * Clean up any resources here.
 */
export function deactivate(): void {
  console.log('Complete extension deactivated');
}
