#!/bin/bash

# compare-screenshots.sh
# Compare two images using ImageMagick's SSIM (Structural Similarity Index)
#
# Usage: ./compare-screenshots.sh <expected_image> <actual_image> <output_diff_path>
#
# Returns:
#   - SSIM score (0.0 to 1.0) to stdout
#   - Visual diff image at output_diff_path
#   - Exit code 0 on success, 1 on error
#
# SSIM Score Interpretation:
#   1.0   = Perfect match (identical images)
#   >0.95 = Excellent match (visually indistinguishable)
#   >0.90 = Good match (minor differences)
#   >0.80 = Acceptable match (noticeable differences)
#   <0.80 = Poor match (significant differences)
#
# Example:
#   SCORE=$(./compare-screenshots.sh expected.png actual.png diff.png)
#   if (( $(echo "$SCORE > 0.95" | bc -l) )); then
#       echo "PASS: Images match (SSIM: $SCORE)"
#   else
#       echo "FAIL: Images differ (SSIM: $SCORE)"
#   fi

set -euo pipefail

# Color codes for terminal output
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to log errors to stderr
log_error() {
    echo -e "${RED}ERROR: $1${NC}" >&2
}

log_warning() {
    echo -e "${YELLOW}WARNING: $1${NC}" >&2
}

# Check if ImageMagick is installed
if ! command -v compare &> /dev/null; then
    log_error "ImageMagick is not installed."
    echo "" >&2
    echo "To install ImageMagick on macOS:" >&2
    echo "  brew install imagemagick" >&2
    echo "" >&2
    echo "To verify installation:" >&2
    echo "  compare -version" >&2
    exit 1
fi

# Check if bc (basic calculator) is installed for floating-point comparisons
if ! command -v bc &> /dev/null; then
    log_warning "bc (basic calculator) is not installed. It's needed for score comparisons."
    echo "To install bc on macOS:" >&2
    echo "  brew install bc" >&2
fi

# Validate number of arguments
if [ "$#" -ne 3 ]; then
    log_error "Invalid number of arguments."
    echo "" >&2
    echo "Usage: $0 <expected_image> <actual_image> <output_diff_path>" >&2
    echo "" >&2
    echo "Arguments:" >&2
    echo "  expected_image    - Path to the expected/baseline image" >&2
    echo "  actual_image      - Path to the actual/test result image" >&2
    echo "  output_diff_path  - Path where the visual diff image will be saved" >&2
    exit 1
fi

EXPECTED_IMAGE="$1"
ACTUAL_IMAGE="$2"
OUTPUT_DIFF="$3"

# Validate expected image exists
if [ ! -f "$EXPECTED_IMAGE" ]; then
    log_error "Expected image not found: $EXPECTED_IMAGE"
    exit 1
fi

# Validate actual image exists
if [ ! -f "$ACTUAL_IMAGE" ]; then
    log_error "Actual image not found: $ACTUAL_IMAGE"
    exit 1
fi

# Create output directory if it doesn't exist
OUTPUT_DIR=$(dirname "$OUTPUT_DIFF")
if [ ! -d "$OUTPUT_DIR" ]; then
    mkdir -p "$OUTPUT_DIR"
fi

# Run ImageMagick compare with SSIM metric
# Note: compare outputs SSIM to stderr, we need to capture it
# Format: ImageMagick outputs "absolute_difference (normalized_difference)"
#   - For identical images: "0 (0)"
#   - For different images: "882.006 (0.0134585)"
# The value in parentheses is the normalized dissimilarity (0 = identical, 1 = completely different)
# We convert this to similarity: SSIM = 1 - dissimilarity
# We use 2>&1 to redirect stderr to stdout for capture
SSIM_OUTPUT=$(compare -metric SSIM "$EXPECTED_IMAGE" "$ACTUAL_IMAGE" "$OUTPUT_DIFF" 2>&1 || true)

# Extract dissimilarity score from parentheses
# Example: "882.006 (0.0134585)" -> extract "0.0134585"
# Example: "0 (0)" -> extract "0"
DISSIMILARITY=$(echo "$SSIM_OUTPUT" | grep -oE '\([0-9.]+\)' | tr -d '()')

# Validate we got a valid dissimilarity score
if [ -z "$DISSIMILARITY" ]; then
    log_error "Failed to extract dissimilarity score from compare output."
    log_error "Compare output was: $SSIM_OUTPUT"
    exit 1
fi

# Convert dissimilarity to similarity using awk (SSIM = 1 - dissimilarity)
# awk is more portable than bc for floating-point arithmetic
SSIM_SCORE=$(awk "BEGIN {printf \"%.6f\", 1 - $DISSIMILARITY}")

# Check if diff image was created
if [ ! -f "$OUTPUT_DIFF" ]; then
    log_warning "Diff image was not created at: $OUTPUT_DIFF"
fi

# Output SSIM score to stdout (ONLY stdout, for easy parsing)
echo "$SSIM_SCORE"

# Exit with success
exit 0
