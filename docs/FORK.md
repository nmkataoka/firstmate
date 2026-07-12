# Fork divergence inventory

## Fork identity and policy

This repository is the `nmkataoka/firstmate` fork of the public `kunchenguid/firstmate` template.
The `origin` remote points to `nmkataoka/firstmate`, and the `upstream` remote points to `kunchenguid/firstmate`.
Pull requests for fork work target `origin` only and must never be opened against `upstream`.

To synchronize, fetch `upstream`, merge `upstream/main` into a fork branch with a merge commit, resolve the fork inventory deliberately, and open the resulting pull request against `origin`.
Never rebase an upstream synchronization because preserving upstream history keeps future merge bases reliable.

## Carried changes

### Watcher fire-time liveness beacon

The watcher re-stamps `state/.last-watcher-beat` on every fire so macOS sleep cannot leave supervision outside the intended post-fire grace window.

- Files touched: `AGENTS.md`, `bin/fm-guard.sh`, `bin/fm-watch.sh`, and `tests/fm-watch-triage.test.sh`.
- Upstream status: fork-only behavior with no equivalent in `upstream/main` at `ad9f3a7`.

### Post-implementation dual review

The fork can pin a full or simple review tier into direct-PR briefs, run the review-only no-mistakes pass plus an independent reviewer, and keep reviewer findings off GitHub.

- Files touched: `.agents/skills/pr-review-dispatch/SKILL.md`, `.gitignore`, `AGENTS.md`, `CONTRIBUTING.md`, `bin/fm-brief.sh`, `bin/fm-review-launch.sh`, `crew/review/diff-review.md`, `crew/review/post-comments.md`, `crew/review/review-procedure.md`, `crew/review/tests-and-comments.md`, `docs/architecture.md`, `docs/configuration.md`, `docs/examples/review.env`, `docs/scripts.md`, `tests/fm-brief.test.sh`, and `tests/fm-review-launch.test.sh`.
- Upstream status: fork-only workflow that is not proposed for upstream.

### Visual PR screenshot evidence

Ship briefs allow task-local screenshots, and the review guidance publishes durable PR evidence through per-PR draft release assets with bootstrap-checked prerequisites.

- Files touched: `AGENTS.md`, `bin/fm-bootstrap.sh`, `bin/fm-brief.sh`, `crew/review/pr-description-writing.md`, `docs/cmux-backend.md`, `docs/configuration.md`, `docs/herdr-backend.md`, `docs/zellij-backend.md`, `tests/fm-bootstrap.test.sh`, `tests/fm-brief.test.sh`, and `tests/fm-x-mode.test.sh`.
- Upstream status: fork-only workflow that is not proposed for upstream.

### Upstream GOTMP fixture reconciliation

The GOTMP teardown fixture includes the shared composer library that upstream's real tmux helper now sources through the fixture's fake root.

- Files touched: `tests/fm-gotmp.test.sh`.
- Upstream status: `upstream/main` at `ad9f3a7` fails this test because the fixture omits that transitive dependency, so the fork carries the minimal fixture repair until upstream includes an equivalent fix.

### Linked secondmate primary CD guard

The primary-shell CD guard applies inside linked secondmate homes while continuing to exempt linked crewmate and scout worktrees.

- Files touched: `bin/fm-cd-pretool-check.sh` and `tests/fm-cd-pretool-check.test.sh`.
- Upstream status: fork-only review fix with no equivalent in `upstream/main` at `ad9f3a7`.

### Herdr secondmate liveness confidence

Bootstrap treats a Herdr dead reading as conclusive only for Claude and Codex, whose agent registration Herdr can verify, so an unregistered Grok, OpenCode, or Pi process cannot trigger a duplicate secondmate.

- Files touched: `bin/fm-bootstrap.sh` and `tests/fm-secondmate-liveness.test.sh`.
- Upstream status: fork-only review fix with no equivalent in `upstream/main` at `ad9f3a7`.

### Watcher restart PID ownership

Watcher restart rejects the PID it just signaled as the healthy replacement, so a TERM-resistant watcher cannot make restart report success immediately before it exits.

- Files touched: `bin/fm-watch-arm.sh` and `tests/fm-watcher-lock.test.sh`.
- Upstream status: fork-only review fix with no equivalent in `upstream/main` at `ad9f3a7`.

### Detached AFK environment propagation

Detached Herdr and tmux AFK launches pass the prepared-state marker and resolved state and config overrides into the daemon child.

- Files touched: `bin/fm-afk-launch.sh` and `tests/fm-afk-launch.test.sh`.
- Upstream status: fork-only review fix with no equivalent in `upstream/main` at `ad9f3a7`.

### Exact Herdr push-wake targets

Herdr blocked-transition wakes pass the exact unannotated window target and separate actionable context to supervision while retaining the diagnostic annotation in the durable queue payload.

- Files touched: `bin/fm-watch.sh`, `bin/fm-supervise-daemon.sh`, `tests/fm-daemon.test.sh`, and `tests/fm-supervision-events.test.sh`.
- Upstream status: fork-only review fix with no equivalent in `upstream/main` at `ad9f3a7`.

### Durable keyed-decision supervision

The watcher and away daemon classify the authoritative keyed-decision fold, retain open decisions behind later events, and include the latest distinct captain-relevant event in their dedupe summary.

- Files touched: `bin/fm-classify-lib.sh`, `bin/fm-supervise-daemon.sh`, `bin/fm-watch.sh`, `tests/fm-daemon.test.sh`, and `tests/fm-watch-triage.test.sh`.
- Upstream status: fork-only review fix with no equivalent in `upstream/main` at `ad9f3a7`.

### Conclusive snapshot decision clearing

Fleet snapshots clear single-owner open decisions only after an explicit working, done, or failed lifecycle state, so an inconclusive run-step cannot hide a captain decision.

- Files touched: `bin/fm-fleet-snapshot.sh` and `tests/fm-fleet-snapshot-view.test.sh`.
- Upstream status: fork-only review fix with no equivalent in `upstream/main` at `ad9f3a7`.

### Pinned tasks-axi CI dependency

Behavior-test CI installs the capability-verified `tasks-axi` 0.2.2 release instead of a floating package version.

- Files touched: `.github/workflows/ci.yml` and `tests/fm-lint.test.sh`.
- Upstream status: fork-only review fix with no equivalent in `upstream/main` at `ad9f3a7`.

## Dropped at the 2026-07-12 sync

- The fork's `fm-stale-ack.sh` mechanism was removed in favor of upstream pull request 421 at `7788fa3`, which uses `paused: <reason>` for declared external waits.
- The fork's positional-relevance arm-command seatbelt patch was removed in favor of upstream pull request 403 at `22b1d71`, including the `bin/fm-arm-command-policy.mjs` engine and its upstream transport, documentation, and tests.
- Claude background-task pane markers as working evidence were dropped by captain decision on 2026-07-12 to reduce future synchronization friction.
- The configurable `config/branch-prefix` feature was dropped by captain decision on 2026-07-12, so scaffolded task branches again use `fm/<id>`.

## Maintenance rule

Update this file in the same pull request as every upstream synchronization or fork-feature change.
