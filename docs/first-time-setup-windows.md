# First-time setup on Windows

This guide takes about 15 minutes and you only do it once. You'll type a few commands into **PowerShell**, a built-in Windows app where you type instructions instead of clicking. Copy each command exactly, paste it (right-click pastes), and press **Enter**.

Before you start, you need:

- **Windows 10 or 11.**
- A **GitHub account** (free, at https://github.com/signup).
- An **invitation** to your team's shared brain. The person who runs it sends this from GitHub. Open the email from GitHub and click **Accept invitation**.
- A Claude subscription that includes Claude Code.

## 1. Open PowerShell

Click **Start**, type `PowerShell`, and click **Windows PowerShell**. A blue or black window with a blinking cursor opens. You don't need "Run as administrator".

## 2. Install Git for Windows

```powershell
winget install --id Git.Git -e
```

If Windows asks *"Do you want to allow this app to make changes?"*, click **Yes**. If it asks you to agree to terms, type `Y` and press **Enter**.

Claude Code needs this to run brainsync. Don't skip it.

## 3. Install the GitHub helper

```powershell
winget install --id GitHub.cli -e
```

## 4. Close and reopen PowerShell

Close the PowerShell window and open a new one (step 1). Newly installed programs are only found by windows opened after the install.

## 5. Sign in to GitHub

```powershell
gh auth login -h github.com -p https --web
```

PowerShell shows a one-time code such as `ABCD-1234`. Press **Enter**. Your browser opens on GitHub. Type the code, then click **Authorize**. PowerShell then says *"Logged in as …"*.

## 6. Install Claude Code

```powershell
irm https://claude.ai/install.ps1 | iex
```

It shows no progress while it downloads, so give it a minute. Then close PowerShell, open a new one, type `claude`, and sign in when asked. Type `/exit` to leave it again.

## 7. Add brainsync to Claude Code

```powershell
claude plugin marketplace add zenobia-gawlikowska/brainsync
claude plugin install brainsync@brainsync
```

## 8. Connect your shared brain

Start Claude Code by typing `claude`, then type in plain words:

> check my computer is ready for the shared brain

Claude runs a check and tells you about anything still missing, and how to fix it. When everything is ready, type the name your team gave you:

> set up our shared brain from my-team/notes

Your notes appear in a folder called **SecondBrain** in your user folder (`C:\Users\<your name>\SecondBrain`). Open it in File Explorer, Obsidian, Word or any other app. From now on, just tell Claude **"pull"** to get your teammates' notes and **"push"** to share yours.

> **Don't move the SecondBrain folder into OneDrive, Dropbox, Google Drive or iCloud Drive.** Those apps can damage it, and your notes are already backed up on GitHub. On many Windows computers **Documents and Desktop are inside OneDrive**, so don't put it there either.

## If something goes wrong

Ask Claude *"check my computer is ready for the shared brain"* again. It lists each problem with a fix. Common ones:

| What you see | Fix |
| --- | --- |
| `winget` isn't recognized | Install **App Installer** from the Microsoft Store, then try again |
| `gh` or `git` isn't recognized | Close and reopen PowerShell (step 4). For Claude Code, close and reopen it too |
| Claude says it can't run commands with Bash | Git for Windows is missing. Do step 2, then close and reopen Claude Code |
| "A note is open in another app" | Close the file in Word, Excel or your editor, then ask again |
| "A teammate shared a note whose name this computer can't store" | Ask them to rename it. Windows doesn't allow `: * ? " < > \|` in file names |
| "You don't have permission" | Ask the person who runs the shared brain to invite you, then accept the email from GitHub |
