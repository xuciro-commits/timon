#!/bin/sh
# Installs the push gate of this repository, once per clone.
#
#   scripts/install-git-hooks.sh
#
# It points `core.hooksPath` at `.githooks/`, so the hooks travel with the code
# instead of sitting in `.git/hooks/` where nobody sees them, and makes them
# executable (a checkout does not keep the bit, and git silently skips a hook it
# cannot run).
#
# Check it took: `git config core.hooksPath` prints `.githooks`.
# Turn it off for one push: `SKIP_PUSH_GATE=1 git push`, or `git push --no-verify`.
set -eu

root=$(git rev-parse --show-toplevel)
cd "$root"

git config core.hooksPath .githooks
chmod +x .githooks/pre-push scripts/sync-push.sh scripts/install-git-hooks.sh

echo "push gate installed."
echo "  core.hooksPath = $(git config --get core.hooksPath)"
echo "  hooks          = $(ls .githooks | tr '\n' ' ')"
echo
echo "Push with: scripts/sync-push.sh   (fetch, integrate, then push)"