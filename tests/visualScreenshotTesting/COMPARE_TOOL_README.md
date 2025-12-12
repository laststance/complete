# Screenshot Comparison Tool

Automated screenshot comparison using ImageMagick's SSIM (Structural Similarity Index) metric.

## Overview

The `compare-screenshots.sh` script compares two images and returns a similarity score from 0.0 to 1.0, where:
- **1.0** = Perfect match (identical images)
- **>0.95** = Excellent match (visually indistinguishable)
- **>0.90** = Good match (minor differences)
- **>0.80** = Acceptable match (noticeable differences)
- **<0.80** = Poor match (significant differences)

## Prerequisites

### Required Software

1. **ImageMagick** (for image comparison)
   ```bash
   brew install imagemagick

   # Verify installation
   compare -version
   ```

2. **awk** (for floating-point arithmetic)
   - Pre-installed on macOS

## Usage

### Basic Usage

```bash
./compare-screenshots.sh <expected_image> <actual_image> <output_diff_path>
```

**Parameters:**
- `expected_image` - Path to the baseline/expected image
- `actual_image` - Path to the test result/actual image
- `output_diff_path` - Path where the visual diff image will be saved

**Returns:**
- SSIM similarity score (0.0 to 1.0) to stdout
- Visual diff image saved to `output_diff_path`
- Exit code: 0 on success, 1 on error

### Example: Basic Comparison

```bash
SCORE=$(./compare-screenshots.sh expected.png actual.png diff.png)
echo "Similarity: $SCORE"
```

### Example: Pass/Fail Test

```bash
SCORE=$(./compare-screenshots.sh expected.png actual.png diff.png)

# Using awk for floating-point comparison (bc not required)
if [ "$(awk "BEGIN {print ($SCORE > 0.95)}")" -eq 1 ]; then
    echo "✅ PASS: Images match (SSIM: $SCORE)"
else
    echo "❌ FAIL: Images differ (SSIM: $SCORE)"
    echo "   Check diff image: diff.png"
fi
```

### Example: Custom Threshold

```bash
THRESHOLD=0.99
SCORE=$(./compare-screenshots.sh baseline.png test.png diff.png)

if [ "$(awk "BEGIN {print ($SCORE >= $THRESHOLD)}")" -eq 1 ]; then
    echo "✅ PASS: Score ($SCORE) meets threshold ($THRESHOLD)"
else
    echo "❌ FAIL: Score ($SCORE) below threshold ($THRESHOLD)"
fi
```

### Example: Integration with Test Script

```bash
#!/bin/bash
set -euo pipefail

EXPECTATIONS_DIR="./expectations"
RESULTS_DIR="./test-results"
DIFFS_DIR="./diffs"

mkdir -p "$DIFFS_DIR"

TEST_PASSED=true

for position in top-left top-right bottom-left bottom-right center; do
    EXPECTED="$EXPECTATIONS_DIR/${position}.png"
    ACTUAL="$RESULTS_DIR/${position}.png"
    DIFF="$DIFFS_DIR/${position}-diff.png"

    if [ ! -f "$ACTUAL" ]; then
        echo "❌ FAIL: Missing test result: $ACTUAL"
        TEST_PASSED=false
        continue
    fi

    SCORE=$(./compare-screenshots.sh "$EXPECTED" "$ACTUAL" "$DIFF")

    if [ "$(awk "BEGIN {print ($SCORE > 0.95)}")" -eq 1 ]; then
        echo "✅ PASS: $position (SSIM: $SCORE)"
    else
        echo "❌ FAIL: $position (SSIM: $SCORE)"
        TEST_PASSED=false
    fi
done

if [ "$TEST_PASSED" = true ]; then
    echo "All tests passed!"
    exit 0
else
    echo "Some tests failed. Check diff images in $DIFFS_DIR"
    exit 1
fi
```

## How It Works

### SSIM Metric

The script uses ImageMagick's SSIM (Structural Similarity Index) metric, which measures the perceptual difference between two images. Unlike pixel-by-pixel comparison, SSIM considers:

1. **Luminance** - Overall brightness
2. **Contrast** - Dynamic range
3. **Structure** - Spatial patterns

This makes SSIM more aligned with human perception than raw pixel differences.

### Implementation Details

1. **ImageMagick Output Format**:
   - ImageMagick's `compare -metric SSIM` outputs: `absolute_diff (normalized_diff)`
   - For identical images: `0 (0)`
   - For different images: `882.006 (0.0134585)`

2. **Score Conversion**:
   - Script extracts the normalized dissimilarity from parentheses
   - Converts to similarity: `SSIM = 1 - dissimilarity`
   - Returns similarity score (0.0 to 1.0)

3. **Visual Diff Output**:
   - ImageMagick creates a difference image highlighting changes
   - Red pixels indicate areas of difference
   - Identical regions appear black/dark

### Error Handling

The script handles:
- Missing ImageMagick installation
- Non-existent input files
- Invalid command-line arguments
- Failed score extraction
- Directory creation for output

All errors are logged to stderr with colored output.

## Running Examples

Execute the example script to see all features in action:

```bash
./example-usage.sh
```

This demonstrates:
- Comparing identical images (SSIM = 1.0)
- Comparing different images (SSIM < 1.0)
- Using custom thresholds
- Score interpretation guidelines

## Troubleshooting

### ImageMagick Not Found

**Error:** `ERROR: ImageMagick is not installed.`

**Solution:**
```bash
brew install imagemagick
compare -version  # Verify installation
```

### Score Extraction Failed

**Error:** `ERROR: Failed to extract dissimilarity score from compare output.`

**Cause:** ImageMagick version incompatibility or invalid image format

**Solution:**
1. Verify images are valid: `file expected.png actual.png`
2. Check ImageMagick version: `compare -version`
3. Try manually: `compare -metric SSIM image1.png image2.png diff.png`

### Permission Denied

**Error:** `Permission denied`

**Solution:**
```bash
chmod +x compare-screenshots.sh
```

## Integration with CI/CD

### GitHub Actions Example

```yaml
- name: Install ImageMagick
  run: brew install imagemagick

- name: Run screenshot comparison tests
  run: |
    cd tests/visualScreenshotTesting
    ./test-all-positions.sh

- name: Upload diff images on failure
  if: failure()
  uses: actions/upload-artifact@v3
  with:
    name: screenshot-diffs
    path: tests/visualScreenshotTesting/diffs/
```

## File Locations

- **Script**: `compare-screenshots.sh`
- **Examples**: `example-usage.sh`
- **Expectations**: `expectations/*.png` (baseline images)
- **Documentation**: This README

## Related Tools

- **Manual Testing**: `test-popup-positions.applescript` (generates test screenshots)
- **Expectations**: `expectations/README.md` (baseline image documentation)
- **Visual Tests**: `test_insertion_visual.sh`, `test_focus.sh`

## Technical Reference

- **ImageMagick Documentation**: https://imagemagick.org/script/compare.php
- **SSIM Paper**: Wang, Zhou, et al. "Image quality assessment: from error visibility to structural similarity." IEEE TIP 2004.
- **ImageMagick Compare Metrics**: https://imagemagick.org/script/command-line-options.php#metric
