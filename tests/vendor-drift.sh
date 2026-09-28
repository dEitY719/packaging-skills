#!/usr/bin/env bash
# tests/vendor-drift.sh — fail when a vendored copy under
# skills/*/lib/vendor/ drifts from its original sibling-skill script.
# structure-refactor vendors these so a single-skill install (Hermes tap,
# `npx skills add`) still runs (packaging-skills#29). Fix a failure by
# re-copying the original over the vendored file.
set -u
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1

fail=0
while read -r copy orig; do
    if ! cmp -s "$orig" "$copy"; then
        echo "FAIL: $copy differs from $orig — run: cp $orig $copy"
        fail=1
    fi
done <<'PAIRS'
skills/structure-refactor/lib/vendor/structure_check.sh skills/structure-check/lib/structure_check.sh
skills/structure-refactor/lib/vendor/parse_remote.sh skills/rename-repo/lib/parse_remote.sh
PAIRS

[ "$fail" -eq 0 ] && echo "PASS: vendored scripts match their originals"
exit "$fail"
