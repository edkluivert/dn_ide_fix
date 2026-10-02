#!/usr/bin/env bash
# Reverts the DartNative IDE / tool fixes. Usage: ./uninstall.sh [/path/to/dartnative-sdk]
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SDK="${1:-}"
if [ -z "$SDK" ]; then
  DN="$(command -v dn || true)"
  [ -n "$DN" ] || { echo "error: 'dn' not on PATH; pass the SDK folder." >&2; exit 1; }
  while [ -L "$DN" ]; do DN="$(readlink "$DN")"; done
  SDK="$(cd "$(dirname "$DN")/.." && pwd)"
fi
SDK="${SDK%/}"
reverted=0
# Reverse order of install.sh: Fix 3 sits on top of Fix 2.
for patch in dn-stock-flutter-handoff.patch dn-ide-devtools.patch; do
  if git -C "$SDK" apply --check --reverse "$HERE/$patch" 2>/dev/null; then
    git -C "$SDK" apply --reverse "$HERE/$patch"
    echo "$patch: reverted."
    reverted=1
  else
    echo "$patch: not installed in $SDK (or the sources changed), skipped."
  fi
done
[ "$reverted" = 1 ] || exit 1
rm -f "$SDK/bin/cache/flutter_tools.snapshot" "$SDK/bin/cache/flutter_tools.stamp"
"$SDK/bin/dn" --version >/dev/null
echo "Rebuilt the dn tool."
