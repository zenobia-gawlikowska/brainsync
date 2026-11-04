#!/usr/bin/env bash
# brain.sh — share a GitHub repository as a team "second brain" without git.
#
#   brain.sh setup <owner/repo> [folder]   connect (clone) the shared brain
#   brain.sh pull                          get teammates' latest notes
#   brain.sh push [description]            share my notes (PR + auto-merge)
#   brain.sh status                        what's changed / waiting
#   brain.sh where                         print the brain folder
#
# Design (ported from AcceleraTTy, plus a PR flow):
#   * Local edits are always saved (committed) before anything else happens,
#     so nothing can ever be overwritten.
#   * Overlapping edits are resolved automatically: the SHARED version keeps
#     the original file name and the user's version is saved next to it as
#     "name (your version).ext". Nothing is lost, nobody sees conflict markers.
#   * Push never writes to the main branch directly. It updates a personal
#     branch brain/<login>, opens (or reuses) a pull request and merges it.
#     If the repository requires review, the PR stays open and the user is told.
#
# Output is plain English meant to be relayed to a non-technical user.
# Lines start with ✔ (done), ⚠ (needs attention / FYI) or ✖ (failed).
# Exit codes: 0 ok, 1 failed, 2 shared but waiting for approval.
# Compatible with macOS bash 3.2.

set -uo pipefail

CONFIG_DIR="${BRAINSYNC_CONFIG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/brainsync}"
CONFIG_FILE="$CONFIG_DIR/config"
GH="${BRAIN_GH:-gh}"
MAX_TRIES=3

export GIT_TERMINAL_PROMPT=0 GH_PROMPT_DISABLED=1 GIT_EDITOR=true GIT_MERGE_AUTOEDIT=no

ok()   { printf '✔ %s\n' "$*"; }
warn() { printf '⚠ %s\n' "$*"; }
info() { printf '  %s\n' "$*"; }
die()  { printf '✖ %s\n' "$*"; exit 1; }

g()   { git -C "$BRAIN_DIR" -c core.quotePath=false "$@"; }
ghr() { (cd "$BRAIN_DIR" && "$GH" "$@"); }

BACKUP_LOG=$(mktemp "${TMPDIR:-/tmp}/brain-backups.XXXXXX")
trap 'rm -f "$BACKUP_LOG"' EXIT

# ── Plain-English errors ──────────────────────────────────────────────────────
explain() {
  local m=$1
  case $m in
    *"could not read Username"*|*"terminal prompts disabled"*|*"Authentication failed"*|*"returned error: 401"*|*"Bad credentials"*)
      die "GitHub didn't accept your sign-in. Run:  gh auth login  and then try again." ;;
    *"Permission to"*"denied"*|*"returned error: 403"*|*"must have push access"*|*"Resource not accessible"*)
      die "You don't have permission to add to this brain. Ask its owner to add you as a collaborator on GitHub." ;;
    *"Repository not found"*|*"Could not resolve to a Repository"*|*"does not appear to be a git repository"*)
      die "I can't find that shared brain on GitHub. Check the name (like my-team/notes) or ask the owner for access." ;;
  esac
  if is_transient "$m"; then
    die "GitHub is having trouble right now (not your fault — see githubstatus.com). Your notes are saved on this computer; ask me to push again in a few minutes."
  fi
  case $m in
    *"Could not resolve host"*|*"unable to access"*|*"Network is unreachable"*|*"timed out"*)
      die "I can't reach GitHub right now. Check your internet connection and try again." ;;
    *"exceeds GitHub's file size limit"*|*"Large files detected"*)
      die "One of your files is too big for GitHub (over 100 MB). Move it out of the brain folder and try again." ;;
  esac
  die "Something went wrong talking to GitHub. Details for whoever helps you: $(printf '%s' "$m" | tail -n 3 | tr '\n' ' ')"
}

# ── Preconditions ─────────────────────────────────────────────────────────────
need_git() {
  command -v git >/dev/null 2>&1 || die "Git isn't installed. On a Mac, open Terminal and type: xcode-select --install"
}

need_gh() {
  need_git
  command -v "$GH" >/dev/null 2>&1 || die "The GitHub helper isn't installed. Install it from https://cli.github.com (Mac: brew install gh)."
  "$GH" auth status >/dev/null 2>&1 || die "You're not signed in to GitHub yet. Run:  gh auth login  (GitHub.com → HTTPS → Login with a web browser), then ask again."
}

