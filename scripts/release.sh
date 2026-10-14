#!/usr/bin/env bash
# Release the plugin in one command, from an up-to-date main to a published GitHub release.
#
#   scripts/release.sh [--dry-run] [--yes] [--date YYYY-MM-DD] <patch|minor|major|X.Y.Z>
#
# It checks the tools, your access, that you're on a clean main that matches GitHub, that CI passed there
# and that CHANGELOG.md has something under [Unreleased]. Then it bumps the version on release/<version>,
# pushes it, opens the release pull request, waits for its checks, merges it, follows the Release
# workflow, verifies the GitHub release, the tag and the stable branch, and leaves you on an updated main.
#
# Everything goes through the GitHub repository in plugin.json's "repository", using whichever git remote
# points at it. Which level to choose: README.md, "Versions and releases".
# Needs git, node, and gh signed in to github.com with write access to the repository.
set -euo pipefail

BASE=main
CI_WORKFLOW=ci.yml
RELEASE_WORKFLOW=release.yml
PLUGIN_JSON=plugins/singularity/.claude-plugin/plugin.json
MARKETPLACE_JSON=.claude-plugin/marketplace.json
POLL=5          # seconds between checks while waiting for something to appear
WAIT_START=300  # seconds to wait for pull request checks or a workflow run to appear

export GH_PROMPT_DISABLED=1 GH_PAGER=cat

if [ -t 1 ]; then
  BOLD=$'\033[1m' RED=$'\033[31m' GREEN=$'\033[32m' YELLOW=$'\033[33m' RESET=$'\033[0m'
else
  BOLD='' RED='' GREEN='' YELLOW='' RESET=''
fi

# Filled in as the release goes; the exit trap uses them to say how to recover.
STAGE='checks' REPO='' REMOTE='' BRANCH='' PR_URL='' NAME='' MARKETPLACE='' VERSION='' TAG='' MERGE_SHA=''

step() { printf '\n%s==> %s%s\n' "$BOLD" "$*" "$RESET"; }
info() { printf '    %s\n' "$*"; }
warn() { printf '%swarning:%s %s\n' "$YELLOW" "$RESET" "$*" >&2; }
die() { printf '%serror:%s %s\n' "$RED" "$RESET" "$*" >&2; exit 1; }
lower() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }

usage() {
  cat <<EOF
Usage: scripts/release.sh [options] <patch|minor|major|X.Y.Z>

Releases the plugin from an up-to-date, clean $BASE: bumps the version on a release branch, opens and
merges the release pull request on GitHub, follows the Release workflow and checks the result.
Which level to choose: README.md, "Versions and releases".

Options:
  -n, --dry-run    check everything and show the release plan, then stop; it only
                   fast-forwards $BASE if GitHub's is ahead
  -y, --yes        don't ask for confirmation (needed when there is no terminal)
      --date DATE  release date in the changelog, YYYY-MM-DD (default: today, UTC)
  -h, --help       show this help
EOF
}

on_exit() {
  local code=$?
  if [ "$code" -eq 0 ] || [ "$STAGE" = 'done' ]; then return 0; fi
  {
    printf '\n'
    case "$STAGE" in
      checks)
        printf 'Nothing was changed.\n' ;;
      local)
        printf 'Nothing was pushed. To drop the release branch:\n'
        printf '  git switch --discard-changes %s && git branch -D %s\n' "$BASE" "$BRANCH" ;;
      pushed)
        printf '%s is on GitHub without a pull request. To drop it:\n' "$BRANCH"
        printf '  git switch %s && git branch -D %s && git push %s --delete %s\n' "$BASE" "$BRANCH" "$REMOTE" "$BRANCH" ;;
      pr)
        printf 'The release pull request is open: %s\n' "$PR_URL"
        printf 'Fix the problem on %s and push; merging the pull request publishes the release.\n' "$BRANCH"
        printf 'To abandon it instead:\n'
        printf '  git switch %s && git branch -D %s && gh pr close %s --repo %s --delete-branch\n' "$BASE" "$BRANCH" "$PR_URL" "$REPO" ;;
      merged|verify)
        printf 'The release pull request is merged. If the Release workflow failed, fix the cause on %s and run it\n' "$BASE"
        printf 'again; it skips whatever is already done:\n'
        printf '  gh workflow run %s --repo %s --ref %s\n' "$RELEASE_WORKFLOW" "$REPO" "$BASE"
        printf 'Runs: https://github.com/%s/actions/workflows/%s\n' "$REPO" "$RELEASE_WORKFLOW"
        printf 'Then update your %s: git switch %s && git pull --ff-only %s %s && git branch -D %s\n' "$BASE" "$BASE" "$REMOTE" "$BASE" "$BRANCH" ;;
    esac
  } >&2
}

