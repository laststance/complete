-- Complete Visual Regression Test - Screenshot Capture Script
-- Standardized screenshot capture for quality gate testing
--
-- Usage: osascript capture-screenshots.applescript [output_directory]
-- Default output: tests/visualScreenshotTesting/captures/
--
-- Prerequisites:
--   1. Complete app must be built and running
--   2. Accessibility permissions granted to Complete and Terminal
--   3. ImageMagick installed for comparison (brew install imagemagick)
--
-- Exit Codes:
--   0 = Success
--   1 = Error (check stderr for details)

on run argv
	-- Configuration
	set projectRoot to do shell script "cd \"$(dirname \"$0\")/../..\" && pwd"

	-- Get output directory from argument or use default
	if (count of argv) > 0 then
		set screenshotDir to item 1 of argv
	else
		set screenshotDir to projectRoot & "/tests/visualScreenshotTesting/captures/"
	end if

	-- Ensure trailing slash
	if screenshotDir does not end with "/" then
		set screenshotDir to screenshotDir & "/"
	end if

	set testText to "Hell"
	set testPositions to {"top-left", "top-right", "bottom-left", "bottom-right", "center"}
	set successCount to 0
	set failCount to 0

	-- Get screen dimensions
	tell application "Finder"
		set screenBounds to bounds of window of desktop
		set screenWidth to item 3 of screenBounds
		set screenHeight to item 4 of screenBounds
	end tell

	-- Calculate test positions (with margins for window chrome)
	set windowWidth to 400
	set windowHeight to 300
	set topMargin to 100
	set bottomMargin to screenHeight - windowHeight - 50
	set leftMargin to 50
	set rightMargin to screenWidth - windowWidth - 50
	set centerX to (screenWidth - windowWidth) / 2
	set centerY to (screenHeight - windowHeight) / 2

	-- Position coordinates map
	set positionCoords to {¬
		{leftMargin, topMargin}, ¬
		{rightMargin, topMargin}, ¬
		{leftMargin, bottomMargin}, ¬
		{rightMargin, bottomMargin}, ¬
		{centerX, centerY}}

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

	-- Output header for parsing
	log "=== VISUAL REGRESSION TEST: SCREENSHOT CAPTURE ==="
	log "Output directory: " & screenshotDir
	log "Test positions: " & (testPositions as string)
	log "Screen size: " & screenWidth & "x" & screenHeight
	log "=================================================="

	-- Run tests for each position
	repeat with i from 1 to count of testPositions
		set positionName to item i of testPositions
		set coords to item i of positionCoords
		set posX to item 1 of coords
		set posY to item 2 of coords

		log ""
		log ">>> Testing: " & positionName & " at (" & posX & ", " & posY & ")"

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
					on error
						log "WARNING: Could not position window precisely"
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

			-- Verify screenshot was created
			try
				do shell script "test -f " & quoted form of screenshotPath
				log "CAPTURED: " & screenshotPath
				set successCount to successCount + 1
			on error
				log "ERROR: Screenshot not created for " & positionName
				set failCount to failCount + 1
			end try

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
			log "ERROR: Test failed for " & positionName & ": " & errMsg
			set failCount to failCount + 1

			-- Try to clean up
			tell application "TextEdit"
				try
					close front document saving no
				end try
			end tell
		end try
	end repeat

	-- Output summary for parsing
	log ""
	log "=== CAPTURE SUMMARY ==="
	log "SUCCESS: " & successCount
	log "FAILED: " & failCount
	log "OUTPUT_DIR: " & screenshotDir
	log "======================="

	if failCount > 0 then
		return "FAILED"
	else
		return "SUCCESS"
	end if
end run
