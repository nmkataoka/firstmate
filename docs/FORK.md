# Fork divergence inventory

## Fork identity and policy

This repository is the `nmkataoka/firstmate` fork of the public `kunchenguid/firstmate` template.
The `origin` remote points to `nmkataoka/firstmate`, and the `upstream` remote points to `kunchenguid/firstmate`.
Pull requests for fork work target `origin` only and must never be opened against `upstream`.
The goal of an upstream merge is to effectively rebase our intended workflow changes and absolutely necessary fixes to things we use in the minimal possible diff on top of latest upstream.
Sync pull requests never introduce new fixes to upstream-owned code; resolve those findings as `out-of-scope-for-sync` and consider filing them upstream instead.

To synchronize, fetch `upstream`, merge `upstream/main` into a fork branch with a merge commit, resolve the fork inventory deliberately, and open the resulting pull request against `origin`.
Never rebase an upstream synchronization because preserving upstream history keeps future merge bases reliable.
The latest synchronization merged `upstream/main` at `daf6dce` on 2026-07-29.

## Carried changes

### Watcher fire-time liveness beacon

The watcher re-stamps `state/.last-watcher-beat` on every fire so macOS sleep cannot leave supervision outside the intended post-fire grace window.

- Files touched: `AGENTS.md`, `bin/fm-guard.sh`, `bin/fm-push-transition-lib.sh`, and `tests/fm-watch-triage.test.sh`.
- Upstream status: fork-only behavior with no equivalent in `upstream/main` at `daf6dce`.

### Post-implementation dual review

The fork can pin a full or simple review tier into direct-PR briefs, run the review-only no-mistakes pass plus an independent reviewer, and keep reviewer findings off GitHub.

- Files touched: `.agents/skills/pr-review-dispatch/SKILL.md`, `.gitignore`, `AGENTS.md`, `CONTRIBUTING.md`, `bin/fm-brief.sh`, `bin/fm-review-launch.sh`, `crew/review/diff-review.md`, `crew/review/post-comments.md`, `crew/review/review-procedure.md`, `crew/review/tests-and-comments.md`, `docs/architecture.md`, `docs/configuration.md`, `docs/examples/review.env`, `docs/scripts.md`, `tests/fm-brief.test.sh`, and `tests/fm-review-launch.test.sh`.
- Upstream status: fork-only workflow that is not proposed for upstream.

### Visual PR screenshot evidence

Ship briefs allow task-local screenshots, and the review guidance publishes durable PR evidence through per-PR draft release assets with bootstrap-checked prerequisites.

- Files touched: `AGENTS.md`, `bin/fm-bootstrap.sh`, `bin/fm-brief.sh`, `crew/review/pr-description-writing.md`, `docs/cmux-backend.md`, `docs/configuration.md`, `docs/herdr-backend.md`, `docs/zellij-backend.md`, `tests/fm-bootstrap.test.sh`, `tests/fm-brief.test.sh`, and `tests/fm-x-mode.test.sh`.
- Upstream status: fork-only workflow that is not proposed for upstream.

### Linked secondmate primary CD guard

The primary-shell CD guard applies inside linked secondmate homes while continuing to exempt linked crewmate and scout worktrees.

- Files touched: `bin/fm-cd-pretool-check.sh`, `docs/cd-guard.md`, and `tests/fm-cd-pretool-check.test.sh`.
- Upstream status: fork-only review fix with no equivalent in `upstream/main` at `daf6dce`.

### Detached AFK environment propagation

Detached Herdr and tmux AFK launches pass the prepared-state marker and resolved state and config overrides into the daemon child.

- Files touched: `bin/fm-afk-launch.sh` and `tests/fm-afk-launch.test.sh`.
- Upstream status: fork-only review fix with no equivalent in `upstream/main` at `daf6dce`.

### Exact Herdr push-wake targets

Herdr blocked-transition wakes pass the exact unannotated window target and separate actionable context to supervision while retaining the diagnostic annotation in the durable queue payload.

