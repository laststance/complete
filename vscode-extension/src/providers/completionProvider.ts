/**
 * Inline Completion Provider
 *
 * Provides spell suggestions as inline completions while typing.
 * Uses VSCode's CompletionItemProvider API for native autocomplete integration.
 *
 * @module providers/completionProvider
 */

import * as vscode from 'vscode';
import type { SpellEngine } from '../services/spellEngine';

/**
 * Minimum word length to trigger completions
 * Shorter words produce too many irrelevant suggestions
 */
const MIN_WORD_LENGTH = 2;

/**
 * Word pattern for extracting word at position
 * Matches alphabetic characters only (for spell checking)
 */
const WORD_PATTERN = /[a-zA-Z]+/;

/**
 * Configuration for the completion provider
 */
export interface CompletionProviderConfig {
  /** Maximum number of suggestions to return */
  maxSuggestions: number;
}

/**
 * Default configuration values
 */
const DEFAULT_CONFIG: CompletionProviderConfig = {
  maxSuggestions: 10,
};

/**
 * Gets the word at the given position in a document
 *
 * @param document - The text document
 * @param position - The cursor position
 * @returns Word info with text and range, or null if no word found
 *
 * @example
 * getWordAtPosition(doc, new Position(0, 3))
 * // => { word: "hello", range: Range(0,0 - 0,5) }
 */
function getWordAtPosition(
  document: vscode.TextDocument,
  position: vscode.Position
): { word: string; range: vscode.Range } | null {
  const wordRange = document.getWordRangeAtPosition(position, WORD_PATTERN);
  if (!wordRange) {
    return null;
  }
  const word = document.getText(wordRange);
  return { word, range: wordRange };
}

/**
 * SpellCompletionProvider - Inline spell suggestions
 *
 * Provides spell suggestions as VSCode completion items while typing.
 * Integrates with the native autocomplete popup for seamless UX.
 *
 * @example
 * ```typescript
 * const provider = new SpellCompletionProvider(spellEngine);
 * const disposable = vscode.languages.registerCompletionItemProvider(
 *   { scheme: 'file' },
 *   provider
 * );
 * ```
 */
export class SpellCompletionProvider implements vscode.CompletionItemProvider {
  private spellEngine: SpellEngine;
  private config: CompletionProviderConfig;

  /**
   * Creates a new SpellCompletionProvider
   *
   * @param spellEngine - The spell engine to use for suggestions
   * @param config - Optional configuration overrides
   */
  constructor(spellEngine: SpellEngine, config?: Partial<CompletionProviderConfig>) {
    this.spellEngine = spellEngine;
    this.config = { ...DEFAULT_CONFIG, ...config };
  }

  /**
   * Provides completion items for the current position
   *
   * Called by VSCode when user types or triggers completion.
   * Returns spell suggestions for the word at cursor position.
   *
   * @param document - The text document
   * @param position - The cursor position
   * @param token - Cancellation token for early exit
   * @returns Promise resolving to completion items
   *
   * @example
   * ```typescript
   * // When cursor is after "helo":
   * provider.provideCompletionItems(doc, pos, token)
   * // => [CompletionItem("hello"), CompletionItem("help"), ...]
   * ```
   */
  async provideCompletionItems(
    document: vscode.TextDocument,
    position: vscode.Position,
    token: vscode.CancellationToken
  ): Promise<vscode.CompletionItem[]> {
    // Early return if cancelled
    if (token.isCancellationRequested) {
      return [];
    }

    // Get word at cursor position
    const wordInfo = getWordAtPosition(document, position);
    if (!wordInfo) {
      return [];
    }

    // Skip short words (too many irrelevant matches)
    if (wordInfo.word.length < MIN_WORD_LENGTH) {
      return [];
    }

    // Check cancellation again before async operation
    if (token.isCancellationRequested) {
      return [];
    }

    // Get spell suggestions
    const suggestions = await this.spellEngine.getSuggestions(
      wordInfo.word,
      this.config.maxSuggestions
    );

    // Check cancellation after async operation
    if (token.isCancellationRequested) {
      return [];
    }

    // Convert to completion items
    return suggestions.map((suggestion, index) => {
      const item = new vscode.CompletionItem(
        suggestion,
        vscode.CompletionItemKind.Text
      );

      // Set sort order (padded for correct string sorting)
      item.sortText = String(index).padStart(3, '0');

      // Set replacement range to replace the entire word
      item.range = wordInfo.range;

      // Add detail to distinguish from other completions
      item.detail = 'Spell suggestion';

      return item;
    });
  }

  /**
   * Updates the provider configuration
   *
   * @param config - Partial configuration to merge
   */
  updateConfig(config: Partial<CompletionProviderConfig>): void {
    this.config = { ...this.config, ...config };
  }
}

/**
 * Creates a disposable registration for the completion provider
 *
 * Utility function to register the provider with VSCode.
 * Supports configurable trigger characters.
 *
 * @param provider - The completion provider instance
 * @param triggerCharacters - Characters that trigger completion (optional)
 * @returns VSCode Disposable for the provider registration
 *
 * @example
 * ```typescript
 * const provider = new SpellCompletionProvider(spellEngine);
 * const disposable = createCompletionProviderRegistration(provider, []);
 * context.subscriptions.push(disposable);
 * ```
 */
export function createCompletionProviderRegistration(
  provider: SpellCompletionProvider,
  triggerCharacters: string[] = []
): vscode.Disposable {
  return vscode.languages.registerCompletionItemProvider(
    { scheme: 'file' }, // All file-based documents
    provider,
    ...triggerCharacters
  );
}
