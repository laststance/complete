#!/bin/bash
# =============================================================================
# Visual Regression Test Orchestrator for Complete App
# =============================================================================
#
# Purpose: Automated visual regression testing as a quality gate
#
# This script orchestrates the complete visual testing workflow across multiple
# applications: TextEdit, Chrome Canary, VSCode, and Terminal.
#
# Test Coverage:
#   - TextEdit: 5 positions (top-left, top-right, bottom-left, bottom-right, center)
#   - Chrome Canary: textarea (3 positions), input (1), address bar (1)
#   - VSCode: editor (3 positions)
#   - Terminal: command line (3 positions)
#   - Total: 18 test cases
#
# Usage:
#   ./run-visual-tests.sh [options]
#
# Options:
#   --skip-build       Skip the build step (use existing build)
#   --update-baseline  Update baseline expectations with current captures
#   --threshold NUM    Set SSIM threshold (default: 0.95)
#   --verbose          Enable verbose output
#   --app APP          Test only specific app (textedit|chrome|vscode|terminal|all)
#   --help             Show this help message
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
MODULES_DIR="$SCRIPT_DIR/modules"

# Quality thresholds
DEFAULT_SSIM_THRESHOLD=0.95
SSIM_THRESHOLD="${DEFAULT_SSIM_THRESHOLD}"

# Flags
SKIP_BUILD=false
UPDATE_BASELINE=false
VERBOSE=false
TEST_APP="all"

# App configurations (bash 3.2 compatible - no associative arrays)
# Use functions to get test lists for each app
get_app_tests() {
    local app="$1"
    case "$app" in
        textedit)
            echo "top-left top-right bottom-left bottom-right center"
            ;;
        chrome-canary)
            echo "textarea-center textarea-top-left textarea-bottom-right input-center addressbar"
            ;;
        vscode)
            echo "editor-center editor-top-left editor-bottom-right"
            ;;
        terminal)
            echo "terminal-center terminal-top-left terminal-bottom-right"
            ;;
        *)
            echo ""
            ;;
    esac
}

# List of all supported apps
ALL_APPS="textedit chrome-canary vscode terminal"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
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
        echo -e "${CYAN}[DEBUG]${NC} $1"
    fi
}

log_app() {
    echo -e "${MAGENTA}[APP]${NC} $1"
}

# =============================================================================
# Argument Parsing
# =============================================================================

show_help() {
    cat << EOF
Visual Regression Test Orchestrator for Complete App
Comprehensive Multi-App Testing Suite

Usage: $(basename "$0") [options]

Options:
  --skip-build       Skip the build step (use existing build)
  --update-baseline  Update baseline expectations with current captures
  --threshold NUM    Set SSIM threshold (default: ${DEFAULT_SSIM_THRESHOLD})
  --verbose          Enable verbose output
  --app APP          Test only specific app (textedit|chrome|vscode|terminal|all)
  --help             Show this help message

Test Applications:
  textedit      Apple TextEdit (5 positions)
  chrome        Chrome Canary (textarea, input, address bar - 5 tests)
  vscode        Visual Studio Code (3 positions)
  terminal      Terminal.app (3 positions)
  all           All applications (default, 16 total tests)

Quality Criteria:
  - SSIM threshold: ${DEFAULT_SSIM_THRESHOLD} (95% similarity required)
  - All tests in selected scope must pass

Output:
  - JSON report: ${REPORTS_DIR}/test-results.json
  - HTML report: ${REPORTS_DIR}/test-results.html
  - Diff images: ${DIFFS_DIR}/

Exit Codes:
  0 - All tests passed
  1 - One or more tests failed
  2 - Setup or infrastructure error

Examples:
  $(basename "$0")                     # Run all tests
  $(basename "$0") --app textedit      # Run only TextEdit tests
  $(basename "$0") --app chrome        # Run only Chrome Canary tests
  $(basename "$0") --update-baseline   # Update all baselines
  $(basename "$0") --verbose           # Run with debug output

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
            --app)
                TEST_APP="$2"
                shift 2
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

    # Validate app selection
    case $TEST_APP in
        all|textedit|chrome|vscode|terminal)
            ;;
        *)
            log_error "Invalid app: $TEST_APP"
            log_info "Valid options: all, textedit, chrome, vscode, terminal"
            exit 2
            ;;
    esac
}

