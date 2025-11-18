# Architectural Decision Records (ADRs)

This directory contains Architectural Decision Records (ADRs) documenting significant architectural choices made during the development of the Complete macOS app.

## What is an ADR?

An Architectural Decision Record (ADR) is a document that captures an important architectural decision made along with its context and consequences. It provides a historical record of why certain design decisions were made, what alternatives were considered, and what trade-offs were accepted.

## Format

Each ADR follows a standard template (see `template.md`) with the following sections:

- **Context**: The issue motivating this decision
- **Decision**: The change being proposed or enacted
- **Alternatives Considered**: Other options evaluated with pros/cons
- **Consequences**: Positive, negative, and neutral impacts
- **Implementation Notes**: Technical details and code patterns
- **References**: Related documentation and resources

## Active ADRs

| # | Title | Status | Date | Key Impact |
|---|-------|--------|------|------------|
| [001](001-ui-framework-choice.md) | UI Framework Choice: AppKit NSPanel + SwiftUI Hybrid | Accepted | 2024-11-08 | 60% memory savings, hybrid complexity |
| [002](002-hotkey-library-selection.md) | Hotkey Library Selection: KeyboardShortcuts | Accepted | 2024-11-08 | <100ms response, built-in customization UI |
| [003](003-completion-engine-design.md) | Completion Engine Design: NSSpellChecker with Aggressive Caching | Accepted | 2024-11-08 | TextEdit compatibility, 85-95% cache hit rate |
| [004](004-result-based-error-handling.md) | Result-Based Error Handling Strategy | Accepted | 2024-11-08 | Type-safe errors, user-friendly messages |
| [005](005-structured-logging-with-oslog.md) | Structured Logging Strategy: os_log | Accepted | 2024-11-08 | Async logging, production debugging |
| [006](006-partial-dependency-injection.md) | Partial Dependency Injection Strategy | Accepted | 2025-11-19 | Protocol-based DI for 3 managers, testability |

## Decision Categories

### Performance & Optimization
- [001](001-ui-framework-choice.md): Memory efficiency (13.5-20.6 MB)
- [003](003-completion-engine-design.md): Caching strategy (0.005-0.012ms cached)
- [005](005-structured-logging-with-oslog.md): Async logging (<1μs overhead)

### User Experience
- [002](002-hotkey-library-selection.md): Global hotkey customization
- [003](003-completion-engine-design.md): TextEdit-compatible completions

### Code Quality
- [004](004-result-based-error-handling.md): Type-safe error handling
- [005](005-structured-logging-with-oslog.md): Structured debugging
- [006](006-partial-dependency-injection.md): Protocol-based testability

### Architecture
- [001](001-ui-framework-choice.md): Hybrid AppKit + SwiftUI approach
- [004](004-result-based-error-handling.md): Result type pattern
- [006](006-partial-dependency-injection.md): Partial dependency injection

## How to Use This Directory

### For Current Developers
- Review ADRs when working on related features
- Understand trade-offs before proposing changes
- Reference implementation notes for patterns

### For New Contributors
- Read ADRs 001-005 to understand core architectural choices
- Use as onboarding material for design rationale
- Learn why certain patterns exist

### For Future Decisions
- Use `template.md` when documenting new architectural decisions
- Link to related ADRs in new records
- Consider whether new decisions supersede existing ones

## Creating a New ADR

1. **Copy the template**: `cp template.md 00X-your-decision.md`
2. **Fill in sections**: Complete all sections with detail
3. **Number sequentially**: Use next available number
4. **Update README**: Add entry to the Active ADRs table
5. **Link related records**: Reference related ADRs in the new record

## Status Meanings

- **Proposed**: Under consideration, not yet implemented
- **Accepted**: Decision made and implemented
- **Deprecated**: No longer applicable but kept for historical reference
- **Superseded**: Replaced by a newer ADR (reference the superseding ADR)

## Best Practices

1. **Be Specific**: Include concrete numbers, measurements, and examples
2. **Document Alternatives**: Show what was considered and why rejected
3. **Explain Trade-offs**: Be honest about negative consequences
4. **Link Resources**: Reference code, issues, PRs, and external docs
5. **Keep Updated**: Mark ADRs as deprecated/superseded when appropriate
6. **Write Retroactively**: Document past decisions if not already recorded

## Related Documentation

- **Inline Documentation**: See `src/` files for method-level documentation
- **Performance Reports**: See `docs/performance-testing-report.md`
- **Distribution Guide**: See `docs/distribution-guide.md`
- **Project Overview**: See `CLAUDE.md`

## Questions?

If you have questions about any architectural decision:
1. Read the relevant ADR first
2. Check referenced issues/PRs
3. Review implementation in source code
4. Ask in project discussions

## License

These ADRs are part of the Complete project and follow the same license.
