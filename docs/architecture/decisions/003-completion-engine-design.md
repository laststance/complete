# 3. Completion Engine Design: NSSpellChecker with Aggressive Caching

**Date:** 2024-11-08 (retroactive)
**Status:** Accepted
**Deciders:** Project team

## Context

The Complete app needs to generate word completions that match TextEdit's behavior exactly. Key requirements:

- **TextEdit Compatibility**: Must use same completion source as macOS TextEdit
- **Performance**: <50ms per completion request (target: 5-15ms cached)
- **Dictionary Support**: System dictionary + user-learned words
- **Language Awareness**: Support for multiple languages (English, Japanese, etc.)
- **Memory Efficiency**: Fit within overall <50MB app budget

The completion engine is called on every hotkey press, making performance critical.

## Decision

Use **NSSpellChecker** as the completion source with **aggressive caching** strategy:

1. **NSSpellChecker Integration**: System-provided spell checker API
2. **NSCache**: In-memory cache with 1000 entry limit, 10MB max
3. **Preloading**: Cache 28 common prefixes at launch for 85-95% hit rate
4. **Thread Safety**: Serial DispatchQueue for cache access

This achieves TextEdit compatibility while delivering <50ms performance through intelligent caching.

## Alternatives Considered

### Option 1: Custom Dictionary/Trie
- **Pros:**
  - Maximum performance control
  - Custom ranking algorithms
  - No system dependencies
- **Cons:**
  - 2-3 weeks implementation time
  - 10-20MB dictionary file size
  - Manual language support
  - No user dictionary integration
  - Breaks TextEdit compatibility
- **Why rejected:** TextEdit compatibility requirement makes this infeasible, massive implementation effort

### Option 2: Third-Party Completion API
- **Pros:**
  - Rich feature set
  - Machine learning powered
  - Context-aware completions
- **Cons:**
  - Network dependency (latency)
  - Privacy concerns
  - Cost (API fees)
  - No offline support
  - Breaks TextEdit compatibility
- **Why rejected:** TextEdit compatibility requirement, privacy concerns, network latency unacceptable

### Option 3: NSSpellChecker without Caching
- **Pros:**
  - Simple implementation
  - TextEdit compatible
  - No cache complexity
- **Cons:**
  - 5-15ms per request (uncached)
  - Doesn't meet <5ms target for common words
  - Repeated lookups waste CPU
- **Why rejected:** Performance target not met for frequent words, inefficient

### Option 4: Core ML Model
- **Pros:**
  - Context-aware predictions
  - Learning from user patterns
  - Modern approach
- **Cons:**
  - 50-100MB model size
  - Training data requirements
  - Inference latency (10-50ms)
  - Breaks TextEdit compatibility
- **Why rejected:** TextEdit compatibility requirement, model size exceeds memory budget

## Consequences

### Positive
- **TextEdit Compatibility**: Identical completion behavior (requirement met)
- **Performance**: 0.005-0.012ms cached lookups (1000x faster than target)
- **Cache Hit Rate**: 85-95% achieved through preloading strategy
- **System Integration**: User-learned words automatically included
- **Multi-Language**: Supports all macOS system languages
- **Memory Efficiency**: <5MB cache size (within budget)

### Negative
- **Cache Complexity**: Preloading + cache management code (~200 lines)
- **Launch Time**: +560ms for preloading (backgrounded, non-blocking)
- **Memory Overhead**: +50KB for cached completions
- **Limited Customization**: Constrained to NSSpellChecker's algorithm

### Neutral
- **Dependency**: Relies on system NSSpellChecker (stable but not controllable)
- **Cache Tuning**: Requires monitoring and adjustment over time

## Implementation Notes

**NSSpellChecker Integration:**
```swift
let completions = spellChecker.completions(
    forPartialWordRange: range,
    in: partialWord,
    language: targetLanguage,
    inSpellDocumentWithTag: spellDocumentTag
)
```

**Caching Strategy:**
```swift
// Cache configuration
completionCache.countLimit = 1000  // Max entries
completionCache.totalCostLimit = 10 * 1024 * 1024  // 10MB max
```

**Preloading for High Hit Rate:**
```swift
// 28 common prefixes → 60-70% of real-world requests
let commonPrefixes = ["the", "and", "for", "are", "but", "not", ...]
```

**Thread Safety:**
```swift
private let cacheQueue = DispatchQueue(label: "com.complete.cache", qos: .userInitiated)
```

**Performance Metrics:**
- Uncached lookup: 5-15ms (NSSpellChecker)
- Cached lookup: 0.005-0.012ms (1000x faster)
- Cache hit rate: 85-95%
- Preload time: ~560ms (background, non-blocking)

## References

- NSSpellChecker: https://developer.apple.com/documentation/appkit/nsspellchecker
- NSCache: https://developer.apple.com/documentation/foundation/nscache
- CompletionEngine implementation: `src/CompletionEngine.swift`
- Performance report: `docs/performance-testing-report.md`
- Inline documentation: `src/CompletionEngine.swift` (preloadCommonWords, generateCompletions)