# =============================================================================
# Setup Functions
# =============================================================================

setup_directories() {
    log_info "Setting up directories..."

    # Create main directories
    mkdir -p "$CAPTURES_DIR"/{textedit,chrome-canary,vscode,terminal}
    mkdir -p "$EXPECTATIONS_DIR"/{textedit,chrome-canary,vscode,terminal}
    mkdir -p "$REPORTS_DIR"
    mkdir -p "$DIFFS_DIR"/{textedit,chrome-canary,vscode,terminal}
    mkdir -p "$MODULES_DIR"

    # Clean previous captures
    rm -f "$CAPTURES_DIR"/*/*.png 2>/dev/null || true
    rm -f "$DIFFS_DIR"/*/*.png 2>/dev/null || true

    log_verbose "Directories created: captures, expectations, reports, diffs"
}

check_prerequisites() {
    log_info "Checking prerequisites..."

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

    # Check for baseline expectations based on selected app
    if [[ "$UPDATE_BASELINE" != true ]]; then
        check_baseline_expectations
    fi

    log_success "All prerequisites satisfied"
}

check_baseline_expectations() {
    local missing_expectations=()

    # Check expectations based on selected app
    local apps_to_check=()
    case $TEST_APP in
        all)
            apps_to_check=("textedit" "chrome-canary" "vscode" "terminal")
            ;;
        chrome)
            apps_to_check=("chrome-canary")
            ;;
        *)
            apps_to_check=("$TEST_APP")
            ;;
    esac

    for app in "${apps_to_check[@]}"; do
        local test_names
        test_names="$(get_app_tests "$app")"
        for test_name in $test_names; do
            local exp_file="$EXPECTATIONS_DIR/$app/${test_name}.png"
            if [[ ! -f "$exp_file" ]]; then
                missing_expectations+=("$app/${test_name}")
            fi
        done
    done

    if [[ ${#missing_expectations[@]} -gt 0 ]]; then
        log_warning "Missing baseline expectations: ${missing_expectations[*]}"
        log_info "Run with --update-baseline to create new baselines"
        # Don't exit - allow test to proceed and create baselines
    fi
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

    if pgrep -x "Complete" > /dev/null; then
        log_verbose "Complete app already running"
        return 0
    fi

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

run_app_tests() {
    local app="$1"
    local app_dir=""
    local module_script=""

    case $app in
        textedit)
            app_dir="textedit"
            module_script="$MODULES_DIR/test-textedit.applescript"
            ;;
        chrome)
            app_dir="chrome-canary"
            module_script="$MODULES_DIR/test-chrome-canary.applescript"
            ;;
        vscode)
            app_dir="vscode"
            module_script="$MODULES_DIR/test-vscode.applescript"
            ;;
        terminal)
            app_dir="terminal"
            module_script="$MODULES_DIR/test-terminal.applescript"
            ;;
    esac

    log_app "Testing: $app"

    if [[ ! -f "$module_script" ]]; then
        log_error "Test module not found: $module_script"
        return 1
    fi

    local capture_dir="$CAPTURES_DIR/$app_dir"
    mkdir -p "$capture_dir"

    log_verbose "Running: osascript $module_script $capture_dir"

    if osascript "$module_script" "$capture_dir" 2>&1 | while IFS= read -r line; do
        if [[ "$VERBOSE" == true ]]; then
            echo "  $line"
        elif [[ "$line" == *"CAPTURED:"* ]] || [[ "$line" == *"ERROR:"* ]]; then
            echo "  $line"
        fi
    done; then
        log_success "$app tests completed"
        return 0
    else
        log_warning "$app tests had issues"
        return 1
    fi
}

