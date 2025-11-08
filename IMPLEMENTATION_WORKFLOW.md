# macOS Autocomplete App - Implementation Workflow

## Project Overview

**Goal**: Create a system-wide spell autocomplete macOS application that mimics TextEdit's built-in completion feature, triggered by global hotkey.

### Core Requirements
- ✅ Global hotkey trigger (default: Ctrl+I)
- ✅ Floating completion window (no dock icon)
- ✅ Manual completion only (no auto-complete)
- ✅ Switchable position (top/bottom of cursor)
- ✅ TextEdit-like NSSpellChecker integration
- ✅ Background service app (LSUIElement)

### Technical Stack
- **Language**: Swift
- **UI Framework**: SwiftUI or AppKit (research needed)
- **APIs**: Accessibility, NSSpellChecker, Carbon/CGEvent
- **macOS Target**: macOS 12+

---

## Implementation Phases

### Phase 1: Foundation & Setup
**Timeline**: Week 1
**Priority**: Critical Path

#### Tasks
1. **task-1**: Initialize Xcode project with LSUIElement configuration
   - Create macOS app project
   - Configure Info.plist for background agent
   - Set up app lifecycle

2. **task-2**: Accessibility Permissions flow
   - Detect permission status
   - Request permissions gracefully
   - Handle denied scenarios

**Dependencies**: None
**Validation**: App launches without dock icon, permissions requested

---

### Phase 2: Hotkey System
**Timeline**: Week 1-2
**Priority**: Critical Path

#### Tasks
1. **task-3**: HotkeyManager - Global hotkey registration
   - Register Ctrl+I globally
   - Implement modern CGEvent approach
   - Add conflict detection

2. **task-17**: Customizable hotkey configuration
   - Settings UI for hotkey customization
   - Persist via UserDefaults
   - Real-time hotkey updates

**Dependencies**: Phase 1 complete
**Validation**: Hotkey triggers app reliably across all applications

**Research Required**: task-13 (Global hotkey modern approaches)

---

### Phase 3: Text Context & Manipulation
**Timeline**: Week 2-3
**Priority**: Critical Path

#### Tasks
1. **task-4**: AccessibilityManager - Text extraction
   - Extract text from active app
   - Detect cursor position
   - Word-at-cursor extraction

2. **task-18**: Text Insertion mechanism
   - Replace partial word with completion
   - Undo/redo compatibility
   - Cross-app compatibility

**Dependencies**: Phase 1 complete, Accessibility permissions
**Validation**: Text extraction works in TextEdit, Mail, Safari, Chrome, VS Code

**Research Required**: task-12 (Accessibility API best practices)

---

### Phase 4: Completion Engine
**Timeline**: Week 3-4
**Priority**: Critical Path

#### Tasks
1. **task-5**: NSSpellChecker integration
   - Wrap NSSpellChecker API
   - Match TextEdit completion behavior
   - System + user dictionary support

2. **task-19**: Performance optimization
   - Achieve <50ms completion generation
   - Implement caching strategies
   - Memory optimization (<50MB)

**Dependencies**: Phase 3 text extraction
**Validation**: Completions match TextEdit quality and speed

**Research Required**: task-14 (NSSpellChecker performance optimization)

---

### Phase 5: Floating Window UI
**Timeline**: Week 4-5
**Priority**: Critical Path

#### Tasks
1. **task-6**: CompletionWindow - Floating panel
   - Borderless NSPanel
   - Dark theme matching spec.png
   - Always-on-top behavior

2. **task-20**: Keyboard navigation
   - Up/down arrow selection
   - Enter to confirm
   - ESC to dismiss
   - Mouse click support

**Dependencies**: Phase 4 completion engine
**Validation**: Window displays correctly with keyboard/mouse navigation

**Research Required**: task-16 (SwiftUI vs AppKit performance)

---

### Phase 6: Position Management
**Timeline**: Week 5
**Priority**: High

#### Tasks
1. **task-21**: Smart window positioning
   - Cursor-relative positioning
   - Screen edge detection
   - Top/bottom toggle
   - Multi-monitor support

**Dependencies**: Phase 5 window UI
**Validation**: Positioning works correctly on multi-monitor setups

---

### Phase 7: Settings & Preferences
**Timeline**: Week 5-6
**Priority**: Medium

#### Tasks
1. **task-7**: Settings Window
   - Preferences UI
   - Hotkey customization
   - Position toggle
   - Launch at login

2. **task-8**: Menu Bar Icon
   - Menu bar access point
   - Settings access
   - Quit option
   - About panel

**Dependencies**: Phases 2, 6 complete
**Validation**: Settings persist and apply correctly

---

### Phase 8: Testing & Quality Assurance
**Timeline**: Week 6-7
**Priority**: Critical for Release

#### Tasks
1. **task-9**: Unit Tests
   - CompletionEngine tests
   - HotkeyManager tests
   - SettingsManager tests
   - >80% code coverage

2. **task-10**: Integration Tests
   - Cross-app compatibility
   - TextEdit, Mail, Safari, Chrome, VS Code
   - No crashes

3. **task-11**: Performance Testing
   - Hotkey response <100ms
   - Completion generation <50ms
   - UI rendering 60fps
   - Memory usage <50MB

**Dependencies**: All phases complete
**Validation**: All tests pass, performance benchmarks met

---

