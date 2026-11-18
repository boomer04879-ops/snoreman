#!/usr/bin/env bash
set -euo pipefail

source_ipa="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
output_dir="$(mkdir -p "$2" && cd "$2" && pwd)"
temp_dir="$(mktemp -d)"
trap 'rm -rf "$temp_dir"' EXIT

unzip -q "$source_ipa" 'Payload/*' -d "$temp_dir"
app="$temp_dir/Payload/Snoreman.app"

sign_bundle() {
  local bundle="$1"
  local executable
  executable="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$bundle/Info.plist")"
  chmod +x "$bundle/$executable"
  codesign --force --sign - --timestamp=none "$bundle"
}

for framework in "$app"/Frameworks/*.framework; do
  sign_bundle "$framework"
done
sign_bundle "$app"
codesign --verify --deep --strict --verbose=2 "$app"

ipa="$output_dir/Snoreman-SideStore-1.1.13-r2.ipa"
rm -f "$ipa"
(cd "$temp_dir" && zip -qry "$ipa" Payload)
unzip -tq "$ipa"
(cd "$output_dir" && shasum -a 256 "$(basename "$ipa")" > "$(basename "$ipa").sha256")
