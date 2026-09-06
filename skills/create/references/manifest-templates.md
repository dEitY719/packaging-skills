# packaging:create — Manifest, CI, LICENSE & .gitignore Templates

Written in Step 5 (split golden layout — see `options.md`). Placeholders:

| Placeholder | Meaning | Example |
|---|---|---|
| `<repo-name>` | repo name | `packaging-skills` |
| `<plugin>` | plugin key = `<repo-name>` minus `-skills` | `packaging` |
| `<owner>` / `<host>` | from the flags | `dEitY719` / `github.com` |
| `<skill>` | one discovered skill directory | `structure-check` |
| `<first-skill>` | the first skill in sorted order | `create` |
| `<year>` | `date +%Y` at runtime — never hardcoded | `2026` |

Keep `.claude-plugin/marketplace.json` `name` equal to the repo name 1:1 (same
rule as `packaging:rename-repo`), and every `name` field in a *plugin* manifest
equal to `<plugin>`. Start every `version` at `0.1.0` — the same string in all
seven version-bearing manifests, or CI fails.

## `.claude-plugin/marketplace.json`

```json
{
  "$schema": "https://anthropic.com/claude-code/marketplace.schema.json",
  "name": "<repo-name>",
  "description": "<one-line marketplace description>",
  "owner": { "name": "<owner>", "url": "https://<host>/<owner>" },
  "plugins": [
    {
      "name": "<plugin>",
      "description": "<plugin description>",
      "version": "0.1.0",
      "source": "./",
      "homepage": "https://<host>/<owner>/<repo-name>",
      "author": { "name": "<owner>", "url": "https://<host>/<owner>" }
    }
  ]
}
```

`source` is `"./"` — the repo root **is** the plugin root. Never
`"./plugins/<plugin>"`; that is the mono layout this skill no longer emits.

## `.claude-plugin/plugin.json`

```json
{
  "name": "<plugin>",
  "description": "<plugin description>",
  "version": "0.1.0",
  "author": { "name": "<owner>", "url": "https://<host>/<owner>" },
  "homepage": "https://<host>/<owner>/<repo-name>",
  "repository": "https://<host>/<owner>/<repo-name>",
  "license": "MIT",
  "keywords": ["skills", "plugin", "marketplace", "<plugin>"]
}
```

## `.codex-plugin/plugin.json`

Same identity fields plus Codex's `skills` pointer and `interface` block.

```json
{
  "name": "<plugin>",
  "version": "0.1.0",
  "description": "<plugin description>",
  "author": { "name": "<owner>", "url": "https://<host>/<owner>" },
  "homepage": "https://<host>/<owner>/<repo-name>",
  "repository": "https://<host>/<owner>/<repo-name>",
  "license": "MIT",
  "keywords": ["skills", "plugin", "marketplace", "<plugin>"],
  "skills": "./skills/",
  "hooks": {},
  "interface": {
    "displayName": "<Plugin>",
    "shortDescription": "<one line, under ~80 chars>",
    "longDescription": "<2-3 sentences naming each bundled skill and its role>",
    "developerName": "<owner>",
    "category": "Developer Tools",
    "capabilities": ["Interactive", "Read", "Write"],
    "defaultPrompt": ["<example prompt 1>", "<example prompt 2>"],
    "websiteURL": "https://<host>/<owner>/<repo-name>",
    "brandColor": "#2563EB",
    "screenshots": []
  }
}
```

## `.kimi-plugin/plugin.json`

Kimi needs `skillInstructions` — the tool-name mapping the skills' generic
prose resolves to on Kimi Code. Write it as one `\n`-escaped string.

```json
{
  "name": "<plugin>",
  "version": "0.1.0",
  "description": "<plugin description>",
  "author": { "name": "<owner>", "url": "https://<host>/<owner>" },
  "homepage": "https://<host>/<owner>/<repo-name>",
  "license": "MIT",
  "keywords": ["skills", "plugin", "marketplace", "<plugin>"],
  "skills": "./skills/",
  "skillInstructions": "Kimi Code tool mapping for <plugin> skills:\n\n- When a skill says to ask the user, or asks for confirmation before a destructive step, call Kimi Code's `AskUserQuestion` tool.\n- When a skill refers to `TodoWrite`, use Kimi Code's `TodoList` tool.\n- When a skill asks to dispatch a subagent, use Kimi Code's `Agent` tool with `subagent_type: \"coder\"` for implementation and `subagent_type: \"explore\"` for read-only exploration; never `general-purpose`.\n- Use Kimi Code's `Read`, `Write`, `Edit`, `Bash`, `Grep`, `Glob` tools by their exposed names.\n- Honour each skill's safety contract: a read-only skill must never call `Write`, `Edit`, or a mutating `Bash` command.",
  "interface": {
    "displayName": "<Plugin>",
    "shortDescription": "<one line>",
    "longDescription": "<2-3 sentences>",
    "developerName": "<owner>",
    "capabilities": ["Interactive", "Read", "Write"],
    "websiteURL": "https://<host>/<owner>/<repo-name>"
  }
}
```

## `.hermes-plugin/plugin.yaml`

```yaml
name: <plugin>
version: 0.1.0
description: <plugin description>
author: <owner>
```

## `.hermes-plugin/__init__.py`

Registers each skill with Hermes' native loader. `register_skill` requires a
`pathlib.Path` — passing a `str` raises `AttributeError` and Hermes silently
disables the whole plugin.

```python
"""Hermes Agent registration for the `<plugin>` skills plugin."""

