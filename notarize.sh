#!/bin/bash
#
# Complete - Notarization Workflow Script
# Automates building, signing, and notarizing the Complete autocomplete app
#
# Prerequisites:
# 1. Apple Developer account with Developer ID Application certificate
# 2. Stored notarization credentials (see docs/distribution-guide.md)
# 3. Swift 5.9+ and Xcode Command Line Tools installed
#
# Usage:
#   ./notarize.sh [options]
#
# Options:
#   --developer-id ID    Your Developer ID (default: from env DEVELOPER_ID)
#   --keychain-profile   Keychain profile name (default: Complete-Notarization)
#   --skip-build         Skip build step (use existing binary)
#   --skip-notarization  Skip notarization (for testing)
#   --output DIR         Output directory (default: ./dist)
#   --help               Show this help message
#
# Environment Variables:
#   DEVELOPER_ID         Developer ID Application certificate name
#   KEYCHAIN_PROFILE     notarytool keychain profile name
#
# Example:
#   export DEVELOPER_ID="Developer ID Application: Your Name (TEAM_ID)"
#   ./notarize.sh
#

set -e  # Exit on error
set -u  # Exit on undefined variable

# Configuration
APP_NAME="Complete"
BUILD_DIR=".build/release"
OUTPUT_DIR="./dist"
ENTITLEMENTS="Complete.entitlements"
SKIP_BUILD=false
SKIP_NOTARIZATION=false

# Defaults (can be overridden by environment or arguments)
DEVELOPER_ID="${DEVELOPER_ID:-}"
KEYCHAIN_PROFILE="${KEYCHAIN_PROFILE:-Complete-Notarization}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
print_step() {
    echo -e "${BLUE}▶ $1${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
    exit 1
}

show_help() {
    grep '^#' "$0" | grep -v '#!/bin/bash' | sed 's/^# //; s/^#//'
    exit 0
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --developer-id)
            DEVELOPER_ID="$2"
            shift 2
            ;;
        --keychain-profile)
            KEYCHAIN_PROFILE="$2"
            shift 2
            ;;
        --skip-build)
            SKIP_BUILD=true
            shift
            ;;
        --skip-notarization)
            SKIP_NOTARIZATION=true
            shift
            ;;
        --output)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        --help)
            show_help
            ;;
        *)
            print_error "Unknown option: $1\nUse --help for usage information"
            ;;
    esac
done

# Validate prerequisites
print_step "Validating prerequisites..."

if [ -z "$DEVELOPER_ID" ]; then
    print_error "DEVELOPER_ID not set. Use --developer-id or set DEVELOPER_ID environment variable."
fi

if ! command -v swift &> /dev/null; then
    print_error "Swift not found. Install Xcode Command Line Tools."
fi

if ! command -v xcrun &> /dev/null; then
    print_error "xcrun not found. Install Xcode Command Line Tools."
fi

if [ ! -f "$ENTITLEMENTS" ]; then
    print_error "Entitlements file not found: $ENTITLEMENTS"
fi

# Verify Developer ID certificate is installed
if ! security find-identity -p basic -v | grep -q "$DEVELOPER_ID"; then
    print_error "Developer ID certificate not found in Keychain: $DEVELOPER_ID"
fi

print_success "Prerequisites validated"

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Step 1: Build (optional)
if [ "$SKIP_BUILD" = true ]; then
    print_warning "Skipping build step"
    if [ ! -f "$BUILD_DIR/$APP_NAME" ]; then
        print_error "Binary not found: $BUILD_DIR/$APP_NAME"
    fi
else
    print_step "Building for release..."

    # Clean previous build
    swift package clean

    # Build release
    swift build -c release

    if [ ! -f "$BUILD_DIR/$APP_NAME" ]; then
        print_error "Build failed: Binary not found at $BUILD_DIR/$APP_NAME"
    fi

    print_success "Build complete: $BUILD_DIR/$APP_NAME"
fi

# Step 2: Create .app bundle structure
print_step "Creating ${APP_NAME}.app bundle..."

APP_BUNDLE="${OUTPUT_DIR}/${APP_NAME}.app"
rm -rf "$APP_BUNDLE"

mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

# Copy binary
cp "$BUILD_DIR/$APP_NAME" "${APP_BUNDLE}/Contents/MacOS/"

# Copy Info.plist
if [ -f "src/Resources/Info.plist" ]; then
    cp "src/Resources/Info.plist" "${APP_BUNDLE}/Contents/"
else
    print_error "Info.plist not found at src/Resources/Info.plist"
fi

# Copy app icon
if [ -f "src/Resources/AppIcon.icns" ]; then
    cp "src/Resources/AppIcon.icns" "${APP_BUNDLE}/Contents/Resources/"
else
    print_warning "AppIcon.icns not found - app will use default icon"
fi

