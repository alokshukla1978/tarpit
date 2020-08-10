#!/bin/sh

GITHUB_BRANCH=${GITHUB_REF##*/}
GITHUB_PROJECT=${GITHUB_REPO##*/}

PULL_REQUEST=$(curl "https://api.github.com/repos/$GITHUB_REPO/pulls?state=open" \
  -H "Authorization: Bearer $GITHUB_TOKEN" | jq ".[] | select(.merge_commit_sha==\"$GITHUB_SHA\") | .number")
  
echo "Got pull request $PULL_REQUEST for branch $GITHUB_BRANCH"

# Install ShiftLeft!
curl https://www.shiftleft.io/download/sl-latest-linux-x64.tar.gz > /tmp/sl.tar.gz && sudo tar -C /usr/local/bin -xzf /tmp/sl.tar.gz

# Analyze code!
sl analyze --version-id "$GITHUB_SHA" --tag branch="$GITHUB_BRANCH" --app "$GITHUB_PROJECT" --java --cpg --wait servlettarpit.war

# Run Build rule check!  
URL="https://www.shiftleft.io/violationlist/$GITHUB_PROJECT?apps=$GITHUB_PROJECT&isApp=1"
BUILDRULECHECK=$(sl check-analysis --app "$GITHUB_PROJECT" --branch "$GITHUB_BRANCH")

# Set up comment body for the merge request
COMMENT_BODY='{"raw":""}'
COMMENT_BODY=$(echo "$COMMENT_BODY" | jq '.raw += "## NG-SAST Analysis Findings \n "')

NEW_FINDINGS=$(curl -H "Authorization: Bearer $SHIFTLEFT_API_TOKEN" "https://www.shiftleft.io/api/v4/orgs/$SHIFTLEFT_ORG_ID/apps/$GITHUB_PROJECT/scans/compare?source=tag.branch=$GITHUB_BRANCH&target=tag.branch=$GITHUB_BRANCH" | jq -c -r '.response.common | .? | .[] | "* [ID " + .id + "](https://www.shiftleft.io/findingDetail/" + .app + "/" + .id + "): " + "["+.severity+"] " + .title')

echo $NEW_FINDINGS

COMMENT_BODY=$(echo "$COMMENT_BODY" | jq ".raw += \"### New findings \n  \n \"")
COMMENT_BODY=$(echo "$COMMENT_BODY" | jq ".raw += \"$NEW_FINDINGS \n  \n \"")

echo "COMMENT_BODY: $COMMENT_BODY"
if [ -n "$BUILDRULECHECK" ]; then
    PR_COMMENT="Build rule failed, click here for vulnerability list! - $URL"  
    echo $PR_COMMENT
    curl -XPOST "https://api.github.com/repos/$GITHUB_REPO/issues/$PULL_REQUEST/comments" \
      -H "Authorization: Bearer $GITHUB_TOKEN" \
      -H "Content-Type: application/json" \
      -d "{\"body\": \"$COMMENT_BODY\"}"
    exit 1
else
    PR_COMMENT="Build rule succeeded, click here for vulnerability list! - $URL" 
    echo $PR_COMMENT
    curl -XPOST "https://api.github.com/repos/$GITHUB_REPO/issues/$PULL_REQUEST/comments" \
      -H "Authorization: Bearer $GITHUB_TOKEN" \
      -H "Content-Type: application/json" \
      -d "{\"body\": \"$COMMENT_BODY\"}"
    exit 0
fi
