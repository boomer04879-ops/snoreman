#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
app="$1"
mkdir -p build/logs
python3 - "$app" <<'PY' | tee build/logs/validation.json
import pathlib, plistlib, subprocess, json, sys
p=pathlib.Path(sys.argv[1]); info=plistlib.loads((p/'Info.plist').read_bytes())
print('App metadata:', {k:info.get(k) for k in ['CFBundleExecutable','CFBundleSupportedPlatforms','UIBackgroundModes']},file=sys.stderr)
assert (p/'main.jsbundle').stat().st_size>0, 'Missing embedded JavaScript'
assert info.get('NSMicrophoneUsageDescription'), 'Missing microphone permission text'
assert 'audio' in info.get('UIBackgroundModes',[]), 'Missing background audio mode'
assert info.get('CFBundleSupportedPlatforms')==['iPhoneOS'], 'Not an iPhoneOS app'
subprocess.run(['lipo',str(p/info['CFBundleExecutable']),'-verify_arch','arm64'],check=True)
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
