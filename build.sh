#!/bin/zsh
set -eu
cd "$(dirname "$0")"
DESTINATION="${1:-$PWD/dist}"
mkdir -p "$DESTINATION" .build/AppIcon.iconset
DESTINATION="$(cd "$DESTINATION" && pwd)"
STAGING="$(mktemp -d -t BatteryTripBuild)"
trap 'rm -rf "$STAGING"' EXIT
APP="$STAGING/Akku.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
for ARCH in arm64 x86_64; do
    swiftc -swift-version 5 -target "$ARCH-apple-macosx13.0" -O Sources/*.swift -o ".build/Akku-$ARCH" -framework AppKit -framework SwiftUI -framework IOKit -framework CoreLocation -framework UserNotifications -framework ServiceManagement -framework MapKit
done
lipo -create .build/Akku-arm64 .build/Akku-x86_64 -output "$APP/Contents/MacOS/Akku"
cp Assets/Info.plist "$APP/Contents/Info.plist"
cp Assets/AkkuLogo.png "$APP/Contents/Resources/"
cp -R Assets/*.lproj "$APP/Contents/Resources/"
swift Assets/MakeIcon.swift .build/Icon.png
for SIZE in 16 32 128 256 512; do
    sips -z "$SIZE" "$SIZE" .build/Icon.png --out ".build/AppIcon.iconset/icon_${SIZE}x${SIZE}.png" >/dev/null
    DOUBLE=$((SIZE * 2))
    sips -z "$DOUBLE" "$DOUBLE" .build/Icon.png --out ".build/AppIcon.iconset/icon_${SIZE}x${SIZE}@2x.png" >/dev/null
done
iconutil -c icns .build/AppIcon.iconset -o "$APP/Contents/Resources/AppIcon.icns"
xattr -cr "$APP"
codesign --force --options runtime --entitlements Assets/Entitlements.plist --sign - "$APP"
codesign --verify --deep --strict "$APP"
ditto --norsrc "$APP" "$DESTINATION/Akku.app"
printf 'Built: %s\n' "$DESTINATION/Akku.app"
