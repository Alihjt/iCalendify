#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
if [[ "$(uname -s)" != "Darwin" || "$(uname -m)" != "arm64" ]]; then
    printf 'iCalendify requires an Apple silicon Mac running macOS 26 or later.\n' >&2
    exit 1
fi
sdk_version="$(xcrun --sdk macosx --show-sdk-version)"
if (( ${sdk_version%%.*} < 26 )); then
    printf 'Select Xcode or Command Line Tools with the macOS 26 SDK or newer.\n' >&2
    exit 1
fi
app="build/iCalendify.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources" build/module-cache
xcrun swiftc -swift-version 5 -O -target arm64-apple-macos26.0 \
    -module-cache-path build/module-cache Sources/Core.swift Sources/DateDetection.swift Sources/AI.swift Sources/App.swift \
    -o "$app/Contents/MacOS/iCalendify"
cp Info.plist "$app/Contents/Info.plist"
cp Assets/AppIcon.icns "$app/Contents/Resources/AppIcon.icns"
codesign --force --sign - --identifier org.icalendify.mac "$app"
codesign --verify --strict "$app"
printf 'Built %s\n' "$PWD/$app"
