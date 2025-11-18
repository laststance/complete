# 1. UI Framework Choice: AppKit NSPanel + SwiftUI Hybrid

**Date:** 2024-11-08 (retroactive)
**Status:** Accepted
**Deciders:** Project team

## Context

The Complete app requires a floating completion window without a dock icon (LSUIElement background agent). Key requirements include:

- **Performance**: 60fps rendering for smooth animations
- **Memory**: <50MB total memory footprint
- **Responsiveness**: <100ms hotkey response time
- **UI Features**: Dark mode support, native look and feel
- **Platform**: macOS 14+ compatibility

The app must display a floating panel above all other windows without disrupting user workflow, similar to Spotlight or Alfred.

## Decision

Use **AppKit NSPanel** for window management combined with **SwiftUI** for content rendering.

This hybrid approach:
- NSPanel provides window lifecycle control, floating level management, and LSUIElement compatibility
- SwiftUI handles UI rendering, state management, and keyboard navigation
- NSHostingController bridges the two frameworks

## Alternatives Considered

### Option 1: Pure SwiftUI
- **Pros:**
  - Modern, declarative API
  - Less boilerplate code
  - Automatic state management
  - Built-in animations
- **Cons:**
  - 40-60% higher memory usage (measured at 34-45MB vs 13.5-20.6MB)
  - Complex global shortcuts integration
  - Less control over window lifecycle
  - No direct NSPanel.level support
- **Why rejected:** Memory budget exceeded target by 60%, global hotkey integration would require AppKit wrapper anyway

### Option 2: Pure AppKit
- **Pros:**
  - Maximum performance control
  - Lowest memory footprint
  - Direct NSPanel API access
  - Mature, stable framework
- **Cons:**
  - Significantly more boilerplate
  - Manual state management
  - Verbose UI code
  - Harder to maintain and evolve
- **Why rejected:** UI code complexity too high, development velocity too slow

### Option 3: Electron/Web Technologies
- **Pros:**
  - Cross-platform potential
  - Familiar web technologies
  - Rich ecosystem
- **Cons:**
  - 100MB+ memory usage
  - Slow startup time (>1s)
  - Non-native look and feel
  - Chromium overhead
- **Why rejected:** Massive overkill for simple completion UI, unacceptable memory footprint

## Consequences

### Positive
- **Memory Efficiency**: Achieved 13.5-20.6 MB (60% below 50MB target)
- **Native Integration**: Direct NSPanel lifecycle control for LSUIElement apps
- **Developer Experience**: SwiftUI benefits for UI code (declarative, reactive)
- **Performance**: 60fps rendering achieved, <100ms hotkey response
- **Maintainability**: Cleaner UI code than pure AppKit

### Negative
- **Hybrid Complexity**: Requires knowledge of both AppKit and SwiftUI
- **Lifecycle Coordination**: Must manage NSPanel lifecycle + SwiftUI view lifecycle
- **Less Common Pattern**: Fewer examples and community resources
- **Framework Bridging**: NSHostingController adds indirection

### Neutral
- **Team Knowledge**: Requires familiarity with both frameworks
- **Documentation**: Need to document hybrid patterns for contributors

## Implementation Notes

**NSPanel Configuration:**
```swift
window.level = .floating
window.styleMask = [.nonactivatingPanel, .borderless]
window.isMovableByWindowBackground = true
window.backgroundColor = .clear
window.hasShadow = true
```

**SwiftUI Integration:**
```swift
let hostingController = NSHostingController(rootView: CompletionListView())
window.contentViewController = hostingController
```

**Critical LSUIElement Behavior:**
- Windows do NOT auto-show with LSUIElement = true
- Must explicitly call `window.makeKeyAndOrderFront(nil)`
- Status bar menu icon is the only persistent UI element

**Memory Profiling Results:**
- Idle: 13.5 MB
- With completions shown: 15.8-20.6 MB
- Target was <50 MB, achieved 60% savings

## References

- Memory testing: `docs/performance-testing-report.md`
- LSUIElement guide: `docs/distribution-guide.md`
- NSPanel documentation: https://developer.apple.com/documentation/appkit/nspanel
- SwiftUI + AppKit integration: https://developer.apple.com/documentation/swiftui/nshostingcontroller
