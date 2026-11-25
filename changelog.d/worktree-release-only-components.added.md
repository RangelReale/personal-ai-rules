- `release-only: true` on a component in `.github/personal-rules.yml` says only the release builds
  it: `check` reports it as a note instead of asking for a CI job, while still expecting its paths
  to skip the main build and the release to build it.
