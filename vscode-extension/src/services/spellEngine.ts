/**
 * Spell Engine Service
 *
 * Provides spell checking and suggestion functionality using cspell-lib.
 * Includes caching for performance optimization.
 *
 * @module services/spellEngine
 */

import {
  getDefaultSettings,
  mergeSettings,
  getDictionary
} from 'cspell-lib';
import type { SpellingDictionary } from 'cspell-lib';
import type { CSpellSettings, DictionaryDefinition } from '@cspell/cspell-types';
import * as path from 'path';

/**
 * Configuration for the spell engine
 */
export interface SpellEngineConfig {
  /** Maximum suggestions to return */
  maxSuggestions: number;
  /** Language/locale for spell checking */
  language: string;
}

/**
 * Default configuration values
 */
const DEFAULT_CONFIG: SpellEngineConfig = {
  maxSuggestions: 10,
  language: 'en',
};

/**
 * Cache entry with timestamp for LRU eviction
 */
interface CacheEntry {
  suggestions: string[];
  timestamp: number;
}

/**
 * SpellEngine - Wrapper around cspell-lib for spell suggestions
 *
 * Features:
 * - Async initialization with cspell settings loading
 * - LRU cache with configurable max entries (default: 1000)
 * - Configurable language and suggestion limits
 * - Clean disposal
 *
 * @example
 * ```typescript
 * const engine = new SpellEngine();
 * await engine.initialize();
 * const suggestions = await engine.getSuggestions('helo', 5);
 * // ['hello', 'help', 'hero', ...]
 * engine.dispose();
 * ```
 */
export class SpellEngine {
  private config: SpellEngineConfig;
  private settings: CSpellSettings | null = null;
  private dictionary: SpellingDictionary | null = null;
  private suggestionCache: Map<string, CacheEntry>;
  private readonly maxCacheSize: number;
  private initialized: boolean;

  /**
   * Creates a new SpellEngine instance
   *
   * @param config - Optional configuration overrides
   * @param maxCacheSize - Maximum cache entries (default: 1000)
   */
  constructor(config?: Partial<SpellEngineConfig>, maxCacheSize = 1000) {
    this.config = { ...DEFAULT_CONFIG, ...config };
    this.suggestionCache = new Map();
    this.maxCacheSize = maxCacheSize;
    this.initialized = false;
  }

  /**
   * Initializes the spell engine
   *
   * Loads English dictionary with explicit path configuration.
   * This approach works reliably in bundled environments where
   * getDefaultBundledSettingsAsync() fails to load dictionary definitions.
   *
   * Must be called before using getSuggestions().
   */
  async initialize(): Promise<void> {
    try {
      // Get default settings as base
      const defaultSettings = await getDefaultSettings();

      // Create explicit dictionary configuration
      // This works reliably in bundled environments
      const dictionarySettings = this.createDictionarySettings();

      // Merge settings with dictionary configuration
      this.settings = mergeSettings(defaultSettings, dictionarySettings);

      // Load the dictionary for suggestions
      this.dictionary = await getDictionary(this.settings);
    } catch (error) {
      console.error('[SpellEngine] Error loading settings:', error);
      throw error;
    }
    this.initialized = true;
  }

  /**
   * Creates dictionary settings with explicit paths
   *
   * Constructs paths to dictionary files based on the extension's location.
   * Works reliably in both development and bundled environments.
   *
   * @returns CSpellSettings with dictionary definitions
   */
  private createDictionarySettings(): CSpellSettings {
    const dictionaryDefinitions: DictionaryDefinition[] = [];

    // Find the extension root directory by looking for package.json
    const extensionRoot = this.findExtensionRoot();
    const nodeModules = path.join(extensionRoot, 'node_modules');

    // Try to find and add the English US dictionary
    // pnpm stores packages in .pnpm with versioned directory names
    const enUsTriePath = this.findDictionaryFile(
      nodeModules,
      '@cspell+dict-en_us',
      '@cspell/dict-en_us',
      'en_US.trie.gz'
    );

    if (enUsTriePath) {
      dictionaryDefinitions.push({
        name: 'en_US',
        path: enUsTriePath,
        description: 'English US Dictionary',
      });
    }

    // Try to add the GB dictionary for en-GB support
    const enGbTriePath = this.findDictionaryFile(
      nodeModules,
      '@cspell+dict-en-gb-mit',
      '@cspell/dict-en-gb-mit',
      'en_GB.trie.gz'
    );

    if (enGbTriePath) {
      dictionaryDefinitions.push({
        name: 'en_GB',
        path: enGbTriePath,
        description: 'English GB Dictionary',
      });
    }

    return {
      language: this.config.language,
      dictionaries: dictionaryDefinitions.map(d => d.name),
      dictionaryDefinitions,
    };
  }

