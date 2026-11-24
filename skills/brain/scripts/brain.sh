#!/usr/bin/env bash
# brain.sh — share a GitHub repository as a team "second brain" without git.
#
#   brain.sh setup <owner/repo> [folder]   connect (clone) the shared brain
#   brain.sh pull                          get teammates' latest notes
#   brain.sh push [description]            share my notes (PR + auto-merge)
#   brain.sh status                        what's changed / waiting
#   brain.sh where                         print the brain folder
#   brain.sh doctor                        check this computer is ready
#   brain.sh install-tools                 install what's missing (no admin)
#   brain.sh signin / signin-wait          sign in to GitHub via the browser
#
# Exit code 3 means "waiting for the user" (click Install, enter a code…).
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
# Compatible with macOS bash 3.2 and Git Bash on Windows (Git for Windows).

set -uo pipefail

# Homebrew's folders are often missing from PATH (people skip the step that
# adds them to the shell), so look there too. ORIG_PATH is kept for `doctor`.
# On Windows, a freshly installed gh isn't on PATH until Claude Code restarts.
ORIG_PATH=$PATH
TOOLS_DIR="${BRAINSYNC_TOOLS_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/brainsync}"
_extra="$TOOLS_DIR/bin:/opt/homebrew/bin:/usr/local/bin:/c/Program Files/GitHub CLI"
if [ -n "${LOCALAPPDATA:-}" ] && command -v cygpath >/dev/null 2>&1; then
  _extra="$_extra:$(cygpath -u "$LOCALAPPDATA")/Microsoft/WinGet/Links"
fi
_ifs=$IFS; IFS=:
for d in $_extra; do
  case ":$PATH:" in *":$d:"*) ;; *) [ -d "$d" ] && PATH="$PATH:$d" ;; esac
done
IFS=$_ifs; unset _extra _ifs
export PATH

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
      die "GitHub didn't accept your sign-in. Run:  $SIGNIN_CMD  and then try again." ;;
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
is_mac() { [ "$(uname -s)" = Darwin ]; }
is_windows() { case $(uname -s) in MINGW*|MSYS*|CYGWIN*) return 0 ;; esac; return 1; }

need_os() { :; }  # macOS, Linux and Windows (Git Bash) are all supported

# Install hints per platform.
if is_windows; then
  GIT_HINT="Install Git for Windows: open PowerShell and type  winget install --id Git.Git -e  then close and reopen Claude Code."
  GH_HINT="Open PowerShell and type  winget install --id GitHub.cli -e  then close and reopen Claude Code."
else
  GIT_HINT="On a Mac, open Terminal and type: xcode-select --install"
  GH_HINT="Install it from https://cli.github.com (Mac: brew install gh)."
fi

# On a Mac /usr/bin/git always exists, but it's only a stub that opens Apple's
# installer until the developer tools are installed. Catch that first.
mac_git_stub() {
  is_mac && [ "$(command -v git)" = /usr/bin/git ] && ! xcode-select -p >/dev/null 2>&1
}

need_git() {
  need_os
  command -v git >/dev/null 2>&1 || die "Git isn't installed. $GIT_HINT"
  mac_git_stub && die "Your Mac needs Apple's free developer tools first. Open Terminal, type:  xcode-select --install  then click Install. Ask again when it has finished."
  return 0
}

SIGNIN_CMD="gh auth login -h github.com -p https --web"   # what a person types; Claude uses `brain.sh signin`

need_gh() {
  need_git
  command -v "$GH" >/dev/null 2>&1 || die "The GitHub helper isn't installed. $GH_HINT"
  "$GH" auth status >/dev/null 2>&1 || die "You're not signed in to GitHub yet. Run:  $SIGNIN_CMD  then ask again."
}

# Notes folders inside iCloud, OneDrive, Dropbox or Google Drive get their
# hidden git data rewritten by the sync app, which can damage it.
cloud_folder() {  # prints the service name if $1 is inside a synced folder
  case $1 in
    "$HOME/Library/Mobile Documents"*) echo iCloud ;;
    "$HOME/Library/CloudStorage/OneDrive"*|"$HOME/OneDrive"*) echo OneDrive ;;
    "$HOME/Library/CloudStorage/Dropbox"*|"$HOME/Dropbox"*) echo Dropbox ;;
    "$HOME/Library/CloudStorage/GoogleDrive"*|"$HOME/Google Drive"*) echo "Google Drive" ;;
    "$HOME/Library/CloudStorage/"*) echo "a cloud-sync app" ;;
    "$HOME/iCloudDrive"*) echo iCloud ;;                       # Windows
    /[a-zA-Z]/"My Drive"*|/[a-zA-Z]/"Shared drives"*) echo "Google Drive" ;;  # Windows drive letter
    *) return 1 ;;
  esac
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

