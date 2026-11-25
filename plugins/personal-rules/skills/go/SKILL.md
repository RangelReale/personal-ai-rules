---
name: go
description: Build and code rules for Go modules, commands and libraries. Use when working in a repository with go.mod, or when creating, building, testing or releasing Go code.
---

# Go rules

## Module

- The Go version lives in `go.mod` (`go` and, when needed, `toolchain`); CI reads it with
  `go-version-file`, so never hard-code a Go version in a workflow.
- Raise the Go version or dependencies in a change of their own, not as a side effect.
- Major versions 2+ change the module path (`/v2`).
- Commands go under `cmd/<name>/`; keep `main` thin and the logic in importable packages.
- Stamp the version into commands with `var version = "dev"` in `main`, set by
  `-ldflags "-X main.version=..."` (`go-release.yml` does this).

## Check a change

Run what CI runs (`go-ci.yml`); all must pass:

```sh
gofmt -l .          # must print nothing
go vet ./...
go test -race ./...
```

No extra linters: gofmt and vet are the standard.

## Code

- Wrap errors with context: `fmt.Errorf("open %s: %w", path, err)`.
- Bind local servers to `127.0.0.1`, not all interfaces, unless they must be reachable.

## Android and iOS apps around the Go code

Go is the main language; the apps are components in their own folders (`ports/android`,
`ports/ios`), listed under `components:` in `.github/personal-rules.yml`.

- Android runs the Go program as a native library: `GOOS=android GOARCH=arm64 CGO_ENABLED=0` into
  the app's `jniLibs/arm64-v8a/lib<name>.so` (see the `android` skill). iOS forbids running a
  separate program, so it links Go as a `c-archive` instead.
- Keep platform code out of the library: desktop or mobile wrappers live in their own folders or
  modules, and every port goes through one entry point so `main` packages stay thin.
- Cross-compile the phone builds to catch desktop-only assumptions:
  `GOOS=android GOARCH=arm64 CGO_ENABLED=0 go build ./cmd/<server>`.

## Releases

- The tag is the version; nothing in the tree is bumped. Libraries publish only the tag and the
  GitHub release (delete the build job in the release caller). Commands get archives for
  linux/darwin/windows built with `CGO_ENABLED=0 -trimpath`.
- After a library release, the module proxy picks the tag up on first request; nothing else to do.