  /**
   * Finds the extension root directory by searching for package.json
   *
   * Walks up the directory tree from __dirname until it finds package.json.
   * Falls back to process.cwd() if not found.
   *
   * @returns Absolute path to extension root directory
   */
  private findExtensionRoot(): string {
    // eslint-disable-next-line @typescript-eslint/no-require-imports
    const fs = require('fs');

    // Start from __dirname and walk up
    let currentDir = __dirname;
    const maxDepth = 10; // Safety limit

    for (let i = 0; i < maxDepth; i++) {
      const packageJsonPath = path.join(currentDir, 'package.json');
      if (fs.existsSync(packageJsonPath)) {
        return currentDir;
      }

      const parentDir = path.dirname(currentDir);
      if (parentDir === currentDir) {
        // Reached root, stop
        break;
      }
      currentDir = parentDir;
    }

    // Fallback to process.cwd()
    console.warn('[SpellEngine] Could not find package.json, falling back to process.cwd()');
    return process.cwd();
  }

  /**
   * Finds a dictionary file in the node_modules directory
   *
   * Searches in multiple locations to handle different package manager layouts:
   * - pnpm: node_modules/.pnpm/[packageNameWithVersion]/node_modules/[scopedPackage]/
   * - npm/yarn: node_modules/[scopedPackage]/
   *
   * @param nodeModules - Path to node_modules directory
   * @param pnpmPackageName - Package name in pnpm format (e.g., '@cspell+dict-en_us')
   * @param scopedPackageName - Scoped package name (e.g., '@cspell/dict-en_us')
   * @param fileName - Dictionary file name (e.g., 'en_US.trie.gz')
   * @returns Full path to dictionary file, or null if not found
   */
  private findDictionaryFile(
    nodeModules: string,
    pnpmPackageName: string,
    scopedPackageName: string,
    fileName: string
  ): string | null {
    // eslint-disable-next-line @typescript-eslint/no-require-imports
    const fs = require('fs');

    // Try pnpm structure first (most common in this project)
    const pnpmDir = path.join(nodeModules, '.pnpm');
    if (fs.existsSync(pnpmDir)) {
      // List directories in .pnpm that match the package name
      const pnpmEntries = fs.readdirSync(pnpmDir) as string[];
      for (const entry of pnpmEntries) {
        if (entry.startsWith(pnpmPackageName + '@')) {
          const triePath = path.join(
            pnpmDir,
            entry,
            'node_modules',
            scopedPackageName,
            fileName
          );
          if (fs.existsSync(triePath)) {
            return triePath;
          }
        }
      }
    }

    // Fallback: try standard npm/yarn structure
    const standardPath = path.join(nodeModules, scopedPackageName, fileName);
    if (fs.existsSync(standardPath)) {
      return standardPath;
    }

    console.warn(`[SpellEngine] Could not find ${fileName} for ${scopedPackageName}`);
    return null;
  }

  /**
   * Gets spell suggestions for a word
   *
   * Uses cspell-lib's suggestionsForWord API to get suggestions.
   * Results are cached for performance.
   *
   * @param word - The word to get suggestions for
   * @param maxResults - Maximum number of suggestions (default: config.maxSuggestions)
   * @returns Array of suggestion strings, sorted by relevance
   * @throws Error if engine is not initialized
   *
   * @example
   * ```typescript
   * const suggestions = await engine.getSuggestions('helo', 5);
   * // Returns: ['hello', 'help', 'held', 'hero', 'heal']
   * ```
   */
  async getSuggestions(word: string, maxResults?: number): Promise<string[]> {
    if (!this.initialized) {
      throw new Error('SpellEngine not initialized. Call initialize() first.');
    }

    // Empty or whitespace-only words return no suggestions
    const trimmedWord = word.trim();
    if (trimmedWord.length === 0) {
      return [];
    }

    const limit = maxResults ?? this.config.maxSuggestions;
    const cacheKey = this.createCacheKey(trimmedWord, limit);

    // Check cache first
    const cached = this.suggestionCache.get(cacheKey);
    if (cached) {
      // Update timestamp for LRU
      cached.timestamp = Date.now();
      return cached.suggestions;
    }

    // Get suggestions from cspell-lib
    const suggestions = await this.fetchSuggestions(trimmedWord, limit);

    // Cache the results
    this.updateCache(cacheKey, suggestions);

    return suggestions;
  }

