#!/bin/bash
# Builds libtagant_display.a (device arm64) into the Godot plugin folder. Runs on macOS (CI).
set -euo pipefail
cd "$(dirname "$0")"
OUT=../../godot/ios/plugins/tagant_display
SDK=$(xcrun --sdk iphoneos --show-sdk-path)
SDKVER=$(xcrun --sdk iphoneos --show-sdk-version)
TARGET=arm64-apple-ios17.0
FLAGS=()
if [ "${SDKVER%%.*}" -ge 27 ]; then FLAGS+=(-D TAGANT_SCENE_ACCESSORY); fi
echo "iOS SDK $SDKVER  flags: ${FLAGS[*]:-none}"

rm -rf build && mkdir build
xcrun --sdk iphoneos swiftc -parse-as-library -static -emit-library \
  -module-name TagantDisplay -target $TARGET -sdk "$SDK" -O ${FLAGS[@]+"${FLAGS[@]}"} \
  TagantDisplay.swift -o build/libswift_part.a
xcrun --sdk iphoneos clang++ -c shim.mm -target $TARGET -isysroot "$SDK" -fobjc-arc -O2 -o build/shim.o
xcrun libtool -static -o "$OUT/libtagant_display.a" build/libswift_part.a build/shim.o
ls -la "$OUT"
