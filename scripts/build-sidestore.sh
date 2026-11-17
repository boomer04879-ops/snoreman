#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ "$(uname -s)" != Darwin ]] || ! command -v xcodebuild >/dev/null; then
  echo 'This build requires macOS with full Xcode and the iPhoneOS SDK.' >&2
  exit 1
fi
command -v pod >/dev/null || { echo 'Install CocoaPods first.' >&2; exit 1; }
export SIDESTORE_BUILD=1
export CI=1
export EXPO_NO_TELEMETRY=1
export NODE_BINARY="$(command -v node)"
mkdir -p build/logs
npm ci --no-audit --no-fund 2>&1 | tee build/logs/npm.log
# --clean regenerates ios/; use this dedicated source checkout only.
npx --no-install expo prebuild --platform ios --clean --no-install 2>&1 | tee build/logs/prebuild.log
(cd ios && pod install) 2>&1 | tee build/logs/pods.log
xcodebuild -version | tee build/logs/xcode-version.txt
xcodebuild -workspace ios/Snoreman.xcworkspace -scheme Snoreman \
  -configuration Release -sdk iphoneos -destination 'generic/platform=iOS' \
  -archivePath "$PWD/build/Snoreman.xcarchive" \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY= \
  DEVELOPMENT_TEAM= archive 2>&1 | tee build/logs/xcodebuild.log
app="$PWD/build/Snoreman.xcarchive/Products/Applications/Snoreman.app"
test -d "$app"
test -s "$app/main.jsbundle"
/usr/libexec/PlistBuddy -c 'Print :NSMicrophoneUsageDescription' "$app/Info.plist"
/usr/libexec/PlistBuddy -c 'Print :UIBackgroundModes' "$app/Info.plist" | grep -q audio
binary=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$app/Info.plist")
lipo -verify_arch arm64 "$app/$binary"
/usr/libexec/PlistBuddy -c 'Print :CFBundleSupportedPlatforms:0' "$app/Info.plist" | grep -qx iPhoneOS
rm -rf build/package
mkdir -p build/package/Payload
ditto "$app" build/package/Payload/Snoreman.app
cp LICENSE build/package/LICENSE.txt
rm -f build/Snoreman-unsigned.ipa
(cd build/package && /usr/bin/zip -qry ../Snoreman-unsigned.ipa Payload LICENSE.txt)
unzip -t build/Snoreman-unsigned.ipa
shasum -a 256 build/Snoreman-unsigned.ipa > build/Snoreman-unsigned.ipa.sha256
echo 'Created build/Snoreman-unsigned.ipa. Sign and install using SideStore.'
