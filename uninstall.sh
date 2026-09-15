#!/usr/bin/env bash
# Reverts the DartNative IDE pub fix. Usage: ./uninstall.sh [/path/to/dartnative-sdk]
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PATCH="$HERE/dn-ide-pub-overrides.patch"
SDK="${1:-}"
if [ -z "$SDK" ]; then
  DN="$(command -v dn || true)"
  [ -n "$DN" ] || { echo "error: 'dn' not on PATH; pass the SDK folder." >&2; exit 1; }
  while [ -L "$DN" ]; do DN="$(readlink "$DN")"; done
  SDK="$(cd "$(dirname "$DN")/.." && pwd)"
fi
SDK="${SDK%/}"
if ! git -C "$SDK" apply --check --reverse "$PATCH" 2>/dev/null; then
  echo "error: the fix is not installed in $SDK (or the sources changed)." >&2
  exit 1
fi
git -C "$SDK" apply --reverse "$PATCH"
rm -f "$SDK/bin/cache/flutter_tools.snapshot" "$SDK/bin/cache/flutter_tools.stamp"
"$SDK/bin/dn" --version >/dev/null
echo "Reverted and rebuilt the dn tool. Delete pubspec_overrides.yaml from projects if you like."
