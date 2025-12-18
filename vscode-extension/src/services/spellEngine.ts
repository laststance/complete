/**
 * Spell Engine Service
 *
 * Provides spell checking and suggestion functionality using cspell-lib.
 * Includes caching for performance optimization.
 *
 * @module services/spellEngine
 */

import { suggestionsForWord, getDefaultSettings } from 'cspell-lib';
import type { SuggestionsForWordResult, SuggestionOptions } from 'cspell-lib';
import type { CSpellSettings } from '@cspell/cspell-types';

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
   * Loads default cspell settings for optimal performance.
   * Must be called before using getSuggestions().
   */
  async initialize(): Promise<void> {
    // Load default settings for use in suggestions
    this.settings = await getDefaultSettings();
    this.initialized = true;
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
   * A word is considered correct if no suggestions are returned
   * or if the only suggestion matches the input word.
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
      const options: SuggestionOptions = {
        locale: this.config.language,
        numSuggestions: 1,
        includeDefaultConfig: true,
      };

      const result: SuggestionsForWordResult = await suggestionsForWord(
        trimmedWord,
        options,
        this.settings ?? undefined
      );

      // If no suggestions or the word itself is the only suggestion, it's correct
      if (result.suggestions.length === 0) {
        return true;
      }

      // Check if the first suggestion exactly matches the word (case-insensitive)
      const firstSuggestion = result.suggestions[0];
      if (firstSuggestion?.word.toLowerCase() === trimmedWord.toLowerCase()) {
        return true;
      }

      return false;
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
    this.initialized = false;
  }

  /**
   * Fetches suggestions from cspell-lib using suggestionsForWord API
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
      const options: SuggestionOptions = {
        locale: this.config.language,
        numSuggestions: limit + 5, // Request extra for filtering
        includeDefaultConfig: true,
      };

      const result: SuggestionsForWordResult = await suggestionsForWord(
        word,
        options,
        this.settings ?? undefined
      );

      // Extract and filter suggestions
      const suggestions = this.extractSuggestions(result, word, limit);
      return suggestions;
    } catch (error) {
      console.error('SpellEngine: Error fetching suggestions:', error);
      return [];
    }
  }

  /**
   * Extracts and filters suggestions from cspell-lib result
   *
   * @param result - Result from suggestionsForWord
   * @param originalWord - The original word (to filter out)
   * @param limit - Maximum suggestions to return
   * @returns Filtered array of suggestions
   */
  private extractSuggestions(
    result: SuggestionsForWordResult,
    originalWord: string,
    limit: number
  ): string[] {
    const lowerOriginal = originalWord.toLowerCase();
    const suggestions: string[] = [];

    for (const suggestion of result.suggestions) {
      const word = suggestion.wordAdjustedToMatchCase ?? suggestion.word;

      // Skip the original word, forbidden words, and duplicates
      if (
        word.toLowerCase() !== lowerOriginal &&
        !suggestion.forbidden &&
        !suggestions.includes(word)
      ) {
        suggestions.push(word);
        if (suggestions.length >= limit) {
          break;
        }
      }
    }

    return suggestions;
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
