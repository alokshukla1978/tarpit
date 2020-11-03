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
sl check-analysis --app "$GITHUB_PROJECT" --branch "$GITHUB_BRANCH" --report --github-pr-number="$1" --github-pr-user="$2" --github-pr-repo="$3" --github-token="$4"