### Phase 9: Distribution Preparation
**Timeline**: Week 7-8
**Priority**: Low (Pre-Release)

#### Tasks
1. **task-22**: Code Signing & Notarization
   - Configure certificates
   - Notarization workflow
   - Entitlements setup

**Dependencies**: Phase 8 testing complete
**Validation**: App launches on clean macOS, notarization successful

**Research Required**: task-15 (LSUIElement distribution)

---

## Research Tasks (Delegate to deep-research-agent)

### High Priority Research
1. **task-12**: macOS Accessibility API best practices 2024/2025
   - Modern API patterns
   - Performance optimization
   - Common pitfalls

2. **task-13**: Global hotkey registration modern approaches
   - Carbon alternatives
   - CGEvent vs NSEvent
   - Pros/cons analysis

### Medium Priority Research
3. **task-14**: NSSpellChecker performance optimization
   - Caching strategies
   - Async patterns
   - Dictionary preloading

4. **task-15**: LSUIElement app distribution and notarization
   - Notarization process
   - Code signing requirements
   - App Store guidelines

5. **task-16**: SwiftUI vs AppKit for floating windows
   - Performance comparison
   - Memory usage
   - API capabilities

---

## Dependency Graph

```
Phase 1 (Foundation)
  ↓
Phase 2 (Hotkey) ─────────────┐
  ↓                            ↓
Phase 3 (Text Access)     Phase 7 (Settings)
  ↓                            ↑
Phase 4 (Completion)           │
  ↓                            │
Phase 5 (UI Window) ───────────┤
  ↓                            │
Phase 6 (Positioning) ─────────┘
  ↓
Phase 8 (Testing)
  ↓
Phase 9 (Distribution)
```

---

## Quality Gates

### Phase 1 Gate
- [ ] App launches as background agent
- [ ] No dock icon visible
- [ ] Accessibility permissions requested
- [ ] Menu bar accessible

### Phase 2 Gate
- [ ] Hotkey triggers app response
- [ ] Works across all applications
- [ ] Conflict detection functional
- [ ] Settings persist

### Phase 3 Gate
- [ ] Text extraction in 5+ apps
- [ ] Cursor position detection accurate
- [ ] Text insertion reliable
- [ ] No text corruption

### Phase 4 Gate
- [ ] Completions match TextEdit
- [ ] Response time <50ms
- [ ] Memory usage <50MB
- [ ] System dictionary used

### Phase 5 Gate
- [ ] Window displays correctly
- [ ] Keyboard navigation works
- [ ] Theme matches spec.png
- [ ] 60fps rendering

### Phase 6 Gate
- [ ] Cursor-relative positioning
- [ ] Multi-monitor support
- [ ] Top/bottom toggle works
- [ ] No off-screen positioning

### Phase 7 Gate
- [ ] Settings UI functional
- [ ] Preferences persist
- [ ] Menu bar accessible
- [ ] Launch at login works

### Phase 8 Gate
- [ ] All unit tests pass
- [ ] Integration tests pass
- [ ] Performance benchmarks met
- [ ] 0% crash rate

### Phase 9 Gate
- [ ] Code signing configured
- [ ] Notarization successful
- [ ] Entitlements correct
- [ ] Clean macOS launch

---

## Risk Mitigation

### High-Risk Areas
1. **Accessibility API Reliability**: Validate early with prototypes across different apps
2. **Hotkey Conflicts**: Implement robust conflict detection
3. **Performance**: Profile early and often, optimize hot paths
4. **Text Insertion**: Handle edge cases (different text systems, RTL languages)

### Mitigation Strategies
- Early prototyping for high-risk components
- Continuous performance monitoring
- Comprehensive testing across diverse applications
- User feedback integration

---

## Success Metrics

### Functional Metrics
- ✅ Works in 95% of macOS applications
- ✅ 99.9% uptime (no crashes)
- ✅ Completions match TextEdit quality

### Performance Metrics
- ⚡ Hotkey response: <100ms
- ⚡ Completion generation: <50ms
- ⚡ UI rendering: 60fps
- 💾 Memory usage: <50MB

### Quality Metrics
- 🧪 Test coverage: >80%
- 🐛 Bug density: <0.5 bugs/KLOC
- ✅ User satisfaction: >4.5/5

---

## Implementation Strategy

### Systematic Approach
1. **Foundation First**: Establish solid base (Phases 1-2)
2. **Core Features**: Build critical path (Phases 3-5)
3. **Enhancement**: Add polish and settings (Phases 6-7)
4. **Quality**: Comprehensive testing (Phase 8)
5. **Distribution**: Prepare for release (Phase 9)

### Parallel Development Opportunities
- Research tasks run in parallel to development
- Settings system alongside core features
- UI design while completion engine develops
- Testing infrastructure from day 1

### Validation Strategy
- Phase-end validation gates
- Continuous integration testing
- Performance benchmarking
- User acceptance testing

---

## Next Steps

1. **Immediate**: Execute research tasks (delegate to deep-research-agent)
2. **Week 1**: Begin Phase 1 foundation work
3. **Week 2**: Start Phase 2 hotkey system
4. **Ongoing**: Parallel research and development

---

## Notes

- All tasks tracked in `/backlog/tasks/`
- Research delegated to deep-research-agent to preserve main context
- Systematic execution with quality-first approach
- Regular validation at phase boundaries
