#!/usr/bin/env bash
# Merges an upstream LibreChat release tag into the Bowdoin base branch and opens a PR.
#
# Env:
#   TAG           upstream tag to sync (default: latest upstream release)
#   BASE_BRANCH   branch to sync into (default: bowdoin-dev)
#   UPSTREAM_URL  upstream repo (default: https://github.com/danny-avila/LibreChat.git)
#   GH_REPO       repo to open the PR in (required unless DRY_RUN=1)
#   DRY_RUN       1 = merge locally and print the PR body; no push, no PR
set -euo pipefail

BASE_BRANCH="${BASE_BRANCH:-bowdoin-dev}"
UPSTREAM_URL="${UPSTREAM_URL:-https://github.com/danny-avila/LibreChat.git}"
UPSTREAM_SLUG="danny-avila/LibreChat"
DRY_RUN="${DRY_RUN:-0}"
DOCKER_FILES=(Dockerfile Dockerfile.multi)
MAX_DIFF_CHARS=40000

if [ -z "${TAG:-}" ]; then
  TAG=$(gh release view --repo "$UPSTREAM_SLUG" --json tagName --jq .tagName)
fi

if ! [[ "$TAG" =~ ^v[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.]+)?$ ]]; then
  echo "Invalid tag: $TAG" >&2
  exit 1
fi

git remote get-url upstream >/dev/null 2>&1 || git remote add upstream "$UPSTREAM_URL"
git fetch --quiet --force upstream "refs/tags/*:refs/tags/*"
BASE_REF="$BASE_BRANCH"
if [ "$DRY_RUN" != "1" ]; then
  git fetch --quiet origin "$BASE_BRANCH"
  BASE_REF="origin/$BASE_BRANCH"
fi

if git merge-base --is-ancestor "$TAG" "$BASE_REF"; then
  echo "$TAG is already merged into $BASE_BRANCH; nothing to do."
  exit 0
fi

PREV_TAG=$(git describe --tags --abbrev=0 --match 'v[0-9]*' "$BASE_REF")
SYNC_BRANCH="sync/upstream-$TAG"
if [ "$DRY_RUN" != "1" ] && git ls-remote --exit-code --heads origin "$SYNC_BRANCH" >/dev/null; then
  echo "$SYNC_BRANCH already exists on origin; leaving it alone. Delete it to re-run the sync."
  exit 0
fi
echo "Syncing $PREV_TAG -> $TAG into $BASE_BRANCH via $SYNC_BRANCH"

git checkout --quiet -B "$SYNC_BRANCH" "$BASE_REF"

CONFLICTS=""
if git merge --quiet --no-ff --no-edit -m "Merge tag $TAG into $BASE_BRANCH" "$TAG"; then
  STATUS="✅ Merged cleanly. Bowdoin customizations are preserved."
else
  CONFLICTS=$(git diff --name-only --diff-filter=U)
  git merge --abort
  git checkout --quiet -B "$SYNC_BRANCH" "$TAG"
  STATUS="⚠️ **Merge conflicts.** This branch points at the upstream tag; resolve locally:

\`\`\`bash
git fetch origin && git checkout $SYNC_BRANCH
git merge origin/$BASE_BRANCH   # resolve, then commit and push
\`\`\`

Conflicted files:
$(printf '%s\n' "$CONFLICTS" | sed 's/^/- `/; s/$/`/')"
fi

DOCKER_DIFF=$(git diff "$PREV_TAG" "$TAG" -- "${DOCKER_FILES[@]}")
if [ -z "$DOCKER_DIFF" ]; then
  DOCKER_SECTION="No upstream changes to \`Dockerfile\` or \`Dockerfile.multi\`; \`Dockerfile.bowdoin\` needs no review."
else
  if [ "${#DOCKER_DIFF}" -gt "$MAX_DIFF_CHARS" ]; then
    DOCKER_DIFF="${DOCKER_DIFF:0:$MAX_DIFF_CHARS}
... (truncated; run: git diff $PREV_TAG $TAG -- ${DOCKER_FILES[*]})"
  fi
  DOCKER_SECTION="⚠️ **Upstream changed its Dockerfile(s).** Review and port relevant changes to \`Dockerfile.bowdoin\`:

\`\`\`diff
$DOCKER_DIFF
\`\`\`"
fi

BODY_FILE=$(mktemp)
cat >"$BODY_FILE" <<EOF
Automated sync of upstream LibreChat **$TAG** into \`$BASE_BRANCH\` (previous: \`$PREV_TAG\`).

$STATUS

- Release notes: https://github.com/$UPSTREAM_SLUG/releases/tag/$TAG
- Upstream changes: https://github.com/$UPSTREAM_SLUG/compare/$PREV_TAG...$TAG

**Merge with "Create a merge commit"** (not squash/rebase) so upstream history stays linked.

## Dockerfile review

$DOCKER_SECTION
EOF

if [ "$DRY_RUN" = "1" ]; then
  echo "----- DRY RUN: PR body -----"
  cat "$BODY_FILE"
  exit 0
fi

git push origin "$SYNC_BRANCH"
gh pr create --repo "$GH_REPO" --base "$BASE_BRANCH" --head "$SYNC_BRANCH" \
  --title "Sync upstream LibreChat $TAG" --body-file "$BODY_FILE"