run_all_tests() {
    log_info "Running screenshot capture tests..."

    local apps_to_test=()

    case $TEST_APP in
        all)
            apps_to_test=("textedit" "chrome" "vscode" "terminal")
            ;;
        *)
            apps_to_test=("$TEST_APP")
            ;;
    esac

    local test_failures=0

    for app in "${apps_to_test[@]}"; do
        echo ""
        if ! run_app_tests "$app"; then
            ((test_failures++))
        fi
    done

    if [[ $test_failures -gt 0 ]]; then
        log_warning "$test_failures app(s) had test issues"
    else
        log_success "All app tests completed"
    fi
}

# =============================================================================
# SSIM Comparison Functions
# =============================================================================

SSIM_PYTHON_SCRIPT='
import sys
from PIL import Image

def compute_ssim_pil(img1_path, img2_path):
    try:
        img1 = Image.open(img1_path).convert("L")
        img2 = Image.open(img2_path).convert("L")

        if img1.size != img2.size:
            img2 = img2.resize(img1.size, Image.Resampling.LANCZOS)

        pixels1 = list(img1.getdata())
        pixels2 = list(img2.getdata())

        n = len(pixels1)
        if n == 0:
            return 0.0

        mean1 = sum(pixels1) / n
        mean2 = sum(pixels2) / n

        var1 = sum((p - mean1) ** 2 for p in pixels1) / n
        var2 = sum((p - mean2) ** 2 for p in pixels2) / n
        covar = sum((p1 - mean1) * (p2 - mean2) for p1, p2 in zip(pixels1, pixels2)) / n

        C1 = (0.01 * 255) ** 2
        C2 = (0.03 * 255) ** 2

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
        python3 << EOF
from PIL import Image, ImageChops

try:
    img1 = Image.open("$expected").convert("RGB")
    img2 = Image.open("$actual").convert("RGB")

    if img1.size != img2.size:
        img2 = img2.resize(img1.size, Image.Resampling.LANCZOS)

    diff = ImageChops.difference(img1, img2)
    diff.save("$diff_output")
except Exception as e:
    print(f"Error generating diff: {e}")
EOF
    fi
}

compare_screenshots() {
    log_info "Comparing screenshots against expectations..."

    local all_passed=true
    local test_results=()
    local total_tests=0
    local passed_tests=0
    local failed_tests=0
    local skipped_tests=0

    # Determine which apps to compare
    local apps_to_compare=()
    case $TEST_APP in
        all)
            apps_to_compare=("textedit" "chrome-canary" "vscode" "terminal")
            ;;
        chrome)
            apps_to_compare=("chrome-canary")
            ;;
        *)
            apps_to_compare=("$TEST_APP")
            ;;
    esac

    for app in "${apps_to_compare[@]}"; do
        local test_names
        test_names="$(get_app_tests "$app")"
        log_verbose "Comparing $app tests..."

        for test_name in $test_names; do
            local expected="$EXPECTATIONS_DIR/$app/${test_name}.png"
            local actual="$CAPTURES_DIR/$app/${test_name}.png"
            local diff="$DIFFS_DIR/$app/${test_name}-diff.png"

            ((total_tests++))

            # Skip if capture doesn't exist
            if [[ ! -f "$actual" ]]; then
                log_warning "$app/$test_name: capture missing (skipped)"
                ((skipped_tests++))
                test_results+=("{\"app\": \"$app\", \"position\": \"$test_name\", \"expected\": \"$expected\", \"actual\": \"$actual\", \"ssim\": 0, \"passed\": false, \"status\": \"skipped\"}")
                continue
            fi

            # Skip if expectation doesn't exist
            if [[ ! -f "$expected" ]]; then
                log_warning "$app/$test_name: baseline missing (skipped)"
                ((skipped_tests++))
                test_results+=("{\"app\": \"$app\", \"position\": \"$test_name\", \"expected\": \"$expected\", \"actual\": \"$actual\", \"ssim\": 0, \"passed\": false, \"status\": \"no_baseline\"}")
                continue
            fi

            # Compute SSIM
            local ssim
            ssim=$(compute_ssim_python "$expected" "$actual")

            # Generate diff image
            mkdir -p "$(dirname "$diff")"
            generate_diff_image "$expected" "$actual" "$diff"

            # Determine pass/fail
            local passed
            local status
            if (( $(echo "$ssim >= $SSIM_THRESHOLD" | bc -l) )); then
                passed=true
                status="passed"
                ((passed_tests++))
                log_success "$app/$test_name: SSIM=$ssim"
            else
                passed=false
                status="failed"
                all_passed=false
                ((failed_tests++))
                log_error "$app/$test_name: SSIM=$ssim (threshold: $SSIM_THRESHOLD)"
            fi

            test_results+=("{\"app\": \"$app\", \"position\": \"$test_name\", \"expected\": \"$expected\", \"actual\": \"$actual\", \"ssim\": $ssim, \"passed\": $passed, \"diff\": \"$diff\", \"status\": \"$status\"}")
        done
    done

    # Generate reports
    generate_json_report "$total_tests" "$passed_tests" "$failed_tests" "$skipped_tests" "${test_results[@]}"
    generate_html_report "$total_tests" "$passed_tests" "$failed_tests" "$skipped_tests" "${test_results[@]}"

    echo ""
    log_info "Test Summary: $passed_tests passed, $failed_tests failed, $skipped_tests skipped (total: $total_tests)"

    if [[ "$all_passed" == true ]] && [[ $skipped_tests -eq 0 ]]; then
        return 0
    else
        return 1
    fi
}

