#!/bin/bash
# Analyze a GitHub issue using Cline CLI

if [ -z "$1" ]; then
    echo "Usage: $0 <github-issue-url> [prompt] [address]"
    echo "Example: $0 https://github.com/owner/repo/issues/123"
    echo "Example: $0 https://github.com/owner/repo/issues/123 'What is the root cause of this issue?'"
    echo "Example: $0 https://github.com/owner/repo/issues/123 'What is the root cause of this issue?' 127.0.0.1:46529"
    exit 1
fi

ISSUE_URL="$1"
PROMPT="${2:-What is the root cause of this issue?} Don't write any code; just answer the question."
if [ -n "$3" ]; then
    ADDRESS="--address $3"
fi

cline -y "$PROMPT: $ISSUE_URL" --mode act $ADDRESS -F json | \
    sed -n '/^{/,$p' | \
    jq 'select(.say == "completion_result") | .text'