- Files touched: `bin/fm-push-transition-lib.sh`, `bin/fm-supervise-daemon.sh`, `docs/herdr-backend.md`, `tests/fm-daemon.test.sh`, and `tests/fm-supervision-events.test.sh`.
- Upstream status: fork-only review fix with no equivalent in `upstream/main` at `daf6dce`.

### Durable keyed-decision supervision

The watcher and away daemon classify the authoritative keyed-decision fold, retain open decisions behind later events, and include the latest distinct captain-relevant event in their dedupe summary.

- Files touched: `bin/fm-classify-lib.sh`, `bin/fm-push-transition-lib.sh`, `bin/fm-supervise-daemon.sh`, `docs/architecture.md`, `tests/fm-daemon.test.sh`, and `tests/fm-watch-triage.test.sh`.
- Upstream status: fork-only review fix with no equivalent in `upstream/main` at `daf6dce`.

### Conclusive snapshot decision clearing

Fleet snapshots clear single-owner open decisions only after an explicit working, done, or failed lifecycle state, so an inconclusive run-step cannot hide a captain decision.

- Files touched: `bin/fm-fleet-snapshot.sh` and `tests/fm-fleet-snapshot-view.test.sh`.
- Upstream status: fork-only review fix with no equivalent in `upstream/main` at `daf6dce`.

### Pending AFK delivery across daemon restarts

Fresh away-mode entry preserves buffered escalations and their first-append sidecar while clearing only the stale wedge marker, and launcher rollback never overwrites pending delivery state.

- Files touched: `.agents/skills/afk/SKILL.md`, `bin/fm-afk-launch.sh`, `bin/fm-afk-start.sh`, `docs/herdr-backend.md`, and `tests/fm-afk-launch.test.sh`.
- Upstream status: fork-only review fix with no equivalent in `upstream/main` at `daf6dce`.

### Configurable brief resolution verb

Secondmate, scout, and ship briefs render the resolution verb configured through the classifier's canonical `FM_CLASSIFY_RESOLVE_VERB` override.

- Files touched: `bin/fm-brief.sh` and `tests/fm-brief.test.sh`.
- Upstream status: fork-only review fix with no equivalent in `upstream/main` at `daf6dce`.

### Pinned tasks-axi CI dependency

Behavior-test CI installs the capability-verified `tasks-axi` 0.2.2 release instead of a floating package version.

- Files touched: `.github/workflows/ci.yml` and `tests/fm-lint.test.sh`.
- Upstream status: fork-only review fix with no equivalent in `upstream/main` at `daf6dce`.

## Repairs added during the 2026-07-29 sync

- `bin/fm-spawn.sh` now fails closed and runs backend cleanup when task metadata publication fails under stock macOS Bash 3.2; upstream's compound-command redirection continued after the failure on Bash 3.2.
- `tests/fm-session-start.test.sh` derives concurrent contender identities without `BASHPID`, which stock macOS Bash 3.2 does not provide.

## Dropped at the 2026-07-29 sync

- The GOTMP fixture reconciliation carry was removed because upstream pull request 527 landed the equivalent composer-library fixture.
- The watcher restart PID-ownership carry was removed because upstream pull request 693's continuous-cycle watcher design supersedes that narrower race fix.
- The Herdr secondmate liveness confidence carry was removed by captain decision because upstream pull request 950's recovery-grade classifier supersedes the fork's Claude/Codex-only confidence gate for every verified harness.

## Dropped at the 2026-07-12 sync

- The fork's `fm-stale-ack.sh` mechanism was removed in favor of upstream pull request 421 at `7788fa3`, which uses `paused: <reason>` for declared external waits.
- The fork's positional-relevance arm-command seatbelt patch was removed in favor of upstream pull request 403 at `22b1d71`, including the `bin/fm-arm-command-policy.mjs` engine and its upstream transport, documentation, and tests.
- Claude background-task pane markers as working evidence were dropped by captain decision on 2026-07-12 to reduce future synchronization friction.
- The configurable `config/branch-prefix` feature was dropped by captain decision on 2026-07-12, so scaffolded task branches again use `fm/<id>`.

## Maintenance rule

Update this file in the same pull request as every upstream synchronization or fork-feature change.
