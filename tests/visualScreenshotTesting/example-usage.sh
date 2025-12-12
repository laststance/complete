#!/bin/bash

# Example usage of compare-screenshots.sh
# This script demonstrates how to use the screenshot comparison tool

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPARE_SCRIPT="$SCRIPT_DIR/compare-screenshots.sh"

echo "=========================================="
echo "Screenshot Comparison Tool - Example Usage"
echo "=========================================="
echo ""

# Example 1: Compare identical images (should get SSIM = 1.0)
echo "Example 1: Comparing identical images"
echo "--------------------------------------"
EXPECTED="$SCRIPT_DIR/expectations/bottom-left.png"
ACTUAL="$SCRIPT_DIR/expectations/bottom-left.png"
DIFF_OUTPUT="/tmp/example-diff-1.png"

SCORE=$("$COMPARE_SCRIPT" "$EXPECTED" "$ACTUAL" "$DIFF_OUTPUT")
echo "SSIM Score: $SCORE"

if [ "$(awk "BEGIN {print ($SCORE > 0.95)}")" -eq 1 ]; then
    echo "✅ PASS: Images match (threshold: 0.95)"
else
    echo "❌ FAIL: Images differ significantly"
fi
echo ""

# Example 2: Compare different images (should get SSIM < 1.0)
echo "Example 2: Comparing different images"
echo "--------------------------------------"
EXPECTED="$SCRIPT_DIR/expectations/bottom-left.png"
ACTUAL="$SCRIPT_DIR/expectations/bottom-right.png"
DIFF_OUTPUT="/tmp/example-diff-2.png"

SCORE=$("$COMPARE_SCRIPT" "$EXPECTED" "$ACTUAL" "$DIFF_OUTPUT")
echo "SSIM Score: $SCORE"

if [ "$(awk "BEGIN {print ($SCORE > 0.95)}")" -eq 1 ]; then
    echo "✅ PASS: Images match (threshold: 0.95)"
else
    echo "❌ FAIL: Images differ significantly"
    echo "   Diff image saved to: $DIFF_OUTPUT"
fi
echo ""

# Example 3: Demonstrating threshold levels
echo "Example 3: SSIM Score Interpretation Guide"
echo "-------------------------------------------"
echo "1.0   = Perfect match (identical images)"
echo ">0.95 = Excellent match (visually indistinguishable)"
echo ">0.90 = Good match (minor differences)"
echo ">0.80 = Acceptable match (noticeable differences)"
echo "<0.80 = Poor match (significant differences)"
echo ""

# Example 4: Using different thresholds
echo "Example 4: Custom threshold comparison"
echo "---------------------------------------"
SCORE=$("$COMPARE_SCRIPT" "$SCRIPT_DIR/expectations/top-left.png" "$SCRIPT_DIR/expectations/top-left.png" "/tmp/example-diff-3.png")
THRESHOLD=0.99

echo "Comparing with threshold: $THRESHOLD"
echo "SSIM Score: $SCORE"

if [ "$(awk "BEGIN {print ($SCORE >= $THRESHOLD)}")" -eq 1 ]; then
    echo "✅ PASS: Score ($SCORE) meets strict threshold ($THRESHOLD)"
else
    echo "⚠️  WARN: Score ($SCORE) below strict threshold ($THRESHOLD)"
fi
echo ""

echo "=========================================="
echo "Examples completed!"
echo "=========================================="
