#!/bin/bash

# Configuration
APP_NAME="SampleBot"
SCHEME="SampleBot"
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
