-- Complete Browser Address Bar Position Test Script
-- Tests popup positioning when triggered from Chrome's address bar
--
-- Usage: osascript test-browser-addressbar.applescript
-- Prerequisites:
--   1. Complete app must be built and installed (./scripts/install-local.sh)
--   2. Accessibility permissions granted to Complete and Terminal
--   3. Google Chrome installed
--
-- This test verifies that the completion popup appears NEAR the address bar cursor,
-- NOT at the bottom of the screen (which was the bug we fixed).

-- Configuration
set screenshotDir to (POSIX path of (path to home folder)) & "Desktop/complete-browser-tests/"
set testText to "hel"
set testDate to do shell script "date +%Y%m%d_%H%M%S"

-- Create screenshot directory
do shell script "mkdir -p " & quoted form of screenshotDir

-- Get screen dimensions for window positioning
tell application "Finder"
	set screenBounds to bounds of window of desktop
	set screenWidth to item 3 of screenBounds
	set screenHeight to item 4 of screenBounds
end tell

-- Define test positions for Chrome window: {name, x, y, width, height}
-- Testing at different positions to ensure popup follows cursor correctly
set testPositions to {¬
	{"top-left", 50, 50, 800, 600}, ¬
	{"top-center", (screenWidth - 800) / 2, 50, 800, 600}, ¬
	{"center", (screenWidth - 800) / 2, (screenHeight - 600) / 2, 800, 600}}

-- Start Complete app if not running
tell application "System Events"
	if not (exists process "Complete") then
		log "Starting Complete app..."
		do shell script "open -a Complete"
		delay 2
	end if
end tell

-- Run tests for each position
repeat with positionData in testPositions
	set positionName to item 1 of positionData
	set posX to item 2 of positionData
	set posY to item 3 of positionData
	set winWidth to item 4 of positionData
	set winHeight to item 5 of positionData

	log "=== Testing Chrome address bar at position: " & positionName & " ==="

	-- Activate Chrome and open new window
	tell application "Google Chrome"
		activate
		delay 0.5
		-- Create a new window (avoids tab complications)
		make new window
		delay 0.5
	end tell

	-- Position and resize Chrome window
	tell application "System Events"
		tell process "Google Chrome"
			set frontmost to true
			delay 0.3
			try
				set position of window 1 to {posX, posY}
				set size of window 1 to {winWidth, winHeight}
			on error errMsg
				log "Error positioning window: " & errMsg
			end try
		end tell
	end tell

	delay 0.5

	-- Focus the address bar with Cmd+L
	tell application "System Events"
		keystroke "l" using command down
	end tell

	delay 0.5

	-- Clear any existing text and type test text
	tell application "System Events"
		keystroke "a" using command down
		delay 0.1
		keystroke testText
	end tell

	delay 0.5

	-- Move mouse to address bar area to help with element detection
	-- Calculate approximate address bar position (top of Chrome window + ~70px for chrome)
	set addressBarX to posX + (winWidth / 2)
	set addressBarY to posY + 70

	-- Position mouse near the address bar using cliclick (if available) or MouseTools
	-- Fallback: just click in the address bar area
	try
		tell application "System Events"
			tell process "Google Chrome"
				-- Click in the address bar to ensure mouse is there
				click at {addressBarX, addressBarY}
			end tell
		end tell
	on error
		-- If click fails, just proceed - the Cmd+L should have focused the address bar
		log "Could not click in address bar area, proceeding anyway"
	end try

	delay 0.3

	-- Take "before" screenshot
	set beforeScreenshotPath to screenshotDir & positionName & "-before.png"
	do shell script "screencapture -x " & quoted form of beforeScreenshotPath
	log "Before screenshot saved: " & beforeScreenshotPath

	-- Trigger Complete popup (Shift+Command+I)
	log "Triggering Shift+Command+I at position: " & positionName
	tell application "System Events"
		key code 34 using {shift down, command down} -- 34 is 'i' key
	end tell

	delay 1.5

	-- Take "after" screenshot (should show popup near address bar)
	set afterScreenshotPath to screenshotDir & positionName & "-after.png"
	do shell script "screencapture -x " & quoted form of afterScreenshotPath
	log "After screenshot saved: " & afterScreenshotPath

	delay 0.3

	-- Dismiss popup with Escape
	tell application "System Events"
		key code 53 -- Escape key
	end tell

	delay 0.3

	-- Close Chrome window
	tell application "Google Chrome"
		close front window
	end tell

	delay 0.5
end repeat

-- Summary
log "========================================"
log "Browser Address Bar Test Complete!"
log "========================================"
log "Screenshots saved to: " & screenshotDir
log ""
log "VERIFICATION CHECKLIST:"
log "1. Open each '*-after.png' screenshot"
log "2. The completion popup should appear NEAR the address bar"
log "3. The popup should NOT be at the bottom of the screen"
log "4. Distance from cursor to popup should be < 50 pixels"
log ""
return "Screenshots saved to: " & screenshotDir
