---
name: android
description: Build and code rules for Android apps in Kotlin with Jetpack Compose and Gradle. Use when working in a repository with a Gradle Android project (build.gradle.kts with com.android.application, AndroidManifest.xml, gradlew), or when creating, building, testing, signing or releasing an Android app.
---

# Android (Kotlin) rules

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
- Keep logic that needs no Android framework (data, rules, formatting) in plain Kotlin classes, so
  JVM unit tests cover it without an emulator.
- Tests: JUnit 4 for unit tests; Robolectric and Compose ui-test for UI logic that needs them.

## Check a change

- `./gradlew testDebugUnitTest lintDebug assembleDebug`: the same command CI runs; it must pass.
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
  builds then fall back to the debug key; CI never publishes an unsigned or debug-signed APK.
- Repository secrets: `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`,
  `ANDROID_KEY_PASSWORD`. Never commit a release keystore or its passwords.
- Release asset: `<repository>-v<version>.apk`.

## Windows

- The local shell may be PowerShell 5.1: no `&&`; strip a UTF-8 BOM from files read as passwords;
  in Git Bash set `MSYS_NO_PATHCONV=1` for `adb shell` paths.
