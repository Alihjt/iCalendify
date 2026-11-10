#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
if [[ $# -gt 1 || ( $# -eq 1 && "$1" != "--ai" ) ]]; then
    printf 'Usage: bash test.sh [--ai]\n' >&2
    exit 2
fi
mkdir -p build/module-cache
xcrun swiftc -swift-version 5 -O -target arm64-apple-macos26.0 \
    -module-cache-path build/module-cache Sources/Core.swift Sources/DateDetection.swift Tests/CoreTests.swift \
    -o build/core-tests
./build/core-tests
if [[ "${1:-}" == "--ai" ]]; then
    xcrun swiftc -swift-version 5 -O -target arm64-apple-macos26.0 \
        -module-cache-path build/module-cache Sources/Core.swift Sources/AI.swift Tests/EnglishTitleProbe.swift \
        -o build/title-probe
    ./build/title-probe
fi
