-- =============================================================================
-- Terminal.app Visual Regression Test Module
-- =============================================================================
-- Tests Complete app autocomplete in Terminal.app
--
-- Note: Terminal uses Complete's clipboard-based fallback mode (Terminal input mode)
-- because Terminal doesn't expose standard AX text attributes.
--
-- Usage: osascript test-terminal.applescript [output_directory]
-- =============================================================================

on run argv
    -- Configuration
    set scriptDir to do shell script "cd \"$(dirname \"$0\")\" && pwd"
    -- Go up 3 levels: modules → visualScreenshotTesting → tests → complete (project root)
    set projectRoot to do shell script "cd \"" & scriptDir & "/../../..\" && pwd"

    -- Get output directory from argument or use default
    if (count of argv) > 0 then
        set screenshotDir to item 1 of argv
    else
        set screenshotDir to projectRoot & "/tests/visualScreenshotTesting/captures/terminal/"
    end if

    -- Ensure trailing slash
    if screenshotDir does not end with "/" then
        set screenshotDir to screenshotDir & "/"
    end if

    set testText to "Hell"
    set successCount to 0
    set failCount to 0

    -- Create screenshot directory
    try
        do shell script "mkdir -p " & quoted form of screenshotDir
    on error errMsg
        log "ERROR: Failed to create directory: " & errMsg
        return "ERROR"
    end try

    log "=== TERMINAL VISUAL REGRESSION TEST ==="
    log "Output: " & screenshotDir

    -- Get screen dimensions
    tell application "Finder"
        set screenBounds to bounds of window of desktop
        set screenWidth to item 3 of screenBounds
        set screenHeight to item 4 of screenBounds
    end tell

    set windowWidth to 800
    set windowHeight to 500

    -- ==========================================================================
    -- TEST 1: Terminal (center position)
    -- ==========================================================================
    log ""
    log ">>> TEST: terminal-center"

    try
        -- Open new Terminal window
        tell application "Terminal"
            activate
            delay 0.5
            do script ""
            delay 1
        end tell

        -- Position window at center
        set centerX to (screenWidth - windowWidth) / 2
        set centerY to (screenHeight - windowHeight) / 2

        tell application "System Events"
            tell process "Terminal"
                set frontmost to true
                delay 0.3
                try
                    set position of window 1 to {centerX, centerY}
                    set size of window 1 to {windowWidth, windowHeight}
                end try
            end tell
        end tell

        delay 0.5

        -- Type test text at command prompt
        tell application "System Events"
            keystroke testText
            delay 0.5

            -- Trigger Complete popup (Shift+Command+I)
            key code 34 using {shift down, command down}
            delay 1.5
        end tell

        -- Take screenshot
        set screenshotPath to screenshotDir & "terminal-center.png"
        do shell script "screencapture -x " & quoted form of screenshotPath
        log "CAPTURED: " & screenshotPath
        set successCount to successCount + 1

        -- Dismiss popup and clear line
        tell application "System Events"
            key code 53 -- Escape
            delay 0.3
            keystroke "u" using {control down} -- Clear line
        end tell

    on error errMsg
        log "ERROR: terminal-center failed: " & errMsg
        set failCount to failCount + 1
    end try

    -- ==========================================================================
    -- TEST 2: Terminal (top-left position)
    -- ==========================================================================
    log ""
    log ">>> TEST: terminal-top-left"

    try
        -- Position window at top-left
        tell application "System Events"
            tell process "Terminal"
                set frontmost to true
                delay 0.3
                try
                    set position of window 1 to {50, 50}
                    set size of window 1 to {windowWidth, windowHeight}
                end try
            end tell
        end tell

        delay 0.5

        tell application "System Events"
            keystroke testText
            delay 0.5

            key code 34 using {shift down, command down}
            delay 1.5
        end tell

        set screenshotPath to screenshotDir & "terminal-top-left.png"
        do shell script "screencapture -x " & quoted form of screenshotPath
        log "CAPTURED: " & screenshotPath
        set successCount to successCount + 1

        tell application "System Events"
            key code 53
            delay 0.3
            keystroke "u" using {control down}
        end tell

    on error errMsg
        log "ERROR: terminal-top-left failed: " & errMsg
        set failCount to failCount + 1
    end try

    -- ==========================================================================
    -- TEST 3: Terminal (bottom-right position)
    -- ==========================================================================
    log ""
    log ">>> TEST: terminal-bottom-right"

    try
        -- Position window at bottom-right
        set bottomRightX to screenWidth - windowWidth - 50
        set bottomRightY to screenHeight - windowHeight - 100

        tell application "System Events"
            tell process "Terminal"
                set frontmost to true
                delay 0.3
                try
                    set position of window 1 to {bottomRightX, bottomRightY}
                    set size of window 1 to {windowWidth, windowHeight}
                end try
            end tell
        end tell

        delay 0.5

        tell application "System Events"
            keystroke testText
            delay 0.5

            key code 34 using {shift down, command down}
            delay 1.5
        end tell

        set screenshotPath to screenshotDir & "terminal-bottom-right.png"
        do shell script "screencapture -x " & quoted form of screenshotPath
        log "CAPTURED: " & screenshotPath
        set successCount to successCount + 1

        tell application "System Events"
            key code 53
            delay 0.3
            keystroke "u" using {control down}
        end tell

    on error errMsg
        log "ERROR: terminal-bottom-right failed: " & errMsg
        set failCount to failCount + 1
    end try

    -- Cleanup: Close Terminal window
    tell application "Terminal"
        try
            close front window
        end try
    end tell

    -- Output summary
    log ""
    log "=== TERMINAL TEST SUMMARY ==="
    log "SUCCESS: " & successCount
    log "FAILED: " & failCount
    log "OUTPUT_DIR: " & screenshotDir
    log "============================="

    if failCount > 0 then
        return "FAILED"
    else
        return "SUCCESS"
    end if
end run
