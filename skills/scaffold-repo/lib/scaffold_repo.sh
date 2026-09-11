#!/usr/bin/env bash
# skills/scaffold-repo/lib/scaffold_repo.sh — deterministic half of packaging:scaffold-repo
# Steps 3+5: golden split-layout directory tree, all seven harness
# manifests, package.json, gemini-extension.json, the Hermes/OpenCode
# integration files, both CI workflows, LICENSE, .gitignore.
#
# Explicitly NOT handled here (left to the calling model, in SKILL.md
# prose): copying skills into skills/ (needs post-copy frontmatter
# judgment — Step 4), CLAUDE.md / GEMINI.md / README.md / INSTALL.md prose
# content (needs per-skill judgment, not mechanical substitution), git
# init/branch (Step 6), and any outward-facing call (gh repo create / git
# push — confirmation-gated, Steps 7-8).
#
# Usage:
#   scaffold_repo.sh --name <repo-name> --plugin <plugin-key> \
#     --dest <path> --owner <owner> --host <host> \
#     --description <marketplace one-liner> \
#     --plugin-description <plugin description> \
#     --skill <skill-name> [--skill <skill-name> ...]
#
# --skill is repeatable and only used to name the Hermes registration
# sentinel (the alphabetically-first skill) — it does not create
# skills/<skill> itself; Step 4 (cp -r into skills/) owns that.
#
# Exits non-zero (no writes) if <dest>/<repo-name> already exists.

set -euo pipefail

usage() {
  echo "Usage: $0 --name <repo-name> --plugin <plugin-key> --dest <path> \\" >&2
  echo "          --owner <owner> --host <host> --description <text> \\" >&2
  echo "          --plugin-description <text> --skill <name> [--skill <name> ...]" >&2
  exit 1
}

NAME="" PLUGIN="" DEST="" OWNER="" HOST="" DESCRIPTION="" PLUGIN_DESCRIPTION=""
SKILLS=()

while [ $# -gt 0 ]; do
  case "$1" in
    --name) NAME="$2"; shift 2 ;;
    --plugin) PLUGIN="$2"; shift 2 ;;
    --dest) DEST="$2"; shift 2 ;;
    --owner) OWNER="$2"; shift 2 ;;
    --host) HOST="$2"; shift 2 ;;
    --description) DESCRIPTION="$2"; shift 2 ;;
    --plugin-description) PLUGIN_DESCRIPTION="$2"; shift 2 ;;
    --skill) SKILLS+=("$2"); shift 2 ;;
    -h|--help) usage ;;
    *) echo "unknown argument: $1" >&2; usage ;;
  esac
done

for v in NAME PLUGIN DEST OWNER HOST DESCRIPTION PLUGIN_DESCRIPTION; do
  if [ -z "${!v}" ]; then
    echo "missing required --${v,,}" >&2
    usage
  fi
done
if [ "${#SKILLS[@]}" -eq 0 ]; then
  echo "missing required --skill (at least one)" >&2
  usage
fi

# Identifier-shaped inputs are validated, not escaped: every one of them is
# interpolated unquoted-and-bare into JSON/YAML/JS/Python string literals
# below, so a value containing a quote, backslash, or newline would corrupt
# the generated file (or, in the .opencode/plugins/<plugin>.js identifier,
# inject code) rather than just look wrong. Reject anything outside a safe
# charset here, once, instead of re-deriving "is this safe to interpolate"
# at every call site.
validate() {
  local label="$1" value="$2" pattern="$3"
  if ! [[ "$value" =~ $pattern ]]; then
    echo "invalid --$label: '$value' does not match $pattern" >&2
    exit 1
  fi
}
validate name "$NAME" '^[a-z0-9]+(-[a-z0-9]+)*$'
validate plugin "$PLUGIN" '^[a-z0-9]+(-[a-z0-9]+)*$'
validate owner "$OWNER" '^[A-Za-z0-9][A-Za-z0-9-]*$'
validate host "$HOST" '^[A-Za-z0-9.-]+$'
for s in "${SKILLS[@]}"; do
  validate skill "$s" '^[a-z0-9]+(-[a-z0-9]+)*$'
