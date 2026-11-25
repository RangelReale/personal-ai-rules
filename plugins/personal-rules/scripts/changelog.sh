#!/usr/bin/env bash
# Changelog fragments (changelog.d/<name>.<type>.md) for Keep a Changelog.
#
#   changelog.sh check               validate fragment names and content
#   changelog.sh preview <version>   print the section a release would add
#   changelog.sh release <version>   add the section to CHANGELOG.md and delete the fragments
#
# Run from the repository root. Types, in section order: added, changed, deprecated, removed,
# fixed, security. A fragment holds one or more bullets ("- text"); a line without "- " starts a
# bullet of its own, and indented lines continue the previous bullet.
set -euo pipefail

dir=changelog.d
changelog=CHANGELOG.md
types=(added changed deprecated removed fixed security)
titles=(Added Changed Deprecated Removed Fixed Security)

fragments() {
  find "$dir" -maxdepth 1 -type f -name '*.md' ! -name README.md 2>/dev/null | LC_ALL=C sort
}

check() {
  local status=0 f name
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    name=${f##*/}
    if [[ ! "$name" =~ ^[A-Za-z0-9._-]+\.(added|changed|deprecated|removed|fixed|security)\.md$ ]]; then
      echo "$f: name it <name>.<added|changed|deprecated|removed|fixed|security>.md" >&2
      status=1
    elif [ -z "$(tr -d '[:space:]' < "$f")" ]; then
      echo "$f: empty fragment" >&2
      status=1
    fi
  done < <(fragments)
  return $status
}

# Prints the bullets of one fragment, each starting with "- ".
bullets() {
  awk '
    /^[[:space:]]*$/ { next }
    /^- / { print; next }
    /^[[:space:]]+/ { print; next }
    { print "- " $0 }
  ' "$1"
}

section() {
  local version=$1 date i f any
  date=$(date -u +%Y-%m-%d)
  echo "## [$version] - $date"
  for i in "${!types[@]}"; do
    any=""
    while IFS= read -r f; do
      [ -z "$f" ] && continue
      if [[ "$f" == *."${types[$i]}".md ]]; then
        if [ -z "$any" ]; then printf '\n### %s\n\n' "${titles[$i]}"; any=1; fi
        bullets "$f"
      fi
    done < <(fragments)
  done
}

release() {
  local version=$1 tmp
  [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?$ ]] || { echo "version must be X.Y.Z" >&2; exit 1; }
  check
  if [ -z "$(fragments)" ]; then echo "no fragments in $dir/" >&2; exit 1; fi
  if [ -f "$changelog" ] && grep -qF "## [$version]" "$changelog"; then
    echo "$changelog already has a section for $version" >&2; exit 1
  fi
  if [ ! -f "$changelog" ]; then
    printf '# Changelog\n\nAll notable changes to this project are documented here. The format follows\n[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow\n[Semantic Versioning](https://semver.org/).\n' > "$changelog"
  fi
  tmp=$(mktemp)
  section "$version" > "$tmp.section"
  # Insert before the first release section, or at the end.
  awk -v sec="$tmp.section" '
    !done && /^## \[/ && $0 !~ /^## \[Unreleased\]/ {
      while ((getline line < sec) > 0) print line
      print ""; done = 1
    }
    { print }
    END { if (!done) { print ""; while ((getline line < sec) > 0) print line } }
  ' "$changelog" > "$tmp"
  mv "$tmp" "$changelog"
  rm -f "$tmp.section"
  fragments | while IFS= read -r f; do rm -- "$f"; done
  echo "Added $version to $changelog and removed the fragments."
}

case "${1:-}" in
  check) check && echo "fragments OK" ;;
  preview) [ -n "${2:-}" ] || { echo "usage: $0 preview <version>" >&2; exit 2; }; section "$2" ;;
  release) [ -n "${2:-}" ] || { echo "usage: $0 release <version>" >&2; exit 2; }; release "$2" ;;
  *) echo "usage: $0 check | preview <version> | release <version>" >&2; exit 2 ;;
esac
