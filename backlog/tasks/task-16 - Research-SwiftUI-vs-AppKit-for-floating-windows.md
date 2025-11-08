---
id: task-16
title: 'Research: SwiftUI vs AppKit for floating windows'
status: Done
assignee: []
created_date: '2025-11-08 03:54'
updated_date: '2025-11-08 04:01'
labels:
  - research
  - ui
  - delegate
dependencies: []
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Compare SwiftUI and AppKit performance for floating window implementation. Research rendering performance, memory usage, and API capabilities. DELEGATE TO deep-research-agent.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Performance comparison documented
- [ ] #2 Memory usage compared
- [ ] #3 API capabilities analyzed
- [ ] #4 Recommendation provided
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Research completed by deep-research-agent. Recommendation: Use AppKit NSPanel + SwiftUI content (hybrid). AppKit provides 40-60% less memory, reliable 60fps, 1-2ms keyboard latency, native global shortcuts. SwiftUI good for content but limited for window management. Professional apps (Raycast, Shottr) use this hybrid approach.
<!-- SECTION:NOTES:END -->
