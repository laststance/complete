/**
 * Configuration Management
 *
 * Provides type-safe access to extension settings.
 *
 * @module utils/config
 */

import * as vscode from 'vscode';

/**
 * Extension configuration interface
 */
export interface CompleteConfig {
  /** Enable inline completion suggestions while typing */
  enableInlineCompletions: boolean;
  /** Maximum number of suggestions to show */
  maxSuggestions: number;
  /** Characters that trigger inline completion */
  triggerCharacters: string[];
  /** Dictionary language for spell suggestions */
  language: string;
}

/**
 * Default configuration values
 */
const DEFAULT_CONFIG: CompleteConfig = {
  enableInlineCompletions: false,
  maxSuggestions: 10,
  triggerCharacters: [],
  language: 'en',
};

/**
 * Get the current extension configuration
 *
 * @returns Current configuration with defaults applied
 */
export function getConfig(): CompleteConfig {
  const config = vscode.workspace.getConfiguration('complete');

  return {
    enableInlineCompletions: config.get<boolean>(
      'enableInlineCompletions',
      DEFAULT_CONFIG.enableInlineCompletions
    ),
    maxSuggestions: config.get<number>(
      'maxSuggestions',
      DEFAULT_CONFIG.maxSuggestions
    ),
    triggerCharacters: config.get<string[]>(
      'triggerCharacters',
      DEFAULT_CONFIG.triggerCharacters
    ),
    language: config.get<string>('language', DEFAULT_CONFIG.language),
  };
}

/**
 * Subscribe to configuration changes
 *
 * @param callback - Function to call when configuration changes
 * @returns Disposable to unsubscribe
 */
export function onConfigChange(
  callback: (config: CompleteConfig) => void
): vscode.Disposable {
  return vscode.workspace.onDidChangeConfiguration((event) => {
    if (event.affectsConfiguration('complete')) {
      callback(getConfig());
    }
  });
}