load_brain() {
  need_git
  if [ -z "${BRAIN_DIR:-}" ] && [ -f "$CONFIG_FILE" ]; then
    BRAIN_DIR=$(sed -n 's/^BRAIN_DIR=//p' "$CONFIG_FILE" | head -n 1)
  fi
  [ -n "${BRAIN_DIR:-}" ] || die "No shared brain is connected yet. Tell me which GitHub repository to use (for example my-team/notes) and I'll set it up."
  [ -d "$BRAIN_DIR/.git" ] || die "The brain folder ($BRAIN_DIR) is missing. Ask me to set the shared brain up again."
  MAIN=$(g config brainsync.main || true)
  [ -n "$MAIN" ] || MAIN=$(detect_main)
  LOGIN=$(g config brainsync.login || true)
  [ -n "$LOGIN" ] || LOGIN=$(g config user.name | tr -c 'A-Za-z0-9-' '-' | sed 's/-*$//')
}

detect_main() {
  local b
  b=$(g symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's#^origin/##')
  [ -n "$b" ] || b=$(g ls-remote --symref origin HEAD 2>/dev/null | sed -n 's#^ref: refs/heads/\(.*\)[[:space:]]HEAD$#\1#p')
  [ -n "$b" ] || b=main
  printf '%s' "$b"
}

has_head() { g rev-parse -q --verify HEAD >/dev/null 2>&1; }
has_ref()  { g rev-parse -q --verify "$1^{commit}" >/dev/null 2>&1; }

# ── Recover from an interrupted run (e.g. laptop closed mid-sync) ─────────────
recover_state() {
  local gd; gd=$(g rev-parse --absolute-git-dir)
  if [ -d "$gd/rebase-merge" ] || [ -d "$gd/rebase-apply" ]; then g rebase --abort >/dev/null 2>&1; fi
  if [ -f "$gd/MERGE_HEAD" ]; then
    resolve_conflicts "$(cat "$gd/MERGE_HEAD")"
    g add -A
    g commit -q --no-edit >/dev/null 2>&1 || g merge --abort >/dev/null 2>&1
  fi
  local cur; cur=$(g symbolic-ref --short -q HEAD || true)
  if [ "$cur" != "$MAIN" ] && has_head; then
    save_local "Saved notes before returning to the shared copy" >/dev/null
    g checkout -q "$MAIN" 2>/dev/null || g checkout -q -b "$MAIN" || die "Your brain folder is in an unusual state. Ask a technical teammate to have a look."
  fi
}

# ── Save local edits (commit) ─────────────────────────────────────────────────
describe_staged() {  # human list of what is staged
  g diff --cached --name-status --no-renames | while IFS="$(printf '\t')" read -r st path; do
    case $st in
      A) info "+ new: $path" ;;
      D) info "- removed: $path" ;;
      *) info "~ updated: $path" ;;
    esac
  done
}

save_local() {  # $1 message; returns 1 if there was nothing to save
  g add -A
  g diff --cached --quiet 2>/dev/null && has_head && return 1
  if ! has_head && [ -z "$(g ls-files)" ]; then return 1; fi
  local n; n=$(g diff --cached --name-only | wc -l | tr -d ' ')
  ok "Saved your $n changed file(s):"
  describe_staged
  g commit -q -m "$1" || die "I couldn't save your changes. Is the disk full?"
  return 0
}

# ── Automatic conflict resolution ─────────────────────────────────────────────
backup_path() {  # notes/plan.md -> notes/plan (your version).md, (your version 2) …
  local p=$1 dir base stem ext n=1 cand full
  base=${p##*/}; dir=${p%/*}; [ "$dir" = "$p" ] && dir=""
  case $base in
    ?*.*) ext=".${base##*.}"; stem=${base%.*} ;;
    *)    ext="";             stem=$base ;;
  esac
  while :; do
    if [ $n -eq 1 ]; then cand="$stem (your version)$ext"; else cand="$stem (your version $n)$ext"; fi
    full=${dir:+$dir/}$cand
    [ -e "$BRAIN_DIR/$full" ] || break
    n=$((n + 1))
  done
  printf '%s' "$full"
}