done
FIRST_SKILL="$(printf '%s\n' "${SKILLS[@]}" | sort | head -n1)"

# DESCRIPTION / PLUGIN_DESCRIPTION are genuine free text (a marketplace
# one-liner) — they can't be charset-restricted like the identifiers above,
# so they get real JSON-string escaping instead. json.dumps' escaping is
# also valid inside a YAML double-quoted scalar (both are C-style), which is
# why the same *_JSON variable is reused for .hermes-plugin/plugin.yaml
# below. Each *_JSON variable already includes its own surrounding quotes.
json_str() {
  python3 -c 'import json, sys; sys.stdout.write(json.dumps(sys.argv[1]))' "$1"
}
DESCRIPTION_JSON="$(json_str "$DESCRIPTION")"
PLUGIN_DESCRIPTION_JSON="$(json_str "$PLUGIN_DESCRIPTION")"

REPO_DIR="$DEST/$NAME"
if [ -e "$REPO_DIR" ]; then
  echo "abort: $REPO_DIR already exists (not idempotent)" >&2
  exit 1
fi

# <Plugin>: PascalCase of <plugin>, hyphens removed (gh-flow -> GhFlow).
# A hyphenated plugin key otherwise produces an invalid JS identifier
# (e.g. `gh-flowPlugin`) in .opencode/plugins/<plugin>.js.
pascal() {
  local out="" part
  IFS='-' read -ra parts <<<"$1"
  for part in "${parts[@]}"; do
    out+="$(tr '[:lower:]' '[:upper:]' <<<"${part:0:1}")${part:1}"
  done
  echo "$out"
}
# Title Case of <repo-name> for .agents marketplace.json displayName
# (packaging-skills -> "Packaging Skills").
title_case() {
  local out="" part
  IFS='-' read -ra parts <<<"$1"
  for part in "${parts[@]}"; do
    out+="$(tr '[:lower:]' '[:upper:]' <<<"${part:0:1}")${part:1} "
  done
  echo "${out% }"
}

PLUGIN_PASCAL="$(pascal "$PLUGIN")"
REPO_TITLE="$(title_case "$NAME")"
YEAR="$(date +%Y)"

# --- Step 3: directory tree -------------------------------------------------
mkdir -p \
  "$REPO_DIR/.claude-plugin" \
  "$REPO_DIR/.codex-plugin" \
  "$REPO_DIR/.kimi-plugin" \
  "$REPO_DIR/.hermes-plugin" \
  "$REPO_DIR/.opencode/plugins" \
  "$REPO_DIR/.agents/plugins" \
  "$REPO_DIR/.github/workflows" \
  "$REPO_DIR/skills" \
  "$REPO_DIR/docs/skill-guides" \
  "$REPO_DIR/docs/skill-output"

# --- Step 5: manifests, CI, LICENSE, .gitignore -----------------------------

cat >"$REPO_DIR/.claude-plugin/marketplace.json" <<EOF
{
  "\$schema": "https://anthropic.com/claude-code/marketplace.schema.json",
  "name": "$NAME",
  "description": $DESCRIPTION_JSON,
  "owner": { "name": "$OWNER", "url": "https://$HOST/$OWNER" },
  "plugins": [
    {
      "name": "$PLUGIN",
      "description": $PLUGIN_DESCRIPTION_JSON,
      "version": "0.1.0",
      "source": "./",
      "homepage": "https://$HOST/$OWNER/$NAME",
      "author": { "name": "$OWNER", "url": "https://$HOST/$OWNER" }
    }
  ]
}
EOF

cat >"$REPO_DIR/.claude-plugin/plugin.json" <<EOF
{
  "name": "$PLUGIN",
  "description": $PLUGIN_DESCRIPTION_JSON,
  "version": "0.1.0",
  "author": { "name": "$OWNER", "url": "https://$HOST/$OWNER" },
  "homepage": "https://$HOST/$OWNER/$NAME",
  "repository": "https://$HOST/$OWNER/$NAME",
  "license": "MIT",
  "keywords": ["skills", "plugin", "marketplace", "$PLUGIN"]
}
EOF

