# Post-implementation review procedure (crew instruction file)

You are the implementing agent.
Your implementation is committed and your PR is open (or firstmate told you to create it first - see "PR creation").
Firstmate has told you the review TIER: `full` or `simple`.
Follow this procedure exactly.

`FM` below is the absolute path of the firstmate root this file lives under; your brief states its value.

## Prerequisites (gate setup and auto-fix posture)

Stage 1 below runs the no-mistakes pipeline, so the repo clone you are in needs the no-mistakes gate.
Firstmate initializes its own project clone once, under its sanctioned project-initialization exception: `cd projects/<name> && no-mistakes init && no-mistakes doctor`.
Your task worktree is a separate clone, so check it yourself before stage 1: run `no-mistakes doctor`, and if it reports the repo is not initialized here, run `no-mistakes init`.
No config change is part of this flow: review auto-fix stays at the global default (`auto_fix.review: 0`), so every blocking or ask-user review finding parks at an approval gate for firstmate triage instead of being self-fixed.
That parking is the intended standing mechanism, not a failure.
If self-driving review fix rounds are ever wanted later, the verified opt-in is a committed per-repo `.no-mistakes.yaml` containing `auto_fix:` with `review: 3`; no-mistakes v1.31.2 honors it from the pushed branch content, so it takes effect from the first branch that carries it (verified 2026-07-10).

## PR creation (if firstmate said no PR exists yet)

- Use the repo's PR template in full (`.github/pull_request_template.md`), per the repo AGENTS.md rules.
- For the Motivation/Context and Changes sections, follow `FM/crew/review/pr-description-writing.md`.

## Stage 1 - pipeline review (reviewer 1 of 2, review-only no-mistakes run)

Every PR gets two independent reviews on the initial round: this pipeline review, then the claude second review in stage 2.
Never review your own diff in this session; this stage runs a fresh reviewer inside the no-mistakes pipeline, on the operator's globally configured no-mistakes agent (`agent:` in `~/.no-mistakes/config.yaml`; codex as of 2026-07-10).
From the worktree root, on your task branch with everything committed, run:

    no-mistakes axi run --intent "<what the user set out to accomplish>" --skip rebase,test,document,lint,push,pr,ci

That invocation runs the pipeline with only the review step active (verified on no-mistakes v1.31.2; `intent` stays listed as a step but completes instantly from the `--intent` flag).
Drive the run per no-mistakes' own guidance: read every return, remember a long-running call is working rather than stalled, and loop until an `outcome:`.
When the run parks at the review gate (`review: awaiting_approval`) with findings, do not triage them yourself: report `needs-decision:` with the findings relayed verbatim, per your brief, and stop until firstmate replies.
Firstmate owns the triage for this gate.
Feed its per-finding decisions back with `no-mistakes axi respond --action fix --findings <ids>` (or `--action approve` to accept the step as-is), and let the pipeline apply every fix - do not hand-edit or commit fixes while the run is active.
Avoid `--yes`.
The terminal state for this shape is `status: completed` with `outcome: passed`, the review step `completed`, and every other step `skipped`; a `fixes[]` list means the pipeline committed fixes.

Because the push step is skipped, pipeline fix commits exist only on the local `no-mistakes` gate remote, not on your branch or origin.
If the run applied fixes (the reported `head:` moved past your commit), bring them onto your branch:

    git fetch no-mistakes <your-branch>
    git merge --ff-only FETCH_HEAD

The fast-forward is safe for this shape because the rebase step was skipped, so fixes are appended commits (verified 2026-07-10); if `--ff-only` refuses, stop and report `blocked:`.

Known trigger quirk (observed 2026-07-10): if `axi run` fails with `no run started for "<branch>"` and the gate repo's `notify-push.log` shows `invalid gate path: .`, trigger the run manually - `git push no-mistakes <branch>` starts an unskipped run, abort it with `no-mistakes axi abort --run <id>`, then repeat the `axi run` invocation above; the rerun path applies the skip flags correctly.

## Stage 2 - claude second reviewer (reviewer 2 of 2, after stage 1 resolves)

This second review is part of the standard initial round for every PR, not an optional extra.
Launch one INDEPENDENT fresh-context claude reviewer whose only inputs are the PR/diff and the tier's prompt.
Run `FM/bin/fm-review-launch.sh <tier> <pr-number> --print` from the worktree root to get the verified launch commands, then run ONLY the printed claude command, capturing its stdout verbatim to a file in your worktree tmp (do not summarize it before saving).
Do not run the printed codex command as a review round - the pipeline review in stage 1 is the codex review.
Reviewer model, effort, launch flags, and the per-repo guideline links baked into the prompt come from the firstmate home's local `config/review.env` when present, with the verified defaults otherwise (format and defaults in the script header).
If the launch fails because a flag does not exist, report it instead of guessing at replacements.

Tier `full` (expensive): the claude prompt has the reviewer use its built-in code-review skill.
The full-tier workflow runs AT MOST ONCE per PR - never repeat it, regardless of outcome; the cap constrains this expensive workflow only, never the number of reviewers.
Tier `simple`: a plain review prompt, no skill.

Then triage the claude findings yourself.
Treat them as: "We have some review feedback on your changes. Please investigate and triage these. If you need help making decision, ask me."

- Triage on the merits; apply what is relevant (no pipeline run is active now, so you make these fixes yourself).
  You do not need permission for routine fixes.
- If a finding genuinely challenges intent/product behavior and you cannot decide, report `needs-decision:` with the finding, per your brief.

If your stage 2 fixes were substantive (behavior changes, not nits), re-review them before the cleanup pass via the cheaper re-review path: run stage 1 once more over the updated branch, or launch one `simple`-tier claude round.
A follow-up round is never zero review, and it never repeats the full-tier workflow.
HARD CAP: three review rounds total (the initial two-reviewer round plus two follow-ups).
Past that, fix what is clearly real, list everything else as rejected/deferred in your final report, and move to the cleanup pass.

## Cleanup pass (once, AFTER all review fixes are applied)

This pass is strictly sequenced after stages 1-2 and their fixes; it is never a parallel third reviewer.
Run one fresh-context claude reviewer over the final branch diff with the prompt in `FM/crew/review/tests-and-comments.md` (adapted to the branch/PR diff rather than staged changes).
Use the claude launch mechanics from `fm-review-launch.sh --print` (substitute the adapted prompt).
Triage and apply the same way.

## Finish

Format/lint per repo pre-push rules, push (your branch now includes any fetched pipeline fix commits), ensure the PR description still matches the final state, then report `done: PR <url>` with a one-line note of any rejected findings.