# ── Names Windows can't use ───────────────────────────────────────────────────
# A teammate on a Mac can create "Call 10:30.md"; Windows can't store it, so
# Windows teammates would never get it. Warn whoever adds such a name.
bad_windows_name() {  # $1 path; succeeds if some part is invalid on Windows
  local part rest=$1 up
  case $rest in *[:\*\?\"\<\>\|\\]*) return 0 ;; esac
  while [ -n "$rest" ]; do
    part=${rest%%/*}
    case $part in *" "|*.) return 0 ;; esac
    up=$(printf '%s' "${part%%.*}" | tr '[:lower:]' '[:upper:]')
    case $up in CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9]) return 0 ;; esac
    [ "$rest" = "$part" ] && break
    rest=${rest#*/}
  done
  return 1
}

warn_windows_names() {  # after save_local: check names added in unshared commits
  local p list=""
  while IFS= read -r p; do
    [ -n "$p" ] && bad_windows_name "$p" && list="$list
  • $p"
  done <<EOF_NAMES
$(g diff --name-only --diff-filter=AR "origin/$MAIN" HEAD 2>/dev/null)
EOF_NAMES
  [ -n "$list" ] && warn "These names won't work for teammates on Windows (avoid : * ? \" < > | \\ and names ending in a space or dot). Please rename them:$list"
  return 0
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
  case $out in
    *"unable to unlink"*|*"unable to create file"*|*"Permission denied"*|*"Device or resource busy"*)
      die "A note is open in another app (Word, Excel, an editor…), so I couldn't update it. Close it and ask again. Nothing was lost." ;;
    *"invalid path"*)
      die "A teammate shared a note whose name this computer can't store (Windows doesn't allow : * ? \" < > | in names). Ask them to rename it. Details: $(printf '%s' "$out" | grep -m1 'invalid path')" ;;
  esac
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
  local repo=${1:-} dir=${2:-$HOME/SecondBrain} out login name id svc ghpath apps
  [ -n "$repo" ] || die "Tell me which GitHub repository holds the shared brain (for example my-team/notes)."
  need_gh
  case $dir in /*) ;; *) dir="$PWD/$dir" ;; esac
  svc=$(cloud_folder "$dir") && die "$dir is inside $svc, which can damage the shared brain's hidden files. Pick a folder outside it, for example ~/SecondBrain."
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
  # Absolute path, so it still works when gh isn't on the shell's PATH.
  ghpath=$(command -v "$GH")
  g config --local --add credential.helper "!'$ghpath' auth git-credential"

  login=$("$GH" api user --jq .login 2>/dev/null)
  [ -n "$login" ] || die "I couldn't read your GitHub account. Run:  $SIGNIN_CMD  and try again."
  g config brainsync.login "$login"
  if [ -z "$(g config user.name || true)" ]; then
    name=$("$GH" api user --jq '.name // .login' 2>/dev/null); [ -n "$name" ] || name=$login
    id=$("$GH" api user --jq .id 2>/dev/null)
    g config --local user.name "$name"
    g config --local user.email "${id:+$id+}$login@users.noreply.github.com"
  fi

  if is_windows; then
    g config --local core.autocrlf true   # Windows line endings on disk, plain ones on GitHub
    g config --local core.longpaths true  # deep Obsidian folders exceed Windows' 260-character limit
  fi

  # Ignore OS/editor clutter locally (doesn't touch the shared repo).
  mkdir -p "$BRAIN_DIR/.git/info"
  for pat in '.DS_Store' 'Thumbs.db' 'desktop.ini' '~$*' '*.swp' '.obsidian/workspace*' '.obsidian/cache'; do
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
  if is_windows; then apps="Obsidian, VS Code, Word, Notepad…"; else apps="Obsidian, VS Code, TextEdit…"; fi
  info "Edit or add files there with any app ($apps), then just say \"push\" or \"pull\"."
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
  warn_windows_names

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

# ── Installing what's missing, without admin rights ───────────────────────────
download() {  # $1 url, $2 file
  curl -fsSL --retry 3 -o "$2" "$1" 2>/dev/null || wget -q -O "$2" "$1" 2>/dev/null
}

install_gh() {  # user-local copy of the GitHub CLI from its official releases
  local os arch ver url tmp exe f name
  case $(uname -s) in
    Darwin) os=macOS ;; Linux) os=linux ;; MINGW*|MSYS*|CYGWIN*) os=windows ;;
    *) die "I can't install the GitHub helper on this kind of computer. Install it from https://cli.github.com" ;;
  esac
  case $(uname -m) in x86_64|amd64) arch=amd64 ;; arm64|aarch64) arch=arm64 ;; *) arch=386 ;; esac
  ver=$(curl -fsSIL -o /dev/null -w '%{url_effective}' https://github.com/cli/cli/releases/latest 2>/dev/null | sed -n 's#.*/tag/v##p')
  [ -n "$ver" ] || die "I couldn't reach GitHub to download its helper. Check your internet connection and ask again."
  # macOS zips are per chip (the universal build is only a .pkg installer).
  case $os in
    macOS)   set -- "gh_${ver}_macOS_${arch}.zip" "gh_${ver}_macOS_universal.zip" ;;
    windows) set -- "gh_${ver}_windows_${arch}.zip" ;;
    linux)   set -- "gh_${ver}_linux_${arch}.tar.gz" ;;
  esac
  tmp=$(mktemp -d); f=""
  for name in "$@"; do
    url="https://github.com/cli/cli/releases/download/v${ver}/$name"
    if download "$url" "$tmp/$name"; then f=$name; break; fi
  done
  [ -n "$f" ] || { rm -rf "$tmp"; die "Downloading the GitHub helper failed. Check your internet connection and ask again. Details for whoever helps you: tried $* from v$ver"; }
  case $f in
    *.zip)
      if command -v unzip >/dev/null 2>&1; then unzip -q "$tmp/$f" -d "$tmp/x"
      else powershell.exe -NoProfile -Command "Expand-Archive -Force '$(cygpath -w "$tmp/$f")' '$(cygpath -w "$tmp/x")'" >/dev/null
      fi ;;
    *) mkdir -p "$tmp/x" && tar -xzf "$tmp/$f" -C "$tmp/x" ;;
  esac
  exe=$(find "$tmp/x" -type f \( -name gh -o -name gh.exe \) -path '*bin/*' | head -n 1)
  [ -n "$exe" ] || { rm -rf "$tmp"; die "The GitHub helper download looked wrong. Install it from https://cli.github.com"; }
  mkdir -p "$TOOLS_DIR/bin"
  cp "$exe" "$TOOLS_DIR/bin/" && chmod +x "$TOOLS_DIR/bin/$(basename "$exe")"
  rm -rf "$tmp"
  ok "Installed the GitHub helper (version $ver) for you only, in $TOOLS_DIR/bin"
}

