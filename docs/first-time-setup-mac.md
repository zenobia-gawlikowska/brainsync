# First-time setup on a Mac

This guide takes about 20 minutes and you only do it once. You'll type a few commands into **Terminal**, a built-in Mac app where you type instructions instead of clicking. Copy each command exactly, paste it, and press **Return**.

Before you start, you need:

- A **GitHub account** (free, at https://github.com/signup).
- An **invitation** to your team's shared brain. The person who runs it sends this from GitHub. Open the email from GitHub and click **Accept invitation**.
- A Claude subscription that includes Claude Code.

> Windows isn't supported yet. These steps are for a Mac.

## 1. Open Terminal

Press **⌘ Command + Space**, type `Terminal`, and press **Return**. A window with a blinking cursor opens. Keep it open for all the steps below.

## 2. Install Apple's developer tools

```bash
xcode-select --install
```

A window pops up. Click **Install** and wait until it says it's done (this can take 10 minutes). If Terminal says *"already installed"*, that's fine. Go on to the next step.

## 3. Install Homebrew

Homebrew is a free tool that installs other programs. Copy this whole line:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

It asks for your **Mac password** (the one you use to log in). Nothing appears as you type it. That's normal. Press **Return** when you're done.

**Don't skip the end of this step.** When Homebrew finishes, it prints a section called **"Next steps"** with two or three lines to copy. Copy and run those lines. On newer Macs (M1, M2, M3, M4 and later) they look like this:

```bash
echo >> ~/.zprofile
echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
eval "$(/opt/homebrew/bin/brew shellenv)"
```

To check it worked, type `brew --version`. You should see a version number, not *"command not found"*.

## 4. Install the GitHub helper

```bash
brew install gh
```

## 5. Sign in to GitHub

```bash
gh auth login -h github.com -p https --web
```

Terminal shows a one-time code such as `ABCD-1234`. Press **Return**. Your browser opens on GitHub. Paste the code, then click **Authorize**. Terminal then says *"Logged in as …"*.

## 6. Install Claude Code

Follow the instructions at https://code.claude.com/docs (look for *Install*). When it's done, type `claude` in Terminal and sign in when asked. Then type `/exit` to leave it again.

## 7. Add brainsync to Claude Code

```bash
claude plugin marketplace add zenobia-gawlikowska/brainsync
claude plugin install brainsync@brainsync
```

## 8. Connect your shared brain

Start Claude Code by typing `claude`, then type in plain words:

> check my computer is ready for the shared brain

Claude runs a check and tells you about anything still missing, and how to fix it. When everything is ready, type the name your team gave you:

> set up our shared brain from my-team/notes

Your notes appear in a folder called **SecondBrain** in your home folder. Open it in Finder, Obsidian or any other app. From now on, just tell Claude **"pull"** to get your teammates' notes and **"push"** to share yours.

> **Don't move the SecondBrain folder into iCloud Drive, OneDrive, Dropbox or Google Drive.** Those apps can damage it. Your notes are already backed up on GitHub.

## If something goes wrong

Ask Claude *"check my computer is ready for the shared brain"* again. It lists each problem with a fix. Common ones:

| What you see | Fix |
| --- | --- |
| A popup asks you to install "command line developer tools" | Click **Install** (that's step 2), then try again |
| `gh: command not found` or `brew: command not found` | You skipped the "Next steps" lines at the end of step 3. Run them, then open a new Terminal window |
| "You don't have permission" | Ask the person who runs the shared brain to invite you, then accept the email from GitHub |
| "Not signed in to GitHub" | Repeat step 5 |
