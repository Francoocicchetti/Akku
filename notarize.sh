#!/bin/zsh
set -eu
# Usage: ./notarize.sh '/path/Akku.app' 'Developer ID Application: Name (TEAMID)' 'existing-keychain-profile'
# Credentials are read by Apple's notarytool from Keychain, never from this repository.
if [[ $# -ne 3 ]]; then
    print -u2 "Usage: $0 APP_PATH DEVELOPER_ID_IDENTITY KEYCHAIN_PROFILE"
    exit 2
fi
APP="$1"
IDENTITY="$2"
PROFILE="$3"
[[ -d "$APP/Contents" ]] || { print -u2 'App bundle not found'; exit 2; }
APP="$(cd "$(dirname "$APP")" && pwd)/$(basename "$APP")"
ARCHIVE="$(dirname "$APP")/Battery-Trip-Notarized.zip"
xattr -cr "$APP"
codesign --force --options runtime --entitlements "$(dirname "$0")/Assets/Entitlements.plist" --timestamp --sign "$IDENTITY" "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"
ditto -c -k --norsrc --keepParent "$APP" "$ARCHIVE"
xcrun notarytool submit "$ARCHIVE" --keychain-profile "$PROFILE" --wait
xcrun stapler staple "$APP"
xcrun stapler validate "$APP"
spctl --assess --type execute --verbose=2 "$APP"
ditto -c -k --norsrc --keepParent "$APP" "$ARCHIVE"
print "Notarized delivery: $ARCHIVE"
