# DartNative IDE pub fix

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

- `dn-ide-pub-overrides.patch` – the change to the SDK (one Dart file plus four
  project templates), applied with `git apply`. It also makes `dn pub get` point a
  project's `.idea` at this SDK when it names another one.
- `install.sh` / `install.ps1` – installer for macOS/Linux and Windows
- `uninstall.sh` – reverts it
