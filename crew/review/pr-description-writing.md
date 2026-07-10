PR description has two important sections: Motivation/Context and Changes.
For Changes, do not regurgitate the PR diff.
You should make sure to deeply understand the PR and then break it down structurally into major changes.
Each major change should mention the key decisions or points of interest that the reviewer would be interested in.
The PR description is a high-level introduction to a PR for a reviewer.
Minimize direct code references as no one is going to have the diff open side-by-side with the PR description.
The PR description should be as concise as possible.

For PRs with visual changes, take screenshots whenever the output is renderable: run the app, render the component, or generate the artifact - whatever the change makes visible.
Save the screenshots locally under the task's data directory at `FM/data/<task-id>/screenshots/`, never inside the project worktree, and report that path in the done report so firstmate can point the captain at them; this local copy is the primary durable record.
Additionally, upload each screenshot to the PR base repository so its collaborators can see it, using a per-PR draft release as the asset host:

```sh
set -eu
PR_NUM="<pr-number>"
REPO="<pr-base-owner>/<pr-base-repo>"
FILE_PATH="<local-path>.png"
FILE_NAME="<file>.png"
TAG="evidence-${PR_NUM}"

[ -f "$FILE_PATH" ] || exit 1
if ! jq -en --arg name "$FILE_NAME" '$name | test("^[a-z0-9]+(-[a-z0-9]+)*\\.png$")' >/dev/null; then
  exit 1
fi

if ! RELEASES=$(gh api --paginate "repos/${REPO}/releases?per_page=100" \
  --jq ".[] | select(.draft == true and .tag_name == \"${TAG}\") | {id, upload_url}"); then
  exit 1
fi
RELEASE=$(printf '%s\n' "$RELEASES" | sed -n '1p')
if [ -z "$RELEASE" ]; then
  if ! RELEASE=$(gh api "repos/${REPO}/releases" -X POST \
    -f tag_name="$TAG" \
    -f name="PR #${PR_NUM} Evidence" \
    -F draft=true); then
    exit 1
  fi
fi
if ! UPLOAD_URL=$(printf '%s\n' "$RELEASE" | jq -er '.upload_url | select(type == "string" and length > 0)'); then
  exit 1
fi
UPLOAD_URL=${UPLOAD_URL%%\{*}
[ -n "$UPLOAD_URL" ] && [ "$UPLOAD_URL" != null ] || exit 1

if ! ENCODED_FILE_NAME=$(jq -rn --arg name "$FILE_NAME" '$name | @uri'); then
  exit 1
fi
[ -n "$ENCODED_FILE_NAME" ] || exit 1
AUTH_TOKEN=$(gh auth token)
[ -n "$AUTH_TOKEN" ] || exit 1
if ! UPLOAD_RESPONSE=$(curl -sS --fail -X POST \
  "${UPLOAD_URL}?name=${ENCODED_FILE_NAME}" \
  --config - \
  -H "Content-Type: image/png" \
  --data-binary "@${FILE_PATH}" <<EOF
header = "Authorization: token ${AUTH_TOKEN}"
EOF
); then
  unset AUTH_TOKEN
  exit 1
fi
unset AUTH_TOKEN
if ! ASSET_URL=$(printf '%s\n' "$UPLOAD_RESPONSE" | \
  jq -er 'select(.state == "uploaded") | .browser_download_url | select(type == "string" and length > 0)'); then
  exit 1
fi
[ -n "$ASSET_URL" ] && [ "$ASSET_URL" != null ] || exit 1
```

This upload applies only when the author has push access to the PR base repository, and the asset links are for that repository's collaborators viewing them in authenticated browser sessions.
For fork-based upstream contributions without base-repository push access, skip the upload and rely on the local `FM/data/<task-id>/screenshots/` copy.
The snippet finds or creates one draft release per PR and reuses it for every additional upload to the same PR.
Uploaded asset names are immutable, so use a unique safe kebab-case filename for every upload.
After a failed upload or a regenerated screenshot, append a new version suffix such as `-v2`, never reuse the previous name, and link the newest asset in the PR description.
Draft releases have no tag ref and are not addressable by tag through `gh release`, so this procedure deliberately uses raw `gh api` plus `curl`.
The release must stay a draft forever: deleting it kills the asset URLs, while a lingering draft is cheap because drafts are invisible to non-collaborators and create no tag.
Verify an upload from the upload response JSON, never by fetching the asset URL afterward: draft asset URLs are served only to repo collaborators' browser sessions, so anonymous and API-token requests get 404 and a curl 404 does not mean the upload failed.
In the PR description, embed each image inline (`![<label>](<asset-url>)`) and put the plain labeled link directly beneath it, so the link still works if the inline embed renders broken for viewers; if first real use shows inline embeds broken, trim this guidance to links-only.