cmd_install_tools() {
  if is_mac && { ! command -v git >/dev/null 2>&1 || mac_git_stub; }; then
    xcode-select --install >/dev/null 2>&1 || true
    warn "A window from Apple has opened asking to install developer tools. Click Install (it takes about 10 minutes), then tell me when it's finished."
    exit 3
  fi
  if ! command -v git >/dev/null 2>&1; then
    if is_windows; then die "Git for Windows is missing. Open PowerShell and type  winget install --id Git.Git -e  then reopen Claude Code."; fi
    die "Git is missing. Ask whoever manages this computer to install it (for example: sudo apt install git)."
  fi
  ok "Git is ready."
  if [ -n "${BRAINSYNC_FORCE_GH_DOWNLOAD:-}" ] || ! command -v "$GH" >/dev/null 2>&1; then
    install_gh
    GH=$TOOLS_DIR/bin/gh; [ -x "$GH" ] || GH=$TOOLS_DIR/bin/gh.exe
    "$GH" --version >/dev/null 2>&1 || die "The GitHub helper was installed but won't start. Install it from https://cli.github.com"
  else
    ok "The GitHub helper is ready."
  fi
  if "$GH" auth status >/dev/null 2>&1; then
    ok "You're signed in to GitHub."
  else
    info "Next: sign in to GitHub (run: brain.sh signin)."
  fi
}

