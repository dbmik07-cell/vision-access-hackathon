#!/bin/zsh
# Compila e installa IpoView sull'iPhone collegato.
set -e
cd "$(dirname "$0")"
find hackaton hackatonTests -name '._*' -delete 2>/dev/null || true
xcodebuild -project hackaton.xcodeproj -scheme hackaton -destination 'generic/platform=iOS' -derivedDataPath /tmp/ipodd-repo -allowProvisioningUpdates build | grep -E "error:|BUILD"
xcrun devicectl device install app --device 00008120-001825461A90A01E /tmp/ipodd-repo/Build/Products/Debug-iphoneos/hackaton.app | grep -E "installed|ERROR"
xcrun devicectl device process launch --terminate-existing --device 00008120-001825461A90A01E com.roccopredapersonalteam.hackaton | tail -1
