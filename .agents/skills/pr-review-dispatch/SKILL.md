---
name: pr-review-dispatch
description: >-
  Agent-only reference for dispatching the post-implementation dual-review workflow.
  Use at intake before dispatching a ship task that should carry the dual review (a review-only no-mistakes pipeline pass plus a claude second reviewer), when choosing the review tier for a PR, or before scaffolding a brief with fm-brief.sh --review.
  Covers the two-tier routing rule, real-line size measurement excluding codegen, the at-most-once full-tier rule, PR sizing strategy, and the config/review.env indirection.
user-invocable: false
metadata:
  internal: true
---

# pr-review-dispatch

Load this at intake before dispatching a ship task that should carry the post-implementation dual review, before choosing the review tier for a PR, and before scaffolding a brief with `--review`.

## What this workflow is

After implementation, the crewmate runs a review-only no-mistakes pipeline pass over its branch (reviewer 1, on the operator's configured no-mistakes agent), then launches one INDEPENDENT fresh-context claude second reviewer over its PR (reviewer 2), and finishes with one cleanup pass - explicitly in that order, before the work is ready for the captain.
Two independent reviews per PR is the standard initial round, not one review plus an optional extra.
The crew-side procedure lives at `crew/review/review-procedure.md` and is the one owner of the stage, cleanup, and rejection rules, including the verified review-only invocation and gate setup; `bin/fm-review-launch.sh` is the one owner of the verified reviewer launch commands and per-tier prompts.
Firstmate never runs the review itself; it decides the tier, hands the contract to the crewmate through the brief, and triages the pipeline review gate's findings when the crewmate escalates them (captain decision 2026-07-09: review auto-fix stays off, so pipeline findings park for firstmate triage).

## Principles

- Reviews run as SEPARATE fresh-context agents, never the implementer self-reviewing in-session.
- Pipeline review-gate findings are firstmate-triaged; the implementer relays them via `needs-decision:` and feeds the decisions back to the gate.
- The implementer IS allowed to triage the claude second reviewer's feedback itself (captain confirmed; it almost never needs help).
- The expensive full-tier workflow runs AT MOST ONCE per PR (~1-2M tokens); the cap constrains that workflow only, never the number of reviewers.
  Follow-up rounds after fixes use the cheaper re-review path - a pipeline re-review or a simple-tier round - never zero review and never a repeat of the full-tier workflow.

## Choosing the tier (firstmate's call at intake)

TWO TIERS ONLY:

- Small or frontend-only PRs: `simple` - the claude second reviewer gets a plain review prompt with no skill.
- Everything else: `full` - the claude reviewer uses its built-in code-review skill, at most once.

The tier shapes only the claude second-reviewer pass; the pipeline review pass and the cleanup pass are tier-independent.

Size is measured in REAL lines: exclude codegen (GraphQL/Hasura types; cdktf output in infra).
Tests count.
~1k real lines = large threshold.

## Carrying the contract

Scaffold the brief with `bin/fm-brief.sh <id> <repo> --review=<full|simple>`.
The generated section pins the tier and points the crewmate at `crew/review/review-procedure.md` by absolute path; the crewmate needs nothing outside the tracked repo plus the optional local config below.
The flag is verified for direct-PR projects only; the scaffold refuses other modes rather than emitting an unverified contract.

## Config indirection (config/review.env)

Reviewer models, efforts, launch flags, and per-repo guideline links are LOCAL, gitignored values in `config/review.env`, read by `bin/fm-review-launch.sh` with the pilot-verified values as defaults (key reference in the script header; template in `docs/examples/review.env`).
An absent file means the verified defaults apply, so a fresh home works without setup.
`config/review.env` is per-home and not in the inheritable config set today; a secondmate home without its own copy uses the defaults.

## PR sizing strategy (captain guidance)

Do not break work into small PRs just to dodge or justify the expensive review.
The conventional habit (sub-500-line chunks for human reviewability, sacrificing atomicity) can invert here: prefer keeping related work together as one coherent 1-2k line PR, run the expensive review ONCE on the whole thing, then optionally split the finalized code into a stack of smaller PRs afterward for human reviewability and safer deployment and rollbacks.
Draw PR lines for coherence first, review economics second.

## No PR yet variant

When no PR exists at review time, the review targets the staged changes or the last N commits instead, attached to a non-leading PR description generated with `crew/review/pr-description-writing.md`.
The procedure's "PR creation" section covers the normal case where the crewmate raises the PR before reviewing.

## Out of scope for the implementation path

`crew/review/post-comments.md` is the comment-formatting prompt for agent-reviewing OTHER people's PRs (concise quoted-block comments, `nit:` prefix, softened phrasing).
Keep it, but do not wire it into the implementation flow.
