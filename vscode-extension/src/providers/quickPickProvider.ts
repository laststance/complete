/**
 * QuickPick Completion Provider
 *
 * Provides the main spell completion workflow using VSCode's QuickPick UI.
 * Coordinates word extraction, spell engine suggestions, and text replacement.
 *
 * @module providers/quickPickProvider
 */

import * as vscode from 'vscode';
import type { SpellEngine } from '../services/spellEngine';
import {
  getWordAtCursor,
  replaceWordAtCursor,
} from '../services/wordExtractor';

/**
 * Result of a completion operation
 */
export interface CompletionResult {
  /** Whether a completion was successfully applied */
  success: boolean;
  /** The original word that was replaced (if any) */
  originalWord?: string;
  /** The replacement word (if any) */
  replacement?: string;
  /** Error message if operation failed */
  error?: string;
}

/**
 * QuickPick completion provider configuration
 */
export interface QuickPickProviderConfig {
  /** Title shown in QuickPick dialog */
  title: string;
  /** Placeholder text when no selection */
  placeholderTemplate: string;
}

/**
 * Default configuration for QuickPick provider
 */
const DEFAULT_CONFIG: QuickPickProviderConfig = {
  title: 'Complete - Spell Suggestions',
  placeholderTemplate: 'Suggestions for "{word}"',
};

/**
 * QuickPickProvider - Main completion workflow coordinator
 *
 * Manages the complete spell completion flow:
 * 1. Get word at cursor position
 * 2. Fetch spell suggestions from engine
 * 3. Display QuickPick UI with suggestions
 * 4. Replace word with user selection
 *
 * @example
 * ```typescript
 * const provider = new QuickPickProvider(spellEngine);
 * await provider.triggerCompletion();
 * ```
 */
export class QuickPickProvider {
  private spellEngine: SpellEngine;
  private config: QuickPickProviderConfig;

  /**
   * Creates a new QuickPickProvider
   *
   * @param spellEngine - The spell engine to use for suggestions
   * @param config - Optional configuration overrides
   */
  constructor(spellEngine: SpellEngine, config?: Partial<QuickPickProviderConfig>) {
    this.spellEngine = spellEngine;
    this.config = { ...DEFAULT_CONFIG, ...config };
  }

  /**
   * Triggers the spell completion workflow
   *
   * Main entry point for the completion feature. Performs the complete
   * workflow of extracting word, getting suggestions, showing UI,
   * and replacing text.
   *
   * @returns Promise resolving to the completion result
   *
   * @example
   * ```typescript
   * const result = await provider.triggerCompletion();
   * if (result.success) {
   *   console.log(`Replaced "${result.originalWord}" with "${result.replacement}"`);
   * }
   * ```
   */
  async triggerCompletion(): Promise<CompletionResult> {
    // Verify we have an active editor
    const editor = vscode.window.activeTextEditor;
    if (!editor) {
      void vscode.window.showWarningMessage('No active editor');
      return { success: false, error: 'No active editor' };
    }

    // Get word at cursor position
    const wordInfo = getWordAtCursor(editor);
    if (!wordInfo || wordInfo.word.length === 0) {
      void vscode.window.showInformationMessage('No word at cursor');
      return { success: false, error: 'No word at cursor' };
    }

    // Get suggestions from spell engine
    const suggestions = await this.getSuggestionsForWord(wordInfo.word);
    if (suggestions.length === 0) {
      void vscode.window.showInformationMessage(
        `No suggestions for "${wordInfo.word}"`
      );
      return {
        success: false,
        originalWord: wordInfo.word,
        error: 'No suggestions available',
      };
    }

    // Show QuickPick UI
    const selected = await this.showQuickPick(wordInfo.word, suggestions);
    if (!selected) {
      // User cancelled
      return {
        success: false,
        originalWord: wordInfo.word,
        error: 'Selection cancelled',
      };
    }

    // Replace word with selection
    const replaced = await replaceWordAtCursor(editor, wordInfo.range, selected);
    return {
      success: replaced,
      originalWord: wordInfo.word,
      replacement: selected,
      error: replaced ? undefined : 'Failed to replace text',
    };
  }

  /**
   * Gets suggestions for a word with error handling
   *
   * @param word - The word to get suggestions for
   * @returns Array of suggestion strings
   */
  private async getSuggestionsForWord(word: string): Promise<string[]> {
    try {
      return await this.spellEngine.getSuggestions(word);
    } catch (error) {
      console.error('Error getting suggestions:', error);
      return [];
    }
  }

  /**
   * Shows the QuickPick UI with suggestions
   *
   * @param word - The original word (for display)
   * @param suggestions - Array of suggestion strings
   * @returns The selected suggestion or undefined if cancelled
   */
  private async showQuickPick(
    word: string,
    suggestions: string[]
  ): Promise<string | undefined> {
    const placeholder = this.config.placeholderTemplate.replace('{word}', word);

    return vscode.window.showQuickPick(suggestions, {
      placeHolder: placeholder,
      title: this.config.title,
    });
  }

  /**
   * Updates the provider configuration
   *
   * @param config - Partial configuration to merge
   */
  updateConfig(config: Partial<QuickPickProviderConfig>): void {
    this.config = { ...this.config, ...config };
  }
}

/**
 * Creates a disposable command for the QuickPick provider
 *
 * Utility function to easily register the trigger command with VSCode.
 *
 * @param provider - The QuickPick provider instance
 * @param commandId - The command identifier (default: 'complete.triggerCompletion')
 * @returns VSCode Disposable for the command registration
 *
 * @example
 * ```typescript
 * const provider = new QuickPickProvider(spellEngine);
 * const command = createTriggerCommand(provider);
 * context.subscriptions.push(command);
 * ```
 */
export function createTriggerCommand(
  provider: QuickPickProvider,
  commandId = 'complete.triggerCompletion'
): vscode.Disposable {
  return vscode.commands.registerCommand(commandId, () => {
    void provider.triggerCompletion();
  });
}
