---
name: android
description: Build and code rules for Android apps in Kotlin with Jetpack Compose and Gradle - both standalone apps and Android apps that are one part of a Rust or Go repository (an app in apps/*-android, ports/android or android/ that bundles a native library built with cargo-ndk or GOOS=android). Use when working on any Gradle Android project (build.gradle.kts with com.android.application, AndroidManifest.xml, gradlew), at the root or in a sub-folder, or when building, testing, signing or releasing an Android app.
---

# Android (Kotlin) rules

An Android app is either the whole repository (standalone) or a **component** of a repository whose
main language is Rust or Go: the app lives in a folder of its own and bundles a native library
built from the main code. `.github/personal-rules.yml` says which (`language: android`, or an entry
under `components:` with its `path` and `native`). The rules below apply to both; the component
section adds to them.

## Project shape

- One `app` module unless there is a reason for more. Kotlin, Jetpack Compose with the Compose BOM,
  Material 3.
- AGP 9 with its built-in Kotlin and new DSL: no `android.builtInKotlin=false` or
  `android.newDsl=false` opt-outs. Use `kotlin { compilerOptions { jvmTarget = JVM_17 } }`, never
  `kotlinOptions`. Java source/target 17; build with JDK 21 (CI uses Temurin 21).
- All versions in `gradle/libs.versions.toml` with plugin aliases. Versions are pinned on purpose:
  do not raise them as a side effect of other work.
- Commit `gradlew` executable (`git update-index --chmod=+x gradlew`) and keep the `gradlew` LF /
  `*.bat` CRLF rules in `.gitattributes`.
- `.gitignore`: `.gradle/ build/ local.properties .idea/ *.iml .kotlin/ captures/`.

## Code

- User-visible text lives in `res/values/strings.xml`; keep every translation (`values-pt-rBR`,
  …) in step in the same change.
- Keep logic that needs no Android framework in plain Kotlin classes, so JVM unit tests cover it
  without an emulator.
- Tests: JUnit 4 for unit tests; Robolectric and Compose ui-test for UI logic that needs them.

## Android as a component (Rust or Go main language)

- Run Gradle from the component folder (`cd apps/android && ./gradlew ...`); the repository root is
  the main language's.
- The native library is built **before** Gradle, into `app/src/main/jniLibs/<abi>/`, which is
  generated and gitignored. Never commit `.so` files.
  - Rust: `cargo ndk -t arm64-v8a -t x86_64 -P 26 -o <app>/app/src/main/jniLibs build -p <ffi crate> --lib --release`
    (arm64 phones, x86_64 emulator), with the NDK version pinned where local builds and CI share it.
    Generated Kotlin bindings (uniffi) are generated output too.
  - Go: `GOOS=android GOARCH=arm64 CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o <app>/app/src/main/jniLibs/arm64-v8a/lib<name>.so ./cmd/<server>`
    (arm64 only: the one Android target Go links without cgo). For a Go server shown in a WebView,
    see the `go-server-android-app` skill if it is installed.
- One command builds both: a Taskfile task (`task android`, with `android:libs` as its dependency)
  or a `build.sh` in the component. CI's `pre-build` runs the same native build.
- A change to the main code can break the app: when the FFI surface or the server's interface
  changes, build the APK too.
- The app's version is the repository's tag (`-PappVersion`), like the main code's; it never has a
  version of its own.

## Check a change

- `./gradlew testDebugUnitTest lintDebug assembleDebug` (after the native build for a component):
  the same command CI runs; it must pass.
- Lint: `warningsAsErrors = true`. Disable only the checks that fight pinned versions
  (`OldTargetApi`, `GradleDependency`, `AndroidGradlePluginVersion`, `NewerVersionAvailable`).
- For UI changes, install on an emulator or device (`adb install -r`) and look at the screens;
  say so when you could not.

## Version and signing

- The version comes from the release tag, never from source: CI passes `-PappVersion=X.Y.Z`
  (`android-release.yml`). Do not hand-edit `versionName`/`versionCode`.
  ```kotlin
  val appVersion = (findProperty("appVersion") as String?) ?: "0.0.0"
  val (major, minor, patch) = appVersion.substringBefore('-').split('.').map { it.toInt() }
  versionName = appVersion
  versionCode = major * 10_000 + minor * 100 + patch
  ```
- Release signing is optional in Gradle: create the config only when `SIGNING_STORE_FILE` is set
  (with `SIGNING_STORE_PASSWORD`, `SIGNING_KEY_ALIAS`, `SIGNING_KEY_PASSWORD`). Local release
  builds then fall back to the debug key; CI refuses to publish a debug-signed APK.
- Repository secrets: `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`,
  `ANDROID_KEY_PASSWORD`. Never commit a release keystore or its passwords.
- Release asset: `<repository>-v<version>.apk`; a component adds its name
  (`<repository>-<name>-v<version>.apk`).

## Windows

- The local shell may be PowerShell 5.1: no `&&`; strip a UTF-8 BOM from files read as passwords;
  in Git Bash set `MSYS_NO_PATHCONV=1` for `adb shell` paths.
