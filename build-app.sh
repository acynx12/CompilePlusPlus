#!/bin/zsh
set -euo pipefail

PROJECT_DIR="${0:A:h}"
BUILD_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/CompilePlusPlus-build.XXXXXX")"
BUILD_CACHE="$PROJECT_DIR/.build-cache"
APP_DIR="$PROJECT_DIR/dist/Compile++.app"
CONTENTS_DIR="$APP_DIR/Contents"
MODULE_CACHE="$BUILD_CACHE/module-cache"
PACKAGE_CACHE="$BUILD_CACHE/swiftpm-cache"

mkdir -p "$MODULE_CACHE" "$PACKAGE_CACHE"
export CLANG_MODULE_CACHE_PATH="$MODULE_CACHE"
export SWIFTPM_MODULECACHE_OVERRIDE="$MODULE_CACHE"

if ! swift build \
  --package-path "$PROJECT_DIR" \
  --scratch-path "$BUILD_ROOT" \
  --cache-path "$PACKAGE_CACHE" \
  --disable-sandbox \
  -Xswiftc -gnone \
  -c release; then
  # Some restricted build environments deny SwiftPM's final dSYM generation
  # even though compilation and linking completed. A new scratch directory
  # cannot contain a stale executable, so it is safe to package that result.
  if [[ ! -x "$BUILD_ROOT/release/CompilePlusPlus" ]]; then
    exit 1
  fi
  echo "Warning: debug-symbol generation was skipped; the app binary is complete."
fi

rm -rf "$APP_DIR"
mkdir -p "$CONTENTS_DIR/MacOS" "$CONTENTS_DIR/Resources"
cp "$BUILD_ROOT/release/CompilePlusPlus" "$CONTENTS_DIR/MacOS/CompilePlusPlus"
cp "$PROJECT_DIR/Resources/Info.plist" "$CONTENTS_DIR/Info.plist"

if [[ -f "$PROJECT_DIR/Resources/AppIcon.icns" ]]; then
  cp "$PROJECT_DIR/Resources/AppIcon.icns" "$CONTENTS_DIR/Resources/AppIcon.icns"
fi

codesign --force --deep --sign - "$APP_DIR"
echo "$APP_DIR"
