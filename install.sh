#!/usr/bin/env bash
# Installs the DartNative IDE pub fix into a DartNative SDK.
# Usage: ./install.sh [/path/to/dartnative-sdk]   (defaults to the SDK that owns `dn` on PATH)
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PATCH="$HERE/dn-ide-pub-overrides.patch"

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
if grep -q '_writePubspecOverridesFile' "$PUB"; then
  echo "Already installed. Nothing to do."
  exit 0
fi
if ! git -C "$SDK" apply --check "$PATCH" 2>/dev/null; then
  echo "error: the patch does not apply to this SDK version:" >&2
  "$SDK/bin/dn" --version 2>/dev/null | head -1 >&2 || true
  echo "It was made for DartNative 3.45.0-0.1.pre (framework 80edbf105e)." >&2
  exit 1
fi

git -C "$SDK" apply "$PATCH"
echo "Patched. Rebuilding the dn tool (about 30 seconds)..."
rm -f "$SDK/bin/cache/flutter_tools.snapshot" "$SDK/bin/cache/flutter_tools.stamp"
"$SDK/bin/dn" --version >/dev/null
echo
echo "Done. Every 'dn pub get' or 'dn run' now writes pubspec_overrides.yaml so"
echo "Android Studio / VS Code / CI pub get resolves the DartNative packages."
echo "In an existing project, run 'dn pub get' once."
