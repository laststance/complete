-- =============================================================================
-- Chrome Canary Visual Regression Test Module
-- =============================================================================
-- Tests Complete app autocomplete in Chrome Canary:
--   1. Textarea element
--   2. Input type="text" element
--   3. Address bar
--
-- Usage: osascript test-chrome-canary.applescript [output_directory]
-- =============================================================================

on run argv
    -- Configuration
    set scriptDir to do shell script "cd \"$(dirname \"$0\")\" && pwd"
    set projectRoot to do shell script "cd \"" & scriptDir & "/../..\" && pwd"
    set testPagePath to projectRoot & "/tests/visualScreenshotTesting/test-apps/test-page.html"

    -- Get output directory from argument or use default
    if (count of argv) > 0 then
        set screenshotDir to item 1 of argv
    else
        set screenshotDir to projectRoot & "/tests/visualScreenshotTesting/captures/chrome-canary/"
    end if

    -- Ensure trailing slash
    if screenshotDir does not end with "/" then
        set screenshotDir to screenshotDir & "/"
    end if

    set testText to "Hell"
    set successCount to 0
    set failCount to 0

    -- Chrome Canary app identifier
    set chromeApp to "Google Chrome Canary"

    -- Create screenshot directory
    try
        do shell script "mkdir -p " & quoted form of screenshotDir
    on error errMsg
        log "ERROR: Failed to create directory: " & errMsg
        return "ERROR"
    end try

    -- Check if Chrome Canary is installed
    try
        tell application "System Events"
            if not (exists application process chromeApp) then
                -- Try to launch Chrome Canary
                tell application chromeApp to activate
                delay 2
            end if
        end tell
    on error
        log "ERROR: Chrome Canary is not installed"
        return "ERROR"
    end try

    log "=== CHROME CANARY VISUAL REGRESSION TEST ==="
    log "Test page: " & testPagePath
    log "Output: " & screenshotDir

    -- Open test page in Chrome Canary
    set testPageURL to "file://" & testPagePath

    tell application chromeApp
        activate
        delay 0.5

        -- Open test page in new window using open location
        open location testPageURL
        delay 2
    end tell

    -- Get screen dimensions
    tell application "Finder"
        set screenBounds to bounds of window of desktop
        set screenWidth to item 3 of screenBounds
        set screenHeight to item 4 of screenBounds
    end tell

    set windowWidth to 800
    set windowHeight to 600

    -- ==========================================================================
    -- TEST 1: Textarea (center position)
    -- ==========================================================================
    log ""
    log ">>> TEST: chrome-textarea-center"

    try
        -- Position window at center
        set centerX to (screenWidth - windowWidth) / 2
        set centerY to (screenHeight - windowHeight) / 2

        tell application "System Events"
            tell process chromeApp
                set frontmost to true
                delay 0.3
                try
                    set position of window 1 to {centerX, centerY}
                    set size of window 1 to {windowWidth, windowHeight}
                end try
            end tell
        end tell

        delay 0.5

        -- Click on textarea (approximate position)
        tell application "System Events"
            -- Tab to focus textarea (it has autofocus)
            keystroke tab
            delay 0.3

            -- Type test text
            keystroke testText
            delay 0.3

            -- Trigger Complete popup (Shift+Command+I)
            key code 34 using {shift down, command down}
            delay 1.5
        end tell

        -- Take screenshot
        set screenshotPath to screenshotDir & "textarea-center.png"
        do shell script "screencapture -x " & quoted form of screenshotPath
        log "CAPTURED: " & screenshotPath
        set successCount to successCount + 1

        -- Dismiss popup and clear
        tell application "System Events"
            key code 53 -- Escape
            delay 0.3
            keystroke "a" using {command down}
            key code 51 -- Delete
        end tell

    on error errMsg
        log "ERROR: textarea-center failed: " & errMsg
        set failCount to failCount + 1
    end try

    -- ==========================================================================
    -- TEST 2: Input text (center position)
    -- ==========================================================================
    log ""
    log ">>> TEST: chrome-input-center"

    try
        tell application "System Events"
            -- Tab to input field
            keystroke tab
            delay 0.3

            -- Type test text
            keystroke testText
            delay 0.3

            -- Trigger Complete popup
            key code 34 using {shift down, command down}
            delay 1.5
        end tell

        -- Take screenshot
        set screenshotPath to screenshotDir & "input-center.png"
        do shell script "screencapture -x " & quoted form of screenshotPath
        log "CAPTURED: " & screenshotPath
        set successCount to successCount + 1

        -- Dismiss popup and clear
        tell application "System Events"
            key code 53 -- Escape
            delay 0.3
            keystroke "a" using {command down}
            key code 51 -- Delete
        end tell

    on error errMsg
        log "ERROR: input-center failed: " & errMsg
        set failCount to failCount + 1
    end try

    -- ==========================================================================
    -- TEST 3: Address bar
    -- ==========================================================================
    log ""
    log ">>> TEST: chrome-addressbar"

    try
        tell application "System Events"
            -- Focus address bar (Cmd+L)
            keystroke "l" using {command down}
            delay 0.5

            -- Type test text
            keystroke testText
            delay 0.3

            -- Trigger Complete popup
            key code 34 using {shift down, command down}
            delay 1.5
        end tell

        -- Take screenshot
        set screenshotPath to screenshotDir & "addressbar.png"
        do shell script "screencapture -x " & quoted form of screenshotPath
        log "CAPTURED: " & screenshotPath
        set successCount to successCount + 1

        -- Dismiss and restore
        tell application "System Events"
            key code 53 -- Escape
            delay 0.3
            key code 53 -- Escape again to exit address bar
        end tell

    on error errMsg
        log "ERROR: addressbar failed: " & errMsg
        set failCount to failCount + 1
    end try

    -- ==========================================================================
    -- TEST 4: Textarea (top-left position)
    -- ==========================================================================
    log ""
    log ">>> TEST: chrome-textarea-top-left"

    try
        -- Position window at top-left
        tell application "System Events"
            tell process chromeApp
                set frontmost to true
                delay 0.3
                try
                    set position of window 1 to {50, 50}
                    set size of window 1 to {windowWidth, windowHeight}
                end try
            end tell
        end tell

        delay 0.5

        -- Reload page to reset using keyboard shortcut
        tell application "System Events"
            keystroke "r" using {command down}
        end tell
        delay 1.5

        tell application "System Events"
            keystroke tab
            delay 0.3
            keystroke testText
            delay 0.3
            key code 34 using {shift down, command down}
            delay 1.5
        end tell

        set screenshotPath to screenshotDir & "textarea-top-left.png"
        do shell script "screencapture -x " & quoted form of screenshotPath
        log "CAPTURED: " & screenshotPath
        set successCount to successCount + 1

        tell application "System Events"
            key code 53
        end tell

    on error errMsg
        log "ERROR: textarea-top-left failed: " & errMsg
        set failCount to failCount + 1
    end try

    -- ==========================================================================
    -- TEST 5: Textarea (bottom-right position)
    -- ==========================================================================
    log ""
    log ">>> TEST: chrome-textarea-bottom-right"

    try
        -- Position window at bottom-right
        set bottomRightX to screenWidth - windowWidth - 50
        set bottomRightY to screenHeight - windowHeight - 100

        tell application "System Events"
            tell process chromeApp
                set frontmost to true
                delay 0.3
                try
                    set position of window 1 to {bottomRightX, bottomRightY}
                    set size of window 1 to {windowWidth, windowHeight}
                end try
            end tell
        end tell

        delay 0.5

        -- Reload page using keyboard shortcut
        tell application "System Events"
            keystroke "r" using {command down}
        end tell
        delay 1.5

        tell application "System Events"
            keystroke tab
            delay 0.3
            keystroke testText
            delay 0.3
            key code 34 using {shift down, command down}
            delay 1.5
        end tell

        set screenshotPath to screenshotDir & "textarea-bottom-right.png"
        do shell script "screencapture -x " & quoted form of screenshotPath
        log "CAPTURED: " & screenshotPath
        set successCount to successCount + 1

        tell application "System Events"
            key code 53
        end tell

    on error errMsg
        log "ERROR: textarea-bottom-right failed: " & errMsg
        set failCount to failCount + 1
    end try

    -- Cleanup: Close Chrome window
    tell application chromeApp
        try
            close front window
        end try
    end tell

    -- Output summary
    log ""
    log "=== CHROME CANARY TEST SUMMARY ==="
    log "SUCCESS: " & successCount
    log "FAILED: " & failCount
    log "OUTPUT_DIR: " & screenshotDir
    log "=================================="

    if failCount > 0 then
        return "FAILED"
    else
        return "SUCCESS"
    end if
end run
