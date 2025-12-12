-- =============================================================================
-- TextEdit Visual Regression Test Module
-- =============================================================================
-- Tests Complete app autocomplete in TextEdit (Apple's native text editor)
--
-- This is the primary test case as TextEdit provides full Accessibility API support.
-- Tests 5 screen positions: top-left, top-right, bottom-left, bottom-right, center
--
-- Usage: osascript test-textedit.applescript [output_directory]
-- =============================================================================

on run argv
    -- Configuration
    set scriptDir to do shell script "cd \"$(dirname \"$0\")\" && pwd"
    set projectRoot to do shell script "cd \"" & scriptDir & "/../..\" && pwd"

    -- Get output directory from argument or use default
    if (count of argv) > 0 then
        set screenshotDir to item 1 of argv
    else
        set screenshotDir to projectRoot & "/tests/visualScreenshotTesting/captures/textedit/"
    end if

    -- Ensure trailing slash
    if screenshotDir does not end with "/" then
        set screenshotDir to screenshotDir & "/"
    end if

    set testText to "Hell"
    set testPositions to {"top-left", "top-right", "bottom-left", "bottom-right", "center"}
    set successCount to 0
    set failCount to 0

    -- Create screenshot directory
    try
        do shell script "mkdir -p " & quoted form of screenshotDir
    on error errMsg
        log "ERROR: Failed to create directory: " & errMsg
        return "ERROR"
    end try

    -- Verify Complete app is running
    tell application "System Events"
        if not (exists process "Complete") then
            log "ERROR: Complete app is not running. Please start it first."
            return "ERROR"
        end if
    end tell

    log "=== TEXTEDIT VISUAL REGRESSION TEST ==="
    log "Output: " & screenshotDir

    -- Get screen dimensions
    tell application "Finder"
        set screenBounds to bounds of window of desktop
        set screenWidth to item 3 of screenBounds
        set screenHeight to item 4 of screenBounds
    end tell

    -- Calculate test positions
    set windowWidth to 400
    set windowHeight to 300
    set topMargin to 100
    set bottomMargin to screenHeight - windowHeight - 50
    set leftMargin to 50
    set rightMargin to screenWidth - windowWidth - 50
    set centerX to (screenWidth - windowWidth) / 2
    set centerY to (screenHeight - windowHeight) / 2

    set positionCoords to {¬
        {leftMargin, topMargin}, ¬
        {rightMargin, topMargin}, ¬
        {leftMargin, bottomMargin}, ¬
        {rightMargin, bottomMargin}, ¬
        {centerX, centerY}}

    -- Run tests for each position
    repeat with i from 1 to count of testPositions
        set positionName to item i of testPositions
        set coords to item i of positionCoords
        set posX to item 1 of coords
        set posY to item 2 of coords

        log ""
        log ">>> TEST: textedit-" & positionName & " at (" & posX & ", " & posY & ")"

        try
            -- Open new TextEdit document
            tell application "TextEdit"
                activate
                set newDoc to make new document
                delay 0.5
            end tell

            -- Position and resize the TextEdit window
            tell application "System Events"
                tell process "TextEdit"
                    set frontmost to true
                    delay 0.3
                    try
                        set position of window 1 to {posX, posY}
                        set size of window 1 to {windowWidth, windowHeight}
                    end try
                end tell
            end tell

            delay 0.5

            -- Type test text
            tell application "System Events"
                keystroke testText
            end tell

            delay 0.3

            -- Trigger Complete popup (Shift+Command+I)
            tell application "System Events"
                key code 34 using {shift down, command down}
            end tell

            -- Wait for popup to appear
            delay 1.0

            -- Take screenshot
            set screenshotPath to screenshotDir & positionName & ".png"
            do shell script "screencapture -x " & quoted form of screenshotPath
            log "CAPTURED: " & screenshotPath
            set successCount to successCount + 1

            delay 0.3

            -- Dismiss popup with Escape
            tell application "System Events"
                key code 53
            end tell

            delay 0.3

            -- Close TextEdit document without saving
            tell application "TextEdit"
                try
                    close front document saving no
                end try
            end tell

            delay 0.3

        on error errMsg
            log "ERROR: textedit-" & positionName & " failed: " & errMsg
            set failCount to failCount + 1

            -- Try to clean up
            tell application "TextEdit"
                try
                    close front document saving no
                end try
            end tell
        end try
    end repeat

    -- Output summary
    log ""
    log "=== TEXTEDIT TEST SUMMARY ==="
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
