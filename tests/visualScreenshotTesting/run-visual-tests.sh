#!/bin/bash
# =============================================================================
# Visual Regression Test Orchestrator for Complete App
# =============================================================================
#
# Purpose: Automated visual regression testing as a quality gate
#
# This script orchestrates the complete visual testing workflow:
# 1. Builds the Complete app
# 2. Starts Complete app in background
# 3. Runs AppleScript test runner to capture screenshots
# 4. Compares screenshots against baseline expectations using SSIM
# 5. Generates JSON and HTML reports
# 6. Returns exit code 0 if ALL tests pass, 1 if ANY fail
#
# Usage:
#   ./run-visual-tests.sh [options]
#
# Options:
#   --skip-build     Skip the build step (use existing build)
#   --update-baseline  Update baseline expectations with current captures
#   --threshold NUM  Set SSIM threshold (default: 0.95)
#   --verbose        Enable verbose output
#   --help           Show this help message
#
# Exit Codes:
#   0 - All tests passed
#   1 - One or more tests failed
#   2 - Setup or infrastructure error
#
# =============================================================================

set -euo pipefail

# =============================================================================
# Configuration
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
EXPECTATIONS_DIR="$SCRIPT_DIR/expectations"
CAPTURES_DIR="$SCRIPT_DIR/captures"
REPORTS_DIR="$SCRIPT_DIR/reports"
DIFFS_DIR="$SCRIPT_DIR/diffs"

# Test positions matching AppleScript test
TEST_POSITIONS=("top-left" "top-right" "bottom-left" "bottom-right" "center")

# Quality thresholds
DEFAULT_SSIM_THRESHOLD=0.95
SSIM_THRESHOLD="${DEFAULT_SSIM_THRESHOLD}"

# Flags
SKIP_BUILD=false
UPDATE_BASELINE=false
VERBOSE=false

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# =============================================================================
# Logging Functions
# =============================================================================

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[PASS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[FAIL]${NC} $1"
}

log_verbose() {
    if [[ "$VERBOSE" == true ]]; then
        echo -e "${BLUE}[DEBUG]${NC} $1"
    fi
}

# =============================================================================
# Argument Parsing
# =============================================================================

show_help() {
    cat << EOF
Visual Regression Test Orchestrator for Complete App

Usage: $(basename "$0") [options]

Options:
  --skip-build       Skip the build step (use existing build)
  --update-baseline  Update baseline expectations with current captures
  --threshold NUM    Set SSIM threshold (default: ${DEFAULT_SSIM_THRESHOLD})
  --verbose          Enable verbose output
  --help             Show this help message

Test Positions:
  top-left, top-right, bottom-left, bottom-right, center

Quality Criteria:
  - SSIM threshold: ${DEFAULT_SSIM_THRESHOLD} (95% similarity required)
  - All 5 positions must pass

Output:
  - JSON report: ${REPORTS_DIR}/test-results.json
  - HTML report: ${REPORTS_DIR}/test-results.html
  - Diff images: ${DIFFS_DIR}/

Exit Codes:
  0 - All tests passed
  1 - One or more tests failed
  2 - Setup or infrastructure error

EOF
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --skip-build)
                SKIP_BUILD=true
                shift
                ;;
            --update-baseline)
                UPDATE_BASELINE=true
                shift
                ;;
            --threshold)
                SSIM_THRESHOLD="$2"
                shift 2
                ;;
            --verbose)
                VERBOSE=true
                shift
                ;;
            --help)
                show_help
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 2
                ;;
        esac
    done
}

# =============================================================================
# Setup Functions
# =============================================================================

