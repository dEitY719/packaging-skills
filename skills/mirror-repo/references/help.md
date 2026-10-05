/packaging:mirror-repo — Mirror an existing external *-skills repo onto GHES

Usage:
  /packaging:mirror-repo <repo-name> [--owner <owner>] [--ghes-owner <owner>]
                         [--dest <path>] [--host <host>] [--ghes-host <host>] [--dry-run]
  /packaging:mirror-repo help

Arguments:
  <repo-name>          Repo name in `<domain>-skills` form (required). A missing
                       `-skills` suffix is auto-appended (you are told). A
                       `claude-plugin-` prefix is REJECTED (pre-#1410 naming).

Flags:
  --owner <owner>      Upstream owner.           default dEitY719
  --ghes-owner <owner> GHES owner.               default = active GHES login
  --dest <path>        Clone parent directory.   default ~/para/project/skills/
  --host <host>        Upstream host.            default github.com
  --ghes-host <host>   GHES host.                default = _gh_resolve_host
  --dry-run            Print the plan only — no clone, no repo, no push.
  -h | --help          Print this help and stop. No filesystem or network calls.

Plan output (Step 2, always printed):
  [PLAN] packaging:mirror-repo
    Source repo  : <host>/<owner>/video-skills
    GHES repo    : <ghes-host>/<ghes-owner>/video-skills
    Destination  : ~/para/project/skills/video-skills/
    Remotes:
      origin    -> git@<ghes-host>:<ghes-owner>/video-skills.git
      upstream  -> https://<host>/<owner>/video-skills.git
    Dry-run     : off
  (--dry-run stops here.)

Behavior:
  0. Resolve both hosts; gh auth status on each; detect the GHES owner.
  1. Validate the name; abort if the dest dir exists, the upstream repo is
     missing, or the GHES repo already exists.
  2. Print the plan (stop if --dry-run).
  3. git clone https://<host>/<owner>/<repo-name>.git <dest>/<repo-name>
  4. gh repo create <ghes-owner>/<repo-name> --private   (after confirmation)
  5. origin -> GHES over SSH, upstream -> source over HTTPS.
  6. git push -u origin <branch>                         (after confirmation)
  7. Verify remotes + GHES repo, print the report.

Completion report (Step 7):
  [OK] packaging:mirror-repo
    Source    : https://<host>/<owner>/video-skills
    GHES repo : https://<ghes-host>/<ghes-owner>/video-skills
    Dest      : ~/para/project/skills/video-skills/
    Remotes   : origin=GHES, upstream=<host>
    Next      : Run skills-sync to verify (should show "already present (skipped)")

Safety:
  - New mirrors only: an existing dest dir or GHES repo aborts the run —
    refreshing a mirror is git-pull-skills.sh's job.
  - GHES repo create and push are each confirmed first; never git push --force.
  - --dry-run writes nothing and creates nothing.
  - marketplaces.json is never edited.

Examples:
  /packaging:mirror-repo video-skills --dry-run
  /packaging:mirror-repo video
  /packaging:mirror-repo notes-skills --ghes-owner my-team --ghes-host ghes.example.com
  /packaging:mirror-repo help

Sister skills:
  /packaging:scaffold-repo       — create a new repo from scratch
  /packaging:rename-repo         — rename a repo to the team convention
  /packaging:structure-check     — read-only layout audit