cat >"$REPO_DIR/.codex-plugin/plugin.json" <<EOF
{
  "name": "$PLUGIN",
  "version": "0.1.0",
  "description": $PLUGIN_DESCRIPTION_JSON,
  "author": { "name": "$OWNER", "url": "https://$HOST/$OWNER" },
  "homepage": "https://$HOST/$OWNER/$NAME",
  "repository": "https://$HOST/$OWNER/$NAME",
  "license": "MIT",
  "keywords": ["skills", "plugin", "marketplace", "$PLUGIN"],
  "skills": "./skills/",
  "hooks": {},
  "interface": {
    "displayName": "$PLUGIN_PASCAL",
    "shortDescription": $PLUGIN_DESCRIPTION_JSON,
    "longDescription": $PLUGIN_DESCRIPTION_JSON,
    "developerName": "$OWNER",
    "category": "Developer Tools",
    "capabilities": ["Interactive", "Read", "Write"],
    "defaultPrompt": [],
    "websiteURL": "https://$HOST/$OWNER/$NAME",
    "brandColor": "#2563EB",
    "screenshots": []
  }
}
EOF

cat >"$REPO_DIR/.kimi-plugin/plugin.json" <<EOF
{
  "name": "$PLUGIN",
  "version": "0.1.0",
  "description": $PLUGIN_DESCRIPTION_JSON,
  "author": { "name": "$OWNER", "url": "https://$HOST/$OWNER" },
  "homepage": "https://$HOST/$OWNER/$NAME",
  "license": "MIT",
  "keywords": ["skills", "plugin", "marketplace", "$PLUGIN"],
  "skills": "./skills/",
  "skillInstructions": "Kimi Code tool mapping for $PLUGIN skills:\n\n- When a skill says to ask the user, or asks for confirmation before a destructive step, call Kimi Code's \`AskUserQuestion\` tool.\n- When a skill refers to \`TodoWrite\`, use Kimi Code's \`TodoList\` tool.\n- When a skill asks to dispatch a subagent, use Kimi Code's \`Agent\` tool with \`subagent_type: \"coder\"\` for implementation and \`subagent_type: \"explore\"\` for read-only exploration; never \`general-purpose\`.\n- Use Kimi Code's \`Read\`, \`Write\`, \`Edit\`, \`Bash\`, \`Grep\`, \`Glob\` tools by their exposed names.\n- Honour each skill's safety contract: a read-only skill must never call \`Write\`, \`Edit\`, or a mutating \`Bash\` command.",
  "interface": {
    "displayName": "$PLUGIN_PASCAL",
    "shortDescription": $PLUGIN_DESCRIPTION_JSON,
    "longDescription": $PLUGIN_DESCRIPTION_JSON,
    "developerName": "$OWNER",
    "capabilities": ["Interactive", "Read", "Write"],
    "websiteURL": "https://$HOST/$OWNER/$NAME"
  }
}
EOF

cat >"$REPO_DIR/.hermes-plugin/plugin.yaml" <<EOF
name: $PLUGIN
version: 0.1.0
description: $PLUGIN_DESCRIPTION_JSON
author: $OWNER
EOF

cat >"$REPO_DIR/.hermes-plugin/__init__.py" <<EOF
"""Hermes Agent registration for the \`$PLUGIN\` skills plugin."""

import os
from pathlib import Path

# Sentinel skill used to recognise a correctly laid out skills/ tree.
_SENTINEL = ("$FIRST_SKILL", "SKILL.md")


