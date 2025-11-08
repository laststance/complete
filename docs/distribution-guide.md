# Complete - Distribution Guide

**Version**: 1.0
**Last Updated**: November 8, 2025
**Target**: macOS 14.0 (Sonoma) and later

## Overview

This guide covers the complete process for signing, notarizing, and distributing the Complete autocomplete application outside the Mac App Store.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Code Signing Setup](#code-signing-setup)
3. [Building for Distribution](#building-for-distribution)
4. [Notarization Process](#notarization-process)
5. [Distribution Methods](#distribution-methods)
6. [Troubleshooting](#troubleshooting)

---

## Prerequisites

### 1. Apple Developer Account

- **Required**: Paid Apple Developer Program membership ($99/year)
- **Purpose**: Access to Developer ID certificates for distribution outside App Store
- **Sign up**: https://developer.apple.com/programs/

### 2. Developer ID Certificate

You need a **Developer ID Application** certificate to sign apps for distribution outside the Mac App Store.

#### Obtaining the Certificate:

1. Log in to [Apple Developer Account](https://developer.apple.com/account/)
2. Navigate to **Certificates, Identifiers & Profiles**
3. Click **+** to create a new certificate
4. Select **Developer ID Application**
5. Follow the Certificate Signing Request (CSR) process:
   - Open **Keychain Access** on your Mac
   - Menu: **Keychain Access > Certificate Assistant > Request a Certificate from a Certificate Authority**
   - Enter your email and name
   - Select **Saved to disk**
   - Upload the CSR file to Apple Developer portal
6. Download the certificate
7. Double-click to install in Keychain Access

#### Verify Installation:

```bash
# List all Developer ID certificates
security find-identity -p basic -v | grep "Developer ID Application"

# Expected output:
# 1) ABC123... "Developer ID Application: Your Name (TEAM_ID)"
```

### 3. Development Tools

- **Xcode** 15.0 or later (for codesign, altool/notarytool)
- **Swift** 5.9 or later
- **Command Line Tools** installed: `xcode-select --install`

---

## Code Signing Setup

### 1. Entitlements Configuration

The app uses **Complete.entitlements** to declare required permissions:

```xml
<!-- Key entitlements: -->
- com.apple.security.automation.apple-events (Accessibility)
- Hardened Runtime enabled (required for notarization)
```

**Location**: `/Complete.entitlements`

### 2. Info.plist Configuration

Ensure LSUIElement is set (background agent without dock icon):

```xml
<key>LSUIElement</key>
<true/>
```

**Location**: `/src/Resources/Info.plist`

### 3. Build Configuration

Update `Package.swift` or use build flags to include entitlements:

#### Option A: Swift Package Manager (SPM)

SPM doesn't natively support entitlements in Package.swift. Use post-build signing:

```bash
# Build first
swift build -c release

# Then sign with entitlements
codesign --force --options runtime \
  --entitlements Complete.entitlements \
  --sign "Developer ID Application: Your Name (TEAM_ID)" \
  .build/release/Complete
```

#### Option B: Xcode Project (Recommended for Distribution)

1. Generate Xcode project:
   ```bash
   swift package generate-xcodeproj
   ```

2. Open `Complete.xcodeproj` in Xcode

3. Select **Complete** target → **Signing & Capabilities**

4. Configure:
   - **Team**: Select your development team
   - **Signing Certificate**: Developer ID Application
   - **Enable Hardened Runtime**: ✓
   - **Entitlements File**: Complete.entitlements

5. Build for release:
   ```bash
   xcodebuild -scheme Complete -configuration Release \
     CODE_SIGN_IDENTITY="Developer ID Application: Your Name (TEAM_ID)" \
     -derivedDataPath ./build
   ```

---

## Building for Distribution

### 1. Clean Build

```bash
# Clean previous builds
swift package clean
rm -rf .build

# Or for Xcode:
xcodebuild clean -scheme Complete
```

### 2. Release Build

```bash
# Swift Package Manager
swift build -c release

# Xcode (signed automatically if configured)
xcodebuild -scheme Complete -configuration Release \
  -derivedDataPath ./build
```

### 3. Sign the Binary

```bash
# Sign with hardened runtime and entitlements
codesign --force --options runtime \
  --entitlements Complete.entitlements \
  --sign "Developer ID Application: Your Name (TEAM_ID)" \
  --timestamp \
  .build/release/Complete

# Verify signature
codesign -dv --verbose=4 .build/release/Complete

# Expected output:
# Executable=/path/to/Complete
# Identifier=com.laststance.Complete
# Format=Mach-O thin (arm64)
# CodeDirectory v=... size=... flags=0x10000(runtime)
# Signature size=...
# Timestamp=...
# Authority=Developer ID Application: Your Name (TEAM_ID)
# Authority=Developer ID Certification Authority
# Authority=Apple Root CA
```

### 4. Create Distributable Package

#### Option A: DMG (Recommended)

```bash
# Create DMG with hdiutil
hdiutil create -volname "Complete" \
  -srcfolder .build/release/Complete \
  -ov -format UDZO \
  Complete.dmg

# Sign the DMG
codesign --sign "Developer ID Application: Your Name (TEAM_ID)" \
  --timestamp \
  Complete.dmg
```

#### Option B: ZIP Archive

```bash
# Create ZIP
ditto -c -k --keepParent .build/release/Complete Complete.zip

# Sign the ZIP (optional, but recommended)
codesign --sign "Developer ID Application: Your Name (TEAM_ID)" \
  --timestamp \
  Complete.zip
```

---

## Notarization Process

### Overview

Notarization is required for all apps distributed outside the Mac App Store. It validates that your app is free of malicious code.

**Timeline**: 15-30 minutes per submission (usually 5-10 minutes)

### 1. Create App-Specific Password

1. Sign in to [appleid.apple.com](https://appleid.apple.com)
2. Navigate to **Security** → **App-Specific Passwords**
3. Click **+** to generate new password
4. Name it "Notarization"
5. Save the password securely

### 2. Store Credentials (Recommended)

```bash
# Store credentials in Keychain
xcrun notarytool store-credentials "Complete-Notarization" \
  --apple-id "your-apple-id@example.com" \
  --team-id "YOUR_TEAM_ID" \
  --password "app-specific-password"

# This saves credentials securely in Keychain for reuse
```

### 3. Submit for Notarization

#### Using notarytool (Xcode 13+, Recommended):

```bash
# Submit DMG
xcrun notarytool submit Complete.dmg \
  --keychain-profile "Complete-Notarization" \
  --wait

# Or submit ZIP
xcrun notarytool submit Complete.zip \
  --keychain-profile "Complete-Notarization" \
  --wait

# Expected output:
# Conducting pre-submission checks for Complete.dmg and initiating connection to the Apple notary service...
# Submission ID received
#   id: 12345678-1234-1234-1234-123456789abc
# Successfully uploaded file
#   id: 12345678-1234-1234-1234-123456789abc
#   path: Complete.dmg
# Waiting for processing to complete.
# Current status: Accepted........Processing complete
#   id: 12345678-1234-1234-1234-123456789abc
#   status: Accepted
```

### 4. Check Notarization Status

```bash
# Check status (if not using --wait)
xcrun notarytool info 12345678-1234-1234-1234-123456789abc \
  --keychain-profile "Complete-Notarization"

# Get detailed log (if rejected)
xcrun notarytool log 12345678-1234-1234-1234-123456789abc \
  --keychain-profile "Complete-Notarization"
```

### 5. Staple the Ticket (DMG only)

```bash
# Staple notarization ticket to DMG
xcrun stapler staple Complete.dmg

# Verify stapling
xcrun stapler validate Complete.dmg

# Expected output:
# Processing: Complete.dmg
# The validate action worked!
```

**Note**: Stapling attaches the notarization ticket directly to the DMG, allowing it to be verified offline.

### 6. Verify Notarization

```bash
# Verify notarization
spctl -a -vv -t install Complete.dmg

# Expected output:
# Complete.dmg: accepted
# source=Notarized Developer ID
```

---

## Distribution Methods

### Option 1: Direct Download (Recommended)

**Pros**:
- Fastest distribution
- No review process
- Full control over updates
- Accessibility features work without App Store restrictions

**Steps**:
1. Upload `Complete.dmg` to your web server
2. Provide download link on your website
3. Include installation instructions

**Installation Instructions for Users**:

```markdown
### Installation

1. Download `Complete.dmg`
2. Open the DMG file
3. Drag `Complete.app` to your Applications folder
4. Launch Complete
5. Grant Accessibility permissions when prompted
6. Configure your hotkey (default: Ctrl+I)
```

### Option 2: Mac App Store

**Note**: Not recommended for this app due to:
- Accessibility API requires special entitlement approval
- Longer review process (7-14 days)
- Sandboxing complications for global hotkeys
- LSUIElement apps less discoverable in App Store

If you still want to pursue App Store distribution, research requirements at:
https://developer.apple.com/app-store/review/guidelines/

### Option 3: GitHub Releases

**Pros**:
- Version control integration
- Automatic release notes
- Open source distribution
- Familiar to developers

**Steps**:
1. Create GitHub repository
2. Tag release: `git tag -a v1.0.0 -m "Release v1.0.0"`
3. Push tag: `git push origin v1.0.0`
4. Upload `Complete.dmg` as release asset
5. Write release notes

---

## Automation Scripts

### notarize.sh - Complete Notarization Workflow

```bash
#!/bin/bash
set -e

# Configuration
APP_NAME="Complete"
DEVELOPER_ID="Developer ID Application: Your Name (TEAM_ID)"
KEYCHAIN_PROFILE="Complete-Notarization"
BUILD_DIR=".build/release"

echo "🔨 Building for release..."
swift build -c release

echo "🔏 Signing binary..."
codesign --force --options runtime \
  --entitlements Complete.entitlements \
  --sign "$DEVELOPER_ID" \
  --timestamp \
  "$BUILD_DIR/$APP_NAME"

echo "📦 Creating DMG..."
hdiutil create -volname "$APP_NAME" \
  -srcfolder "$BUILD_DIR/$APP_NAME" \
  -ov -format UDZO \
  "$APP_NAME.dmg"

echo "🔏 Signing DMG..."
codesign --sign "$DEVELOPER_ID" \
  --timestamp \
  "$APP_NAME.dmg"

echo "🚀 Submitting for notarization..."
xcrun notarytool submit "$APP_NAME.dmg" \
  --keychain-profile "$KEYCHAIN_PROFILE" \
  --wait

echo "📎 Stapling ticket..."
xcrun stapler staple "$APP_NAME.dmg"

echo "✅ Verifying..."
spctl -a -vv -t install "$APP_NAME.dmg"

echo "✅ Distribution ready: $APP_NAME.dmg"
```

**Usage**:

```bash
chmod +x notarize.sh
./notarize.sh
```

---

## Troubleshooting

### Issue: "The executable requests the com.apple.security.automation.apple-events entitlement..."

**Solution**: Ensure entitlements file is correctly specified during signing.

```bash
codesign --force --options runtime \
  --entitlements Complete.entitlements \  # ← Must include this
  --sign "Developer ID Application: ..." \
  .build/release/Complete
```

---

### Issue: Notarization rejected with "invalid signature"

**Causes**:
- Binary not signed with hardened runtime
- Missing timestamp
- Entitlements mismatch

**Solution**:

```bash
# Re-sign with all required flags
codesign --force --options runtime \
  --entitlements Complete.entitlements \
  --sign "Developer ID Application: Your Name (TEAM_ID)" \
  --timestamp \  # ← Critical for notarization
  .build/release/Complete

# Verify before submitting
codesign -dv --verbose=4 .build/release/Complete | grep -i runtime
# Should show: flags=0x10000(runtime)
```

---

### Issue: "Accessibility permission denied" on user's machine

**Cause**: App not signed, or signature broken during transfer

**Solution**:
1. Ensure app is signed and notarized
2. User must manually grant permission in System Settings:
   - System Settings → Privacy & Security → Accessibility
   - Click **+** and add Complete.app
   - Enable the toggle

---

### Issue: "App is damaged and can't be opened"

**Causes**:
- Gatekeeper quarantine attribute
- Incomplete notarization
- Missing stapled ticket

**Solution**:

```bash
# For developer testing only (NOT for users):
sudo xattr -cr /Applications/Complete.app

# For production:
# Ensure notarization is complete and ticket is stapled
xcrun stapler staple Complete.dmg
```

---

### Issue: notarytool reports "Invalid credentials"

**Solution**:

```bash
# Verify stored credentials
xcrun notarytool history \
  --keychain-profile "Complete-Notarization"

# If fails, re-store credentials
xcrun notarytool store-credentials "Complete-Notarization" \
  --apple-id "your-apple-id@example.com" \
  --team-id "YOUR_TEAM_ID" \
  --password "app-specific-password"
```

---

## Security Best Practices

1. **Never commit certificates or passwords** to version control
2. **Use keychain for credentials** instead of hardcoding
3. **Enable hardened runtime** for all distributed builds
4. **Keep entitlements minimal** - only request necessary permissions
5. **Regularly update certificates** before expiration (annually)
6. **Test on clean macOS** before public release

---

## Release Checklist

- [ ] Clean build (`swift package clean`)
- [ ] Release build (`swift build -c release`)
- [ ] Code sign binary with hardened runtime
- [ ] Verify signature (`codesign -dv`)
- [ ] Create DMG package
- [ ] Sign DMG
- [ ] Submit for notarization
- [ ] Wait for acceptance
- [ ] Staple ticket to DMG
- [ ] Verify notarization (`spctl -a -vv`)
- [ ] Test on clean macOS installation
- [ ] Upload to distribution channel
- [ ] Update release notes
- [ ] Announce release

---

## Additional Resources

- [Apple Notarization Guide](https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution)
- [Code Signing Guide](https://developer.apple.com/library/archive/documentation/Security/Conceptual/CodeSigningGuide/Introduction/Introduction.html)
- [Hardened Runtime](https://developer.apple.com/documentation/security/hardened_runtime)
- [Entitlements Documentation](https://developer.apple.com/documentation/bundleresources/entitlements)
- [notarytool Documentation](https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution/customizing_the_notarization_workflow)

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2025-11-08 | Initial distribution guide |

---

## Support

For distribution issues:
- Check [Apple Developer Forums](https://developer.apple.com/forums/)
- Review notarization logs: `xcrun notarytool log <submission-id>`
- Verify code signature: `codesign -dvvv --deep Complete.app`

**Contact**: [Your contact information]
