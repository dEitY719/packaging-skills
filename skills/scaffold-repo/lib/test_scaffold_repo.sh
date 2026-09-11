#!/usr/bin/env bash
# skills/scaffold-repo/lib/test_scaffold_repo.sh — one runnable smoke test for
# scaffold_repo.sh. Not a framework: asserts, plain bash. Run directly:
#   bash skills/scaffold-repo/lib/test_scaffold_repo.sh

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$HERE/scaffold_repo.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

fail() { echo "FAIL: $1" >&2; exit 1; }

# --- happy path --------------------------------------------------------
OUT="$("$SCRIPT" \
  --name demo-skills --plugin demo --dest "$TMP" \
  --owner acme --host github.com \
  --description "Demo marketplace" --plugin-description "Demo plugin" \
  --skill zeta --skill alpha)"
REPO="$TMP/demo-skills"
[ "$OUT" = "$REPO" ] || fail "stdout should print the repo path"

for f in \
  .claude-plugin/marketplace.json .claude-plugin/plugin.json \
  .codex-plugin/plugin.json .kimi-plugin/plugin.json \
  .hermes-plugin/plugin.yaml .hermes-plugin/__init__.py \
  .opencode/plugins/demo.js .agents/plugins/marketplace.json \
  gemini-extension.json package.json \
  .github/workflows/validate.yml .github/workflows/board-sync.yml \
  LICENSE .gitignore
do
  [ -f "$REPO/$f" ] || fail "missing $f"
done
for d in skills docs/skill-guides docs/skill-output; do
  [ -d "$REPO/$d" ] || fail "missing dir $d"
done

# JSON must parse
for j in .claude-plugin/marketplace.json .claude-plugin/plugin.json \
         .codex-plugin/plugin.json .kimi-plugin/plugin.json \
         .agents/plugins/marketplace.json gemini-extension.json package.json
do
  python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$REPO/$j" \
    || fail "invalid JSON: $j"
done

# version/license agreement across all seven version-bearing manifests
python3 - "$REPO" <<'PY'
import json, sys, re, pathlib
repo = pathlib.Path(sys.argv[1])
versions = set()
for rel in [
    ".claude-plugin/plugin.json", ".claude-plugin/marketplace.json",
    ".codex-plugin/plugin.json", ".kimi-plugin/plugin.json",
    "gemini-extension.json", "package.json",
]:
    data = json.loads((repo / rel).read_text())
    v = data["plugins"][0]["version"] if rel.endswith("marketplace.json") else data["version"]
    versions.add(v)
m = re.search(r"^version:\s*(\S+)", (repo / ".hermes-plugin/plugin.yaml").read_text(), re.M)
versions.add(m.group(1))
assert versions == {"0.1.0"}, f"version mismatch: {versions}"

licenses = set()
for rel in [".claude-plugin/plugin.json", ".codex-plugin/plugin.json",
            ".kimi-plugin/plugin.json", "package.json"]:
    licenses.add(json.loads((repo / rel).read_text())["license"])
assert (repo / "LICENSE").read_text().splitlines()[0] == "MIT License"
assert licenses == {"MIT"}, f"license mismatch: {licenses}"
PY

# PascalCase identifier must be valid JS and match the hyphenated plugin key
grep -q "export const DemoPlugin = " "$REPO/.opencode/plugins/demo.js" \
  || fail "PascalCase export not found"

# Hermes sentinel must point at the alphabetically-first --skill (alpha, not zeta)
grep -q '_SENTINEL = ("alpha", "SKILL.md")' "$REPO/.hermes-plugin/__init__.py" \
  || fail "hermes sentinel should pick the first skill alphabetically"

# --- refuses to overwrite an existing destination -----------------------
if "$SCRIPT" --name demo-skills --plugin demo --dest "$TMP" \
     --owner acme --host github.com \
     --description x --plugin-description y --skill a >/dev/null 2>&1; then
  fail "should refuse an existing destination"
fi

# --- descriptions with quotes/backslashes/newlines must not corrupt output
"$SCRIPT" \
  --name quote-skills --plugin quote --dest "$TMP" \
  --owner acme --host github.com \
  --description 'She said "hi" \o/' \
  --plugin-description $'multi\nline "desc" with a \\backslash' \
  --skill only >/dev/null
QREPO="$TMP/quote-skills"
python3 - "$QREPO" <<'PY'
import json, pathlib, sys
repo = pathlib.Path(sys.argv[1])
mkt = json.loads((repo / ".claude-plugin/marketplace.json").read_text())
assert mkt["description"] == 'She said "hi" \\o/', mkt["description"]
plugin = json.loads((repo / ".claude-plugin/plugin.json").read_text())
assert plugin["description"] == 'multi\nline "desc" with a \\backslash', plugin["description"]
PY
grep -q '^description: "multi\\nline \\"desc\\" with a \\\\backslash"$' \
  "$QREPO/.hermes-plugin/plugin.yaml" \
  || fail "hermes plugin.yaml description not safely quoted"

# --- rejects an unsafe identifier instead of emitting a broken manifest --
if "$SCRIPT" --name 'not a repo name!' --plugin demo --dest "$TMP" \
     --owner acme --host github.com \
     --description x --plugin-description y --skill a >/dev/null 2>&1; then
  fail "should reject an invalid --name"
fi

echo "OK: scaffold_repo.sh smoke test passed"
