#!/bin/bash
set -euo pipefail

# Run on macOS with Xcode installed. This creates an unsigned IPA shell
# that must be re-signed in ESign with a certificate/profile you are
# authorized to use. It does not add the missing game runtime.
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT="$ROOT/NarutoConnections.xcodeproj"
DERIVED="$ROOT/build/DerivedData"
APP="$DERIVED/Build/Products/Release-iphoneos/NarutoConnections.app"
OUT="$ROOT/build/unsigned"

xcodebuild -project "$PROJECT" \
  -scheme NarutoConnections \
  -configuration Release \
  -sdk iphoneos \
  -derivedDataPath "$DERIVED" \
  CODE_SIGNING_ALLOWED=NO \
  build

if [[ ! -d "$APP" ]]; then
  echo "Build succeeded but app bundle was not found: $APP" >&2
  exit 1
fi

rm -rf "$OUT"
mkdir -p "$OUT/Payload"
cp -R "$APP" "$OUT/Payload/"
(
  cd "$OUT"
  /usr/bin/zip -qry "$ROOT/build/NarutoConnections-unsigned.ipa" Payload
)
echo "Created: $ROOT/build/NarutoConnections-unsigned.ipa"
echo "Import into ESign and sign only with a certificate/profile you are authorized to use."
