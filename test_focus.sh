#!/bin/bash

echo "🧪 Testing Automatic Focus Fix"
echo "================================"
echo ""
echo "Instructions:"
echo "1. Run this script"
echo "2. Press Ctrl+I when prompted"
echo "3. DO NOT CLICK with mouse"
echo "4. Try arrow keys IMMEDIATELY"
echo "5. Expected: Arrow keys work without mouse click"
echo ""
echo "Debug output will show:"
echo "  🎯 Activating app for keyboard focus"
echo "  🎯 App activated: true"
echo "  🎯 Window is key: true"
echo "  🎯 First responder set: true"
echo ""
echo "Starting Complete in 3 seconds..."
sleep 3

# Run the app
swift run Complete
