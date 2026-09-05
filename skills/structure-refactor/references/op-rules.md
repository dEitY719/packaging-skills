# Structure Refactor: --op Flag Rules

Under `--op` (`--recommended`), R1-R5 fixes are applied in addition to the
mandatory M1-M10 (which includes the M7 source injection and M10 plugin.json
prune — both run under `--mp` too). R6-R8 are audit-only WARN items:
`$schema` / `description` / `homepage` / README-URL fixes are **not**
auto-applied; a developer fills those. Specific behaviors when
`--apply --op` is active:

## R1 — per-skill guide generation

Delegate to `/visuals:visualize <SKILL.md>` → `docs/skill-guides/<skill>.html`.
Skip when the file already exists (idempotent). Never call
`/visuals:excalidraw-diagram` here.

## R2 — usage sample stubs

Create `docs/skill-output/<skill>-usage.md` as a placeholder stub containing
a TODO comment pointing at `/visuals:visualize` — a Markdown body, matching
apply rule 5 in `references/plan-and-report-templates.md`. These remain stubs
— they are never auto-populated with real content. The spec's
`-usage.{html,md}` tolerance is for the **audit** side only: a repo that
publishes only a rendered `-usage.html` still passes R2/R5.

## R4 — naming correction

`name:` must be the **bare** skill-directory basename (spec R4). On a mismatch
— a colon in `name:`, or any other divergence — rewrite `name:` in `SKILL.md`
to that basename. **Never `git mv` the directory**: the directory name is what
the user types after `/<plugin>:`, so renaming it is a public API change,
whereas `name:` is internal.

**Out of scope — a directory basename that is not itself a valid bare name**
(it contains a colon). Rewriting `name:` to that basename only reproduces the
violation, and the only other fix is the directory rename this rule forbids.
Leave it as R4's WARN for the developer to resolve by hand; never rename
automatically.

## R5 — README link backfill

For each discovered skill `<s>`, ensure `README.md` contains both:
- a link to `skill-guides/<s>.html`, and
- a link to `skill-output/<s>-usage.{html,md}`.

Backfill uses the GitHub Pages absolute URL (derived from
`git remote get-url origin`):

| Host | Pages base | Full guide URL |
|------|------------|----------------|
| `github.com` | `https://<owner>.github.io/<repo>` | `…/skill-guides/<s>.html` |
| GHE (e.g. `github.samsungds.net`) | `https://<host>/pages/<owner>/<repo>` | `…/skill-guides/<s>.html` |

## GitHub Pages activation

Auto-activate GitHub Pages when inactive (github.com + GHE). This is a
soft-fail step: a missing token scope or unreachable host warns and continues
— it never aborts the run.

Full apply sequence and Pages host/URL derivation:
see `references/plan-and-report-templates.md` → "Apply rules" and
"Pages host & URL derivation (`--op`)".