def _skills_dir() -> str:
    """Locate the stock skills/ tree for either supported install layout.

    - git-clone install: the plugin dir is the repo root, so \`.hermes-plugin/\`
      and \`skills/\` are siblings and this module resolves \`../skills\`.
    - flattened install: \`skills/\` sits next to this module.

    Raises loudly when neither matches — a bootstrap that silently skips is how
    a broken install masquerades as a working one.
    """
    here = os.path.dirname(os.path.realpath(__file__))
    candidates = (
        os.path.realpath(os.path.join(here, "..", "skills")),
        os.path.realpath(os.path.join(here, "skills")),
    )
    for cand in candidates:
        if os.path.isfile(os.path.join(cand, *_SENTINEL)):
            return cand
    raise RuntimeError(
        "$PLUGIN plugin: cannot find the skills/ tree "
        f"(looked at {candidates}). Reinstall with "
        "\`hermes plugins install $OWNER/$NAME\`."
    )


def register(ctx):
    skills_dir = _skills_dir()
    for name in sorted(os.listdir(skills_dir)):
        skill_md = os.path.join(skills_dir, name, "SKILL.md")
        if os.path.isfile(skill_md):
            ctx.register_skill(name, Path(skill_md))
EOF

cat >"$REPO_DIR/.opencode/plugins/$PLUGIN.js" <<EOF
/**
 * $PLUGIN plugin for OpenCode.ai
 *
 * Auto-registers the skills directory via the config hook (no symlinks needed).
 */

import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

export const ${PLUGIN_PASCAL}Plugin = async () => {
  const skillsDir = path.resolve(__dirname, '../../skills');

  return {
    // Config.get() returns a cached singleton, so a mutation here is visible
    // when skills are lazily discovered later.
    config: async (config) => {
      config.skills = config.skills || {};
      config.skills.paths = config.skills.paths || [];
      if (!config.skills.paths.includes(skillsDir)) {
        config.skills.paths.push(skillsDir);
      }
    },
  };
};
EOF

cat >"$REPO_DIR/.agents/plugins/marketplace.json" <<EOF
{
  "name": "$NAME",
  "interface": { "displayName": "$REPO_TITLE" },
  "plugins": [
    {
      "name": "$PLUGIN",
      "source": { "source": "url", "url": "./" },
      "policy": { "installation": "AVAILABLE", "authentication": "ON_INSTALL" },
      "category": "Developer Tools"
    }
  ]
}
EOF

cat >"$REPO_DIR/gemini-extension.json" <<EOF
{
  "name": "$PLUGIN",
  "description": $PLUGIN_DESCRIPTION_JSON,
  "version": "0.1.0",
  "contextFileName": "GEMINI.md"
}
EOF

cat >"$REPO_DIR/package.json" <<EOF
{
  "name": "$NAME",
  "version": "0.1.0",
  "description": $PLUGIN_DESCRIPTION_JSON,
  "type": "module",
  "main": ".opencode/plugins/$PLUGIN.js",
  "license": "MIT",
  "repository": {
    "type": "git",
    "url": "git+https://$HOST/$OWNER/$NAME.git"
  },
  "keywords": ["skills", "plugin", "marketplace", "$PLUGIN"]
}
EOF

cat >"$REPO_DIR/.github/workflows/validate.yml" <<EOF
name: validate

on:
  push:
    branches: [main]
  pull_request:
  workflow_dispatch:

permissions:
  contents: read

jobs:
  validate:
    uses: dEitY719/harness-skills/.github/workflows/skill-check.yml@main
    with:
      plugin-name: $PLUGIN
EOF

cat >"$REPO_DIR/.github/workflows/board-sync.yml" <<EOF
name: board-sync

on:
  issues:
    types: [opened, reopened, transferred]

permissions:
  contents: read

jobs:
  board-sync:
    uses: dEitY719/harness-skills/.github/workflows/add-to-project.yml@main
    secrets: inherit
EOF

cat >"$REPO_DIR/LICENSE" <<EOF
MIT License

Copyright (c) $YEAR $OWNER

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
EOF

cat >"$REPO_DIR/.gitignore" <<'EOF'
node_modules/
__pycache__/
*.pyc
.DS_Store
.venv/
EOF

echo "$REPO_DIR"
