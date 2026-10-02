#!/usr/bin/env bash
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

# tracked + untracked-but-not-ignored; skip files deleted from disk but still in the index
files=()
while IFS= read -r -d '' f; do
  [[ -e $f ]] && files+=("$f")
done < <(git ls-files -z --cached --others --exclude-standard)

SKIP="${SKIP:-no-commit-to-branch}" pre-commit run --files "${files[@]}"
