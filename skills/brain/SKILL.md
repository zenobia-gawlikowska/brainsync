---
name: brain
description: Sync the user's shared team "second brain" — a GitHub repository of notes and documents — for people who know nothing about git. Use whenever the user says push, pull, sync, share my notes, upload, get the latest, download updates, "what's new", "what haven't I shared", or asks to set up / connect / join a shared brain, team notes or knowledge repo. Pull requests, merging and overlapping edits are handled automatically.
---

# Shared brain

The user treats a GitHub repository as a shared folder of notes. **You do the git so they never have to.** Every operation goes through one script, which saves first, never loses anything, and prints plain-English lines to pass on:

```
<this skill's base directory>/scripts/brain.sh <command>
```

| User says | Run |
| --- | --- |
| "set up / connect / join our brain (my-team/notes)" | `brain.sh setup <owner/repo> [folder]` (default folder `~/SecondBrain`) |
| "pull", "get the latest", "what did others add" | `brain.sh pull` |
| "push", "share", "upload my notes", "sync" | `brain.sh push "<one-line description>"`. For "sync", run `push` (it gets updates first) |
| "what's changed", "anything unshared?" | `brain.sh status` |
| "where are my notes?" | `brain.sh where` |

## How to talk to the user

- **Don't use git words** (commit, branch, merge, pull request, rebase, conflict, HEAD, origin) unless the user uses them first. Use: *save*, *share*, *get updates*, *share request / approval*, *edited the same note at the same time*.
- Pass on the script's result in 1–3 short sentences. Leave out file paths in temp folders and anything after "Details for whoever helps you" unless they ask.
- Lines starting with ✔ mean it worked. ⚠ means something they should know about. ✖ means it failed, and the line explains why in plain words. Exit code 2 means the changes were sent but a teammate has to approve them; give the user the approval link to pass on.

## Rules

1. **Never run git commands in the brain folder that change anything** (no `git commit/merge/reset/push/checkout/stash`, no editing `.git/`). They skip the script's protections. Read-only `git log` or `git diff` is fine if the user asks about history ("who changed the roadmap last week?"). Answer in plain words.
2. **For push, write the description yourself**: a short summary of *what the notes are about* ("Added Q3 interview notes; updated pricing ideas"), not file names. Run `brain.sh status` first if you need to see what changed.
3. **Not signed in to GitHub?** Tell the user to type `! gh auth login` in this chat, then choose GitHub.com → HTTPS → "Login with a web browser". Never ask for their password or token. Missing `gh` → `brew install gh` (Mac) or https://cli.github.com.
4. The user can edit files in the brain folder with any app (Obsidian, VS Code, Finder, TextEdit) or ask you to write notes there. Either way, the next push shares them.

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
