- `custom: [ci, release]` in `.github/personal-rules.yml` marks workflows a repository writes
  itself: `check` audits what the rules rely on (the required check, path rules, tag and version
  checks, every component built) and never replaces them with a template. A workflow without the
  personal-rules header is never replaced either.
- `ci-check` in the record names the required check when it is not `CI result`; `establish`,
  `release` and merging use it.
- Components of `language: other` (a TV, console or other platform port) with a `build` command
  and one or more paths, new `ci-component-other.yml` and `release-component-other.yml` jobs, and a
  survey that finds Tizen, webOS and other platform ports.