# Copy SPM resource bundles (critical for KeyboardShortcuts localization)
print_step "Copying SPM resource bundles..."
BUNDLE_COUNT=0
for bundle in "$BUILD_DIR"/*.bundle; do
    if [ -d "$bundle" ]; then
        cp -R "$bundle" "${APP_BUNDLE}/Contents/Resources/"
        BUNDLE_COUNT=$((BUNDLE_COUNT + 1))
        echo "  Copied: $(basename "$bundle")"
    fi
done
if [ "$BUNDLE_COUNT" -eq 0 ]; then
    print_warning "No SPM resource bundles found - this may cause runtime issues"
else
    print_success "Copied $BUNDLE_COUNT SPM resource bundle(s)"
fi

# Set executable permissions
chmod +x "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"

print_success "App bundle created: ${APP_BUNDLE}"

# Step 3: Code Sign App Bundle
print_step "Signing app bundle with hardened runtime..."

# First sign any resource bundles
for bundle in "${APP_BUNDLE}/Contents/Resources"/*.bundle; do
    if [ -d "$bundle" ]; then
        echo "  Signing: $(basename "$bundle")"
        codesign --force --options runtime \
          --sign "$DEVELOPER_ID" \
          --timestamp \
          "$bundle"
    fi
done

# Then sign the binary inside the bundle
codesign --force --options runtime \
  --entitlements "$ENTITLEMENTS" \
  --sign "$DEVELOPER_ID" \
  --timestamp \
  "${APP_BUNDLE}/Contents/MacOS/$APP_NAME"

# Then sign the whole bundle
codesign --force --options runtime \
  --entitlements "$ENTITLEMENTS" \
  --sign "$DEVELOPER_ID" \
  --timestamp \
  "$APP_BUNDLE"

# Verify signature
print_step "Verifying signature..."
codesign -dv --verbose=4 "$APP_BUNDLE" 2>&1 | grep -q "runtime" || \
    print_error "Hardened runtime not enabled in signature"

print_success "App bundle signed successfully"

# Step 4: Create DMG
print_step "Creating DMG package..."

DMG_NAME="${APP_NAME}-$(date +%Y%m%d).dmg"
DMG_PATH="$OUTPUT_DIR/$DMG_NAME"

# Remove existing DMG if present
[ -f "$DMG_PATH" ] && rm "$DMG_PATH"

# Create temporary directory for DMG contents
TEMP_DMG_DIR=$(mktemp -d)
cp -R "$APP_BUNDLE" "$TEMP_DMG_DIR/"

# Create DMG
hdiutil create -volname "$APP_NAME" \
  -srcfolder "$TEMP_DMG_DIR" \
  -ov -format UDZO \
  "$DMG_PATH"

# Clean up temporary directory and app bundle
rm -rf "$TEMP_DMG_DIR"
rm -rf "$APP_BUNDLE"

print_success "DMG created: $DMG_PATH"

# Step 5: Sign DMG
print_step "Signing DMG..."

codesign --sign "$DEVELOPER_ID" \
  --timestamp \
  "$DMG_PATH"

print_success "DMG signed successfully"

# Step 6: Notarization (optional)
if [ "$SKIP_NOTARIZATION" = true ]; then
    print_warning "Skipping notarization step"
    print_success "Distribution package ready: $DMG_PATH"
    print_warning "Note: Package is NOT notarized. Users will see Gatekeeper warnings."
    exit 0
fi

print_step "Submitting for notarization..."
print_warning "This may take 5-30 minutes. Please wait..."

# Submit and wait for notarization
SUBMISSION_OUTPUT=$(xcrun notarytool submit "$DMG_PATH" \
  --keychain-profile "$KEYCHAIN_PROFILE" \
  --wait 2>&1)

# Check if notarization succeeded
if echo "$SUBMISSION_OUTPUT" | grep -q "status: Accepted"; then
    print_success "Notarization accepted"

    # Extract submission ID for reference
    SUBMISSION_ID=$(echo "$SUBMISSION_OUTPUT" | grep -m 1 "id:" | awk '{print $2}')
    echo "  Submission ID: $SUBMISSION_ID"
else
    print_error "Notarization failed. Output:\n$SUBMISSION_OUTPUT"
fi

# Step 7: Staple Ticket
print_step "Stapling notarization ticket..."

xcrun stapler staple "$DMG_PATH"

# Verify stapling
if xcrun stapler validate "$DMG_PATH" | grep -q "The validate action worked"; then
    print_success "Ticket stapled successfully"
else
    print_error "Stapling failed"
fi

# Step 8: Final Verification
print_step "Performing final verification..."

SPCTL_OUTPUT=$(spctl -a -vv -t install "$DMG_PATH" 2>&1)

if echo "$SPCTL_OUTPUT" | grep -q "accepted"; then
    print_success "Gatekeeper verification passed"
else
    print_warning "Gatekeeper verification returned unexpected result:\n$SPCTL_OUTPUT"
fi

# Summary
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${GREEN}✓ Distribution package ready!${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  Package: $DMG_PATH"
echo "  Status:  Signed and Notarized"
echo ""
echo "Next Steps:"
echo "  1. Test on a clean macOS system"
echo "  2. Upload to distribution server"
echo "  3. Update release notes"
echo "  4. Announce release"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