# ── GitHub sign-in that works without a terminal ──────────────────────────────
# gh's browser sign-in runs in the background; we print its one-time code so
# Claude can pass it on, then `signin-wait` waits until GitHub confirms.
cmd_signin() {
  need_git
  command -v "$GH" >/dev/null 2>&1 || die "The GitHub helper isn't installed yet (run: brain.sh install-tools)."
  if "$GH" auth status >/dev/null 2>&1; then ok "You're already signed in to GitHub as $("$GH" api user --jq .login 2>/dev/null)."; return 0; fi
  mkdir -p "$CONFIG_DIR"
  local log="$CONFIG_DIR/signin.log" code="" i
  : > "$log"
  ( nohup "$GH" auth login -h github.com -p https --web --skip-ssh-key </dev/null >"$log" 2>&1 & ) 2>/dev/null
  for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15; do
    code=$(grep -o '[A-Z0-9]\{4\}-[A-Z0-9]\{4\}' "$log" 2>/dev/null | head -n 1)
    [ -n "$code" ] && break
    sleep 1
  done
  [ -n "$code" ] || die "I couldn't start the GitHub sign-in. Details for whoever helps you: $(tail -n 3 "$log" | tr '\n' ' ')"
  ok "Your one-time code is:  $code"
  info "Your browser should open GitHub. If it doesn't, go to https://github.com/login/device"
  info "Type the code there, click Continue, then Authorize. Tell me when you've done it."
  exit 3
}

cmd_signin_wait() {
  local i
  for i in $(seq 1 60); do
    if "$GH" auth status >/dev/null 2>&1; then ok "Signed in to GitHub as $("$GH" api user --jq .login 2>/dev/null)."; return 0; fi
    sleep 3
  done
  die "GitHub hasn't confirmed the sign-in yet. Ask me to sign in again and I'll give you a new code."
}

cmd_doctor() {  # check every prerequisite and print a plain fix for each
  local bad=0 ghp svc dir
  printf 'Checking this computer…\n'
  if ! command -v git >/dev/null 2>&1; then
    printf '✖ Git is missing. %s\n' "$GIT_HINT"; bad=1
  elif mac_git_stub; then
    printf "✖ Apple's developer tools aren't installed. Open Terminal, type  xcode-select --install  and click Install.\n"; bad=1
  else
    ok "Git is installed."
  fi
  if ! ghp=$(command -v "$GH" 2>/dev/null); then
    if is_windows; then
      printf '✖ The GitHub helper is missing. %s\n' "$GH_HINT"
    elif is_mac && ! command -v brew >/dev/null 2>&1; then
      printf '✖ The GitHub helper is missing, and so is Homebrew (which installs it). Install Homebrew from https://brew.sh, then type  brew install gh\n'
    else
      printf '✖ The GitHub helper is missing. Mac: type  brew install gh   Other: https://cli.github.com\n'
    fi
    bad=1
  else
    ok "The GitHub helper is installed."
    if ! PATH=$ORIG_PATH command -v "$GH" >/dev/null 2>&1; then
      if is_windows; then
        warn "The GitHub helper was just installed. Close and reopen Claude Code so everything can find it."
      else
      warn "Your Terminal can't find Homebrew's programs. Fix: type  echo 'eval \"\$($(dirname "$ghp")/brew shellenv)\"' >> ~/.zprofile  then open a new Terminal window."
      fi
    fi
    if "$GH" auth status >/dev/null 2>&1; then
      ok "Signed in to GitHub as $("$GH" api user --jq .login 2>/dev/null || echo '?')."
    else
      printf '✖ Not signed in to GitHub. Type  %s\n' "$SIGNIN_CMD"; bad=1
    fi
  fi
  if [ -f "$CONFIG_FILE" ]; then
    dir=$(sed -n 's/^BRAIN_DIR=//p' "$CONFIG_FILE")
    if [ -d "$dir/.git" ]; then
      ok "Your shared brain is connected at $dir"
      if svc=$(cloud_folder "$dir"); then warn "That folder is inside $svc, which can damage it. Ask me to move it somewhere else, like ~/SecondBrain."; fi
    else
      printf '✖ Your shared brain folder (%s) is missing. Ask me to set it up again.\n' "$dir"; bad=1
    fi
  else
    info "No shared brain is connected yet. Say: set up our shared brain from <owner/repo>."
  fi
  [ $bad -eq 0 ] && ok "Everything looks ready." || exit 1
}

case ${1:-} in
  setup)  shift; cmd_setup "$@" ;;
  pull)   shift; cmd_pull ;;
  push)   shift; cmd_push "$*" ;;
  status) shift; cmd_status ;;
  where)  load_brain; printf '%s\n' "$BRAIN_DIR" ;;
  doctor) cmd_doctor ;;
  install-tools) cmd_install_tools ;;
  signin) cmd_signin ;;
  signin-wait) cmd_signin_wait ;;
  *) printf 'usage: brain.sh setup <owner/repo> [folder] | pull | push [description] | status | where | doctor | install-tools | signin | signin-wait\n'; exit 1 ;;
esac