# The git remote whose URL points at github.com/$REPO (https or ssh), whatever it is called.
find_remote() {
  local want r url
  want=$(lower "$REPO")
  for r in $(git remote); do
    url=$(lower "$(git config --get "remote.$r.url" || true)")
    url=${url%/}
    url=${url%.git}
    case "$url" in
      *github.com/"$want" | *github.com:"$want") printf '%s' "$r"; return 0 ;;
    esac
  done
  return 1
}

# Run a command until it prints something, for at most $WAIT_START seconds, and print what it printed.
poll() {
  local what=$1 waited=0 out
  shift
  while :; do
    out=$("$@" 2>/dev/null || true)
    if [ -n "$out" ]; then printf '%s' "$out"; return 0; fi
    [ "$waited" -lt "$WAIT_START" ] || die "$what didn't appear within $((WAIT_START / 60)) minutes"
    sleep "$POLL"
    waited=$((waited + POLL))
  done
}

checks_reported() {
  local n
  n=$(gh pr checks "$PR_URL" --repo "$REPO" --json name -q length 2>/dev/null || true)
  if [ "${n:-0}" -gt 0 ] 2>/dev/null; then echo yes; fi
}

release_run() {
  gh run list --repo "$REPO" --workflow "$RELEASE_WORKFLOW" --commit "$MERGE_SHA" --limit 1 \
    --json databaseId -q '.[0].databaseId // empty'
}

# Wait without a time limit: a required review can take a while. Closing the pull request stops the wait.
wait_merged() {
  local state waited=0
  while :; do
    state=$(gh pr view "$PR_URL" --repo "$REPO" --json state -q .state 2>/dev/null || true)
    case "$state" in
      MERGED) return 0 ;;
      CLOSED) die "the release pull request was closed without merging: $PR_URL" ;;
    esac
    if [ $((waited % 300)) -eq 0 ]; then info "waiting for the merge ($((waited / 60)) min so far): $PR_URL"; fi
    sleep 15
    waited=$((waited + 15))
  done
}

