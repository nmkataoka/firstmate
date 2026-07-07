# Post-implementation review procedure (crew instruction file)

You are the implementing agent.
Your implementation is committed and your PR is open (or firstmate told you to create it first - see "PR creation").
Firstmate has told you the review TIER: `full` or `simple`.
Follow this procedure exactly.

`FM` below is the absolute path of the firstmate root this file lives under; your brief states its value.

## PR creation (if firstmate said no PR exists yet)

- Use the repo's PR template in full (`.github/pull_request_template.md`), per the repo AGENTS.md rules.
- For the Motivation/Context and Changes sections, follow `FM/crew/review/pr-description-writing.md`.

## Round 1 - dual review, in parallel, fresh contexts

Never review your own diff in this session.
Launch two INDEPENDENT reviewers (claude and codex) whose only inputs are the PR/diff and the tier's prompts.

Launch both with `FM/bin/fm-review-launch.sh <tier> <pr-number>`, run from the worktree root.
That script owns the verified launch commands and the per-tier reviewer prompts, launches both reviewers as parallel subprocesses, and captures each reviewer's stdout to a file; run it with `--print` first to inspect the exact commands it will run.
Reviewer models, efforts, launch flags, and the per-repo guideline links baked into the prompts come from the firstmate home's local `config/review.env` when present, with the verified defaults otherwise (format and defaults in the script header).
If a launch fails because a flag does not exist, report it instead of guessing at replacements.

Tier `full` (expensive; runs AT MOST ONCE per PR - never repeat, regardless of outcome):

- The claude prompt has the reviewer use its built-in code-review skill.
- The codex prompt points the reviewer at the review skill at `FM/crew/review/diff-review.md` and contains the words "Use subagents", which MUST appear in the prompt.

Tier `simple` (also used for ALL follow-up rounds after fixes, even on full-tier PRs):

- Both reviewers get a plain review prompt: no skill, no subagents.

Both tiers' prompts have the reviewers consult the repo's review guideline links.
Save each reviewer's findings VERBATIM to files in your worktree tmp; the launch script's capture files satisfy this (do not summarize them before saving).

## Triage and fix

Treat the combined findings as:
"We have some review feedback on your changes. Please investigate and triage these. If you need help making decision, ask me."

- Triage on the merits; apply what is relevant.
  You do not need permission for routine fixes.
- If a finding genuinely challenges intent/product behavior and you cannot decide, report `needs-decision:` with the finding, per your brief.

## Follow-up rounds

After applying fixes, run one `simple` round (both reviewers).
Repeat triage/fix until a round comes back clean or with only findings you deliberately reject (note rejections in your final report).
HARD CAP: 3 review rounds total (initial + 2 follow-ups).
After round 3, do NOT launch another round no matter what it returned - fix what is clearly real, list everything else as rejected/deferred in your final report, and move to the cleanup pass.
Reviewer suggestions converge asymptotically; past round 3 they are nits, and review fixes themselves keep generating new nits.

## Cleanup pass (once, after all review rounds are resolved)

Run one fresh-context claude reviewer over the final branch diff with the prompt in `FM/crew/review/tests-and-comments.md` (adapted to the branch/PR diff rather than staged changes).
Use the same claude launch mechanics as the round reviews (`fm-review-launch.sh --print` shows the claude command; substitute the adapted prompt).
Triage and apply the same way.

## Finish

Format/lint per repo pre-push rules, push, ensure the PR description still matches the final state, then report `done: PR <url>` with a one-line note of any rejected findings.
