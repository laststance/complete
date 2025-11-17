#!/bin/bash
# Visual test for text insertion - uses AppleScript + screenshots

set -e

echo "🧪 Starting visual text insertion test..."

# Kill any existing Complete process
pkill -f "Complete" || true
sleep 1

# Start Complete in background
echo "▶️  Starting Complete..."
swift run &
COMPLETE_PID=$!
sleep 3

# Open TextEdit
echo "📝 Opening TextEdit..."
osascript <<'EOF'
tell application "TextEdit"
    activate
    delay 0.5

    -- Create new document
    make new document
    delay 0.5

    -- Type test text
    tell application "System Events"
        keystroke "hel"
        delay 0.5
    end tell
end tell
EOF

# Take "before" screenshot
echo "📸 Taking BEFORE screenshot..."
screencapture -x "/tmp/complete_test_before.png"

# Trigger completion with Ctrl+I
echo "⌨️  Triggering Ctrl+I..."
osascript <<'EOF'
tell application "System Events"
    delay 0.5
    -- Ctrl+I (control = 0x100000)
    key code 34 using {control down}
    delay 1

    -- Press arrow down twice to select second item
    key code 125 -- down arrow
    delay 0.3
    key code 125 -- down arrow
    delay 0.3

    -- Press Enter
    key code 36
    delay 1
end tell
EOF

# Take "after" screenshot
echo "📸 Taking AFTER screenshot..."
screencapture -x "/tmp/complete_test_after.png"

# Get TextEdit content via AppleScript
echo "📋 Checking TextEdit content..."
CONTENT=$(osascript <<'EOF'
tell application "TextEdit"
    get text of front document
end tell
EOF
)

echo ""
echo "═══════════════════════════════════════"
echo "📊 TEST RESULTS"
echo "═══════════════════════════════════════"
echo "TextEdit content: '$CONTENT'"
echo ""
echo "Expected: 'hello' or similar completion"
echo "Actual:   '$CONTENT'"
echo ""

if [[ "$CONTENT" == "hel" ]]; then
    echo "❌ FAILED: Text was NOT inserted (still shows 'hel')"
    echo ""
    echo "Screenshots saved:"
    echo "  Before: /tmp/complete_test_before.png"
    echo "  After:  /tmp/complete_test_after.png"
    echo ""
    echo "Opening screenshots for visual inspection..."
    open "/tmp/complete_test_before.png"
    open "/tmp/complete_test_after.png"
    RESULT=1
elif [[ "$CONTENT" =~ ^hel.+ ]]; then
    echo "✅ PASSED: Text was inserted!"
    echo "   Result: '$CONTENT'"
    RESULT=0
else
    echo "⚠️  UNEXPECTED: Content doesn't start with 'hel'"
    echo "   Got: '$CONTENT'"
    RESULT=1
fi

# Cleanup
echo ""
echo "🧹 Cleaning up..."
osascript -e 'tell application "TextEdit" to quit'
kill $COMPLETE_PID 2>/dev/null || true

exit $RESULT
