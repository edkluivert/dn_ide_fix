#!/usr/bin/env bash
# Installs the DartNative IDE / tool fixes into a DartNative SDK.
# Usage: ./install.sh [/path/to/dartnative-sdk]   (defaults to the SDK that owns `dn` on PATH)
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

SDK="${1:-}"
if [ -z "$SDK" ]; then
  DN="$(command -v dn || true)"
  if [ -z "$DN" ]; then
    echo "error: 'dn' is not on your PATH. Pass the SDK folder: ./install.sh /path/to/dartnative-sdk" >&2
    exit 1
  fi
  while [ -L "$DN" ]; do DN="$(readlink "$DN")"; done
  SDK="$(cd "$(dirname "$DN")/.." && pwd)"
fi
SDK="${SDK%/}"

PUB="$SDK/packages/flutter_tools/lib/src/dart/pub.dart"
if [ ! -f "$SDK/bin/dn" ] || [ ! -f "$PUB" ]; then
  echo "error: $SDK does not look like a DartNative SDK (no bin/dn or tool sources)." >&2
  exit 1
fi
if ! command -v git >/dev/null; then
  echo "error: git is required (the dn tool itself needs it too)." >&2
  exit 1
fi

echo "SDK: $SDK"
applied=0
# Each fix is one patch, applied in order and skipped when its marker is
# already in the tool sources. Fix 3 is made on top of Fix 2.
apply_fix() {
  local name="$1" patch="$HERE/$2" marker="$3"
  if grep -q "$marker" "$PUB"; then
    echo "$name: already installed."
    return 0
  fi
  if ! git -C "$SDK" apply --check "$patch" 2>/dev/null; then
    echo "error: $name does not apply to this SDK version:" >&2
    "$SDK/bin/dn" --version 2>/dev/null | head -1 >&2 || true
    echo "It was made for DartNative SDK 113c27aacb2 (2026-09-28)." >&2
    exit 1
  fi
  git -C "$SDK" apply "$patch"
  echo "$name: patched."
  applied=1
}
apply_fix "Fix 2 (DevTools)"          dn-ide-devtools.patch        _registerIdeDartSdk
apply_fix "Fix 3 (stock Flutter hand-off)" dn-stock-flutter-handoff.patch _dependsOnDartNative

if [ "$applied" = 0 ]; then
  echo "Nothing to do."
  exit 0
fi
echo "Rebuilding the dn tool (about 30 seconds)..."
rm -f "$SDK/bin/cache/flutter_tools.snapshot" "$SDK/bin/cache/flutter_tools.stamp"
"$SDK/bin/dn" --version >/dev/null
echo
echo "Done. 'dn create' now writes the IDE's Dart SDK files for plugins and FFI"
echo "packages, every 'dn pub get' / 'dn run' adds them to an existing project"
echo "that lacks them (then reopen it in Android Studio once), and the SDK's"
echo "'flutter' hands a project that does not depend on dartnative to stock"
echo "Flutter instead of editing its pubspec."