resolve_conflicts() {  # $1 = the ref being merged in (for "who changed it")
  local theirs_ref=$1 list p ours theirs backup who
  list=$(mktemp "${TMPDIR:-/tmp}/brain-unmerged.XXXXXX")
  g diff --name-only --diff-filter=U -z > "$list"
  while IFS= read -r -d '' p; do
    ours=""; theirs=""
    g cat-file -e ":2:$p" 2>/dev/null && ours=$(g rev-parse ":2:$p")
    g cat-file -e ":3:$p" 2>/dev/null && theirs=$(g rev-parse ":3:$p")
    who=$(g log -1 --format=%an "$theirs_ref" -- "$p" 2>/dev/null)
    [ -n "$who" ] || who="a teammate"
    backup=""
    if [ -n "$ours" ] && [ "$ours" != "$theirs" ]; then
      backup=$(backup_path "$p")
      mkdir -p "$(dirname "$BRAIN_DIR/$backup")"
      g cat-file blob "$ours" > "$BRAIN_DIR/$backup"
      g add -- "$backup"
    fi
    if [ -n "$theirs" ]; then
      mkdir -p "$(dirname "$BRAIN_DIR/$p")"
      g cat-file blob "$theirs" > "$BRAIN_DIR/$p"
      g add -- "$p"
      [ -n "$backup" ] && printf 'edit\t%s\t%s\t%s\n' "$p" "$backup" "$who" >> "$BACKUP_LOG"
    else
      g rm -q -f --ignore-unmatch -- "$p" >/dev/null 2>&1
      [ -n "$backup" ] && printf 'deleted\t%s\t%s\t%s\n' "$p" "$backup" "$who" >> "$BACKUP_LOG"
    fi
  done < "$list"
  rm -f "$list"
}

report_backups() {
  [ -s "$BACKUP_LOG" ] || return 0
  warn "You and a teammate changed the same note(s) at the same time. Nothing was lost:"
  while IFS="$(printf '\t')" read -r kind orig backup who; do
    if [ "$kind" = deleted ]; then
      info "• $who removed \"$orig\" — your edited copy was kept as \"$backup\""
    else
      info "• \"$orig\" now has $who's version — yours is saved as \"$backup\""
    fi
  done < "$BACKUP_LOG"
}

# ── Bring in another line of work (teammates' main, or my own pending PR) ────
merge_ref() {  # $1 ref, $2 description for the history
  local ref=$1 what=$2 out
  has_ref "$ref" || return 0
  if ! has_head; then g checkout -q -B "$MAIN" "$ref"; return 0; fi
  g merge-base --is-ancestor "$ref" HEAD 2>/dev/null && return 0
  if out=$(g merge -q --no-edit --allow-unrelated-histories -m "Brought in $what" "$ref" 2>&1); then
    return 0
  fi
  if [ -n "$(g diff --name-only --diff-filter=U)" ]; then
    resolve_conflicts "$ref"
    g commit -q --no-edit -m "Brought in $what (overlapping edits kept side by side)" >/dev/null \
      || die "I couldn't finish combining the notes. Ask a technical teammate to have a look."
    return 0
  fi
  g merge --abort >/dev/null 2>&1
  die "I couldn't combine your notes with $what. Details: $(printf '%s' "$out" | tail -n 2 | tr '\n' ' ')"
}

fetch() {
  local out
  retry_git fetch -q --prune origin
}

get_updates() {  # fetch + merge teammates' work into mine, then report
  local before after n who
  fetch
  before=$(g rev-parse -q --verify HEAD 2>/dev/null || true)
  merge_ref "origin/$MAIN" "teammates' updates"
  after=$(g rev-parse -q --verify HEAD 2>/dev/null || true)
  if [ -z "$after" ] || [ "$before" = "$after" ]; then
    ok "You already have everything your teammates have shared."
  else
    if [ -n "$before" ]; then
      n=$(g diff --name-only "$before" "$after" | wc -l | tr -d ' ')
      who=$(g log --no-merges --format=%an "$before..origin/$MAIN" | sort -u | paste -sd ',' - | sed 's/,/, /g')
    else
      n=$(g ls-files | wc -l | tr -d ' ')
      who=""
    fi
    ok "Got the latest from the shared brain: $n file(s) changed${who:+ (by $who)}."
    if [ -n "$before" ]; then
      g diff --name-status --no-renames "$before" "$after" | head -n 30 | while IFS="$(printf '\t')" read -r st path; do
        case $st in A) info "+ new: $path" ;; D) info "- removed: $path" ;; *) info "~ updated: $path" ;; esac
      done
    fi
  fi
}

