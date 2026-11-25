"""Writes the caller workflow templates.

Usage: python3 -I scripts/gen-templates.py plugins/personal-rules/templates/workflows
Edit this script, not the generated files; CI fails when they differ.
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


def ci(lang, cfg):
    vf = cfg["version_files"]
    changes_with = f"    with:\n      version-files: {vf}\n" if vf else ""
    if cfg["ci_with"] is None:
        build = """  # The project's own checks; they run only when code changed.
  build:
    needs: changes
    if: needs.changes.outputs.code == 'true'
    runs-on: ubuntu-26.04
    steps:
      - uses: actions/checkout@v7
      - run: echo "Replace with the project's build and tests"
"""
    else:
        build = f"""  build:
    needs: changes
    if: needs.changes.outputs.code == 'true'
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
  pull_request:
  workflow_dispatch:

permissions:
  contents: read

# A new push to a pull request cancels its older run; runs on master all finish.
concurrency:
  group: ci-${{{{ github.event.pull_request.number || github.ref }}}}
  cancel-in-progress: ${{{{ github.event_name == 'pull_request' }}}}

jobs:
  # docs, version or code: docs-only and version-only changes skip the build.
  changes:
    uses: {REPO}/changes.yml@{REF}
{changes_with}
{build}
  # >>> changelog (feature: changelog)
  changelog:
    needs: changes
    if: github.event_name == 'pull_request'
    uses: {REPO}/changelog-check.yml@{REF}
    with:
      kind: ${{{{ needs.changes.outputs.kind }}}}
  # <<< changelog

  # The only check branch protection requires. Skipped jobs pass, so the jobs above can change
  # without touching the protection.
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


os.makedirs(OUT, exist_ok=True)
for lang, cfg in LANGS.items():
    for kind, fn in (("ci", ci), ("release", release)):
        with open(os.path.join(OUT, f"{kind}-{lang}.yml"), "w", newline="\n") as f:
            f.write(fn(lang, cfg).replace("\n\n\n", "\n\n"))
print("written")
