/**
 * Word Extractor Service
 *
 * Provides utilities for extracting and manipulating words at the cursor position.
 * Handles word detection, range calculation, and text replacement.
 *
 * @module services/wordExtractor
 */

import * as vscode from 'vscode';

/**
 * Information about a word at the cursor position
 */
export interface WordInfo {
  /** The word text */
  word: string;
  /** The range of the word in the document */
  range: vscode.Range;
}

/**
 * Regular expression pattern for matching words
 * Matches alphabetic characters only (for spell checking)
 */
const WORD_PATTERN = /[a-zA-Z]+/;

/**
 * Gets the word at the current cursor position
 *
 * Uses VSCode's built-in word range detection with a custom pattern
 * that matches only alphabetic characters (suitable for spell checking).
 *
 * @param editor - The active text editor
 * @returns Word info with the word text and range, or null if no word found
 *
 * @example
 * ```typescript
 * const wordInfo = getWordAtCursor(editor);
 * if (wordInfo) {
 *   console.log(`Word: ${wordInfo.word}, Range: ${wordInfo.range}`);
 * }
 * ```
 */
export function getWordAtCursor(editor: vscode.TextEditor): WordInfo | null {
  const position = editor.selection.active;
  const wordRange = editor.document.getWordRangeAtPosition(position, WORD_PATTERN);

  if (!wordRange) {
    return null;
  }

  const word = editor.document.getText(wordRange);
  return { word, range: wordRange };
}

/**
 * Replaces the word at the specified range with a replacement string
 *
 * Performs an atomic edit operation that replaces the text within the
 * given range. Returns success status of the edit operation.
 *
 * @param editor - The active text editor
 * @param range - The range to replace
 * @param replacement - The replacement text
 * @returns Promise resolving to true if edit was successful
 *
 * @example
 * ```typescript
 * const success = await replaceWordAtCursor(editor, wordInfo.range, 'hello');
 * if (success) {
 *   console.log('Word replaced successfully');
 * }
 * ```
 */
export async function replaceWordAtCursor(
  editor: vscode.TextEditor,
  range: vscode.Range,
  replacement: string
): Promise<boolean> {
  return editor.edit((editBuilder) => {
    editBuilder.replace(range, replacement);
  });
}

/**
 * Gets the word at cursor with extended context
 *
 * Returns additional information about the word's position within the line
 * and surrounding text for more advanced completion scenarios.
 *
 * @param editor - The active text editor
 * @returns Extended word info or null if no word found
 */
export function getWordAtCursorWithContext(
  editor: vscode.TextEditor
): (WordInfo & { lineText: string; lineNumber: number }) | null {
  const wordInfo = getWordAtCursor(editor);
  if (!wordInfo) {
    return null;
  }

  const lineNumber = editor.selection.active.line;
  const lineText = editor.document.lineAt(lineNumber).text;

  return {
    ...wordInfo,
    lineText,
    lineNumber,
  };
}

/**
 * Checks if there is a valid word at the cursor position
 *
 * Quick utility to check word existence without fetching full info.
 *
 * @param editor - The active text editor
 * @returns true if there is a word at the cursor position
 */
export function hasWordAtCursor(editor: vscode.TextEditor): boolean {
  const position = editor.selection.active;
  const wordRange = editor.document.getWordRangeAtPosition(position, WORD_PATTERN);
  return wordRange !== undefined;
}
