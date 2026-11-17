#!/bin/sh
# Fetch, integrate, then push — the order a change has to enter in.
#
#   scripts/sync-push.sh              # push the current branch
#   scripts/sync-push.sh --dry-run    # everything but the push itself
#
# What it does, in order:
#   1. `git fetch <remote> --prune`;
#   2. integrates the base it targets: on the base branch (main) a merge, so the
#      history of the branch everybody shares stays linear; on a feature branch a
#      rebase, so the branch lands as the commits it was written as;
#   3. pushes, through `.githooks/pre-push` as usual.
#
# A conflict stops it: the merge or the rebase is aborted, the conflicted files
# and the whole conflicted diff are written to `.git/push-gate/conflicts-<time>.md`,
# and the exit code is 1. Nothing is resolved here on purpose — a tool guessing at
# a conflict is how a rebase drops a commit without saying so. The report is what
# an agent (or you) reads to pick the work up: resolve the files it names, then
# `git rebase --continue` (or `git commit` for a merge) and run this again.
set -eu

remote="${SYNC_REMOTE:-origin}"
branch=$(git rev-parse --abbrev-ref HEAD)
git_dir=$(git rev-parse --git-dir)
report_dir="$git_dir/push-gate"

if [ "$branch" = "HEAD" ]; then
  echo "sync-push: a detached HEAD has no branch to integrate; check one out first" >&2
  exit 2
fi

git fetch "$remote" --prune

base="${PUSH_GATE_BASE:-}"
if [ -z "$base" ]; then
  base=$(git symbolic-ref -q "refs/remotes/$remote/HEAD" 2>/dev/null | sed "s#^refs/remotes/$remote/##" || true)
  [ -n "$base" ] || base=main
fi
base_ref="$remote/$base"

behind=$(git rev-list --count "HEAD..$base_ref")
if [ "$behind" -eq 0 ]; then
  echo "sync-push: up to date with $base_ref"
  exec git push "$@"
fi

echo "sync-push: $behind commit(s) on $base_ref not on $branch; integrating"

# The hand-over. Written before the abort, so the conflicted files are still the
# working tree's when it is read.
write_report() {
  operation=$1
  mkdir -p "$report_dir"
  report="$report_dir/conflicts-$(date +%Y%m%d-%H%M%S).md"
  {
    echo "# $branch: a $operation against $base_ref stopped on conflicts"
    echo
    echo "- date: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "- branch: $branch"
    echo "- base: $base_ref"
    echo "- HEAD: $(git rev-parse --short HEAD 2>/dev/null || echo none)"
    echo
    echo "## Files in conflict"
    echo
    git diff --name-only --diff-filter=U | sed 's/^/- /'
    echo
    echo "## The conflicted diff, markers and all"
    echo
    echo '```diff'
    git diff --diff-filter=U || true
    echo '```'
    echo
    echo "## Next"
    echo
    echo "\`git $operation $base_ref\` again, resolve each file below after reading both"
    echo "sides, \`git add\` it, then \`git $operation --continue\` (for a merge: \`git commit\`)."
    echo "Run \`scripts/sync-push.sh\` again when the tree is whole."
  } >"$report"
  echo "sync-push: conflicts written to $report" >&2
}

if [ "$branch" = "$base" ]; then
  # On the base branch: a merge commit, not a rebase — a rebase of main would
  # rewrite commits other clones already have.
  if ! git merge --no-edit "$base_ref"; then
    write_report merge
    git merge --abort 2>/dev/null || true
    exit 1
  fi
else
  if ! git rebase "$base_ref"; then
    write_report rebase
    git rebase --abort 2>/dev/null || true
    exit 1
  fi
fi

echo "sync-push: integrated $base_ref with no conflict"
exec git push "$@"