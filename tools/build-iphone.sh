#!/bin/sh
# Personal build: refresh the seed from the Mac's KUNLIGHT, build, install on the phone.
# Needs KUNLIGHT_TEAM (Apple team id), KUNLIGHT_BUNDLE_ID and KUNLIGHT_DEVICE (device id),
# from the environment or tools/local.env (not committed).
# Usage: tools/build-iphone.sh [device id]
set -e
cd "$(dirname "$0")/.."
[ -f tools/local.env ] && . tools/local.env
: "${KUNLIGHT_TEAM:?set KUNLIGHT_TEAM}" "${KUNLIGHT_BUNDLE_ID:?set KUNLIGHT_BUNDLE_ID}"
DEVICE="${1:-${KUNLIGHT_DEVICE:?set KUNLIGHT_DEVICE or pass a device id}}"
python3 -I tools/kunseed.py
xcodebuild -project Moonlight.xcodeproj -scheme Moonlight -configuration Release -destination 'generic/platform=iOS' \
  -derivedDataPath build DEVELOPMENT_TEAM="$KUNLIGHT_TEAM" PRODUCT_BUNDLE_IDENTIFIER="$KUNLIGHT_BUNDLE_ID" \
  CODE_SIGN_STYLE=Automatic ENABLE_USER_SCRIPT_SANDBOXING=NO -allowProvisioningUpdates build > build.log 2>&1 \
  || { grep -E 'error:' build.log | sort -u; exit 1; }
xcrun devicectl device install app --device "$DEVICE" build/Build/Products/Release-iphoneos/Moonlight.app
