# Manual Test Scripts

This directory contains manual test scripts used during development and debugging. These scripts complement the automated test suite when visual verification or specific system interaction patterns are needed.

## Scripts

### test_focus.sh
- **Purpose**: Debug keyboard focus issues
- **Use case**: Testing window activation and keyboard event handling
- **When to use**: When debugging focus-related issues that automated tests can't reproduce

### test_insertion_visual.sh
- **Purpose**: Visual validation of text insertion with screenshots
- **Use case**: End-to-end testing with real applications (TextEdit)
- **When to use**: Before releases, or when debugging insertion behavior in specific apps

## Running Manual Tests

These scripts are not part of the automated CI/CD pipeline. Run them manually when:
- Debugging platform-specific focus or insertion issues
- Verifying behavior in real applications
- Creating visual documentation for bug reports

## Note

Automated tests (in `tests/`) should be preferred when possible. These manual scripts are kept for scenarios that require human visual verification or complex system interactions that are difficult to automate.
