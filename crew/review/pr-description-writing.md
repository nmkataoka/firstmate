PR description has two important sections: Motivation/Context and Changes. For Changes, do not regurgitate the PR diff. You should make sure to deeply understand the PR and then break it down structural into major changes. Each major change should mention the key decisions or points of interest that the reviewer would be interested in. The PR description is a high-level introduction to a PR for a reviewer. Minimize direct code references as no one is going to have the diff open side-by-side with the PR description. The PR description should be as concise as possible.

For PRs with visual changes, take screenshots whenever the output is renderable: run the app, render the component, or generate the artifact - whatever the change makes visible.
Save the screenshots locally under the task's data directory at `FM/data/<task-id>/screenshots/`, never inside the project worktree, and report that path in the done report so firstmate can point the captain at them; this local copy is the primary durable record.
Additionally, upload each screenshot to GitHub so PR readers can see it, using a per-PR draft release as the asset host:

```sh
PR_NUM=<pr-number>
UPLOAD_URL=$(gh api repos/<owner>/<repo>/releases -X POST \
  -f tag_name="evidence-${PR_NUM}" \
  -f name="PR #${PR_NUM} Evidence" \
  -F draft=true --jq '.upload_url' | sed 's/{.*//')
ASSET_URL=$(curl -s -X POST "${UPLOAD_URL}?name=<file>.png" \
  -H "Authorization: token $(gh auth token)" \
  -H "Content-Type: image/png" \
  --data-binary "@<local-path>.png" | jq -r '.browser_download_url')
```

Create one draft release per PR and reuse it for every additional upload to the same PR.
The release must stay a draft forever: deleting it kills the asset URLs, while a lingering draft is cheap because drafts are invisible to non-collaborators and create no tag.
Verify an upload from the upload response JSON, never by fetching the asset URL afterward: draft asset URLs are served only to repo collaborators' browser sessions, so anonymous and API-token requests get 404 and a curl 404 does not mean the upload failed.
In the PR description, embed each image inline (`![<label>](<asset-url>)`) and put the plain labeled link directly beneath it, so the link still works if the inline embed renders broken for viewers; if first real use shows inline embeds broken, trim this guidance to links-only.