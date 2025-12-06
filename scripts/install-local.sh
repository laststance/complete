#!/bin/bash
#
# Complete - Local Installation Script
# Creates .app bundle and installs to /Applications for local development
#
# Usage:
#   ./install-local.sh [options]
#
# Options:
#   --debug          Build in debug mode (default: release)
#   --no-install     Create .app but don't install to /Applications
#   --sign [NAME]    Sign with certificate (maintains accessibility permissions)
#   --help           Show this help message
#
# Note: Without --sign, accessibility permissions must be re-granted after each rebuild.
#       Create a self-signed certificate in Keychain Access for consistent permissions.
#

set -e  # Exit on error
set -u  # Exit on undefined variable

# Configuration
APP_NAME="Complete"
BUILD_CONFIG="release"
INSTALL_TO_APPLICATIONS=true
SIGN_IDENTITY=""

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
        --debug)
            BUILD_CONFIG="debug"
            shift
            ;;
        --no-install)
            INSTALL_TO_APPLICATIONS=false
            shift
            ;;
        --sign)
            if [[ $# -gt 1 && ! "$2" =~ ^-- ]]; then
                SIGN_IDENTITY="$2"
                shift 2
            else
                # Auto-detect first available code signing identity
                SIGN_IDENTITY=$(security find-identity -v -p codesigning 2>/dev/null | grep -oE '"[^"]+"' | head -1 | tr -d '"' || echo "")
                if [ -z "$SIGN_IDENTITY" ]; then
                    print_error "No code signing identity found. Create a self-signed certificate in Keychain Access."
                fi
                shift
            fi
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

if ! command -v swift &> /dev/null; then
    print_error "Swift not found. Install Xcode Command Line Tools."
fi

if [ ! -f "Package.swift" ]; then
    print_error "Package.swift not found. Run this script from project root."
fi

if [ ! -f "src/Resources/Info.plist" ]; then
    print_error "Info.plist not found at src/Resources/Info.plist"
fi

print_success "Prerequisites validated"

# Step 1: Build
print_step "Building ${APP_NAME} in ${BUILD_CONFIG} mode..."

swift build -c ${BUILD_CONFIG}

BINARY_PATH=".build/${BUILD_CONFIG}/${APP_NAME}"
if [ ! -f "$BINARY_PATH" ]; then
    print_error "Build failed: Binary not found at ${BINARY_PATH}"
fi

BINARY_SIZE=$(ls -lh "$BINARY_PATH" | awk '{print $5}')
print_success "Build complete: ${BINARY_PATH} (${BINARY_SIZE})"

# Step 2: Create app bundle structure
print_step "Creating ${APP_NAME}.app bundle..."

APP_BUNDLE="${APP_NAME}.app"
rm -rf "$APP_BUNDLE"

mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

print_success "App bundle structure created"

# Step 3: Copy files
print_step "Copying files into bundle..."

cp "$BINARY_PATH" "${APP_BUNDLE}/Contents/MacOS/"
cp "src/Resources/Info.plist" "${APP_BUNDLE}/Contents/"
cp "src/Resources/AppIcon.icns" "${APP_BUNDLE}/Contents/Resources/"

print_success "Files copied"

# Step 4: Set permissions
print_step "Setting executable permissions..."

chmod +x "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"

print_success "Permissions set"

# Step 5: Code sign (optional but recommended)
if [ -n "$SIGN_IDENTITY" ]; then
    print_step "Signing app bundle with: ${SIGN_IDENTITY}..."

    # Check if entitlements file exists
    ENTITLEMENTS_FILE="Complete.entitlements"
    if [ ! -f "$ENTITLEMENTS_FILE" ]; then
        print_warning "Entitlements file not found: $ENTITLEMENTS_FILE"
        print_warning "Signing without entitlements - accessibility may not work properly"
        ENTITLEMENTS_FLAG=""
    else
        ENTITLEMENTS_FLAG="--entitlements $ENTITLEMENTS_FILE"
    fi

    # Sign with hardened runtime and entitlements (required for accessibility)
    # First sign the binary inside the bundle
    codesign --force --options runtime \
        $ENTITLEMENTS_FLAG \
        --sign "$SIGN_IDENTITY" \
        --timestamp \
        "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}" 2>&1 || {
        print_warning "Binary signing failed. Continuing without signature."
        SIGN_IDENTITY=""
    }

    # Then sign the whole bundle
    if [ -n "$SIGN_IDENTITY" ]; then
        codesign --force --options runtime \
            $ENTITLEMENTS_FLAG \
            --sign "$SIGN_IDENTITY" \
            --timestamp \
            "${APP_BUNDLE}" 2>&1 || {
            print_warning "Bundle signing failed. Continuing without signature."
            SIGN_IDENTITY=""
        }
    fi

    if [ -n "$SIGN_IDENTITY" ]; then
        print_success "App signed with hardened runtime"

        # Verify signature includes hardened runtime
        VERIFY_OUTPUT=$(codesign -dv --verbose=2 "${APP_BUNDLE}" 2>&1)
        if echo "$VERIFY_OUTPUT" | grep -q "runtime"; then
            print_success "Hardened runtime verified"
        else
            print_warning "Hardened runtime flag not detected"
        fi

        # Verify entitlements are embedded
        if [ -n "$ENTITLEMENTS_FLAG" ]; then
            if codesign -d --entitlements - "${APP_BUNDLE}" 2>&1 | grep -q "automation.apple-events"; then
                print_success "Entitlements embedded correctly"
            else
                print_warning "Entitlements may not be embedded correctly"
            fi
        fi
    fi
fi

# Step 6: Install to /Applications (optional)
if [ "$INSTALL_TO_APPLICATIONS" = true ]; then
    print_step "Installing to /Applications..."

    INSTALL_PATH="/Applications/${APP_BUNDLE}"

    if [ -d "$INSTALL_PATH" ]; then
        print_warning "Removing existing app at ${INSTALL_PATH}"
        rm -rf "$INSTALL_PATH"
    fi

    cp -R "$APP_BUNDLE" /Applications/

    print_success "Installed to ${INSTALL_PATH}"

    # Remove quarantine attribute if present (allows running unsigned app)
    if xattr "$INSTALL_PATH" 2>/dev/null | grep -q "com.apple.quarantine"; then
        print_step "Removing quarantine attribute..."
        xattr -d com.apple.quarantine "$INSTALL_PATH" 2>/dev/null || true
        print_success "Quarantine attribute removed"
    fi
else
    print_success "${APP_BUNDLE} created in project directory"
fi

# Summary
echo ""
echo -e "${GREEN}═══════════════════════════════════════════════${NC}"
echo -e "${GREEN}✓ Installation Complete${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════${NC}"
echo ""

if [ "$INSTALL_TO_APPLICATIONS" = true ]; then
    echo "📍 Location: /Applications/${APP_NAME}.app"
    if [ -n "$SIGN_IDENTITY" ]; then
        echo "🔏 Signed with: ${SIGN_IDENTITY}"
        echo ""
        echo "✨ Accessibility permissions will persist across rebuilds!"
    else
        echo ""
        echo "⚠️  Unsigned: Re-grant accessibility permissions after each rebuild"
        echo "   Use --sign to maintain permissions: ./install-local.sh --sign"
    fi
    echo ""
    echo "🚀 Next Steps:"
    echo "   1. Launch via Spotlight: Cmd+Space → 'Complete' → Enter"
    echo "   2. Grant accessibility permissions when prompted"
    echo "      (System Settings → Privacy & Security → Accessibility)"
    echo "   3. Use Ctrl+I in any text field to trigger completion"
    echo ""
    echo "🔧 Management:"
    echo "   • Uninstall: rm -rf /Applications/${APP_NAME}.app"
    echo "   • Reinstall: ./install-local.sh"
    echo "   • Debug mode: ./install-local.sh --debug"
else
    echo "📦 App bundle created: ./${APP_BUNDLE}"
    echo ""
    echo "To install manually:"
    echo "   cp -R ${APP_BUNDLE} /Applications/"
fi

echo ""
echo "📚 Documentation:"
echo "   • README.md - Project overview"
echo "   • docs/distribution-guide.md - Full distribution workflow"
echo ""