import os
from pathlib import Path

# Sentinel skill used to recognise a correctly laid out skills/ tree.
_SENTINEL = ("<first-skill>", "SKILL.md")


def _skills_dir() -> str:
    """Locate the stock skills/ tree for either supported install layout.

    - git-clone install: the plugin dir is the repo root, so `.hermes-plugin/`
      and `skills/` are siblings and this module resolves `../skills`.
    - flattened install: `skills/` sits next to this module.

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
        "<plugin> plugin: cannot find the skills/ tree "
        f"(looked at {candidates}). Reinstall with "
        "`hermes plugins install <owner>/<repo-name>`."
    )


def register(ctx):
    skills_dir = _skills_dir()
    for name in sorted(os.listdir(skills_dir)):
        skill_md = os.path.join(skills_dir, name, "SKILL.md")
        if os.path.isfile(skill_md):
            ctx.register_skill(name, Path(skill_md))
```

## `.opencode/plugins/<plugin>.js`

The filename **must** be `<plugin>.js` — CI checks that exact path.

```javascript
/**
 * <plugin> plugin for OpenCode.ai
 *
 * Auto-registers the skills directory via the config hook (no symlinks needed).
 */

import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

export const <Plugin>Plugin = async () => {
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
```

## `.opencode/INSTALL.md`

Short install doc: prerequisites, the `opencode.json` `plugin` array entry
`"<plugin>@git+https://<host>/<owner>/<repo-name>.git"`, usage via OpenCode's
native `skill` tool, the tool mapping (`read`, `apply_patch`, `bash`, `grep`,
`glob`, `todowrite`, `task`), each skill's safety contract, troubleshooting, and
the issues URL `https://<host>/<owner>/<repo-name>/issues`.

## `.agents/plugins/marketplace.json`

```json
{
  "name": "<repo-name>",
  "interface": { "displayName": "<Repo Name>" },
  "plugins": [
    {
      "name": "<plugin>",
      "source": { "source": "url", "url": "./" },
      "policy": { "installation": "AVAILABLE", "authentication": "ON_INSTALL" },
      "category": "Developer Tools"
    }
  ]
}
```

## `gemini-extension.json`

```json
{
  "name": "<plugin>",
  "description": "<plugin description>",
  "version": "0.1.0",
  "contextFileName": "GEMINI.md"
}
```

## `GEMINI.md`

A skill index, not a copy of `CLAUDE.md`: one table row per skill with
`@./skills/<skill>/SKILL.md` and a "use when" sentence, an instruction to load
only the matching skill (never all of them), the Gemini CLI tool mapping
(`read_file`, `write_file`, `replace`, `run_shell_command`,
`search_file_content`, `glob`), and each skill's safety rules.

## `package.json`

```json
{
  "name": "<repo-name>",
  "version": "0.1.0",
  "description": "<plugin description>",
  "type": "module",
  "main": ".opencode/plugins/<plugin>.js",
  "license": "MIT",
  "repository": {
    "type": "git",
    "url": "git+https://<host>/<owner>/<repo-name>.git"
  },
  "keywords": ["skills", "plugin", "marketplace", "<plugin>"]
}
```

## `CLAUDE.md` + the `AGENTS.md` symlink

`CLAUDE.md` is the AI context SSOT. Create the symlink, never a second copy —
run it **from inside the repo** so the stored target is the bare relative name
`CLAUDE.md`, which is what CI's `readlink AGENTS.md` check compares against:

```bash
(cd <dest>/<repo-name> && ln -s CLAUDE.md AGENTS.md)
```

An absolute or `../`-prefixed target fails that check even when it resolves.

`CLAUDE.md` states: what the repo is (one table row per skill), the split
layout and why the manifests must not move under `plugins/`, the rules for
changing skills (bare `name:` matching the directory, namespaced invocation in
prose, progressive disclosure, safety contracts), the version-bump list, and
the no-emoji rule.

## `.github/workflows/validate.yml`

Do **not** inline the checks — call the shared workflow, so a fix lands once
for every `*-skills` repo.

```yaml
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
      plugin-name: <plugin>
```

## `.github/workflows/board-sync.yml`

```yaml
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
```

## `LICENSE` (MIT, current year)

Derive the year at runtime (`date +%Y`) — do not hardcode it. The first line
must read `MIT License`: CI compares it against the `license` field of the
three `*-plugin/plugin.json` manifests, `package.json`, and every
`skills/*/SKILL.md`.

```
MIT License

Copyright (c) <year> <owner>

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
```

## `.gitignore`

```gitignore
node_modules/
__pycache__/
*.pyc
.DS_Store
.venv/
```
