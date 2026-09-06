# Options — full flag/argument reference for packaging:create

Positional `<repo-name>` (required) + optional `[skill ...]` list, plus the
flags below. (The same surface, with examples, is in `help.md`.)

| Option | Description | Default |
|--------|-------------|---------|
| `<repo-name>` | repo name in `<domain>-skills` form (required) | — |
| `[skill ...]` | skill directory names to copy (space-separated) | inferred from chat, else ask |
| `--src <path>` | skill source directory (**required** — no default) | — |
| `--dest <path>` | repo creation location | `~/para/project/skills/` |
| `--host <host>` | GitHub host | `github.com` |
| `--owner <owner>` | GitHub owner | `dEitY719` |
| `--plugin <name>` | plugin key (inner name) | `<repo-name>` minus the `-skills` suffix |
| `--dry-run` | plan only — no writes/repo/commit | off |
| `-h`/`--help` | print help, stop | — |

## Validation rules (Step 1)

- Append `-skills` if the suffix is missing (tell the user): `packaging` ->
  `packaging-skills`.
- **Reject a `claude-plugin-` prefix.** That is the pre-#1410 naming; tell the
  user the convention is `<domain>-skills` and propose the rewritten name.
- Enforce lowercase-hyphen naming (GitHub repo naming rules).
- Abort if `--src` is missing.
- Abort if `<dest>/<repo-name>` already exists — no overwrite, NOT idempotent.
- `[skill ...]`: infer from the conversation when omitted; if not inferable,
  ask the user (never guess).

## Golden split layout built in Step 3

One repo = one plugin (dEitY719/dotfiles#1410 P-1). Every harness manifest sits
at the **repo root** and points at a single flat `./skills/` tree:

```
<dest>/<repo-name>/
  .claude-plugin/marketplace.json     # Claude Code — plugins[0].source = "./"
  .claude-plugin/plugin.json          # Claude Code
  .codex-plugin/plugin.json           # Codex
  .kimi-plugin/plugin.json            # Kimi CLI
  .hermes-plugin/plugin.yaml          # Hermes Agent
  .hermes-plugin/__init__.py          # Hermes Agent — skill registration
  .opencode/plugins/<plugin>.js       # OpenCode — filename must equal <plugin>
  .opencode/INSTALL.md                # OpenCode
  .agents/plugins/marketplace.json    # Antigravity
  gemini-extension.json               # Gemini CLI
  GEMINI.md                           # Gemini CLI context/skill index
  CLAUDE.md                           # AI context doc (SSOT)
  AGENTS.md -> CLAUDE.md              # symlink, never a second copy
  .github/workflows/validate.yml      # calls harness-skills/skill-check.yml
  .github/workflows/board-sync.yml    # calls harness-skills/add-to-project.yml
  skills/<skill>/SKILL.md             # skills copied in at Step 4
  docs/skill-guides/                  # placeholder stubs
  docs/skill-output/                  # placeholder stubs
  README.md
  LICENSE
  .gitignore
```

## Copied-skill frontmatter (Step 4)

`--src` is copy-only, so a source skill that predates this convention will not
have been fixed there — but the **copy** in the new repo must satisfy CI on its
first push. After copying, check each
`<dest>/<repo-name>/skills/<skill>/SKILL.md`:

- YAML frontmatter exists, with `name:` **bare** (no `<plugin>:` prefix) and
  equal to its directory name;
- `description:` is present and non-empty (and under 1024 chars);
- `license: MIT` is present — a skill carrying a different licence, or none,
  fails the repo-wide licence-agreement gate;
- the file is 100 lines or fewer.

Fix violations **in the copy** and tell the user what was changed, or abort if
the fix is not mechanical (a non-MIT licence is a decision, not a typo). Never
edit, move or rewrite anything under `--src`.

```python
# run over <dest>/<repo-name>/skills
import re, sys, pathlib
fail = 0
for md in sorted(pathlib.Path(sys.argv[1]).glob("*/SKILL.md")):
    text = md.read_text(encoding="utf-8")
    m = re.match(r"^---\n(.*?)\n---\n", text, re.S)
    if not m:
        print(f"FAIL {md}: no frontmatter"); fail = 1; continue
    fm = m.group(1)
    name = re.search(r"^name:\s*(.+?)\s*$", fm, re.M)
    if not name or ":" in name.group(1) or name.group(1).strip("\"'") != md.parent.name:
        print(f"FAIL {md}: name must be the bare directory name"); fail = 1
    if not re.search(r"^description:", fm, re.M):
        print(f"FAIL {md}: no description"); fail = 1
    lic = re.search(r"^license:\s*(\S+)", fm, re.M)
    if not lic or lic.group(1) != "MIT":
        print(f"FAIL {md}: license must be MIT"); fail = 1
    if len(text.splitlines()) > 100:
        print(f"FAIL {md}: over 100 lines"); fail = 1
sys.exit(fail)
```

## Why not the mono layout

`plugins/<plugin>/skills/` (`marketplace.json` `source: "./plugins/<plugin>"`)
is the pre-#1410 mono layout. **Only Claude Code resolves it.** Codex, Kimi,
Hermes, OpenCode, Antigravity and Gemini CLI all look for their manifest at the
repo root and a skills tree at `./skills/`, so nesting silently reduces a new
plugin to Claude-Code-only. `harness-skills`' reusable `skill-check.yml` fails
any repo that contains a `plugins/` directory — a mono skeleton is red on its
first push.

Reference implementations to copy from when a template here is ambiguous:
`dEitY719/packaging-skills` and `dEitY719/harness-skills`.

## What CI gates (so Step 5 must get it right)

`.github/workflows/validate.yml` calls
`dEitY719/harness-skills/.github/workflows/skill-check.yml@main`, which fails on:

- any missing file from the required list above (plus `README.md`, `LICENSE`,
  `package.json`);
- `AGENTS.md` not being a symlink whose target is exactly `CLAUDE.md`;
- a `plugins/` directory existing, or `skills/` missing;
- `skills/<name>/SKILL.md` whose frontmatter `name:` is namespaced or does not
  equal its directory name, or which has no `description:`;
- a `SKILL.md` over 100 lines (progressive disclosure — push detail into
  `references/`);
- the seven version-bearing manifests disagreeing on `version`
  (`.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`
  `plugins[0].version`, `.codex-plugin/plugin.json`, `.kimi-plugin/plugin.json`,
  `.hermes-plugin/plugin.yaml`, `gemini-extension.json`, `package.json`);
- `license` disagreeing across `LICENSE`, the three `*-plugin/plugin.json`
  manifests, `package.json`, and every `skills/*/SKILL.md` frontmatter — all
  must read `MIT`;
- any emoji anywhere in the repo.

**What CI does not gate.** No harness-specific manifest schema is checked: for
`.codex-plugin`, `.kimi-plugin`, `.hermes-plugin`, `.agents/` and
`gemini-extension.json`, CI verifies presence, JSON/YAML parse, and the
`version`/`license` agreement — nothing about whether the keys inside are the
ones that harness actually reads. A typo in a key name is therefore a silent
load-time failure on that harness alone. Diff a generated manifest against the
same file in a reference repo before pushing.
