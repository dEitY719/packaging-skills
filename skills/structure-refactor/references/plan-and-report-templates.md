# packaging:structure-refactor — Plan & Report Templates

## Executable engine

`lib/refactor_apply.sh` runs Apply rules 1 and 3-8 below — every deterministic
operation except rule 2 (see its note). It reuses
`../structure-check/lib/structure_check.sh` for mode-aware plugin/skill
discovery instead of re-deriving it, and `../rename-repo/lib/parse_remote.sh`
for host/owner/repo parsing (Pages, R5 link URLs) — one implementation each,
not a third prose spec of the same rules (packaging-skills#8).

Call pattern from Step 4:

```bash
bash skills/structure-refactor/lib/refactor_apply.sh "$REPO" \
  --mode "$MODE" --scope "$SCOPE" ${APPLY:+--apply}
```

`$MODE` is the already-resolved detected/forced mode from Step 2 (the
conversion guard below runs *before* this call and short-circuits the whole
step when it fires). `$SCOPE` is `mp` or `op`. The script prints the plan
(context lines, then one `[ID] verb detail` line per pending change) and a
`SUMMARY applied=… created=… sourced=… pruned=… stubbed=… renamed=… linked=…
pages=…` line; Step 5's report is built from that output.

R1's real guide content is the one piece the script cannot produce itself
(`/visuals:visualize` is an AI skill invocation): under `--op --apply`, Step 4
calls `/visuals:visualize <SKILL.md>` → `docs/skill-guides/<s>.html` for every
skill still missing that file **before** invoking the script, then invokes
it — the script's own R1 step only ever writes the documented TODO fallback
stub, and only for a guide still missing afterward (delegation unavailable or
failed).

## Plan template (dry-run AND the pre-amble of --apply)

```
claude-plugin structure refactor — <repo-path>   (mode: mono|single[, 추정]  scope: mandatory|recommended)
  plugin roots: <p1> / <p2>   skills: <count>   (git: yes|no, tree: clean|dirty)

계획 (현재 → 목표):
  [M1] create  .claude-plugin/marketplace.json   (skeleton, 1 plugin)
  [M7] source  plugins[].source 주입 (visuals ← ./plugins/visuals | git URL)
  [M3] create  plugins/visuals/.claude-plugin/plugin.json (skeleton)
  [M10] prune  plugins/visuals/.claude-plugin/plugin.json ← 미지원 필드(skills) 제거 (.bak 백업)
  [M5] mkdir   docs/skill-guides/, docs/skill-output/
  [R1] visualize docs/skill-guides/visualize.html   (→ /visuals:visualize, --op only)
  [R2] stub    docs/skill-output/visualize-usage.md  (--op only)
  [Pages] enable GitHub Pages (branch=main, path=/docs) (--op only)
  [R4] rename  SKILL.md name: 교정 → visualize (bare = 디렉터리명)  (--op only)
  [R5] link    README.md ← visualize guide Pages URL 링크 추가 (--op only)

총 <n> 변경  (필수 <m>, 권장 <r>)
```

- The header `mode:` is the detected (or forced) layout — `mono` /
  `single`, with `, 추정` appended when detection was ambiguous (spec
  priority 4). For `single` the action paths are root-relative (`skills/<s>/`,
  root `.claude-plugin/plugin.json`) and **no `plugins/` directory is
  created**; for `mono` they are `plugins/<p>/…` as shown above.
- One line per change: `[<ID>] <verb>  <path / detail>`.
- Verbs: `create` (new file), `mkdir` (new dir), `git mv` / `mv` (move),
  `source` (inject a missing `plugins[].source` into an existing marketplace — M7),
  `prune` (strip unknown top-level fields from an existing `plugin.json`, `.bak` kept — M10),
  `visualize` (generate an R1 guide by delegating to `/visuals:visualize`),
  `stub` (empty placeholder), `pages` (activate GitHub Pages),
  `rename` (frontmatter `name:` fix — never a directory rename),
  `link` (append a per-skill Pages-URL guide link into README — R5).
- Items already correct produce **no line** (idempotent — proof there is
  nothing to do is an empty plan + `총 0 변경`).
- R1-R5 lines appear only when scope is `--op` / `--recommended`. R6-R8 are
  audit-only WARNs (surfaced by structure-check) — refactor never emits a plan
  line or applies a fix for them.
- M2 (no plugin root), M4 (a skill directory exists but its SKILL.md doesn't),
  M8/M9 (a malformed or dangling `plugins[].source`) also produce no
  auto-fix — Apply rule 2's note explains why. They stay whatever
  structure-check reports; a human resolves them.

### Layout-conversion warning (forced mode ≠ detected mode)

When `--single`/`--mono` forces a **target** mode that differs from the
detected **current** layout, refactor does **not** convert (single↔mono is a
whole-plugin relocation + manifest rewrite — out of scope). The plan shows a
single warning line **in place of** any fix lines, and `--apply` stops
without writing:

```
claude-plugin structure refactor — <repo-path>   (mode: single→mono  scope: mandatory)
  plugin roots: . (single)   skills: <count>   (git: yes, tree: clean)

  [convert] 레이아웃 변환 필요 (single → mono) — 현재 미지원, 변경 없음.
            single↔mono 변환은 후속 작업(structure-convert)으로 분리됨.

총 0 변경  (변환 미수행)
```

## Apply rules

Execute the plan in this order so later steps see earlier results:

1. **mkdir** missing dirs: `.claude-plugin/`, `docs/skill-guides/`,
   `docs/skill-output/`, `plugins/<p>/skills/`.
2. **move** misplaced files: `git mv <src> <dst>` inside a git repo;
   `mv <src> <dst>` otherwise. Never overwrite an existing destination.
   **Not automated** — discovery (shared with structure-check) only ever
   finds a skill by its canonical `<root>/skills/<s>/SKILL.md` path, so a
   file sitting somewhere else is invisible to it; there is no reliable
   source path to move *from*. `lib/refactor_apply.sh` does not implement
   this step (M4 stays a manual `git mv` when structure-check reports it).
3. **skeleton** for a missing JSON:
   - `marketplace.json`:
     ```json
     { "name": "<repo-basename>", "plugins": ["./plugins/<p>"] }
     ```
   - `plugins/<p>/.claude-plugin/plugin.json`:
     ```json
     { "name": "<p>", "version": "0.0.0" }
     ```
   Fill `marketplace.json`'s plugins array from the dynamically discovered
   plugin names. Do not clobber a JSON that already parses — only create when
   missing. **plugin.json carries no `skills` array** — the runtime auto-scans
   `skills/`, and a `skills` field fails manifest validation (M10, dEitY719/dotfiles#1084); the
   skeleton stays schema-clean so it satisfies M10 on creation.

   New skeletons are written source-clean: the `marketplace.json` above uses
   `"plugins": ["./plugins/<p>"]` (string = source shorthand) for mono and
   `[{ "source": "./" }]` for single, so a freshly-created skeleton already
   satisfies M7/M8.
3b. **M7 source injection (mandatory — runs under both `--mp` and `--op`)**:
   when a marketplace.json **already exists** and a `plugins[]` **object**
   element lacks its own `source`, inject one (the claude-plugin-jira#61
   install-fail shape). Derivation order per element:
   - if the element has a `homepage`/`repository` ending in `.git` →
     `{ "source": "url", "url": "<that>" }` (remote fetch);
   - else the local path of the detected mode — mono `./plugins/<name>`
     (from the element's `name`), single `"./"`.
   Idempotent: a no-op when every element already carries a source, and never
   touches string-form elements (they are already a source).
3c. **M10 unknown-field prune (mandatory — runs under both `--mp` and `--op`)**:
   for each existing, valid `plugin.json`, drop every top-level key outside the
   known-field whitelist (`name`, `version`, `description`, `author`,
   `homepage`, `repository`, `license`, `keywords`) — the claude-plugin-jira#65
   `skills`-array case that fails manifest validation at load. Copy the file to
   `plugin.json.bak` first (recoverable removal), then rewrite with
   `jq 'with_entries(select(.key as $x | $known | index($x)))'`. Idempotent: a
   no-op (and no `.bak`) when the manifest already has only known fields.
4. **`--op` only — R1 guide (delegate to `/visuals:visualize`)**: for each
   discovered skill `<s>`, if `docs/skill-guides/<s>.html` is **missing**,
   invoke `/visuals:visualize <path-to-SKILL.md>` to generate the guide at
   `docs/skill-guides/<s>.html` — real content, not a stub. Skip when the
   file already exists (idempotent). If `/visuals:visualize` is unavailable or
   fails, warn and fall back to the R1 stub below; never abort the run.
   Fallback stub `docs/skill-guides/<s>.html`:
   ```html
   <!-- TODO: claude-plugin guide for <s> -->
   <!-- 이 가이드는 /visuals:visualize 로 채우세요 (placeholder stub). -->
   ```
5. **`--op` only — R2 usage stub**: empty placeholder
   `docs/skill-output/<s>-usage.md` with a TODO header (unchanged — usage
   samples stay stub level):
   ```markdown
   <!-- TODO: <s> usage sample — fill with /visuals:visualize -->
   ```
   This is always a `.md` stub. The `-usage.{html,md}` extension tolerance in
   `structure-spec.md`'s R2/R5 items is for the **audit** side only, so a repo
   that instead publishes a rendered `-usage.html` (from some other pipeline)
   still passes both checks without this skill ever writing one.
6. **`--op` only — GitHub Pages activation**: derive `$HOST` / `$OWNER` /
   `$REPO` per "Pages host & URL derivation (`--op`)" below. Query the
   current state:
   ```bash
   gh api --hostname "$HOST" "repos/$OWNER/$REPO/pages"
   ```
   If it 404s (Pages inactive), activate it (pipe the JSON in via stdin — no
   bash-only here-string, so the snippet is `/bin/sh`-safe):
   ```bash
   echo '{"source":{"branch":"main","path":"/docs"}}' \
     | gh api --hostname "$HOST" "repos/$OWNER/$REPO/pages" -X POST --input -
   ```
   Skip when Pages already responds 200 (idempotent). Soft-fail: a missing
   token scope or unreachable host warns and continues.
7. **`--op` only — R4 naming**: when a SKILL.md `name:` is not the bare
   directory basename — it carries a colon, or differs from the basename —
   rewrite `name:` in that `SKILL.md` to the basename. Never `git mv` the
   directory: the directory name is the public invocation path
   (`/<plugin>:<dir>`), while `name:` is internal. **Skip the skill entirely**
   when the directory basename itself contains a colon — rewriting `name:` to
   it would just reproduce the violation, and the only other fix is the
   forbidden rename. Emit no plan line for it; R4's WARN stands.
8. **`--op` only — R5 README links**: for each skill `<s>` whose README is
   missing the guide or usage link, append into the README under that
   skill's section — **each missing link only** (check guide and usage
   independently, same as before). The **guide** link now uses the
   Pages-URL format from "Pages host & URL derivation (`--op`)" below; the usage
   link stays a relative path (usage is stub level):
   ```markdown
   - `<s>` ([visual guide ↗](<pages-base>/skill-guides/<s>.html))
   - `<s>` usage: [usage](docs/skill-output/<s>-usage.md)
   ```
   Append only the link(s) actually missing — if the guide is already linked
   (relative `skill-guides/<s>.html` or the Pages URL both count) and only
   the usage is absent, append the usage line alone. Never rewrite or
   reorder existing README content, and never duplicate a link already
   present (idempotent).

Skeleton/stub writes never touch a file that already exists, link backfill
never duplicates an existing link, and Pages activation is skipped when
already active — the skill is idempotent.

## Pages host & URL derivation (`--op`)

Parse `git remote get-url origin` for `<host>/<owner>/<repo>`
(host-independent — works for both `https://` and `git@` forms, and for any
GHE hostname, mirroring `packaging:rename-repo`'s owner/repo parsing):

| Host | `gh api` target | Pages base (`<pages-base>`) |
|------|-----------------|------------------------------|
| `github.com` | `--hostname github.com` | `https://<owner>.github.io/<repo>` |
| GHE (e.g. `github.samsungds.net`) | `--hostname <host>` | `https://<host>/pages/<owner>/<repo>` |

The full R5 guide URL is therefore
`<pages-base>/skill-guides/<s>.html`, e.g.
`https://acme.github.io/claude-plugin-visuals/skill-guides/visualize.html`
(github.com) or
`https://github.samsungds.net/pages/<owner>/<repo>/skill-guides/visualize.html`
(GHE).

## Completion report template

```
## packaging:structure-refactor Report
Repo: <repo-path>
Layout: mono | single  (detected | forced[, 추정])
Mode: dry-run | apply
Scope: mandatory | recommended

Planned: <n>   Applied: <n>   Skipped (already correct): <n>

<the plan block above, with applied lines marked ✓>

[OK] refactor complete   |   [FAIL] <reason>
applied=<n> moved=<n> created=<n> sourced=<n> pruned=<n> visualized=<n> stubbed=<n> renamed=<n> pages=<activated|active|skip|n/a> linked=<n> layout=<mono|single> mode=<dry-run|apply> scope=<mp|op>
```

`created`/`sourced`/`pruned`/`stubbed`/`renamed`/`linked`/`pages` come
straight from `lib/refactor_apply.sh`'s own `SUMMARY` line; `applied` is that
line's `applied` count plus 1 per real (non-fallback) R1 guide Step 4
generated before calling it. `moved` is always `0` — M4 is never automated
(Apply rule 2's note). `visualized` counts only the real
`/visuals:visualize` guides Step 4 generated; a guide the script wrote as a
fallback stub counts toward `stubbed`, not `visualized`. `layout`/`mode`/
`scope` are Step 1/2's own resolved values, not part of the script's output.

For a guarded layout-conversion (forced mode ≠ detected) the report is
`[OK] no conversion (out of scope)` with `applied=0 layout=<from>→<to>` and
the verify hint — never `[FAIL]` (refusing an out-of-scope move is a
safe no-op, not an error).

End with the next-action hint:

- after a dry-run: `Next: /packaging:structure-refactor <path> --apply [--op]`
- after `--apply`: `Next: /packaging:structure-check <path>`

A no-op run (nothing to change) still reports `[OK] refactor complete` with
`applied=0` and the verify hint.

## Constraints (Never / Always)

- **Never** write anything without `--apply`; dry-run only ever prints the
  plan above.
- **Never** auto-apply on a dirty tree — show the dry-run plan and require an
  explicit `--apply`.
- **Never** perform a single↔mono conversion — see "Layout-conversion
  warning" above; `--apply` stops without writing, even when given.
- **Never** abort the run over a soft-fail step (Pages activation, R5 link
  backfill): warn and continue.
- **Always** prefer `git mv` over `mv` inside a git repo, to preserve
  history — for the one move this skill still leaves to a human (M4; Apply
  rule 2's note), not something `lib/refactor_apply.sh` itself does today.
- **Always** discover plugins/skills by scan (repo-agnostic) — the spec in
  `../structure-check/references/structure-spec.md` is abstract, never
  hardcoded to one repo's names.
- **Always** treat an already-standard repo (within scope) as a no-op —
  idempotency is the skill's whole safety story, not an aspiration.
- **Assumes** `structure-check` and `rename-repo` are installed as sibling
  skill directories (`lib/refactor_apply.sh` shells out to
  `../../structure-check/lib/structure_check.sh` and
  `../../rename-repo/lib/parse_remote.sh` by relative path). True for every
  install of this plugin today (`CLAUDE.md`: one plugin, four co-installed
  skills) — if that ever changes, these two paths are the first thing to fix.
