"""Writes the caller workflow templates.

Usage: python3 -I scripts/gen-templates.py plugins/personal-rules/templates/workflows
Edit this script, not the generated files; CI fails when they differ.

Outputs:
  ci-<language>.yml, release-<language>.yml    whole workflows for the main language
  ci-component-<kind>.yml, release-component-<kind>.yml
                                               jobs to add for a component (an Android app or an
                                               iOS port inside a Rust or Go repository)
Placeholders: __RULES_REF__ (v<plugin version>); in component jobs __NAME__, __PATH__, __NATIVE__.
"""
import os
import sys

OUT = sys.argv[1]
REPO = "RangelReale/personal-ai-rules/.github/workflows"
REF = "__RULES_REF__"

LANGS = {
    "go": {"version_files": "", "ci_with": "", "release_build": f"""  build:
    needs: check
    uses: {REPO}/go-release.yml@{REF}
    with:
      version: ${{{{ needs.check.outputs.version }}}}
      # package: ./cmd/<name>      # the main package, if not the repository root
      # A library has no binaries: delete this job and `build` from publish's needs.
"""},
    "rust": {"version_files": "Cargo.toml", "ci_with": """    # with:
    #   os: '["ubuntu-26.04", "windows-2025", "macos-26"]'
    #   linux-packages: libasound2-dev
""", "release_build": f"""  build:
    needs: check
    uses: {REPO}/rust-release.yml@{REF}
    with:
      version: ${{{{ needs.check.outputs.version }}}}
      # bins: <binary names>       # defaults to the repository name
"""},
    "android": {"version_files": "", "ci_with": "", "release_build": f"""  build:
    needs: check
    uses: {REPO}/android-release.yml@{REF}
    with:
      version: ${{{{ needs.check.outputs.version }}}}
    secrets:
      keystore-base64: ${{{{ secrets.ANDROID_KEYSTORE_BASE64 }}}}
      keystore-password: ${{{{ secrets.ANDROID_KEYSTORE_PASSWORD }}}}
      key-alias: ${{{{ secrets.ANDROID_KEY_ALIAS }}}}
      key-password: ${{{{ secrets.ANDROID_KEY_PASSWORD }}}}
"""},
    "cpp": {"version_files": "CMakeLists.txt", "ci_with": """    # with:
    #   matrix: '[{"os": "windows-2025", "preset": "windows-ninja", "setup": "pwsh -File scripts/setup.ps1"}]'
""", "release_build": f"""  build:
    needs: check
    uses: {REPO}/cpp-release.yml@{REF}
    with:
      version: ${{{{ needs.check.outputs.version }}}}
"""},
    "generic": {"version_files": "", "ci_with": None, "release_build": """  # Build the release files here and upload them as artifacts named release-*;
  # publish attaches them. Without files, delete this job and `build` from publish's needs.
  build:
    needs: check
    runs-on: ubuntu-26.04
    steps:
      - uses: actions/checkout@v7
      - run: echo "Build version ${{ needs.check.outputs.version }} into dist/" && mkdir -p dist
      # - uses: actions/upload-artifact@v7
      #   with:
      #     name: release-files
      #     path: dist/*
"""},
}

HEADER = """# Managed by personal-rules ({ref}); /personal-rules:check compares it with the template.
"""

COMPONENT_IF = ("needs.changes.outputs.main == 'true' || "
                "contains(fromJSON(needs.changes.outputs.components), '__NAME__')")

# Jobs added to ci.yml for a component; add the job name to ci-result's needs and the component to
# the `components` input of `changes`.
CI_COMPONENTS = {
    "android": f"""  # Android component __NAME__ in __PATH__: runs when its folder or the main code changed.
  __NAME__:
    needs: changes
    if: {COMPONENT_IF}
    uses: {REPO}/android-ci.yml@{REF}
    with:
      working-directory: __PATH__
      native: __NATIVE__
      # pre-build: >-
      #   cargo ndk -t arm64-v8a -t x86_64 -P 26 -o __PATH__/app/src/main/jniLibs
      #   build -p <ffi crate> --lib --release
""",
    "ios": f"""  # iOS component __NAME__ in __PATH__: an unsigned simulator build with the component's own script.
  __NAME__:
    needs: changes
    if: {COMPONENT_IF}
    runs-on: macos-26
    timeout-minutes: 60
    steps:
      - uses: actions/checkout@v7
      # Set up the main language first, for example:
      # - uses: actions/setup-go@v7
      #   with:
      #     go-version-file: go.mod
      - name: Build
        run: ./__PATH__/build.sh
""",
}

# Jobs added to release.yml for a component; add the job name to publish's needs.
RELEASE_COMPONENTS = {
    "android": f"""  __NAME__:
    needs: check
    uses: {REPO}/android-release.yml@{REF}
    with:
      version: ${{{{ needs.check.outputs.version }}}}
      name: __NAME__
      working-directory: __PATH__
      native: __NATIVE__
      # pre-build: >-
      #   cargo ndk -t arm64-v8a -t x86_64 -P 26 -o __PATH__/app/src/main/jniLibs
      #   build -p <ffi crate> --lib --release
    secrets:
      keystore-base64: ${{{{ secrets.ANDROID_KEYSTORE_BASE64 }}}}
      keystore-password: ${{{{ secrets.ANDROID_KEYSTORE_PASSWORD }}}}
      key-alias: ${{{{ secrets.ANDROID_KEY_ALIAS }}}}
      key-password: ${{{{ secrets.ANDROID_KEY_PASSWORD }}}}
""",
    "ios": """  # iOS component __NAME__: signing needs an Apple certificate, so the default is an unsigned
  # build that checks the release still compiles. Upload a release-* artifact to attach a file.
  __NAME__:
    needs: check
    runs-on: macos-26
    timeout-minutes: 60
    steps:
      - uses: actions/checkout@v7
      - name: Build
        env:
          VERSION: ${{ needs.check.outputs.version }}
        run: ./__PATH__/build.sh
""",
}


