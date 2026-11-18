#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
trap 'echo "::error title=SideStore build::Failed at line $LINENO (exit $?)"' ERR
if [[ "$(uname -s)" != Darwin ]] || ! command -v xcodebuild >/dev/null; then
  echo 'This build requires macOS with full Xcode and the iPhoneOS SDK.' >&2
  exit 1
fi
command -v pod >/dev/null || { echo 'Install CocoaPods first.' >&2; exit 1; }
export SIDESTORE_BUILD=1 CI=1 EXPO_NO_TELEMETRY=1
export NODE_BINARY="$(command -v node)"
mkdir -p build/logs
npm ci --no-audit --no-fund 2>&1 | tee build/logs/npm.log
npx --no-install expo prebuild --platform ios --clean --no-install 2>&1 | tee build/logs/prebuild.log
(cd ios && pod install) 2>&1 | tee build/logs/pods.log
xcodebuild -version | tee build/logs/xcode-version.txt
xcodebuild -workspace ios/Snoreman.xcworkspace -scheme Snoreman \
  -configuration Release -sdk iphoneos -destination 'generic/platform=iOS' \
  -derivedDataPath "$PWD/build/DerivedData" \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY= \
  DEVELOPMENT_TEAM= build 2>&1 | tee build/logs/xcodebuild.log
app="$PWD/build/DerivedData/Build/Products/Release-iphoneos/Snoreman.app"
if [[ ! -d "$app" ]]; then
  echo '::error::Expected Release device app was not found'
  find build/DerivedData/Build/Products -maxdepth 3 -name '*.app'
  exit 1
fi
# Preserve the native product before validation or IPA packaging.
ditto -c -k --keepParent "$app" build/Snoreman-app.zip
python3 - "$app" <<'PY' | tee build/logs/validation.json
import pathlib, plistlib, subprocess, json, sys
p=pathlib.Path(sys.argv[1]); info=plistlib.loads((p/'Info.plist').read_bytes())
assert (p/'main.jsbundle').stat().st_size>0, 'Missing embedded JavaScript'
assert info.get('NSMicrophoneUsageDescription'), 'Missing microphone permission text'
assert 'audio' in info.get('UIBackgroundModes',[]), 'Missing background audio mode'
assert info.get('CFBundleSupportedPlatforms')==['iPhoneOS'], 'Not an iPhoneOS app'
subprocess.run(['lipo','-verify_arch','arm64',str(p/info['CFBundleExecutable'])],check=True)
print(json.dumps({k:info.get(k) for k in ['CFBundleIdentifier','CFBundleShortVersionString','MinimumOSVersion','CFBundleSupportedPlatforms','UIBackgroundModes']},indent=2))
PY
rm -rf build/package
mkdir -p build/package/Payload
ditto "$app" build/package/Payload/Snoreman.app
cp LICENSE build/package/LICENSE.txt
rm -f build/Snoreman-unsigned.ipa
(cd build/package && /usr/bin/zip -qry ../Snoreman-unsigned.ipa Payload LICENSE.txt)
unzip -tq build/Snoreman-unsigned.ipa
(cd build && shasum -a 256 Snoreman-unsigned.ipa > Snoreman-unsigned.ipa.sha256)
echo 'Created build/Snoreman-unsigned.ipa. Sign and install using SideStore.'
