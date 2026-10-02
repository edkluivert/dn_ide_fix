# DartNative IDE fixes

Three fixes for the `dn` tool, applied as patches to your DartNative SDK (`./install.sh`
applies the current ones in order; Fix 1 is obsolete).

## Fix 3 (2026-10-02, SDK 113c27a): a plain Flutter project must not run the DartNative tool

**Symptom.** The DartNative SDK's `bin` folder is on PATH (the editor's SDK discovery wants a
`flutter` there), so on a machine that also has stock Flutter, `flutter build` in a plain Flutter
app silently runs DartNative's tool. Before this fix the launcher only printed a warning and
carried on, and the tool's pub step then edited the app's committed files before pub failed:

```
dartnative: removed incompatible pubspec entry "flutter_test" (not supported by DartNative — …)
Because … depends on flutter_localizations from sdk which doesn't exist … version solving failed.
```

`flutter_test: sdk: flutter` was deleted from `pubspec.yaml`, `.dart_tool/flutter_build` was wiped and
a `dn_closed_sdk.stamp` left behind (custovia, 2026-10-02).

**What the patch does.**

1. `bin/flutter` (and `bin/dn`, the same file; `bin/flutter.bat` on Windows): when invoked as
   `flutter` in a project whose pubspec names no `dartnative` / `dartnative_*` dependency, it
   hands the whole command to stock Flutter: `$DN_STOCK_FLUTTER` (a `flutter` launcher or a
   Flutter root) first, then every other `flutter` on PATH that is a real Flutter checkout, then
   the usual install folders (`~/Development/flutter`, `~/flutter`, `~/fvm/default`, snap, `/opt`,
   Homebrew). One stderr line says which one ran. With no stock Flutter found it warns and carries
   on as before. Invoked as `dn`, nothing changes.
2. `pub.dart`: a `_dependsOnDartNative(pubspec)` gate in front of the DartNative-only project
   mutations, so even a direct `dn build` on a plain Flutter project rewrites nothing: the
   `flutter_test` / `flutter_web_plugins` strip, the `.idea` Dart SDK registration (Fix 2), and
   the closed-SDK stamp that clears `.dart_tool/flutter_build`. Pub then fails with its ordinary
   message and the project is untouched.

**Verify.** In a stock Flutter project with the DartNative `bin` first on PATH, `flutter --version`
prints one `dn: … running stock Flutter at …` line on stderr and the stock version on stdout;
`git status` shows no change to `pubspec.yaml`. In a DartNative project `dn pub get` behaves as
before.

---

## Fix 2 (2026-09-30, SDK 113c27a): DevTools in Android Studio / IntelliJ

**Symptom.** Opening DevTools (or the Flutter Inspector / Performance tabs) on a DartNative
project fails after 15 seconds with:

```
DevTools server start-up failure.
java.lang.Exception: Timed out waiting for Dart plugin to start DevTools.
```

**Cause.** The JetBrains Dart plugin starts the Dart Tooling Daemon and DevTools exactly once,
in its project start-up activity, and only when a module of the project already carries the
"Dart SDK" library at that moment. Nothing starts them later; changing the SDK afterwards only
re-roots the analysis server. The Flutter plugin does not start DevTools itself any more: it waits
for the Dart plugin's instance and gives up. So any project that was opened *before* its Dart SDK
was configured has no DevTools for the whole session. That is the normal case for DartNative
plugins and FFI packages: `dn create -t plugin|plugin_ffi|package_ffi` shipped no `.idea/`, and a
folder first opened from the IDE gets an `.idea/` without an SDK. (App and package templates ship
`.idea/libraries/Dart_SDK.xml`, which is why apps were fine.)

**What the patch does.**

1. `dn create -t plugin|plugin_ffi|package_ffi` now writes `.idea/modules.xml`,
   `.idea/libraries/Dart_SDK.xml` and (for `package_ffi`) the module file, like the app and
   package templates.
2. `dn pub get`, `dn pub upgrade` and `dn run` check an existing `.idea/`: a missing
   `.idea/libraries/Dart_SDK.xml` is written, and a Dart module (`<name>.iml` beside the pubspec or
   in `.idea/`) missing the `Dart SDK` order entry gets it. Files that exist are never rewritten.
   Android modules are left alone. When something was added the tool says so and asks for one
   reopen of the project, since only a fresh open starts DevTools.

**Verify.** After installing, in the affected project: `dn pub get`, then File → Close Project and
open it again. Android Studio's log (Help → Show Log) should show
`DartToolingDaemonService - Starting Dart Tooling Daemon` and
`DartDevToolsService - Starting Dart DevTools` right after the LSP server starts, and the DevTools
button works.

Install: `./install.sh` (finds the SDK that owns `dn` on PATH; or pass the SDK folder). Re-run
after every SDK update, because the installer script replaces the SDK folder and drops the patch.

---

## Fix 1 (2026-09-15, SDK 80edbf105e, OBSOLETE since SDK 113c27a): pubspec_overrides for IDE pub get

Kept as `dn-ide-pub-overrides.patch` for reference. SDK 113c27a resolves the closed DartNative
packages by itself, so this patch is no longer needed and no longer applies.

