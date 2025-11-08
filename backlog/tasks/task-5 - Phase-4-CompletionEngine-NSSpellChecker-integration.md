---
id: task-5
title: 'Phase 4: CompletionEngine - NSSpellChecker integration'
status: To Do
assignee: []
created_date: '2025-11-08 03:54'
labels:
  - core
  - completion
  - phase-4
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Create CompletionEngine class wrapping NSSpellChecker. Implement completions(forPartialWordRange:in:language:inSpellDocumentWithTag:) to match TextEdit behavior exactly.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Completions match TextEdit quality
- [ ] #2 System dictionary used
- [ ] #3 User dictionary included
- [ ] #4 Language-aware completions
- [ ] #5 Proper nouns included
<!-- AC:END -->
