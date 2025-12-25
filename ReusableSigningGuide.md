# Reusable macOS Signing & Notarization Guide

This guide explains how to add automated, secure signing and notarization to **any** Xcode project using the same script we built for `SampleBot`.

## 1. Prerequisites
You need:
1.  **Apple Developer Account** (Paid membership required for Notarization).
2.  **Developer ID Application Certificate**:
    *   Create it at [developer.apple.com](https://developer.apple.com).
    *   Download and double-click to install into your Keychain.
3.  **Notary Credentials**:
    *   Create an App-Specific Password at [appleid.apple.com](https://appleid.apple.com).
    *   Run this command one time on your machine:
        ```bash
        xcrun notarytool store-credentials "NotaryProfile" \
                   --apple-id "YOUR_EMAIL" \
                   --team-id "YOUR_TEAM_ID" \
                   --password "YOUR_APP_SPECIFIC_PASSWORD"
        ```

        ```

## 2. Key Concept: Reuse vs. Per-Project
**What you REUSE (One-time setup per machine):**
*   **Developer Certificate**: You use the same "Developer ID Application" certificate for ALL your projects. You do *not* need a new one for each app.
*   **Notary Profile**: The `NotaryProfile` credential stored in Step 1 is linked to your Apple ID. You use this same profile name for every project.

**What is UNIQUE (Per-Project):**
*   **Bundle Identifier**: Each app needs its own unique ID (e.g., `com.example.MyApp`) in Xcode.
*   **`.env` File**: You must copy/create the `.env` file in each new project folder so the script knows which Team ID to use, even if the ID is the same.

## 3. The Build Script
Copy the following script into a file named `build_release.sh` in the root of your new project.

**Important**: Change the `APP_NAME` variable at the top to match your new project's name.

```bash
#!/bin/bash

# --- CONFIGURATION ---
APP_NAME="YourAppName"   # <--- CHANGE THIS
SCHEME="YourAppScheme"   # <--- CHANGE THIS (Usually same as APP_NAME)
# ---------------------

ARCHIVE_PATH="./.build_dest/$APP_NAME.xcarchive"
EXPORT_PATH="./Dist"
IPA_PATH="$EXPORT_PATH/$APP_NAME.ipa"
APP_PATH="$EXPORT_PATH/$APP_NAME.app"
ZIP_PATH="$EXPORT_PATH/$APP_NAME-Signed.zip"
KEYCHAIN_PROFILE="NotaryProfile"

# Load Secrets
if [ -f ".env" ]; then
    source .env
fi

if [ -z "$DEVELOPMENT_TEAM" ]; then
    echo "❌ Error: DEVELOPMENT_TEAM is not set."
    echo "Please create a .env file with DEVELOPMENT_TEAM=\"YourTeamID\" or export it in your shell."
    exit 1
fi

echo "🔐 Using Team ID: $DEVELOPMENT_TEAM"

# Clean
rm -rf "$EXPORT_PATH"
mkdir -p "$EXPORT_PATH"

echo "🚧 Archiving..."
xcodebuild archive \
  -project "$APP_NAME/$APP_NAME.xcodeproj" \
  -scheme "$SCHEME" \
  -configuration Release \
  -archivePath "$ARCHIVE_PATH" \
  -destination 'generic/platform=macOS' \
  CODE_SIGN_STYLE="Manual" \
  CODE_SIGN_IDENTITY="Developer ID Application" \
  DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM" || exit 1

echo "📦 Exporting..."
# Generate temporary ExportOptions.plist with the correct Team ID
cat <<EOF > ExportOptions.plist
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>developer-id</string>
    <key>teamID</key>
    <string>$DEVELOPMENT_TEAM</string>
</dict>
</plist>
EOF

xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportOptionsPlist "ExportOptions.plist" \
  -exportPath "$EXPORT_PATH" || exit 1

# Cleanup temporary plist
rm ExportOptions.plist

echo "🤐 Zipping for Notarization..."
/usr/bin/ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"

echo "📝 Notarizing..."
xcrun notarytool submit "$ZIP_PATH" --keychain-profile "$KEYCHAIN_PROFILE" --wait

echo "✅ Stapling..."
xcrun stapler staple "$APP_PATH"

echo "🎉 Done! Signed and Notarized app is in $APP_PATH"
```

## 4. Project Configuration

### Xcode Settings
For notarization to work, your App Target must have **Hardened Runtime** enabled.
1.  Open Xcode.
2.  Go to **Signing & Capabilities**.
3.  Click **+ Capability**.
4.  Add **Hardened Runtime**.

### Private Config (.env)
Just like before, create a `.env` file in the project root to store your Team ID safely:
```bash
echo 'DEVELOPMENT_TEAM="YOUR_TEAM_ID"' > .env
```

### Git Ignore
Add these lines to your `.gitignore` to prevent committing artifacts and secrets:
```gitignore
# Build Artifacts
.build_dest/
Dist/
*.zip

# Secrets
.env
```

## 5. Run It!
Make the script executable and run it:
```bash
chmod +x build_release.sh
./build_release.sh
```
