#!/usr/bin/env bash
# Archive ProBro for one platform and upload it to App Store Connect.
#
# Usage: scripts/release.sh <ios|macos>
#
# Required environment:
#   DEVELOPMENT_TEAM      Apple Developer Team ID (10 characters)
#   ASC_KEY_ID            App Store Connect API key ID
#   ASC_ISSUER_ID         App Store Connect API issuer ID
#   ASC_KEY_PATH          Path to the AuthKey_XXXX.p8 file
# Optional:
#   BUILD_NUMBER          CURRENT_PROJECT_VERSION for this upload (default: timestamp)
set -euo pipefail

platform="${1:?usage: $0 <ios|macos>}"
case "$platform" in
  ios)   destination="generic/platform=iOS" ;;
  macos) destination="generic/platform=macOS" ;;
  *) echo "unknown platform: $platform" >&2; exit 2 ;;
esac

: "${DEVELOPMENT_TEAM:?DEVELOPMENT_TEAM is not set}"
: "${ASC_KEY_ID:?ASC_KEY_ID is not set}"
: "${ASC_ISSUER_ID:?ASC_ISSUER_ID is not set}"
: "${ASC_KEY_PATH:?ASC_KEY_PATH is not set}"
build_number="${BUILD_NUMBER:-$(date +%Y%m%d%H%M)}"

root="$(cd "$(dirname "$0")/.." && pwd)"
out="$root/build/$platform"
rm -rf "$out"
mkdir -p "$out"

auth=(
  -allowProvisioningUpdates
  -authenticationKeyPath "$ASC_KEY_PATH"
  -authenticationKeyID "$ASC_KEY_ID"
  -authenticationKeyIssuerID "$ASC_ISSUER_ID"
)

xcodebuild archive \
  -project "$root/ProBro.xcodeproj" \
  -scheme ProBro \
  -configuration Release \
  -destination "$destination" \
  -archivePath "$out/ProBro.xcarchive" \
  DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM" \
  CURRENT_PROJECT_VERSION="$build_number" \
  "${auth[@]}"

cp "$root/Config/ExportOptions.plist" "$out/ExportOptions.plist"
/usr/libexec/PlistBuddy -c "Add :teamID string $DEVELOPMENT_TEAM" "$out/ExportOptions.plist"

xcodebuild -exportArchive \
  -archivePath "$out/ProBro.xcarchive" \
  -exportOptionsPlist "$out/ExportOptions.plist" \
  -exportPath "$out/export" \
  "${auth[@]}"

echo "Uploaded $platform build $build_number to App Store Connect."