### Original notes

Makes DartNative projects resolve dependencies from **Android Studio, IntelliJ, VS Code
or CI** with a plain `dart pub get`, so the green **Run** button just works.

## The problem it fixes

Pressing Run (or "Get dependencies") in Android Studio on a DartNative project fails with:

```
Because my_app depends on dartnative_skia any which doesn't exist
(could not find package dartnative_skia at https://pub.dev), version solving failed.
```

The DartNative packages (`dartnative`, `dartnative_ios`, `dartnative_android`,
`dartnative_skia`, ...) ship inside the SDK, not on pub.dev. Only the `dn` tool knows
how to resolve them. IDEs call the plain Dart `pub` directly, which does not.

## What the fix does

It patches the `dn` tool inside your DartNative SDK so that every `dn pub get` or
`dn run`:

1. copies the Dart side of the DartNative packages your app uses into
   `.dart_tool/dartnative_sdk/` (a few MB: Dart sources only, no natives or assets, and no plugin section, so no tool mistakes them for plugins), and
2. writes a `pubspec_overrides.yaml` next to your `pubspec.yaml` that points each
   package at its copy.

Pub reads `pubspec_overrides.yaml` automatically, so any pub get from any tool now
succeeds. Before every build, `dn` still points the packages back at the real SDK,
so nothing about how your app compiles changes.

Two safety nets added 2026-09-24, after a project opened in Android Studio was built
with the machine's *stock* Flutter SDK (the IDE fell back to its last known Flutter
SDK because the project had no `.idea/libraries/Dart_SDK.xml`): the app ran, but
every `MaterialSymbolsRounded` / `CupertinoIcons` glyph was a question-mark box,
because the header copies carried no fonts.

3. The copies now keep each package's `flutter: fonts:` entries and the font files
   they name (about 2 MB for `dartnative`), so even a stock-Flutter build on the
   copies bundles the icon fonts.
4. `dn pub get` / `dn run` create `.idea/libraries/Dart_SDK.xml` when the IDE has
   already created `.idea/` without one, so the IDE picks this SDK rather than
   whatever Flutter it used last. A project with no `.idea/` at all is left alone.

New projects from `dn create` gitignore `pubspec_overrides.yaml`. Your `pubspec.yaml`
is never modified.

## Requirements

- DartNative SDK **3.45.0-0.1.pre** (framework revision `80edbf105e`). Check with `dn --version`.
- `git` on your PATH (the `dn` tool already needs it).

## Install

macOS / Linux:

```bash
cd dn_ide_fix
./install.sh
```

Windows (PowerShell):

```powershell
cd dn_ide_fix
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

The installer finds the SDK that owns `dn` on your PATH. If `dn` is not on PATH, pass
the SDK folder, for example `./install.sh ~/zero` or `.\install.ps1 C:\dartnative`.

It applies the patch, rebuilds the `dn` tool (about 30 seconds) and exits. Running it
again is safe; it reports "Already installed".

## After installing

- **New project:** `dn create my_app`, open it in Android Studio, press Run. Done.
- **Existing project:** run `dn pub get` once in the project folder. From then on the
  IDE handles everything.
- **Fresh clone of a project:** run `dn pub get` once, because the package copies live
  in `.dart_tool`, which git ignores.

No SDK path to set in Android Studio: `dn create` writes the project's `.idea` config
pointing at the DartNative SDK, and for a project created elsewhere (a Flutter-created
package, a copy from another machine) the first `dn pub get` rewrites the stale
`.idea/libraries/Dart_SDK.xml` to this SDK. Only a project with no `.idea` folder at
all is left to the IDE's own SDK detection.

## Verify

In any DartNative project, after `dn pub get`, this must succeed without the `dn` tool:

```bash
<sdk>/bin/cache/dart-sdk/bin/dart pub get
```

and the project folder must contain `pubspec_overrides.yaml`.

## Good to know

- `pubspec.lock` will list the DartNative packages as relative `path` entries under
  `.dart_tool/dartnative_sdk/`. That is portable across machines.
- `pubspec_overrides.yaml` has three sections. Entries you add under "your overrides"
  are kept. Entries under "managed by dn" are rewritten on every resolve.
- If you upgrade or reinstall the SDK, the patch is gone. Run the installer again.

## Uninstall

```bash
./uninstall.sh
```

This reverts the patch and rebuilds the tool. Delete `pubspec_overrides.yaml` from
your projects afterwards if you want them exactly as before.

## Files

- `dn-ide-devtools.patch` – Fix 2: one Dart file plus the plugin / FFI project templates,
  applied with `git apply`.
- `dn-stock-flutter-handoff.patch` – Fix 3, made on top of Fix 2: `bin/flutter`, `bin/dn`,
  `bin/flutter.bat` and the `_dependsOnDartNative` gate in the same Dart file.
- `dn-ide-pub-overrides.patch` – Fix 1, obsolete; kept for SDK 80edbf105e only.
- `install.sh` / `install.ps1` – installer for macOS/Linux and Windows (applies Fix 2 then Fix 3,
  skipping what is already installed, and rebuilds the tool)
- `uninstall.sh` – reverts them in reverse order
