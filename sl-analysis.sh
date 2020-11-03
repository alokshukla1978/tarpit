#!/bin/sh

GITHUB_BRANCH=${GITHUB_REF##*/}
GITHUB_PROJECT=${GITHUB_REPO##*/}

PULL_REQUEST=$(curl "https://api.github.com/repos/$GITHUB_REPO/pulls?state=open" \
  -H "Authorization: Bearer $GITHUB_TOKEN" | jq ".[] | select(.merge_commit_sha==\"$GITHUB_SHA\") | .number")
  
echo "Got pull request $PULL_REQUEST for branch $GITHUB_BRANCH"

# Install ShiftLeft
curl https://www.shiftleft.io/download/sl-latest-linux-x64.tar.gz > /tmp/sl.tar.gz && sudo tar -C /usr/local/bin -xzf /tmp/sl.tar.gz

# Analyze code!
sl analyze --version-id "$GITHUB_SHA" --tag branch="$GITHUB_BRANCH" --app "$GITHUB_PROJECT" --java --cpg --wait servlettarpit.war

# Run Build rule check!  
URL="https://www.shiftleft.io/violationlist/$GITHUB_PROJECT?apps=$GITHUB_PROJECT&isApp=1"
#BUILDRULECHECK=$(sl check-analysis --app "$GITHUB_PROJECT" --branch "$GITHUB_BRANCH")
sl check-analysis --app "$GITHUB_PROJECT" --branch "$GITHUB_BRANCH" --report --github-pr-number=${{github.event.number}} --github-pr-user=${{ github.repository_owner }} --github-pr-repo=${{ github.event.repository.name }}  --github-token=${{ secrets.GITHUB_TOKEN }}

# if [ -n "$BUILDRULECHECK" ]; then
#    PR_COMMENT="Build rule failed, click here for vulnerability list! - $URL"  
#    echo $PR_COMMENT
#    curl -XPOST "https://api.github.com/repos/$GITHUB_REPO/issues/$PULL_REQUEST/comments" \
#      -H "Authorization: Bearer $GITHUB_TOKEN" \
#      -H "Content-Type: application/json" \
#      -d "{\"body\": \"$PR_COMMENT\"}"
#    exit 1
# else
#    PR_COMMENT="Build rule succeeded, click here for vulnerability list! - $URL" 
#    echo $PR_COMMENT
#    curl -XPOST "https://api.github.com/repos/$GITHUB_REPO/issues/$PULL_REQUEST/comments" \
#      -H "Authorization: Bearer $GITHUB_TOKEN" \
#      -H "Content-Type: application/json" \
#      -d "{\"body\": \"$PR_COMMENT\"}"
#    exit 0
# fi