# ── Commands ──────────────────────────────────────────────────────────────────
cmd_setup() {
  local repo=${1:-} dir=${2:-$HOME/SecondBrain} out login name id
  [ -n "$repo" ] || die "Tell me which GitHub repository holds the shared brain (for example my-team/notes)."
  need_gh
  case $dir in /*) ;; *) dir="$PWD/$dir" ;; esac
  if [ -d "$dir/.git" ]; then
    ok "The brain folder already exists at $dir — reconnecting it."
  else
    [ -e "$dir" ] && [ -n "$(ls -A "$dir" 2>/dev/null)" ] && die "The folder $dir already has other files in it. Pick an empty or new folder."
    out=$("$GH" repo clone "$repo" "$dir" -- -q 2>&1) || explain "$out"
    ok "Downloaded the shared brain into $dir"
  fi
  BRAIN_DIR=$dir

  # Use the GitHub sign-in for this folder only (no global git changes).
  g config --local --replace-all credential.helper ''
  g config --local --add credential.helper "!$GH auth git-credential"

  login=$("$GH" api user --jq .login 2>/dev/null)
  [ -n "$login" ] || die "I couldn't read your GitHub account. Run:  gh auth login  and try again."
  g config brainsync.login "$login"
  if [ -z "$(g config user.name || true)" ]; then
    name=$("$GH" api user --jq '.name // .login' 2>/dev/null); [ -n "$name" ] || name=$login
    id=$("$GH" api user --jq .id 2>/dev/null)
    g config --local user.name "$name"
    g config --local user.email "${id:+$id+}$login@users.noreply.github.com"
  fi

  # Ignore OS/editor clutter locally (doesn't touch the shared repo).
  mkdir -p "$BRAIN_DIR/.git/info"
  for pat in '.DS_Store' 'Thumbs.db' '~$*' '*.swp' '.obsidian/workspace*' '.obsidian/cache'; do
    grep -qxF "$pat" "$BRAIN_DIR/.git/info/exclude" 2>/dev/null || printf '%s\n' "$pat" >> "$BRAIN_DIR/.git/info/exclude"
  done

  if has_head; then
    MAIN=$(detect_main)
  else
    # Brand-new empty repository: create the first page directly.
    MAIN=main
    g checkout -q -b "$MAIN" 2>/dev/null || true
    if [ -z "$(ls -A "$BRAIN_DIR" | grep -v '^\.git$')" ]; then
      printf '# Our shared brain\n\nNotes, ideas and documents the whole team can read and add to.\n' > "$BRAIN_DIR/README.md"
    fi
    g add -A && g commit -q -m "Start the shared brain"
    retry_git push -q -u origin "HEAD:refs/heads/$MAIN"
    ok "The repository was empty, so I created a first page (README.md)."
  fi
  g config brainsync.main "$MAIN"

  mkdir -p "$CONFIG_DIR"
  printf 'BRAIN_DIR=%s\n' "$BRAIN_DIR" > "$CONFIG_FILE"
  ok "All set. Your shared brain lives in: $BRAIN_DIR"
  info "Edit or add files there with any app (Obsidian, VS Code, TextEdit…), then just say \"push\" or \"pull\"."
}

cmd_pull() {
  load_brain
  recover_state
  save_local "Notes saved before getting updates" >/dev/null || true
  get_updates
  report_backups
}

# Tries merge methods the repo allows. Sets MERGE_OUT; returns 0 merged, 1 not.
try_merge() {
  local pr=$1 m attempt
  for m in --merge --squash --rebase; do
    attempt=1
    while :; do
      if MERGE_OUT=$(ghr pr merge "$pr" "$m" 2>&1); then MERGE_METHOD=$m; return 0; fi
      # Seen live: a merge that "failed" with a 5xx, or "Merge already in
      # progress", has often gone through. Trust the PR state, not the error.
      if wait_merged "$pr" "$MERGE_OUT"; then MERGE_METHOD=$m; return 0; fi
      # GitHub computes mergeability asynchronously right after a push/PR create.
      is_transient "$MERGE_OUT" && [ $attempt -lt 5 ] || break
      backoff $attempt; attempt=$((attempt + 1))
    done
    case $MERGE_OUT in
      *"not allowed"*|*"not enabled"*|*"is not allowed on this repository"*) continue ;;
    esac
    MERGE_METHOD=$m
    return 1
  done
  return 1
}

pr_merged() { [ "$(ghr pr view "$1" --json state --jq .state 2>/dev/null)" = MERGED ]; }
wait_merged() {  # $1 pr, $2 error text; polls longer if GitHub says a merge is running
  local n=1 max=1
  case $2 in *"already in progress"*) max=10 ;; esac
  while :; do
    pr_merged "$1" && return 0
    [ $n -ge $max ] && return 1
    sleep "${BRAIN_BACKOFF:-2}"; n=$((n + 1))
  done
}

# GitHub hiccups worth retrying: 5xx, rate/abuse throttling, mergeability still computing.
is_transient() {
  case $1 in
    *"HTTP 50"[0-9]*|*"error: 50"[0-9]*|*"Bad Gateway"*|*"Service Unavailable"*|*"Gateway Time"*|\
    *"Internal Server Error"*|*"Server Error"*|*"unexpected end of JSON"*|*"secondary rate limit"*|\
    *"unknown state"*|*"mergeability"*|*"try again"*|*"Something went wrong"*|*"early EOF"*|*"RPC failed"*|\
    *"already in progress"*|*"remote rejected"*"(failure)"*|*"cannot lock ref"*) return 0 ;;
  esac
  return 1
}

# Run a networked git command, retrying GitHub hiccups; explain on final failure.
retry_git() {
  local out attempt=1
  while ! out=$(g "$@" 2>&1); do
    if is_transient "$out" && [ $attempt -lt 5 ]; then backoff $attempt; attempt=$((attempt + 1)); continue; fi
    explain "$out"
  done
}
backoff() { sleep $(( ${BRAIN_BACKOFF:-2} * $1 )); }

# Find my open share request or create one. Sets pr + url.
open_pr() {
  local title=$1 body=$2 line out attempt=1
  while :; do
    # Re-check every time: a create that "failed" with a 5xx may have succeeded.
    line=$(ghr pr list --head "brain/$LOGIN" --base "$MAIN" --state open --json number,url \
             --jq '.[0] | select(.) | "\(.number) \(.url)"' 2>/dev/null)
    if [ -n "$line" ]; then
      pr=${line%% *}; url=${line#* }
      ghr pr edit "$pr" --title "$title" --body "$body" >/dev/null 2>&1 || true
      return 0
    fi
    if out=$(ghr pr create --base "$MAIN" --head "brain/$LOGIN" --title "$title" --body "$body" 2>&1); then
      url=$(printf '%s\n' "$out" | grep -Eo 'https?://[^ ]+/pull/[0-9]+' | tail -n 1)
      pr=${url##*/}
      [ -n "$pr" ] && return 0
    fi
    if is_transient "$out" && [ $attempt -lt 5 ]; then backoff $attempt; attempt=$((attempt + 1)); continue; fi
    explain "$out"
  done
}