setup_directories() {
    log_info "Setting up directories..."

    mkdir -p "$CAPTURES_DIR"
    mkdir -p "$REPORTS_DIR"
    mkdir -p "$DIFFS_DIR"

    # Clean previous captures
    rm -f "$CAPTURES_DIR"/*.png 2>/dev/null || true
    rm -f "$DIFFS_DIR"/*.png 2>/dev/null || true

    log_verbose "Directories created: captures, reports, diffs"
}

check_prerequisites() {
    log_info "Checking prerequisites..."

    # Check for required tools
    local missing_tools=()

    if ! command -v swift &> /dev/null; then
        missing_tools+=("swift")
    fi

    if ! command -v osascript &> /dev/null; then
        missing_tools+=("osascript")
    fi

    if ! command -v python3 &> /dev/null; then
        missing_tools+=("python3")
    fi

    # Check for ImageMagick compare (used for diff images only)
    # SSIM computation uses Python PIL for consistency across platforms
    if command -v compare &> /dev/null; then
        USE_IMAGEMAGICK=true
        log_verbose "ImageMagick 'compare' found (used for diff images)"
    else
        USE_IMAGEMAGICK=false
        log_verbose "ImageMagick not found, using Python PIL for diff images"
    fi

    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        exit 2
    fi

    # Check for baseline expectations
    local missing_expectations=()
    for position in "${TEST_POSITIONS[@]}"; do
        if [[ ! -f "$EXPECTATIONS_DIR/${position}.png" ]]; then
            missing_expectations+=("$position")
        fi
    done

    if [[ ${#missing_expectations[@]} -gt 0 ]]; then
        log_error "Missing baseline expectations: ${missing_expectations[*]}"
        log_info "Run with --update-baseline to create new baselines"
        exit 2
    fi

    log_success "All prerequisites satisfied"
}

# =============================================================================
# Build Functions
# =============================================================================

build_app() {
    if [[ "$SKIP_BUILD" == true ]]; then
        log_info "Skipping build (--skip-build specified)"
        return 0
    fi

    log_info "Building Complete app..."

    cd "$PROJECT_ROOT"

    if swift build 2>&1; then
        log_success "Build completed successfully"
    else
        log_error "Build failed"
        exit 2
    fi
}

# =============================================================================
# App Management Functions
# =============================================================================

start_complete_app() {
    log_info "Starting Complete app..."

    # Check if already running
    if pgrep -x "Complete" > /dev/null; then
        log_verbose "Complete app already running"
        return 0
    fi

    # Try to start from build directory first
    local build_path="$PROJECT_ROOT/.build/debug/Complete"

    if [[ -f "$build_path" ]]; then
        log_verbose "Starting from build directory: $build_path"
        "$build_path" &
        sleep 2
    elif [[ -d "/Applications/Complete.app" ]]; then
        log_verbose "Starting from /Applications"
        open -a Complete
        sleep 2
    else
        log_error "Complete app not found. Please build first with 'swift build'"
        exit 2
    fi

    # Verify it started
    if pgrep -x "Complete" > /dev/null; then
        log_success "Complete app started"
    else
        log_warning "Could not verify Complete app is running"
    fi
}

stop_complete_app() {
    log_verbose "Stopping Complete app..."
    pkill -x "Complete" 2>/dev/null || true
}

# =============================================================================
# Test Execution Functions
# =============================================================================

run_screenshot_tests() {
    log_info "Running screenshot capture tests..."

    # Modify the AppleScript to save to our captures directory
    local applescript_path="$SCRIPT_DIR/test-popup-positions.applescript"

    if [[ ! -f "$applescript_path" ]]; then
        log_error "AppleScript test file not found: $applescript_path"
        exit 2
    fi

    # Create a temporary AppleScript that saves to our captures directory
    local temp_applescript=$(mktemp)
    sed "s|set screenshotDir to.*|set screenshotDir to \"$CAPTURES_DIR/\"|" \
        "$applescript_path" > "$temp_applescript"

    log_verbose "Running AppleScript test runner..."

    if osascript "$temp_applescript" 2>&1; then
        log_success "Screenshot capture completed"
    else
        log_error "Screenshot capture failed"
        rm -f "$temp_applescript"
        exit 2
    fi

    rm -f "$temp_applescript"

    # Verify captures exist
    local missing_captures=()
    for position in "${TEST_POSITIONS[@]}"; do
        if [[ ! -f "$CAPTURES_DIR/${position}.png" ]]; then
            missing_captures+=("$position")
        fi
    done

    if [[ ${#missing_captures[@]} -gt 0 ]]; then
        log_error "Missing captures: ${missing_captures[*]}"
        exit 2
    fi

    log_success "All ${#TEST_POSITIONS[@]} screenshots captured"
}

# =============================================================================
# SSIM Comparison Functions
# =============================================================================

# Python script for SSIM calculation (embedded)
SSIM_PYTHON_SCRIPT='
import sys
import json
from PIL import Image
import math

def compute_ssim_pil(img1_path, img2_path):
    """
    Compute a simplified SSIM-like metric using PIL.
    Returns a value between 0 and 1, where 1 means identical.
    """
    try:
        img1 = Image.open(img1_path).convert("L")  # Convert to grayscale
        img2 = Image.open(img2_path).convert("L")

        # Resize to same dimensions if different
        if img1.size != img2.size:
            # Resize img2 to match img1
            img2 = img2.resize(img1.size, Image.Resampling.LANCZOS)

        pixels1 = list(img1.getdata())
        pixels2 = list(img2.getdata())

        n = len(pixels1)
        if n == 0:
            return 0.0

        # Calculate means
        mean1 = sum(pixels1) / n
        mean2 = sum(pixels2) / n

        # Calculate variances and covariance
        var1 = sum((p - mean1) ** 2 for p in pixels1) / n
        var2 = sum((p - mean2) ** 2 for p in pixels2) / n
        covar = sum((p1 - mean1) * (p2 - mean2) for p1, p2 in zip(pixels1, pixels2)) / n

        # SSIM constants
        C1 = (0.01 * 255) ** 2
        C2 = (0.03 * 255) ** 2

        # SSIM formula
        numerator = (2 * mean1 * mean2 + C1) * (2 * covar + C2)
        denominator = (mean1 ** 2 + mean2 ** 2 + C1) * (var1 + var2 + C2)

        if denominator == 0:
            return 1.0 if numerator == 0 else 0.0

        ssim = numerator / denominator
        return max(0.0, min(1.0, ssim))

    except Exception as e:
        print(f"Error computing SSIM: {e}", file=sys.stderr)
        return 0.0

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python ssim.py <image1> <image2>", file=sys.stderr)
        sys.exit(1)

    ssim = compute_ssim_pil(sys.argv[1], sys.argv[2])
    print(f"{ssim:.6f}")
'

compute_ssim_imagemagick() {
    local expected="$1"
    local actual="$2"
    local diff_output="$3"

    # Use ImageMagick compare with DSSIM metric (returns dissimilarity)
    # Note: ImageMagick SSIM returns (raw_value, normalized_dissimilarity)
    # We extract the normalized value and convert to similarity (1 - dissimilarity)
    local result
    result=$(compare -metric DSSIM "$expected" "$actual" "$diff_output" 2>&1 || true)

    # Extract the dissimilarity value and convert to similarity
    local dssim
    dssim=$(echo "$result" | grep -oE '[0-9]+\.?[0-9]*' | head -1 || echo "1")

    # Convert DSSIM to SSIM-like similarity (1 - dssim, clamped to [0,1])
    python3 -c "print(max(0.0, min(1.0, 1.0 - float('$dssim'))))"
}

compute_ssim_python() {
    local expected="$1"
    local actual="$2"

    python3 -c "$SSIM_PYTHON_SCRIPT" "$expected" "$actual"
}

generate_diff_image() {
    local expected="$1"
    local actual="$2"
    local diff_output="$3"

    if [[ "$USE_IMAGEMAGICK" == true ]]; then
        compare -compose src "$expected" "$actual" "$diff_output" 2>/dev/null || true
    else
        # Python fallback for diff generation
        python3 << EOF
from PIL import Image, ImageChops
import sys

try:
    img1 = Image.open("$expected").convert("RGB")
    img2 = Image.open("$actual").convert("RGB")

    if img1.size != img2.size:
        img2 = img2.resize(img1.size, Image.Resampling.LANCZOS)

    diff = ImageChops.difference(img1, img2)
    diff.save("$diff_output")
except Exception as e:
    print(f"Error generating diff: {e}", file=sys.stderr)
    sys.exit(1)
EOF
    fi
}

compare_screenshots() {
    log_info "Comparing screenshots against expectations..."

    local all_passed=true
    local test_results=()

    for position in "${TEST_POSITIONS[@]}"; do
        local expected="$EXPECTATIONS_DIR/${position}.png"
        local actual="$CAPTURES_DIR/${position}.png"
        local diff="$DIFFS_DIR/${position}-diff.png"

        log_verbose "Comparing: $position"

        # Compute SSIM using Python (consistent across platforms)
        local ssim
        ssim=$(compute_ssim_python "$expected" "$actual")

        # Generate diff image
        generate_diff_image "$expected" "$actual" "$diff"

        # Determine pass/fail
        local passed
        if (( $(echo "$ssim >= $SSIM_THRESHOLD" | bc -l) )); then
            passed=true
            log_success "$position: SSIM=$ssim (threshold: $SSIM_THRESHOLD)"
        else
            passed=false
            all_passed=false
            log_error "$position: SSIM=$ssim (threshold: $SSIM_THRESHOLD)"
        fi

        # Store result
        test_results+=("{\"position\": \"$position\", \"expected\": \"$expected\", \"actual\": \"$actual\", \"ssim\": $ssim, \"passed\": $passed, \"diff\": \"$diff\"}")
    done

    # Generate reports
    generate_json_report "${test_results[@]}"
    generate_html_report "${test_results[@]}"

    if [[ "$all_passed" == true ]]; then
        return 0
    else
        return 1
    fi
}

# =============================================================================
# Report Generation Functions
# =============================================================================

generate_json_report() {
    local -a results=("$@")
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    local passed_count=0
    local failed_count=0

    for result in "${results[@]}"; do
        if echo "$result" | grep -q '"passed": true'; then
            ((passed_count++))
        else
            ((failed_count++))
        fi
    done

    local all_passed=false
    if [[ $failed_count -eq 0 ]]; then
        all_passed=true
    fi

    # Build JSON array
    local tests_json
    tests_json=$(printf '%s\n' "${results[@]}" | paste -sd ',' -)

    cat > "$REPORTS_DIR/test-results.json" << EOF
{
  "timestamp": "$timestamp",
  "passed": $all_passed,
  "threshold": $SSIM_THRESHOLD,
  "summary": {
    "total": ${#TEST_POSITIONS[@]},
    "passed": $passed_count,
    "failed": $failed_count
  },
  "tests": [
    $tests_json
  ]
}
EOF

    log_info "JSON report generated: $REPORTS_DIR/test-results.json"
}

generate_html_report() {
    local -a results=("$@")
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    local passed_count=0
    local failed_count=0

    for result in "${results[@]}"; do
        if echo "$result" | grep -q '"passed": true'; then
            ((passed_count++))
        else
            ((failed_count++))
        fi
    done

    local status_class="pass"
    local status_text="ALL TESTS PASSED"
    if [[ $failed_count -gt 0 ]]; then
        status_class="fail"
        status_text="$failed_count TEST(S) FAILED"
    fi

    # Generate test rows
    local test_rows=""
    for result in "${results[@]}"; do
        local position=$(echo "$result" | grep -oP '"position":\s*"\K[^"]+')
        local ssim=$(echo "$result" | grep -oP '"ssim":\s*\K[0-9.]+')
        local passed=$(echo "$result" | grep -oP '"passed":\s*\K(true|false)')
        local expected=$(echo "$result" | grep -oP '"expected":\s*"\K[^"]+')
        local actual=$(echo "$result" | grep -oP '"actual":\s*"\K[^"]+')
        local diff=$(echo "$result" | grep -oP '"diff":\s*"\K[^"]+')

        local row_class="pass"
        local row_status="PASS"
        if [[ "$passed" == "false" ]]; then
            row_class="fail"
            row_status="FAIL"
        fi

        test_rows+="
        <tr class=\"$row_class\">
            <td><strong>$position</strong></td>
            <td class=\"ssim\">$ssim</td>
            <td class=\"status-$row_class\">$row_status</td>
            <td>
                <div class=\"image-comparison\">
                    <div class=\"image-container\">
                        <h4>Expected</h4>
                        <img src=\"file://$expected\" alt=\"Expected $position\" />
                    </div>
                    <div class=\"image-container\">
                        <h4>Actual</h4>
                        <img src=\"file://$actual\" alt=\"Actual $position\" />
                    </div>
                    <div class=\"image-container\">
                        <h4>Diff</h4>
                        <img src=\"file://$diff\" alt=\"Diff $position\" />
                    </div>
                </div>
            </td>
        </tr>"
    done

    cat > "$REPORTS_DIR/test-results.html" << EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Visual Regression Test Report - Complete App</title>
    <style>
        :root {
            --pass-color: #22c55e;
            --fail-color: #ef4444;
            --bg-color: #1a1a2e;
            --card-bg: #16213e;
            --text-color: #e5e7eb;
            --border-color: #374151;
        }

        * {
            box-sizing: border-box;
            margin: 0;
            padding: 0;
        }

        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
            background-color: var(--bg-color);
            color: var(--text-color);
            line-height: 1.6;
            padding: 2rem;
        }

        .container {
            max-width: 1400px;
            margin: 0 auto;
        }

        header {
            text-align: center;
            margin-bottom: 2rem;
            padding: 2rem;
            background: var(--card-bg);
            border-radius: 12px;
            border: 1px solid var(--border-color);
        }

        h1 {
            font-size: 2rem;
            margin-bottom: 0.5rem;
        }

        .timestamp {
            color: #9ca3af;
            font-size: 0.9rem;
        }

        .summary {
            display: flex;
            justify-content: center;
            gap: 2rem;
            margin: 1.5rem 0;
        }

        .summary-card {
            padding: 1rem 2rem;
            border-radius: 8px;
            text-align: center;
        }

        .summary-card.total {
            background: #3b82f6;
        }

        .summary-card.passed {
            background: var(--pass-color);
        }

        .summary-card.failed {
            background: var(--fail-color);
        }

        .summary-card .number {
            font-size: 2rem;
            font-weight: bold;
        }

        .summary-card .label {
            font-size: 0.8rem;
            text-transform: uppercase;
        }

        .status-banner {
            padding: 1rem;
            border-radius: 8px;
            font-weight: bold;
            font-size: 1.2rem;
            margin-top: 1rem;
        }

        .status-banner.pass {
            background: var(--pass-color);
        }

        .status-banner.fail {
            background: var(--fail-color);
        }

        .threshold-info {
            margin-top: 1rem;
            padding: 0.5rem 1rem;
            background: rgba(255,255,255,0.1);
            border-radius: 4px;
            display: inline-block;
        }

        table {
            width: 100%;
            border-collapse: collapse;
            margin-top: 2rem;
            background: var(--card-bg);
            border-radius: 12px;
            overflow: hidden;
        }

        th, td {
            padding: 1rem;
            text-align: left;
            border-bottom: 1px solid var(--border-color);
        }

        th {
            background: rgba(0,0,0,0.3);
            font-weight: 600;
            text-transform: uppercase;
            font-size: 0.8rem;
            letter-spacing: 0.05em;
        }

        tr.pass {
            background: rgba(34, 197, 94, 0.1);
        }

        tr.fail {
            background: rgba(239, 68, 68, 0.1);
        }

        .ssim {
            font-family: 'SF Mono', Monaco, 'Courier New', monospace;
            font-size: 1.1rem;
            font-weight: bold;
        }

        .status-pass {
            color: var(--pass-color);
            font-weight: bold;
        }

        .status-fail {
            color: var(--fail-color);
            font-weight: bold;
        }

        .image-comparison {
            display: flex;
            gap: 1rem;
            flex-wrap: wrap;
        }

        .image-container {
            flex: 1;
            min-width: 200px;
        }

        .image-container h4 {
            margin-bottom: 0.5rem;
            font-size: 0.9rem;
            color: #9ca3af;
        }

        .image-container img {
            max-width: 100%;
            max-height: 200px;
            border-radius: 4px;
            border: 1px solid var(--border-color);
            cursor: pointer;
            transition: transform 0.2s;
        }

        .image-container img:hover {
            transform: scale(1.05);
        }

        footer {
            text-align: center;
            margin-top: 2rem;
            padding: 1rem;
            color: #6b7280;
            font-size: 0.9rem;
        }

        /* Modal for full-size images */
        .modal {
            display: none;
            position: fixed;
            top: 0;
            left: 0;
            width: 100%;
            height: 100%;
            background: rgba(0,0,0,0.9);
            z-index: 1000;
            cursor: pointer;
        }

        .modal img {
            max-width: 90%;
            max-height: 90%;
            position: absolute;
            top: 50%;
            left: 50%;
            transform: translate(-50%, -50%);
        }
    </style>
</head>
<body>
    <div class="container">
        <header>
            <h1>Visual Regression Test Report</h1>
            <p class="timestamp">Generated: $timestamp</p>

            <div class="summary">
                <div class="summary-card total">
                    <div class="number">${#TEST_POSITIONS[@]}</div>
                    <div class="label">Total Tests</div>
                </div>
                <div class="summary-card passed">
                    <div class="number">$passed_count</div>
                    <div class="label">Passed</div>
                </div>
                <div class="summary-card failed">
                    <div class="number">$failed_count</div>
                    <div class="label">Failed</div>
                </div>
            </div>

            <div class="status-banner $status_class">$status_text</div>

            <div class="threshold-info">
                SSIM Threshold: $SSIM_THRESHOLD (${SSIM_THRESHOLD%.*}% similarity required)
            </div>
        </header>

        <table>
            <thead>
                <tr>
                    <th>Position</th>
                    <th>SSIM Score</th>
                    <th>Status</th>
                    <th>Visual Comparison</th>
                </tr>
            </thead>
            <tbody>
                $test_rows
            </tbody>
        </table>

        <footer>
            <p>Complete App - Visual Regression Testing</p>
            <p>Report generated by run-visual-tests.sh</p>
        </footer>
    </div>

    <div class="modal" id="modal" onclick="closeModal()">
        <img id="modal-img" src="" alt="Full size image" />
    </div>

    <script>
        // Click on images to show full size
        document.querySelectorAll('.image-container img').forEach(img => {
            img.addEventListener('click', (e) => {
                e.stopPropagation();
                document.getElementById('modal-img').src = img.src;
                document.getElementById('modal').style.display = 'block';
            });
        });

        function closeModal() {
            document.getElementById('modal').style.display = 'none';
        }

        document.addEventListener('keydown', (e) => {
            if (e.key === 'Escape') closeModal();
        });
    </script>
</body>
</html>
EOF

    log_info "HTML report generated: $REPORTS_DIR/test-results.html"
}

# =============================================================================
# Baseline Update Function
# =============================================================================

update_baseline() {
    log_info "Updating baseline expectations..."

    for position in "${TEST_POSITIONS[@]}"; do
        local capture="$CAPTURES_DIR/${position}.png"
        local expectation="$EXPECTATIONS_DIR/${position}.png"

        if [[ -f "$capture" ]]; then
            cp "$capture" "$expectation"
            log_success "Updated: $position"
        else
            log_warning "Missing capture for: $position"
        fi
    done

    log_success "Baseline expectations updated"
}

# =============================================================================
# Cleanup Functions
# =============================================================================

cleanup() {
    log_verbose "Cleaning up..."

    # Close TextEdit documents that might be left open
    osascript -e 'tell application "TextEdit" to close every document saving no' 2>/dev/null || true
}

# =============================================================================
# Main Function
# =============================================================================

main() {
    local start_time
    start_time=$(date +%s)

    echo ""
    echo "================================================================="
    echo "  Complete App - Visual Regression Test Suite"
    echo "================================================================="
    echo ""

    parse_args "$@"

    # Set up trap for cleanup
    trap cleanup EXIT

    # Setup phase
    setup_directories

    if [[ "$UPDATE_BASELINE" == true ]]; then
        # Just run tests and update baseline
        check_prerequisites || true  # Don't fail if expectations missing
        build_app
        start_complete_app
        run_screenshot_tests
        update_baseline

        local end_time
        end_time=$(date +%s)
        local duration=$((end_time - start_time))

        echo ""
        echo "================================================================="
        log_success "Baseline update completed in ${duration}s"
        echo "================================================================="
        exit 0
    fi

    check_prerequisites
    build_app
    start_complete_app
    run_screenshot_tests

    local test_result=0
    if compare_screenshots; then
        test_result=0
    else
        test_result=1
    fi

    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - start_time))

    echo ""
    echo "================================================================="
    if [[ $test_result -eq 0 ]]; then
        log_success "All visual regression tests PASSED in ${duration}s"
        echo ""
        echo "  Reports:"
        echo "    JSON: $REPORTS_DIR/test-results.json"
        echo "    HTML: $REPORTS_DIR/test-results.html"
    else
        log_error "Visual regression tests FAILED in ${duration}s"
        echo ""
        echo "  Reports:"
        echo "    JSON: $REPORTS_DIR/test-results.json"
        echo "    HTML: $REPORTS_DIR/test-results.html"
        echo ""
        echo "  Review diff images in: $DIFFS_DIR/"
    fi
    echo "================================================================="
    echo ""

    exit $test_result
}

# =============================================================================
# Entry Point
# =============================================================================

main "$@"
