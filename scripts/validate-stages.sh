#!/usr/bin/env bash
# Validate every stage root module independently. Used as a fan-out hook when
# shared code (_shared/ or modules/) changes.
set -euo pipefail

root="$(git rev-parse --show-toplevel)/terraform"
status=0

for dir in "$root"/[0-9][0-9]-*/; do
  name="${dir#"$root"/}"
  echo "==> validate ${name%/}"
  if ! terraform -chdir="$dir" init -backend=false -input=false -no-color >/dev/null; then
    status=1
    continue
  fi
  terraform -chdir="$dir" validate -no-color || status=1
done

exit "$status"
