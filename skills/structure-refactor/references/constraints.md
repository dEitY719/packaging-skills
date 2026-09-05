# Structure Refactor: Constraints

- Dry-run is the default — only `--apply` writes. Never auto-apply on a
  dirty tree.
- Idempotent: an already-standard repo (within scope) is a no-op.
- R1 guides under `--op` are real content — delegate to `/visuals:visualize`
  (skip if the guide already exists; idempotent). R2 usage samples stay
  placeholder stubs (TODO pointing at `/visuals:visualize`). Never call
  `/visuals:excalidraw-diagram` here.
- GitHub Pages activation and R5 link backfill are soft-fail: a missing
  token scope or an unreachable host warns and continues — it never aborts
  the run.
- Prefer `git mv` to preserve history; fall back to `mv` outside a git repo.
- Mode-aware: fix toward the **detected** layout's golden form — `single`
  never creates a `plugins/` directory; `mono` keeps the `plugins/<p>/…`
  paths. A `--single`/`--mono` that differs from the detected current layout
  is a single↔mono conversion: **out of scope** — warn and write nothing
  (never a partial move), even under `--apply`.
- Repo-agnostic: discover plugins/skills by scan; the spec is embedded in
  `references/structure-spec.md`.