cmd_push() {
  local msg=${1:-} title body pr url line out try files
  need_gh
  load_brain
  recover_state

  [ -n "$msg" ] || msg="Notes from $LOGIN"
  save_local "$msg" || true

  # Bring in teammates' work AND anything of mine still waiting in an open PR
  # (e.g. pushed from another computer) so nothing is dropped by the update.
  get_updates
  merge_ref "origin/brain/$LOGIN" "your earlier shared changes"

  if ! has_ref "origin/$MAIN"; then
    retry_git push -q -u origin "HEAD:refs/heads/$MAIN"
    ok "Shared! The brain was empty, so your notes are now its first content."
    report_backups; return 0
  fi
  if g diff --quiet "origin/$MAIN" HEAD; then
    ok "Nothing new to share — the shared brain already has all your changes."
    report_backups; return 0
  fi

  files=$(g diff --name-status --no-renames "origin/$MAIN" HEAD | head -n 50 | sed \
    -e 's/^A[[:space:]]*/- added: /' -e 's/^D[[:space:]]*/- removed: /' -e 's/^[MTU][[:space:]]*/- updated: /')
  title=$msg
  body=$(printf 'Shared by @%s with brainsync.\n\n%s\n' "$LOGIN" "$files")

  try=1
  while [ $try -le $MAX_TRIES ]; do
    retry_git push -q -f origin "HEAD:refs/heads/brain/$LOGIN"

    open_pr "$title" "$body"

    if try_merge "$pr"; then
      g push -q origin --delete "brain/$LOGIN" >/dev/null 2>&1 || true
      fetch
      # After a squash/rebase merge the shared copy equals mine: line up history.
      if g diff --quiet HEAD "origin/$MAIN"; then
        g reset -q --hard "origin/$MAIN"
      else
        merge_ref "origin/$MAIN" "teammates' updates"
      fi
      ok "Shared! Your changes are now in the shared brain for everyone."
      info "$url"
      report_backups
      return 0
    fi

    # Order matters: GitHub's review-required message also says "not mergeable".
    case $MERGE_OUT in
      *"review"*|*"approv"*|*"policy prohibits"*|*"protected branch"*|*"status check"*|*"required"*)
        if ghr pr merge "$pr" --auto "${MERGE_METHOD:---merge}" >/dev/null 2>&1; then
          ok "Sent! This brain needs a teammate's approval first; your changes will go in automatically once approved."
        else
          ok "Sent! This brain needs a teammate's approval before your changes go in."
        fi
        info "Approval link to share with a teammate: $url"
        report_backups
        exit 2 ;;
      *"not mergeable"*|*"cannot be cleanly created"*|*"conflict"*|*"not up to date"*|*"behind"*|*"Head branch was modified"*)
        # A teammate shared at the same moment — combine and retry.
        get_updates
        try=$((try + 1))
        continue ;;
    esac
    explain "$MERGE_OUT"
  done
  die "Teammates kept sharing at the same moment, so I couldn't finish. Your notes are safe — just ask me to push again."
}

