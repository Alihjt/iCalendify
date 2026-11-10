#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

bash build.sh
version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Info.plist)"
if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    printf 'Expected a three-part numeric app version.\n' >&2
    exit 1
fi

mkdir -p dist
staging="$(mktemp -d "$PWD/build/package.XXXXXX")"
trap 'rm -rf -- "$staging"' EXIT
ditto --norsrc --noextattr build/iCalendify.app "$staging/iCalendify.app"
codesign --verify --strict "$staging/iCalendify.app"
ln -s /Applications "$staging/Applications"
cp LICENSE "$staging/License.txt"
cat > "$staging/Read Me.txt" <<'INSTRUCTIONS'
iCalendify

Requires an Apple silicon Mac with macOS 26 or later and iCloud Calendar.

1. Drag iCalendify into Applications.
2. Open iCalendify from Applications.
3. Click Load calendars, allow Calendar access, and choose a calendar.

This early release is not signed with an Apple Developer ID or notarized
by Apple. macOS may block it. If you trust this download, after trying to
open it, go to System Settings > Privacy & Security > Open Anyway.
Do not disable Gatekeeper system-wide.

For AI titles, enable Apple Intelligence in System Settings. Manual entry
also works without AI. You do not need Xcode or Terminal to use the app.

Select text, then right-click > Services > Add to Calendar with iCalendify.
Review the title, date, year, time, and calendar before saving. The selected
text becomes the event's notes and syncs with the event through iCloud.

Help and source: https://github.com/Alihjt/iCalendify
INSTRUCTIONS

filename="iCalendify-${version}-arm64.dmg"
hdiutil create -volname iCalendify -srcfolder "$staging" -format UDZO -ov "dist/$filename"
hdiutil verify "dist/$filename"
(cd dist && shasum -a 256 "$filename" > "$filename.sha256")
printf 'Packaged dist/%s\n' "$filename"
