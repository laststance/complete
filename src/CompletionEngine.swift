import Foundation
import AppKit

/// CompletionEngine wraps NSSpellChecker to provide intelligent word completions
/// matching TextEdit's built-in completion behavior.
///
/// Features:
/// - System dictionary integration
/// - User dictionary support
/// - Language-aware completions
/// - Performance-optimized caching (target: <50ms, 5-15ms cached)
/// - Async completion generation
final class CompletionEngine {

    // MARK: - Singleton

    static let shared = CompletionEngine()

    // MARK: - Properties

    private let spellChecker: NSSpellChecker
    private let completionCache: NSCache<NSString, NSArray>
    private let cacheQueue = DispatchQueue(label: "com.complete.cache", qos: .userInitiated)

    /// Current spell document tag for tracking spell-checking sessions
    private var spellDocumentTag: Int = 0

    /// Default language (system language)
    private var preferredLanguage: String {
        return NSSpellChecker.shared.language()
    }

    // MARK: - Cache Statistics (for performance monitoring)

    private var cacheHits: Int = 0
    private var cacheMisses: Int = 0

    var cacheHitRate: Double {
        let total = cacheHits + cacheMisses
        guard total > 0 else { return 0.0 }
        return Double(cacheHits) / Double(total)
    }

    // MARK: - Initialization

    private init() {
        self.spellChecker = NSSpellChecker.shared
        self.completionCache = NSCache<NSString, NSArray>()

        // Configure cache limits (adjust based on memory constraints)
        // Target: 85-95% hit rate with reasonable memory usage
        completionCache.countLimit = 1000  // Max 1000 cached entries
        completionCache.totalCostLimit = 10 * 1024 * 1024  // 10MB max

        // Initialize spell document tag
        spellDocumentTag = NSSpellChecker.uniqueSpellDocumentTag()

        // Preload common completions in background
        Task {
            await preloadCommonWords()
        }
    }

    deinit {
        spellChecker.closeSpellDocument(withTag: spellDocumentTag)
    }

    // MARK: - Public API

    /// Generate completions for a partial word
    ///
    /// - Parameters:
    ///   - partialWord: The incomplete word to complete
    ///   - language: Optional language code (defaults to system language)
    /// - Returns: Array of completion strings, ordered by relevance
    func completions(for partialWord: String, language: String? = nil) -> [String] {
        // Fast path: empty or whitespace-only input
        guard !partialWord.isEmpty, partialWord.trimmingCharacters(in: .whitespaces) == partialWord else {
            return []
        }

        // Check cache first
        let cacheKey = cacheKey(for: partialWord, language: language)
        if let cached = getCachedCompletions(for: cacheKey) {
            return cached
        }

        // Generate completions using NSSpellChecker
        let completions = generateCompletions(for: partialWord, language: language)

        // Cache results
        cacheCompletions(completions, for: cacheKey)

        return completions
    }

    /// Generate completions asynchronously (for non-blocking UI)
    ///
    /// - Parameters:
    ///   - partialWord: The incomplete word to complete
    ///   - language: Optional language code
    /// - Returns: Array of completion strings
    func completionsAsync(for partialWord: String, language: String? = nil) async -> [String] {
        return await Task.detached(priority: .userInitiated) {
            return self.completions(for: partialWord, language: language)
        }.value
    }

    /// Clear the completion cache (useful for memory management)
    func clearCache() {
        cacheQueue.async { [weak self] in
            self?.completionCache.removeAllObjects()
            self?.cacheHits = 0
            self?.cacheMisses = 0
        }
    }

    /// Update the preferred language for completions
    ///
    /// - Parameter language: Language code (e.g., "en", "ja", "fr")
    func setLanguage(_ language: String) {
        spellChecker.setLanguage(language)
    }

    // MARK: - Private Methods

    /// Generate completions using NSSpellChecker
    private func generateCompletions(for partialWord: String, language: String?) -> [String] {
        let targetLanguage = language ?? preferredLanguage

        // Use NSSpellChecker's completions method
        // This matches TextEdit's behavior exactly
        let range = NSRange(location: 0, length: partialWord.utf16.count)

        let completions = spellChecker.completions(
            forPartialWordRange: range,
            in: partialWord,
            language: targetLanguage,
            inSpellDocumentWithTag: spellDocumentTag
        )

        return completions?.map { $0 as String } ?? []
    }

    /// Generate cache key for a partial word and language
    private func cacheKey(for partialWord: String, language: String?) -> String {
        let lang = language ?? preferredLanguage
        return "\(lang):\(partialWord.lowercased())"
    }

    /// Retrieve cached completions
    private func getCachedCompletions(for key: String) -> [String]? {
        var result: [String]?

        cacheQueue.sync {
            if let cached = completionCache.object(forKey: key as NSString) as? [String] {
                cacheHits += 1
                result = cached
            } else {
                cacheMisses += 1
            }
        }

        return result
    }

    /// Cache completions for future use
    private func cacheCompletions(_ completions: [String], for key: String) {
        cacheQueue.async { [weak self] in
            // Estimate cost: roughly 50 bytes per completion string
            let cost = completions.reduce(0) { $0 + $1.utf8.count }
            self?.completionCache.setObject(
                completions as NSArray,
                forKey: key as NSString,
                cost: cost
            )
        }
    }

    /// Preload common words for better cache hit rate
    private func preloadCommonWords() async {
        // Common partial words to preload
        let commonPrefixes = [
            "the", "and", "for", "are", "but", "not", "you", "all",
            "can", "her", "was", "one", "our", "out", "day", "get",
            "com", "app", "use", "new", "way", "may", "say", "she",
            "thi", "tha", "whi", "wit", "fro", "wor", "mor", "tim"
        ]

        // Preload in background
        for prefix in commonPrefixes {
            _ = completions(for: prefix)
            // Small delay to avoid overwhelming the system
            try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
        }
    }

    // MARK: - Dictionary Management

    /// Learn a new word (adds to user dictionary)
    ///
    /// - Parameter word: The word to add to the user dictionary
    func learnWord(_ word: String) {
        spellChecker.learnWord(word)
        // Clear cache to ensure learned words appear in completions
        clearCache()
    }

    /// Forget a learned word (removes from user dictionary)
    ///
    /// - Parameter word: The word to remove from the user dictionary
    func forgetWord(_ word: String) {
        spellChecker.unlearnWord(word)
        // Clear cache to ensure forgotten words don't appear
        clearCache()
    }

    /// Check if a word has been learned
    ///
    /// - Parameter word: The word to check
    /// - Returns: true if the word is in the user dictionary
    func hasLearnedWord(_ word: String) -> Bool {
        return spellChecker.hasLearnedWord(word)
    }
}

// MARK: - Performance Metrics Extension

extension CompletionEngine {

    /// Get performance statistics for monitoring
    struct PerformanceStats {
        let cacheHitRate: Double
        let totalQueries: Int
        let cacheHits: Int
        let cacheMisses: Int
    }

    var performanceStats: PerformanceStats {
        return PerformanceStats(
            cacheHitRate: cacheHitRate,
            totalQueries: cacheHits + cacheMisses,
            cacheHits: cacheHits,
            cacheMisses: cacheMisses
        )
    }

    /// Reset performance statistics
    func resetStats() {
        cacheQueue.async { [weak self] in
            self?.cacheHits = 0
            self?.cacheMisses = 0
        }
    }
}
