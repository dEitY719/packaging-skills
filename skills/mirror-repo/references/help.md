/packaging:mirror-repo — Mirror an existing repo onto another host (e.g. github.com -> GHES)

Usage:
  /packaging:mirror-repo --upstream <url> --origin <url> [--dest <path>]
                         [--visibility public|private] [--dry-run]
  /packaging:mirror-repo help

Flags:
  --upstream <url>     Source repo to clone (required).
  --origin <url>       Mirror repo to create and push to (required). Its repo
                       name is used verbatim — no naming convention enforced.
  --dest <path>        Clone parent directory.   default ~/para/project/
  --visibility <v>     Mirror repo visibility.   default private (public|private only)
  --dry-run            Print the plan only — no clone, no repo, no push.
  -h | --help          Print this help and stop. No filesystem or network calls.

URL forms (both flags; `.git` optional; used verbatim for clone and remotes):
  https://<host>/<owner>/<repo>.git   http://<host>/<owner>/<repo>.git
  git@<host>:<owner>/<repo>.git       ssh://git@<host>/<owner>/<repo>.git

Plan output (Step 2, always printed):
  [PLAN] packaging:mirror-repo
    Source repo  : github.com/dEitY719/equinest
    Mirror repo  : <ghes-host>/<owner>/equinest
    Destination  : ~/para/project/equinest/
    Remotes:
      origin    -> git@<ghes-host>:<owner>/equinest.git
      upstream  -> https://github.com/dEitY719/equinest.git
    Visibility  : private
    Dry-run     : off
  (--dry-run stops here.)

Behavior:
  0. Parse both URLs offline; gh auth status on both hosts.
  1. Abort on a malformed URL, origin host == upstream host, an internal PC
     with a github.com origin, an existing dest dir, a missing upstream repo,
     or an existing mirror repo.
  2. Print the plan (stop if --dry-run).
  3. git clone <upstream-url> <dest>/<repo>
  4. gh repo create <owner>/<repo> --public|--private   (after confirmation)
  5. origin -> <origin-url>, upstream -> <upstream-url>.
  6. git push -u origin <branch>                         (after confirmation)
  7. Verify remotes + mirror repo, print the report.

Completion report (Step 7):
  [OK] packaging:mirror-repo
    Source  : https://github.com/dEitY719/equinest.git
    Mirror  : git@<ghes-host>:<owner>/equinest.git
    Dest    : ~/para/project/equinest/
    Remotes : origin=<ghes-host>, upstream=github.com

Safety:
  - New mirrors only: an existing dest dir or mirror repo aborts the run.
  - Origin host must differ from upstream host. On an internal PC
    (~/.dotfiles-setup-mode = internal) a github.com origin aborts.
  - Mirror repo create and push are each confirmed first; never git push --force.
  - --dry-run writes nothing and creates nothing.
  - --visibility public is refused when the upstream repo is not PUBLIC.
  - marketplaces.json is never edited.

Examples:
  # Check the plan first (dry-run)
  /packaging:mirror-repo --upstream https://github.com/dEitY719/equinest.git \
                         --origin git@ghes.example.com:my-user/equinest.git --dry-run
  # SSH (scp-form) origin
  /packaging:mirror-repo --upstream https://github.com/dEitY719/video-skills.git \
                         --origin git@ghes.example.com:my-user/video-skills.git
  # HTTPS origin with a custom --dest
  /packaging:mirror-repo --upstream https://github.com/dEitY719/notes-skills.git \
                         --origin https://ghes.example.com/my-user/notes-skills.git \
                         --dest ~/work/mirrors
  # URLs without the .git suffix
  /packaging:mirror-repo --upstream https://github.com/dEitY719/equinest \
                         --origin git@ghes.example.com:my-user/equinest
  # Public mirror under a team owner
  /packaging:mirror-repo --upstream https://github.com/dEitY719/herdr-skills.git \
                         --origin ssh://git@ghes.example.com/my-team/herdr-skills.git \
                         --visibility public
  /packaging:mirror-repo help

Sister skills:
  /packaging:scaffold-repo       — create a new repo from scratch
  /packaging:rename-repo         — rename a repo to the team convention
  /packaging:structure-check     — read-only layout audit