# =============================================================================
# Report Generation Functions
# =============================================================================

generate_json_report() {
    local total="$1"
    local passed="$2"
    local failed="$3"
    local skipped="$4"
    shift 4
    local -a results=("$@")

    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    local all_passed=false
    if [[ $failed -eq 0 ]] && [[ $skipped -eq 0 ]]; then
        all_passed=true
    fi

    local tests_json
    tests_json=$(printf '%s\n' "${results[@]}" | paste -sd ',' -)

    cat > "$REPORTS_DIR/test-results.json" << EOF
{
  "timestamp": "$timestamp",
  "passed": $all_passed,
  "threshold": $SSIM_THRESHOLD,
  "apps_tested": "$TEST_APP",
  "summary": {
    "total": $total,
    "passed": $passed,
    "failed": $failed,
    "skipped": $skipped
  },
  "tests": [
    $tests_json
  ]
}
EOF

    log_info "JSON report generated: $REPORTS_DIR/test-results.json"
}

generate_html_report() {
    local total="$1"
    local passed="$2"
    local failed="$3"
    local skipped="$4"
    shift 4
    local -a results=("$@")

    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    local status_class="pass"
    local status_text="ALL TESTS PASSED"
    if [[ $failed -gt 0 ]]; then
        status_class="fail"
        status_text="$failed TEST(S) FAILED"
    elif [[ $skipped -gt 0 ]]; then
        status_class="warn"
        status_text="$skipped TEST(S) SKIPPED"
    fi

    # Generate test rows
    local test_rows=""
    for result in "${results[@]}"; do
        # Extract fields using sed (compatible with macOS)
        local app=$(echo "$result" | sed -n 's/.*"app": "\([^"]*\)".*/\1/p')
        local position=$(echo "$result" | sed -n 's/.*"position": "\([^"]*\)".*/\1/p')
        local ssim=$(echo "$result" | sed -n 's/.*"ssim": \([0-9.]*\).*/\1/p')
        local status=$(echo "$result" | sed -n 's/.*"status": "\([^"]*\)".*/\1/p')
        local expected=$(echo "$result" | sed -n 's/.*"expected": "\([^"]*\)".*/\1/p')
        local actual=$(echo "$result" | sed -n 's/.*"actual": "\([^"]*\)".*/\1/p')
        local diff=$(echo "$result" | sed -n 's/.*"diff": "\([^"]*\)".*/\1/p')

        local row_class="pass"
        local row_status="PASS"
        case $status in
            passed)
                row_class="pass"
                row_status="PASS"
                ;;
            failed)
                row_class="fail"
                row_status="FAIL"
                ;;
            skipped|no_baseline)
                row_class="skip"
                row_status="SKIP"
                ;;
        esac

        test_rows+="
        <tr class=\"$row_class\">
            <td><span class=\"app-badge\">$app</span></td>
            <td><strong>$position</strong></td>
            <td class=\"ssim\">$ssim</td>
            <td class=\"status-$row_class\">$row_status</td>
            <td>
                <div class=\"image-comparison\">
                    <div class=\"image-container\">
                        <h4>Expected</h4>
                        <img src=\"file://$expected\" alt=\"Expected\" onerror=\"this.style.display='none'\" />
                    </div>
                    <div class=\"image-container\">
                        <h4>Actual</h4>
                        <img src=\"file://$actual\" alt=\"Actual\" onerror=\"this.style.display='none'\" />
                    </div>
                    <div class=\"image-container\">
                        <h4>Diff</h4>
                        <img src=\"file://$diff\" alt=\"Diff\" onerror=\"this.style.display='none'\" />
                    </div>
                </div>
            </td>
        </tr>"
    done

    cat > "$REPORTS_DIR/test-results.html" << 'HTMLEOF'
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
            --skip-color: #f59e0b;
            --bg-color: #1a1a2e;
            --card-bg: #16213e;
            --text-color: #e5e7eb;
            --border-color: #374151;
        }
        * { box-sizing: border-box; margin: 0; padding: 0; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background-color: var(--bg-color);
            color: var(--text-color);
            line-height: 1.6;
            padding: 2rem;
        }
        .container { max-width: 1600px; margin: 0 auto; }
        header {
            text-align: center;
            margin-bottom: 2rem;
            padding: 2rem;
            background: var(--card-bg);
            border-radius: 12px;
            border: 1px solid var(--border-color);
        }
        h1 { font-size: 2rem; margin-bottom: 0.5rem; }
        .subtitle { color: #9ca3af; font-size: 1rem; margin-bottom: 1rem; }
        .timestamp { color: #6b7280; font-size: 0.9rem; }
        .summary { display: flex; justify-content: center; gap: 1rem; margin: 1.5rem 0; flex-wrap: wrap; }
        .summary-card {
            padding: 1rem 2rem;
            border-radius: 8px;
            text-align: center;
            min-width: 100px;
        }
        .summary-card.total { background: #3b82f6; }
        .summary-card.passed { background: var(--pass-color); }
        .summary-card.failed { background: var(--fail-color); }
        .summary-card.skipped { background: var(--skip-color); }
        .summary-card .number { font-size: 2rem; font-weight: bold; }
        .summary-card .label { font-size: 0.8rem; text-transform: uppercase; }
        .status-banner {
            padding: 1rem;
            border-radius: 8px;
            font-weight: bold;
            font-size: 1.2rem;
            margin-top: 1rem;
        }
        .status-banner.pass { background: var(--pass-color); }
        .status-banner.fail { background: var(--fail-color); }
        .status-banner.warn { background: var(--skip-color); }
        table {
            width: 100%;
            border-collapse: collapse;
            margin-top: 2rem;
            background: var(--card-bg);
            border-radius: 12px;
            overflow: hidden;
        }
        th, td { padding: 1rem; text-align: left; border-bottom: 1px solid var(--border-color); }
        th {
            background: rgba(0,0,0,0.3);
            font-weight: 600;
            text-transform: uppercase;
            font-size: 0.8rem;
        }
        tr.pass { background: rgba(34, 197, 94, 0.1); }
        tr.fail { background: rgba(239, 68, 68, 0.1); }
        tr.skip { background: rgba(245, 158, 11, 0.1); }
        .ssim { font-family: 'SF Mono', Monaco, monospace; font-size: 1.1rem; font-weight: bold; }
        .status-pass { color: var(--pass-color); font-weight: bold; }
        .status-fail { color: var(--fail-color); font-weight: bold; }
        .status-skip { color: var(--skip-color); font-weight: bold; }
        .app-badge {
            background: rgba(59, 130, 246, 0.3);
            padding: 4px 8px;
            border-radius: 4px;
            font-size: 0.8rem;
            font-weight: 500;
        }
        .image-comparison { display: flex; gap: 1rem; flex-wrap: wrap; }
        .image-container { flex: 1; min-width: 150px; }
        .image-container h4 { margin-bottom: 0.5rem; font-size: 0.8rem; color: #9ca3af; }
        .image-container img {
            max-width: 100%;
            max-height: 150px;
            border-radius: 4px;
            border: 1px solid var(--border-color);
            cursor: pointer;
        }
        footer { text-align: center; margin-top: 2rem; padding: 1rem; color: #6b7280; font-size: 0.9rem; }
    </style>
</head>
<body>
    <div class="container">
        <header>
            <h1>🧪 Visual Regression Test Report</h1>
            <p class="subtitle">Complete App - Multi-Application Testing Suite</p>
HTMLEOF

    echo "            <p class=\"timestamp\">Generated: $timestamp</p>" >> "$REPORTS_DIR/test-results.html"

    cat >> "$REPORTS_DIR/test-results.html" << HTMLEOF2
            <div class="summary">
                <div class="summary-card total">
                    <div class="number">$total</div>
                    <div class="label">Total</div>
                </div>
                <div class="summary-card passed">
                    <div class="number">$passed</div>
                    <div class="label">Passed</div>
                </div>
                <div class="summary-card failed">
                    <div class="number">$failed</div>
                    <div class="label">Failed</div>
                </div>
                <div class="summary-card skipped">
                    <div class="number">$skipped</div>
                    <div class="label">Skipped</div>
                </div>
            </div>
            <div class="status-banner $status_class">$status_text</div>
        </header>
        <table>
            <thead>
                <tr>
                    <th>App</th>
                    <th>Test</th>
                    <th>SSIM</th>
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
            <p>Apps tested: $TEST_APP | Threshold: $SSIM_THRESHOLD</p>
        </footer>
    </div>
</body>
</html>
HTMLEOF2

    log_info "HTML report generated: $REPORTS_DIR/test-results.html"
}

# =============================================================================
# Baseline Update Function
# =============================================================================

update_baseline() {
    log_info "Updating baseline expectations..."

    local apps_to_update=()
    case $TEST_APP in
        all)
            apps_to_update=("textedit" "chrome-canary" "vscode" "terminal")
            ;;
        chrome)
            apps_to_update=("chrome-canary")
            ;;
        *)
            apps_to_update=("$TEST_APP")
            ;;
    esac

    local updated=0
    local missing=0

    for app in "${apps_to_update[@]}"; do
        local test_names
        test_names="$(get_app_tests "$app")"

        for test_name in $test_names; do
            local capture="$CAPTURES_DIR/$app/${test_name}.png"
            local expectation="$EXPECTATIONS_DIR/$app/${test_name}.png"

            if [[ -f "$capture" ]]; then
                mkdir -p "$(dirname "$expectation")"
                cp "$capture" "$expectation"
                log_success "Updated: $app/$test_name"
                ((updated++))
            else
                log_warning "Missing capture: $app/$test_name"
                ((missing++))
            fi
        done
    done

    echo ""
    log_info "Baseline update complete: $updated updated, $missing missing"
}

# =============================================================================
# Cleanup Functions
# =============================================================================

cleanup() {
    log_verbose "Cleaning up..."

    # Close TextEdit documents
    osascript -e 'tell application "TextEdit" to close every document saving no' 2>/dev/null || true

    # Close Chrome test tabs/windows opened by tests
    # (Cleanup handled by individual test modules)
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
    echo "  Multi-Application Testing: TextEdit, Chrome, VSCode, Terminal"
    echo "================================================================="
    echo ""

    parse_args "$@"

    trap cleanup EXIT

    setup_directories

    if [[ "$UPDATE_BASELINE" == true ]]; then
        check_prerequisites || true
        build_app
        start_complete_app
        run_all_tests
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
    run_all_tests

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
    else
        log_error "Visual regression tests FAILED in ${duration}s"
    fi
    echo ""
    echo "  Reports:"
    echo "    JSON: $REPORTS_DIR/test-results.json"
    echo "    HTML: $REPORTS_DIR/test-results.html"
    echo ""
    echo "  Diff images: $DIFFS_DIR/"
    echo "================================================================="
    echo ""

    exit $test_result
}

# =============================================================================
# Entry Point
# =============================================================================

main "$@"
