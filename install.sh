#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
source_app="$PWD/build/iCalendify.app"
destination="$HOME/Applications/iCalendify.app"
test -x "$source_app/Contents/MacOS/iCalendify"
if [[ -e "$destination" ]]; then
    printf 'An app already exists at %s. Move it aside before reinstalling.\n' "$destination" >&2
    exit 1
fi
mkdir -p "$HOME/Applications"
ditto "$source_app" "$destination"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$destination"
open "$destination"
printf 'Installed %s\n' "$destination"
