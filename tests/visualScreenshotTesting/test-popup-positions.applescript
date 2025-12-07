-- Complete Popup Position Test Script
-- Tests popup positioning at 5 screen locations with automated screenshots
--
-- Usage: osascript test-popup-positions.applescript
-- Prerequisites:
--   1. Complete app must be built (swift build)
--   2. Accessibility permissions granted to Complete and Terminal
--   3. Close other apps to avoid interference

-- Configuration
set screenshotDir to (POSIX path of (path to home folder)) & "Desktop/complete-popup-tests/"
set testText to "Hell"

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

-- Define test positions: {name, x, y}
set testPositions to {¬
	{"top-left", leftMargin, topMargin}, ¬
	{"top-right", rightMargin, topMargin}, ¬
	{"bottom-left", leftMargin, bottomMargin}, ¬
	{"bottom-right", rightMargin, bottomMargin}, ¬
	{"center", centerX, centerY}}

-- Create screenshot directory
do shell script "mkdir -p " & quoted form of screenshotDir

-- Start Complete app if not running
tell application "System Events"
	if not (exists process "Complete") then
		do shell script "open -a Complete"
		delay 2
	end if
end tell

-- Run tests for each position
repeat with positionData in testPositions
	set positionName to item 1 of positionData
	set posX to item 2 of positionData
	set posY to item 3 of positionData

	log "Testing position: " & positionName & " at (" & posX & ", " & posY & ")"

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
	log "Triggering Shift+Command+I at position: " & positionName
	tell application "System Events"
		key code 34 using {shift down, command down} -- 34 is 'i' key
	end tell

	delay 1.0

	-- Take screenshot
	set screenshotPath to screenshotDir & positionName & ".png"
	do shell script "screencapture -x " & quoted form of screenshotPath
	log "Screenshot saved: " & screenshotPath

	delay 0.3

	-- Dismiss popup with Escape
	tell application "System Events"
		key code 53 -- Escape key
	end tell

	delay 0.3

	-- Close TextEdit document without saving
	tell application "TextEdit"
		close front document saving no
	end tell

	delay 0.5
end repeat

log "Test completed. Screenshots saved to: " & screenshotDir
return "Screenshots saved to: " & screenshotDir