  /**
   * Checks if a word is spelled correctly
   *
   * Uses the dictionary's has() method to check if the word exists.
   *
   * @param word - The word to check
   * @returns true if the word is spelled correctly
   */
  async isCorrect(word: string): Promise<boolean> {
    if (!this.initialized) {
      throw new Error('SpellEngine not initialized. Call initialize() first.');
    }

    const trimmedWord = word.trim();
    if (trimmedWord.length === 0) {
      return true;
    }

    try {
      if (!this.dictionary) {
        // On error, assume word is correct to avoid false positives
        return true;
      }

      // Use dictionary.has() to check if word exists
      return this.dictionary.has(trimmedWord);
    } catch {
      // On error, assume word is correct to avoid false positives
      return true;
    }
  }

  /**
   * Updates the engine configuration
   *
   * Clears the cache since language or other settings may have changed.
   *
   * @param config - Partial configuration to merge
   */
  updateConfig(config: Partial<SpellEngineConfig>): void {
    this.config = { ...this.config, ...config };
    // Clear cache when config changes (language might differ)
    this.suggestionCache.clear();
  }

  /**
   * Gets current cache statistics
   *
   * @returns Object with cache size and max size
   */
  getCacheStats(): { size: number; maxSize: number } {
    return {
      size: this.suggestionCache.size,
      maxSize: this.maxCacheSize,
    };
  }

  /**
   * Clears the suggestion cache
   */
  clearCache(): void {
    this.suggestionCache.clear();
  }

  /**
   * Disposes of the spell engine and clears resources
   */
  dispose(): void {
    this.suggestionCache.clear();
    this.settings = null;
    this.dictionary = null;
    this.initialized = false;
  }

  /**
   * Fetches suggestions using the loaded SpellingDictionary
   *
   * Uses dictionary.suggest() which works correctly in bundled environments,
   * unlike suggestionsForWord() which fails to load dictionaries dynamically.
   *
   * @param word - Word to get suggestions for
   * @param limit - Maximum suggestions to return
   * @returns Array of suggestion strings
   */
  private async fetchSuggestions(
    word: string,
    limit: number
  ): Promise<string[]> {
    try {
      if (!this.dictionary) {
        return [];
      }

      // Use dictionary.suggest() which works in bundled code
      const results = this.dictionary.suggest(word, {
        numSuggestions: limit + 5, // Request extra for filtering
      });

      // Extract and filter suggestions
      const lowerOriginal = word.toLowerCase();
      const suggestions: string[] = [];

      for (const result of results) {
        const suggestionWord = result.word;

        // Skip the original word and duplicates
        if (
          suggestionWord.toLowerCase() !== lowerOriginal &&
          !suggestions.includes(suggestionWord)
        ) {
          suggestions.push(suggestionWord);
          if (suggestions.length >= limit) {
            break;
          }
        }
      }

      return suggestions;
    } catch (error) {
      console.error('SpellEngine: Error fetching suggestions:', error);
      return [];
    }
  }

  /**
   * Creates a cache key for a word and limit combination
   */
  private createCacheKey(word: string, limit: number): string {
    return `${this.config.language}:${word.toLowerCase()}:${limit}`;
  }

  /**
   * Updates the cache with LRU eviction
   */
  private updateCache(key: string, suggestions: string[]): void {
    // Evict oldest entries if cache is full
    if (this.suggestionCache.size >= this.maxCacheSize) {
      this.evictOldestEntries(Math.floor(this.maxCacheSize * 0.1)); // Remove 10%
    }

    this.suggestionCache.set(key, {
      suggestions,
      timestamp: Date.now(),
    });
  }

  /**
   * Evicts the oldest cache entries based on timestamp
   */
  private evictOldestEntries(count: number): void {
    // Sort entries by timestamp (oldest first)
    const entries = [...this.suggestionCache.entries()].sort(
      (a, b) => a[1].timestamp - b[1].timestamp
    );

    // Remove oldest entries
    for (let i = 0; i < Math.min(count, entries.length); i++) {
      const entry = entries[i];
      if (entry) {
        this.suggestionCache.delete(entry[0]);
      }
    }
  }
}
