---
name: brainsync
description: Sync the user's shared team "second brain" — a GitHub repository of notes and documents — for people who know nothing about git. Use whenever the user says push, pull, sync, share my notes, upload, get the latest, download updates, "what's new", "what haven't I shared", or asks to set up / connect / join a shared brain, team notes or knowledge repo. Pull requests, merging and overlapping edits are handled automatically.
allowed-tools: Bash(*/skills/brainsync/scripts/brain.sh *), Bash(*/skills/brainsync/scripts/brain.sh)
---

# Shared brain

The user treats a GitHub repository as a shared folder of notes. **You do the git so they never have to.** Every operation goes through one script, which saves first, never loses anything, and prints plain-English lines to pass on:

```
<this skill's base directory>/scripts/brain.sh <command>
```

| User says | Run |
| --- | --- |
| "install brainsync", first-time setup | `brain.sh install-tools`, then `signin` (and `signin-wait`), then ask for the repository and run `setup`, then `doctor`. Full steps: https://github.com/zenobia-gawlikowska/brainsync/blob/master/INSTALL.md |
| "set up / connect / join our brain (my-team/notes)" | `brain.sh setup <owner/repo> [folder]` (default folder `~/SecondBrain`) |
| "pull", "get the latest", "what did others add" | `brain.sh pull` |
| "push", "share", "upload my notes", "sync" | `brain.sh push "<one-line description>"`. For "sync", run `push` (it gets updates first) |
| "what's changed", "anything unshared?" | `brain.sh status` |
| "where are my notes?" | `brain.sh where` |
| "is everything set up?", "it doesn't work", before the first `setup` | `brain.sh doctor` (checks this computer and prints a plain fix for each problem) |

## How to talk to the user

- **Don't use git words** (commit, branch, merge, pull request, rebase, conflict, HEAD, origin) unless the user uses them first. Use: *save*, *share*, *get updates*, *share request / approval*, *edited the same note at the same time*.
- Pass on the script's result in 1–3 short sentences. Leave out file paths in temp folders and anything after "Details for whoever helps you" unless they ask.
- Lines starting with ✔ mean it worked. ⚠ means something they should know about. ✖ means it failed, and the line explains why in plain words. Exit code 2 means the changes were sent but a teammate has to approve them; give the user the approval link to pass on.

## Rules

1. **Never run git commands in the brain folder that change anything** (no `git commit/merge/reset/push/checkout/stash`, no editing `.git/`). They skip the script's protections. Read-only `git log` or `git diff` is fine if the user asks about history ("who changed the roadmap last week?"). Answer in plain words.
2. **For push, write the description yourself**: a short summary of *what the notes are about* ("Added Q3 interview notes; updated pricing ideas"), not file names. Run `brain.sh status` first if you need to see what changed.
3. **Not signed in, or something missing?** Run `brain.sh install-tools` (installs what's missing, no admin), then `brain.sh signin`. It exits with code 3 after printing a one-time code: give the user the code, tell them to enter it on the GitHub page that opens (or github.com/login/device) and click Authorize, then run `brain.sh signin-wait`. Exit code 3 from any command means "waiting for the user". Say what they need to do and run it again once they're done. Never ask for their password or token. `brain.sh doctor` lists anything still wrong.
4. The user can edit files in the brain folder with any app (Obsidian, VS Code, Finder, TextEdit) or ask you to write notes there. Either way, the next push shares them.
5. **On Windows, always run the script with the Bash tool** (Git Bash), never PowerShell, and use forward slashes in its path. If there is no Bash tool, Git for Windows is missing: tell the user to type `winget install --id Git.Git -e` in PowerShell, then close and reopen Claude Code. If the script says a note is open in another app, ask them to close it (Word and Excel lock open files) and try again.
6. **Don't put the brain folder inside iCloud Drive, OneDrive, Dropbox or Google Drive** (on Windows, Documents and Desktop are often inside OneDrive). The script refuses; suggest `~/SecondBrain`.

## When notes overlapped (⚠ "changed the same note")

The script has already handled it: the teammate's version keeps the original name and the user's version is saved next to it as `name (your version).ext`. Both are now shared. Nothing was lost.

Then **offer to combine them**. This is where you add the most value. If the user agrees:
1. Read both files and merge them sensibly: keep everyone's additions, and where the two genuinely disagree, ask the user which one to keep.
2. Write the result into the original file and delete the `(your version)` file.
3. Run `brain.sh push "Combined overlapping edits to <topic>"`.

## Failure cases

- "Teammates kept sharing at the same moment" → wait a few seconds and push again once. If it fails twice, tell the user their notes are safe on this computer.
- "You don't have permission" → the repository owner has to invite them as a collaborator on GitHub (Settings → Collaborators).
- "No shared brain is connected yet" → ask which repository to use, then run `setup`.
- ⚠ "names won't work for teammates on Windows" → offer to rename the listed files (for example replace `:` with `-`) and push again.
