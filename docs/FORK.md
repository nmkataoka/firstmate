# Fork divergence inventory

## Fork identity and policy

This repository is the `nmkataoka/firstmate` fork of the public `kunchenguid/firstmate` template.
The `origin` remote points to `nmkataoka/firstmate`, and the `upstream` remote points to `kunchenguid/firstmate`.
Pull requests for fork work target `origin` only and must never be opened against `upstream`.
Fork changes live as a small patch stack directly on top of `upstream/main`.
Sync pull requests never introduce new fixes to upstream-owned code; resolve those findings as `out-of-scope-for-sync` and consider filing them upstream instead.

To synchronize, fetch `upstream`, check every retained carry against current upstream behavior, and either rebase its patch, minimally reimplement its purpose, or record why upstream supersedes it.
Rebuild the retained stack on the new `upstream/main` tip with one commit per carry.
Push an exact upstream snapshot branch to `origin`, and open the sync pull request against that snapshot so its diff contains only the fork patch stack.
After captain approval, preserve the previous `main` as `legacy/main-<date>` and land the new stack by force-pushing `main` with a lease.
Never merge the sync pull request through GitHub.
The latest synchronization rebuilt the stack on `upstream/main` at `d6660d7` on 2026-09-05.

## Carried changes

### Watcher fire-time liveness beacon

The watcher re-stamps `state/.last-watcher-beat` on every fire so macOS sleep cannot leave supervision outside the intended post-fire grace window.

- Files touched: `AGENTS.md`, `bin/fm-push-transition-lib.sh`, and `tests/fm-watch-triage.test.sh`.
- Upstream status: retained because the fire path at `d6660d7` still did not stamp the beacon before dispatch.

### Post-implementation dual review

The fork can pin a full or simple review tier into direct-PR briefs, run the review-only no-mistakes pass plus an independent reviewer, and keep reviewer findings off GitHub.

- Files touched: `.agents/skills/pr-review-dispatch/SKILL.md`, `AGENTS.md`, `CONTRIBUTING.md`, `bin/fm-brief.sh`, `bin/fm-review-launch.sh`, `bin/fm-test-run.sh`, `crew/review/diff-review.md`, `crew/review/post-comments.md`, `crew/review/review-procedure.md`, `crew/review/tests-and-comments.md`, `docs/architecture.md`, `docs/configuration.md`, `docs/documentation-audiences.json`, `docs/examples/review.env`, `docs/scripts.md`, `tests/fm-brief.test.sh`, `tests/fm-review-launch.test.sh`, and `tests/fm-test-run.test.sh`.
- Upstream status: retained because upstream had no equivalent review-tier brief scaffold or dual-review launcher at `d6660d7`.

### Visual PR screenshot evidence

Ship briefs allow task-local screenshots, and the review guidance publishes durable PR evidence through per-PR draft release assets with bootstrap-checked prerequisites.

- Files touched: `AGENTS.md`, `bin/fm-bootstrap.sh`, `bin/fm-brief.sh`, `crew/review/pr-description-writing.md`, `docs/cmux-backend.md`, `docs/configuration.md`, `docs/documentation-audiences.json`, `docs/herdr-backend.md`, `docs/zellij-backend.md`, `tests/fm-bootstrap.test.sh`, and `tests/fm-brief.test.sh`.
- Upstream status: retained because upstream ship briefs and review guidance had no equivalent screenshot-evidence workflow at `d6660d7`.

### Linked secondmate primary CD guard

The primary-shell CD guard applies inside linked secondmate homes while continuing to exempt linked crewmate and scout worktrees.

- Files touched: `bin/fm-cd-pretool-check.sh`, `docs/cd-guard.md`, and `tests/fm-cd-pretool-check.test.sh`.
- Upstream status: retained as a clean carry because the guard at `d6660d7` did not recognize linked secondmate primary markers.

### Detached AFK environment propagation

Detached Herdr and tmux AFK launches pass the prepared-state marker and resolved state and config overrides into the daemon child.

- Files touched: `bin/fm-afk-launch.sh` and `tests/fm-afk-launch.test.sh`.
- Upstream status: retained because detached launch commands at `d6660d7` still omitted the prepared marker and resolved overrides.

### Exact Herdr push-wake targets

Herdr blocked-transition wakes pass the exact unannotated window target and separate actionable context to supervision while retaining the diagnostic annotation in the durable queue payload.

- Files touched: `bin/fm-push-transition-lib.sh`, `bin/fm-supervise-daemon.sh`, `docs/herdr-backend.md`, `tests/fm-daemon.test.sh`, and `tests/fm-supervision-events.test.sh`.
- Upstream status: retained because the push path at `d6660d7` still combined the target and diagnostic annotation into one wake argument.

### Conclusive snapshot decision clearing

Fleet snapshots clear single-owner open decisions only after an explicit working, done, or failed lifecycle state, so an inconclusive run-step cannot hide a captain decision.

- Files touched: `bin/fm-fleet-snapshot.sh` and `tests/fm-fleet-snapshot-view.test.sh`.
- Upstream status: retained because the snapshot fold at `d6660d7` still cleared decisions on non-conclusive run-step states.

### Pending AFK delivery across daemon restarts

Fresh away-mode entry preserves buffered escalations and their first-append sidecar while clearing only the stale wedge marker, and launcher rollback never overwrites pending delivery state.

- Files touched: `.agents/skills/afk/SKILL.md`, `bin/fm-afk-launch.sh`, `bin/fm-afk-start.sh`, `docs/herdr-backend.md`, and `tests/fm-afk-launch.test.sh`.
- Upstream status: retained because fresh entry at `d6660d7` still removed the pending escalation buffer.

### Configurable brief resolution verb

Secondmate, scout, and ship briefs render the resolution verb configured through the classifier's canonical `FM_CLASSIFY_RESOLVE_VERB` override.

- Files touched: `bin/fm-brief.sh` and `tests/fm-brief.test.sh`.
- Upstream status: retained because the classifier supported the override at `d6660d7` while the brief scaffolds still hard-coded `resolved`.

### Pinned tasks-axi CI dependency

Behavior-test CI installs the capability-verified `tasks-axi` 0.2.5 release instead of a floating package version.

- Files touched: `.github/workflows/ci.yml` and `tests/fm-lint.test.sh`.
- Upstream status: retained because upstream pull request 1733 raised the floor to 0.2.4 and pull request 3420 pinned one auxiliary install to 0.2.5, but three primary installs still floated at `d6660d7`.

## Dropped at the 2026-09-05 sync

- Durable keyed-decision supervision was removed because upstream pull requests 1711, 1737, 1842, 2330, 2490, 2728, 3696, and 3776 replaced it with bounded authoritative open-decision folds, captain holds, and keyed answer-time clearing across watcher, away, and pending-reply paths.

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
