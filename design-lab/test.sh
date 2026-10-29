#!/bin/bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
if [ -z "${SDKROOT:-}" ] && [ -d /Library/Developer/CommandLineTools/SDKs/MacOSX26.sdk ]; then
    export SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.sdk
fi
mkdir -p "$HERE/.build"
# Foundation/Combine only; also runs with Command Line Tools, without XCTest/Xcode.
swiftc "$HERE/Sources/DesignLab/Model.swift" "$HERE/Sources/DesignLab/Capabilities.swift" "$HERE/Sources/DesignLab/AuthFlow.swift" "$HERE/Sources/DesignLab/TOTP.swift" "$HERE/Sources/DesignLab/QRImport.swift" "$HERE/Sources/DesignLab/ImportLocalization.swift" "$HERE/Tests/DesignLabTests/ModelTests.swift" -o "$HERE/.build/model-tests"
"$HERE/.build/model-tests"