def ci(lang, cfg):
    vf = cfg["version_files"]
    components = ("      # Components (see ci-component-*.yml), one per line: <name>: <folder>\n"
                  "      # components: |\n"
                  "      #   android: apps/android\n")
    if vf:
        changes_with = f"    with:\n      version-files: {vf}\n" + components
    else:
        changes_with = "    # with:\n" + components
    if cfg["ci_with"] is None:
        build = """  # The project's own checks; they run only when the main code changed.
  build:
    needs: changes
    if: needs.changes.outputs.main == 'true'
    runs-on: ubuntu-26.04
    steps:
      - uses: actions/checkout@v7
      - run: echo "Replace with the project's build and tests"
"""
    else:
        build = f"""  build:
    needs: changes
    if: needs.changes.outputs.main == 'true'
    uses: {REPO}/{lang}-ci.yml@{REF}
{cfg['ci_with']}"""
    return HEADER.format(ref=REF) + f"""name: CI

# Pull request runs are titled "PR #<number>: <title>"; an empty run-name keeps GitHub's default.
run-name: >-
  ${{{{ github.event_name == 'pull_request'
  && format('PR #{{0}}: {{1}}', github.event.pull_request.number, github.event.pull_request.title)
  || '' }}}}

on:
  push:
    branches: [master]
  # labeled/unlabeled: adding the no-changelog label re-runs the changelog check.
  pull_request:
    types: [opened, synchronize, reopened, labeled, unlabeled]
  workflow_dispatch:

permissions:
  contents: read

# A new push to a pull request cancels its older run; runs on master all finish.
concurrency:
  group: ci-${{{{ github.event.pull_request.number || github.ref }}}}
  cancel-in-progress: ${{{{ github.event_name == 'pull_request' }}}}

jobs:
  # docs, version or code, and which parts changed: docs-only and version-only changes skip builds.
  changes:
    uses: {REPO}/changes.yml@{REF}
{changes_with}
{build}
  # Fragments in changelog.d/; passes when the repository keeps none.
  changelog:
    needs: changes
    if: github.event_name == 'pull_request'
    uses: {REPO}/changelog-check.yml@{REF}
    with:
      kind: ${{{{ needs.changes.outputs.kind }}}}

  # The only check branch protection requires. Skipped jobs pass, so jobs can be added without
  # touching the protection: list every other job in needs.
  ci-result:
    name: CI result
    needs: [changes, build, changelog]
    if: always()
    runs-on: ubuntu-26.04
    timeout-minutes: 5
    steps:
      - env:
          RESULTS: ${{{{ join(needs.*.result, ' ') }}}}
        run: |
          echo "Results: $RESULTS"
          for result in $RESULTS; do
            case "$result" in success | skipped) ;; *) exit 1 ;; esac
          done
"""


def release(lang, cfg):
    vf = cfg["version_files"]
    check_with = "    with:\n      version-files: " + vf + "\n" if vf else ""
    return HEADER.format(ref=REF) + f"""name: Release

# Pushing a tag vX.Y.Z (or vX.Y.Z-rc.N, a prerelease) checks it, builds the release files and
# publishes the GitHub release. To redo a failed run, re-run its failed jobs.
run-name: Release ${{{{ github.ref_name }}}}

on:
  push:
    tags: ['v[0-9]*.[0-9]*.[0-9]*']

permissions:
  contents: read

concurrency:
  group: release-${{{{ github.ref_name }}}}
  cancel-in-progress: false

jobs:
  check:
    uses: {REPO}/release-check.yml@{REF}
{check_with}
{cfg['release_build']}
  # Component release jobs (see release-component-*.yml) go here; add each to publish's needs.

  publish:
    needs: [check, build]
    permissions:
      contents: write
    uses: {REPO}/release-publish.yml@{REF}
    with:
      tag: ${{{{ needs.check.outputs.tag }}}}
      version: ${{{{ needs.check.outputs.version }}}}
      prerelease: ${{{{ needs.check.outputs.prerelease }}}}
"""


def write(name, text):
    with open(os.path.join(OUT, name), "w", newline="\n") as f:
        f.write(text.replace("\n\n\n", "\n\n"))


os.makedirs(OUT, exist_ok=True)
for lang, cfg in LANGS.items():
    write(f"ci-{lang}.yml", ci(lang, cfg))
    write(f"release-{lang}.yml", release(lang, cfg))
for kind, text in CI_COMPONENTS.items():
    write(f"ci-component-{kind}.yml", "# Jobs to add to ci.yml for a component; see the header of ci-<language>.yml.\n" + text)
for kind, text in RELEASE_COMPONENTS.items():
    write(f"release-component-{kind}.yml", "# Jobs to add to release.yml for a component.\n" + text)
print("written")
