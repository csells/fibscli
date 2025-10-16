#!/bin/bash
# Analyze a GitHub issue using Cline CLI

if [ -z "$1" ]; then
    echo "Usage: $0 <github-issue-url> [prompt] [address]"
    echo "Example: $0 https://github.com/owner/repo/issues/123"
    echo "Example: $0 https://github.com/owner/repo/issues/123 'What is the security impact?'"
    echo "Example: $0 https://github.com/owner/repo/issues/123 'What is the security impact?' 127.0.0.1:46529"
    exit 1
fi

ISSUE_URL="$1"
PROMPT="${2:-What is the root cause of this issue}"
ADDRESS="$3"

if [ -z "$ADDRESS" ]; then
    cline -y "$PROMPT: $ISSUE_URL" --mode act -F plain
else
    cline -y "$PROMPT: $ISSUE_URL" --mode act --address "$ADDRESS" -F plain
fi
