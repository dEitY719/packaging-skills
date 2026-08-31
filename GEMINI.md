# packaging — skill index

Four skills for building and maintaining agent skill marketplace repos. Each
lives in this extension's `skills/` directory. They are task-triggered: load the
one that matches the job by reading its `SKILL.md`, then follow it. Do not load
all four.

| Skill | Read | Use when |
|-------|------|----------|
| `create` | `@./skills/create/SKILL.md` | Scaffolding a brand-new marketplace repo — structure, manifests, skill import, `git init`, repo create, push. New repos only. |
| `rename-repo` | `@./skills/rename-repo/SKILL.md` | Renaming an existing plugin repo to the team convention and fixing every hardcoded reference. |
| `structure-check` | `@./skills/structure-check/SKILL.md` | Auditing an existing repo's layout. Read-only — it reports, it does not fix. |
| `structure-refactor` | `@./skills/structure-refactor/SKILL.md` | Applying the fixes `structure-check` found. Dry-run unless `--apply`. |

Each skill's `references/` directory holds the detail it loads on demand;
`SKILL.md` says which file to read and when. Do not read `references/` files
up front.

## Tool mapping for Gemini CLI

The skills speak in actions. On Gemini CLI these resolve to:

- "Read a file" -> `read_file` / `read_many_files`
- "Create a file" / "edit a file" -> `write_file`, `replace`
- "Run a shell command" -> `run_shell_command`
- "Search file contents" -> `search_file_content`
- "Find files by name" -> `glob`
- "Ask the user" -> ask in the conversation and wait for the answer

## Safety rules

- `structure-check` is strictly read-only. Never write, edit, or run a mutating
  shell command while following it.
- `structure-refactor` prints a plan and stops unless the user passed `--apply`.
- `create` and `rename-repo` both reach `gh repo create` / `git push`. Confirm
  with the user before either.
