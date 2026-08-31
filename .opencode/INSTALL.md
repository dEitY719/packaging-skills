# Installing packaging for OpenCode

## Prerequisites

- [OpenCode.ai](https://opencode.ai) installed

## Installation

Add the plugin to the `plugin` array in your `opencode.json` (global or
project-level):

```json
{
  "plugin": ["packaging@git+https://github.com/dEitY719/packaging-skills.git"]
}
```

Restart OpenCode. The plugin installs through OpenCode's plugin manager and
registers all four skills.

OpenCode uses its own plugin install. If you also use Claude Code, Codex, or
another harness, install this plugin separately for each one.

## Usage

Use OpenCode's native `skill` tool:

```
use skill tool to list skills
use skill tool to load structure-check
```

## Tool mapping

The skills speak in actions. On OpenCode these resolve to:

- "Read a file" -> `read`
- "Create a file" / "edit a file" -> `apply_patch`
- "Run a shell command" -> `bash`
- "Search file contents" / "find files by name" -> `grep`, `glob`
- "Create a todo" -> `todowrite`
- "Dispatch a subagent" -> `task` with `subagent_type: "general"` (or
  `"explore"` for read-only repo exploration)
- "Invoke a skill" -> OpenCode's native `skill` tool

`structure-check` is read-only — it must never reach for `apply_patch` or a
mutating `bash` command. `structure-refactor` is dry-run unless `--apply` was
passed.

## Troubleshooting

### Plugin not loading

1. Check logs: `opencode run --print-logs "hello" 2>&1 | grep -i packaging`
2. Verify the plugin line in your `opencode.json`
3. Make sure you are running a recent version of OpenCode

### Skills not found

1. Use the `skill` tool to list what was discovered
2. Check that the plugin is loading (see above)

## Getting Help

Report issues: https://github.com/dEitY719/packaging-skills/issues
