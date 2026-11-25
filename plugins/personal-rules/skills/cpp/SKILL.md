---
name: cpp
description: Build and code rules for C++ desktop apps with Qt 6 and CMake (Windows, macOS, Linux; tray apps, packaging with cpack). Use when working in a repository with CMakeLists.txt or CMakePresets.json, or when creating, building, testing, packaging or releasing a C++/Qt project.
---

# C++ / Qt / CMake rules

## Toolchain

- C++20, the current Qt 6 release, CMake with `CMakePresets.json`.
- Qt is a prebuilt download: `scripts/setup.ps1` and `scripts/setup.sh` run
  `uvx --from aqtinstall aqt install-qt ...` into `$QT_ROOT` (a Qt folder shared between projects
  and worktrees) or else `.qt/` (gitignored). Pin the Qt version in both scripts and in
  `CMakePresets.json`, and change all three together. Configure with `--fresh` after changing
  `QT_ROOT`: CMake caches the Qt it found.
- Presets: `windows` (Visual Studio generator, local work), `windows-ninja` (Ninja Multi-Config
  with the MSVC in the environment; CI), `macos` (Ninja Multi-Config, universal binary), `linux`.
  A `ci` configuration treats warnings as errors.
- A `Taskfile.yml` wraps setup, build, test, run, package; keep it in step with `CLAUDE.md`.

## Layout

- Split the code into libraries (`<app>_core` without widgets, `<app>_ui`) so tests link them;
  `main.cpp` and `src/platform/` belong only to the executable.
- Platform code goes in `src/platform/`, one `<Thing>_<platform>.cpp` per platform. When a change
  touches a platform you did not build locally, say so.
- Draw the app icon in code and generate `.ico`/`.icns` from it with a CMake target; commit the
  generated files and regenerate them after changing the drawing.

## Check a change

```sh
cmake --preset <preset> && cmake --build --preset <preset> && ctest --preset <preset>
```

- Run tests only through `ctest`: it sets `QT_QPA_PLATFORM=offscreen`, `QT_PLUGIN_PATH` and `PATH`.
  Run directly, a GUI test shows a blocking "no Qt platform plugin" dialog.
- Qt Test logs TAP (`-o -,tap`): the plain logger prints nothing to a pipe on Windows.
- Other sessions may build at the same time: use `-j 4`, not all cores.
- A running app locks its executable (LNK1104 on Windows). Never kill an instance you did not
  start; point trial runs at a scratch data file through an environment variable.
- New JSON fields need defaults when reading, so old data keeps loading.

## Platform notes

- On macOS Qt's `Ctrl` is Command and `Meta` is Control.
- Tray apps on macOS: hiding the window makes the app an accessory (no Dock icon); showing it makes
  it regular again. Login items: `SMAppService` on macOS, the per-user Run key on Windows.
- Check Qt workarounds (tray icon, theme icons, modal dialog level) after every Qt upgrade.

## Packaging and releases

- `cmake --install` deploys the Qt runtime (absolute prefix). `cpack -C Release` makes the NSIS
  setup on Windows, the DragNDrop disk image on macOS, and a `.deb` on Linux.
- The install step re-signs the macOS bundle ad hoc after `macdeployqt` (Apple silicon refuses
  unsigned code); a Developer ID identity adds the hardened runtime and notarisation.
- The version is `project(VERSION)` in `CMakeLists.txt`, checked against the tag, or a cache
  variable the release sets from the tag (`version-define` in `cpp-release.yml`).
- Jobs holding signing secrets run in the protected `release` environment, with their actions
  pinned to commits.