cmd_status() {
  local changes behind line
  load_brain
  g fetch -q origin >/dev/null 2>&1 || warn "Couldn't reach GitHub, so this may be out of date."
  changes=$(g status --porcelain --untracked-files=all)
  if [ -n "$changes" ]; then
    ok "You have $(printf '%s\n' "$changes" | wc -l | tr -d ' ') file(s) changed on this computer that aren't shared yet:"
    printf '%s\n' "$changes" | head -n 30 | while IFS= read -r l; do
      case ${l:0:2} in
        '??'|'A '|' A') info "+ new: ${l:3}" ;;
        ' D'|'D ')      info "- removed: ${l:3}" ;;
        *)              info "~ updated: ${l:3}" ;;
      esac
    done
  else
    ok "No unshared edits on this computer."
  fi
  if has_ref "origin/$MAIN" && has_head; then
    behind=$(g rev-list --no-merges --count "HEAD..origin/$MAIN")
    [ "$behind" -gt 0 ] && warn "Teammates have shared $behind update(s) you don't have yet — say \"pull\" to get them."
    if ! g diff --quiet "origin/$MAIN" HEAD -- 2>/dev/null && [ -z "$changes" ] && [ "$behind" -eq 0 ]; then
      warn "You have saved changes that aren't in the shared brain yet — say \"push\" to share them."
    fi
  fi
  if command -v "$GH" >/dev/null 2>&1; then
    line=$(ghr pr list --head "brain/$LOGIN" --base "$MAIN" --state open --json url --jq '.[0].url // empty' 2>/dev/null)
    [ -n "$line" ] && warn "Your last share is waiting for a teammate's approval: $line"
  fi
  return 0
}

case ${1:-} in
  setup)  shift; cmd_setup "$@" ;;
  pull)   shift; cmd_pull ;;
  push)   shift; cmd_push "$*" ;;
  status) shift; cmd_status ;;
  where)  load_brain; printf '%s\n' "$BRAIN_DIR" ;;
  *) printf 'usage: brain.sh setup <owner/repo> [folder] | pull | push [description] | status | where\n'; exit 1 ;;
esac
