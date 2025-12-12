-- =============================================================================
-- VSCode Visual Regression Test Module
-- =============================================================================
-- Tests Complete app autocomplete in Visual Studio Code editor
--
-- Note: VSCode is an Electron app that requires special accessibility handling.
-- Complete app uses clipboard-based fallback for Electron apps.
--
-- Usage: osascript test-vscode.applescript [output_directory]
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
        set screenshotDir to projectRoot & "/tests/visualScreenshotTesting/captures/vscode/"
    end if

    -- Ensure trailing slash
    if screenshotDir does not end with "/" then
        set screenshotDir to screenshotDir & "/"
    end if

    set testText to "Hell"
    set successCount to 0
    set failCount to 0

    -- VSCode app identifier
    set vscodeApp to "Visual Studio Code"

    -- Create screenshot directory
    try
        do shell script "mkdir -p " & quoted form of screenshotDir
    on error errMsg
        log "ERROR: Failed to create directory: " & errMsg
        return "ERROR"
    end try

    -- Check if VSCode is installed
    try
        tell application "System Events"
            if not (exists application process "Code") then
                -- Try to launch VSCode
                tell application vscodeApp to activate
                delay 3
            end if
        end tell
    on error
        log "WARNING: VSCode not found, skipping VSCode tests"
        return "SKIPPED"
    end try

    log "=== VSCODE VISUAL REGRESSION TEST ==="
    log "Output: " & screenshotDir

    -- Get screen dimensions
    tell application "Finder"
        set screenBounds to bounds of window of desktop
        set screenWidth to item 3 of screenBounds
        set screenHeight to item 4 of screenBounds
    end tell

    set windowWidth to 1000
    set windowHeight to 700

    -- Activate VSCode
    tell application vscodeApp
        activate
        delay 1
    end tell

    -- ==========================================================================
    -- TEST 1: VSCode Editor (center position)
    -- ==========================================================================
    log ""
    log ">>> TEST: vscode-editor-center"

    try
        -- Position window at center
        set centerX to (screenWidth - windowWidth) / 2
        set centerY to (screenHeight - windowHeight) / 2

        tell application "System Events"
            tell process "Code"
                set frontmost to true
                delay 0.3
                try
                    set position of window 1 to {centerX, centerY}
                    set size of window 1 to {windowWidth, windowHeight}
                end try
            end tell
        end tell

        delay 0.5

        -- Create new file (Cmd+N)
        tell application "System Events"
            keystroke "n" using {command down}
            delay 1
        end tell

        -- Type test text
        tell application "System Events"
            keystroke testText
            delay 0.5

            -- Trigger Complete popup (Shift+Command+I)
            key code 34 using {shift down, command down}
            delay 1.5
        end tell

        -- Take screenshot
        set screenshotPath to screenshotDir & "editor-center.png"
        do shell script "screencapture -x " & quoted form of screenshotPath
        log "CAPTURED: " & screenshotPath
        set successCount to successCount + 1

        -- Dismiss popup and close file without saving
        tell application "System Events"
            key code 53 -- Escape
            delay 0.3
            keystroke "w" using {command down} -- Close file
            delay 0.5
            -- Don't save dialog - click "Don't Save"
            keystroke "d" using {command down}
            delay 0.3
        end tell

    on error errMsg
        log "ERROR: vscode-editor-center failed: " & errMsg
        set failCount to failCount + 1
    end try

    -- ==========================================================================
    -- TEST 2: VSCode Editor (top-left position)
    -- ==========================================================================
    log ""
    log ">>> TEST: vscode-editor-top-left"

    try
        -- Position window at top-left
        tell application "System Events"
            tell process "Code"
                set frontmost to true
                delay 0.3
                try
                    set position of window 1 to {50, 50}
                    set size of window 1 to {windowWidth, windowHeight}
                end try
            end tell
        end tell

        delay 0.5

        -- Create new file
        tell application "System Events"
            keystroke "n" using {command down}
            delay 1

            keystroke testText
            delay 0.5

            key code 34 using {shift down, command down}
            delay 1.5
        end tell

        set screenshotPath to screenshotDir & "editor-top-left.png"
        do shell script "screencapture -x " & quoted form of screenshotPath
        log "CAPTURED: " & screenshotPath
        set successCount to successCount + 1

        tell application "System Events"
            key code 53
            delay 0.3
            keystroke "w" using {command down}
            delay 0.5
            keystroke "d" using {command down}
        end tell

    on error errMsg
        log "ERROR: vscode-editor-top-left failed: " & errMsg
        set failCount to failCount + 1
    end try

    -- ==========================================================================
    -- TEST 3: VSCode Editor (bottom-right position)
    -- ==========================================================================
    log ""
    log ">>> TEST: vscode-editor-bottom-right"

    try
        -- Position window at bottom-right
        set bottomRightX to screenWidth - windowWidth - 50
        set bottomRightY to screenHeight - windowHeight - 100

        tell application "System Events"
            tell process "Code"
                set frontmost to true
                delay 0.3
                try
                    set position of window 1 to {bottomRightX, bottomRightY}
                    set size of window 1 to {windowWidth, windowHeight}
                end try
            end tell
        end tell

        delay 0.5

        -- Create new file
        tell application "System Events"
            keystroke "n" using {command down}
            delay 1

            keystroke testText
            delay 0.5

            key code 34 using {shift down, command down}
            delay 1.5
        end tell

        set screenshotPath to screenshotDir & "editor-bottom-right.png"
        do shell script "screencapture -x " & quoted form of screenshotPath
        log "CAPTURED: " & screenshotPath
        set successCount to successCount + 1

        tell application "System Events"
            key code 53
            delay 0.3
            keystroke "w" using {command down}
            delay 0.5
            keystroke "d" using {command down}
        end tell

    on error errMsg
        log "ERROR: vscode-editor-bottom-right failed: " & errMsg
        set failCount to failCount + 1
    end try

    -- Output summary
    log ""
    log "=== VSCODE TEST SUMMARY ==="
    log "SUCCESS: " & successCount
    log "FAILED: " & failCount
    log "OUTPUT_DIR: " & screenshotDir
    log "==========================="

    if failCount > 0 then
        return "FAILED"
    else
        return "SUCCESS"
    end if
end run