main() {
  local level='' dry_run=0 yes=0 date='' answer tool url perm branch ci ci_id ci_status ci_conclusion
  local out head notes current changed release_url tagged stable
  while [ $# -gt 0 ]; do
    case "$1" in
      -n | --dry-run) dry_run=1 ;;
      -y | --yes) yes=1 ;;
      --date) [ $# -ge 2 ] || die "--date needs a value, YYYY-MM-DD"; date=$2; shift ;;
      --date=*) date=${1#--date=} ;;
      -h | --help) usage; exit 0 ;;
      -*) die "unknown option $1 (see --help)" ;;
      *) [ -z "$level" ] || die "give one level (see --help)"; level=$1 ;;
    esac
    shift
  done
  if [ -z "$level" ]; then usage >&2; exit 2; fi
  case "$level" in
    patch | minor | major) ;;
    *) [[ "$level" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "the level must be patch, minor, major or X.Y.Z, not \"$level\"" ;;
  esac
  if [ -n "$date" ] && ! [[ "$date" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then die "--date must be YYYY-MM-DD, not \"$date\""; fi

  trap on_exit EXIT
  trap 'exit 130' INT TERM
  cd "$(dirname "$0")/.."

  step "Checking the tools, your access and $BASE"
  for tool in git node gh; do
    command -v "$tool" >/dev/null 2>&1 || die "$tool is not installed"
  done
  gh auth status --hostname github.com >/dev/null 2>&1 || die "gh isn't signed in to github.com: run gh auth login"

  NAME=$(node -p "require('./$PLUGIN_JSON').name")
  MARKETPLACE=$(node -p "require('./$MARKETPLACE_JSON').name")
  url=$(node -p "String(require('./$PLUGIN_JSON').repository || '')")
  case "$url" in
    https://github.com/*/*) ;;
    *) die "\"repository\" in $PLUGIN_JSON must be https://github.com/<owner>/<repo>, not \"$url\"" ;;
  esac
  REPO=${url#https://github.com/}
  REPO=${REPO%/}
  REPO=${REPO%.git}
  info "repository  https://github.com/$REPO"

  perm=$(gh repo view "$REPO" --json viewerPermission -q .viewerPermission 2>/dev/null || true)
  case "$perm" in
    ADMIN | MAINTAIN | WRITE) ;;
    *) die "releasing needs write access to $REPO; gh reports: ${perm:-no access}" ;;
  esac
  REMOTE=$(find_remote) || die "no git remote points at github.com/$REPO; add one: git remote add upstream https://github.com/$REPO.git"
  info "git remote  $REMOTE"

  branch=$(git symbolic-ref --quiet --short HEAD || true)
  [ "$branch" = "$BASE" ] || die "releases start on $BASE, and you're on ${branch:-a detached HEAD}: git switch $BASE"
  if [ -n "$(git status --porcelain --untracked-files=no)" ]; then
    die "the working tree has uncommitted changes: commit or stash them first"
  fi
  git fetch --quiet "$REMOTE" "$BASE"
  head=$(git rev-parse FETCH_HEAD)
  if [ "$(git rev-parse HEAD)" != "$head" ]; then
    if git merge-base --is-ancestor HEAD "$head"; then
      info "fast-forwarding $BASE to GitHub's ${head:0:7}"
      git merge --quiet --ff-only "$head"
    else
      die "your $BASE has commits that aren't on GitHub, and a release contains only what is on $REPO's $BASE: merge them through a pull request first"
    fi
  fi
  info "$BASE        ${head:0:7}, same as GitHub"

  ci=$(gh run list --repo "$REPO" --workflow "$CI_WORKFLOW" --branch "$BASE" --commit "$head" --limit 1 \
    --json databaseId,status,conclusion -q '.[0] | select(. != null) | "\(.databaseId) \(.status) \(.conclusion)"')
  [ -n "$ci" ] || die "CI hasn't run on $BASE at ${head:0:7}: https://github.com/$REPO/actions/workflows/$CI_WORKFLOW"
  read -r ci_id ci_status ci_conclusion <<<"$ci"
  if [ "$ci_status" != completed ]; then
    info "waiting for CI on $BASE to finish: https://github.com/$REPO/actions/runs/$ci_id"
    gh run watch "$ci_id" --repo "$REPO" --exit-status --interval 10 >/dev/null || true
    ci_conclusion=$(gh run view "$ci_id" --repo "$REPO" --json conclusion -q .conclusion)
  fi
  [ "$ci_conclusion" = success ] || die "CI on $BASE ended with \"${ci_conclusion:-nothing}\": https://github.com/$REPO/actions/runs/$ci_id"
  info "CI          passed"

  out=$(node scripts/version.js check 2>&1) || die "the version check failed:
$out"
  notes=$(node scripts/version.js notes Unreleased 2>/dev/null) || die "nothing to release: CHANGELOG.md has no lines under ## [Unreleased]"
  current=$(node scripts/version.js current)
  VERSION=$(node scripts/version.js next "$level")
  TAG=$(node scripts/version.js tag "$VERSION")
  BRANCH=release/$VERSION
  if printf '%s\n' "$notes" | grep -q 'Breaking:'; then
    case "$level" in
      patch) die "the unreleased changes include **Breaking:** lines, so this can't be a patch release" ;;
      minor) if [ "${current%%.*}" -gt 0 ]; then die "the unreleased changes include **Breaking:** lines: from 1.0 on, that is a major release"; fi ;;
    esac
  fi
  if git show-ref --verify --quiet "refs/heads/$BRANCH"; then die "a local branch $BRANCH already exists"; fi
  if git ls-remote --exit-code --heads "$REMOTE" "$BRANCH" >/dev/null 2>&1; then
    die "$BRANCH already exists on GitHub: https://github.com/$REPO/tree/$BRANCH"
  fi
  if git ls-remote --exit-code --tags "$REMOTE" "refs/tags/$TAG" >/dev/null 2>&1; then die "$TAG already exists on GitHub"; fi

  step "Release plan: $NAME $current -> $VERSION"
  info "$level release, tag $TAG, pull request from $BRANCH into $BASE"
  printf '\n'
  printf '%s\n' "$notes" | sed 's/^/    /'
  if [ "$dry_run" -eq 1 ]; then
    STAGE='done'
    printf '\nDry run: nothing was changed.\n'
    return 0
  fi
  if [ "$yes" -eq 0 ]; then
    [ -t 0 ] || die "there's no terminal to confirm in: run with --yes"
    printf '\nRelease %s %s? [y/N] ' "$NAME" "$VERSION"
    read -r answer || answer=''
    case "$answer" in
      y | Y | yes | Yes | YES) ;;
      *) die "cancelled" ;;
    esac
  fi

  step "Bumping the version on $BRANCH"
  STAGE='local'
  git switch --quiet -c "$BRANCH"
  if [ -n "$date" ]; then
    node scripts/version.js bump "$VERSION" --date "$date" >/dev/null
  else
    node scripts/version.js bump "$VERSION" >/dev/null
  fi
  changed=$(git diff --name-only | LC_ALL=C sort | tr '\n' ' ')
  [ "$changed" = "CHANGELOG.md $PLUGIN_JSON " ] || die "the bump changed unexpected files: $changed"
  node scripts/version.js check >/dev/null
  git --no-pager diff --stat
  git commit --quiet -am "chore(release): $NAME $VERSION"

  step "Opening the release pull request"
  git push --quiet -u "$REMOTE" "$BRANCH"
  STAGE='pushed'
  PR_URL=$(gh pr create --repo "$REPO" --base "$BASE" --head "$BRANCH" \
    --title "chore(release): $NAME $VERSION" --body "$(node scripts/version.js notes "$VERSION")")
  STAGE='pr'
  info "$PR_URL"

  step "Waiting for the pull request checks"
  poll "checks on $PR_URL" checks_reported >/dev/null
  gh pr checks "$PR_URL" --repo "$REPO" --watch --fail-fast --interval 10

  step "Merging the release pull request"
  if out=$(gh pr merge "$PR_URL" --repo "$REPO" --squash 2>&1); then
    info "merged"
  else
    out=$(printf '%s\n' "$out" | tail -n 1)
    if gh pr merge "$PR_URL" --repo "$REPO" --squash --auto >/dev/null 2>&1; then
      info "GitHub can't merge it yet ($out). Auto-merge is on: it merges as soon as the requirements are met"
    else
      info "GitHub can't merge it yet ($out). Merge it on GitHub and this carries on: $PR_URL"
    fi
  fi
  wait_merged
  MERGE_SHA=$(gh pr view "$PR_URL" --repo "$REPO" --json mergeCommit -q .mergeCommit.oid)
  STAGE='merged'
  info "merged into $BASE as ${MERGE_SHA:0:7}"

  step "Following the Release workflow"
  out=$(poll "a $RELEASE_WORKFLOW run for ${MERGE_SHA:0:7}" release_run)
  info "https://github.com/$REPO/actions/runs/$out"
  gh run watch "$out" --repo "$REPO" --exit-status --interval 10

  step "Checking the release on GitHub"
  STAGE='verify'
  release_url=$(gh release view "$TAG" --repo "$REPO" --json url -q .url 2>/dev/null || true)
  [ -n "$release_url" ] || die "the GitHub release $TAG wasn't published"
  tagged=$(git ls-remote "$REMOTE" "refs/tags/$TAG^{}" | cut -f1)
  [ -n "$tagged" ] || tagged=$(git ls-remote "$REMOTE" "refs/tags/$TAG" | cut -f1)
  [ -n "$tagged" ] || die "the tag $TAG isn't on GitHub"
  stable=$(git ls-remote "$REMOTE" refs/heads/stable | cut -f1)
  [ "$stable" = "$tagged" ] || die "stable is at ${stable:0:7}, not at $TAG (${tagged:0:7})"
  [ "$tagged" = "$MERGE_SHA" ] || warn "$TAG is at ${tagged:0:7}, not at the merge commit ${MERGE_SHA:0:7}"
  info "release     $release_url"
  info "tag         $TAG at ${tagged:0:7}, and stable points there"

  step "Updating your $BASE"
  git switch --quiet "$BASE"
  git pull --quiet --ff-only "$REMOTE" "$BASE"
  git fetch --quiet "$REMOTE" tag "$TAG"
  git branch --quiet -D "$BRANCH"
  if git ls-remote --exit-code --heads "$REMOTE" "$BRANCH" >/dev/null 2>&1; then
    git push --quiet "$REMOTE" --delete "$BRANCH"
  fi
  STAGE='done'

  printf '\n%s%sReleased %s %s.%s\n' "$GREEN" "$BOLD" "$NAME" "$VERSION" "$RESET"
  info "Projects with auto-update get it in their next session; others run: claude plugin update $NAME@$MARKETPLACE"
}

main "$@"
