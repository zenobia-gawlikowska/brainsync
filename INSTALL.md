# Installing brainsync (instructions for the AI assistant)

These steps work in **Claude Code** and in **OpenAI Codex**. Only steps 1 and 2 differ between them.

A person asked you to install brainsync, probably with a message like *"install brainsync from github.com/zenobia-gawlikowska/brainsync"*. They may know nothing about git, GitHub or terminals. **Do every step yourself.** Only ask them to do the few things only a person can do: click a button, enter a code in their browser, or tell you the name of their team's notes repository.

Talk to them in plain words. Don't use git jargon, and don't show them commands unless they ask.

Every step is safe to repeat. If anything is interrupted, just start again from step 1.

## 1. Install the skill

### Claude Code

This only works in Claude Code running on the person's own computer (the desktop app or the `claude` terminal command). If you are running in Claude Code on the web (a cloud session in a remote container), stop: tell the person brainsync needs Claude Code on their computer, because notes and sign-in live there.

Run these with your shell tool (Bash, or PowerShell on Windows if you don't have Bash):

```
claude plugin marketplace add zenobia-gawlikowska/brainsync
claude plugin install brainsync@brainsync
claude plugin update brainsync@brainsync
```

If the marketplace is already added or the plugin is already installed, these say so and succeed. That's fine.

### Codex

This only works in Codex running on the person's own computer (the Codex app, IDE extension or CLI). If you are Codex Cloud (Codex in ChatGPT, running on OpenAI's computers), stop: tell the person brainsync needs Codex installed on their computer, because notes and sign-in live there.

Codex loads personal skills from `~/.agents/skills`. Copy the skill folder there. This needs no git, so it also works on a Mac before Apple's developer tools are installed. Running it again updates the skill.

- **macOS, Linux, or Git Bash on Windows:**
  ```bash
  t=$(mktemp -d)
  curl -fsSL https://codeload.github.com/zenobia-gawlikowska/brainsync/tar.gz/refs/heads/master | tar -xz -C "$t"
  mkdir -p ~/.agents/skills && rm -rf ~/.agents/skills/brainsync
  cp -R "$t/brainsync-master/skills/brainsync" ~/.agents/skills/brainsync && rm -rf "$t"
  ```
- **Windows PowerShell:**
  ```powershell
  $t = Join-Path $env:TEMP "brainsync-src"; Remove-Item -Recurse -Force $t -ErrorAction SilentlyContinue; New-Item -ItemType Directory $t | Out-Null
  curl.exe -fsSL https://codeload.github.com/zenobia-gawlikowska/brainsync/tar.gz/refs/heads/master -o "$t\src.tgz"
  tar -xzf "$t\src.tgz" -C $t
  New-Item -ItemType Directory -Force "$HOME\.agents\skills" | Out-Null; Remove-Item -Recurse -Force "$HOME\.agents\skills\brainsync" -ErrorAction SilentlyContinue
  Copy-Item -Recurse "$t\brainsync-master\skills\brainsync" "$HOME\.agents\skills\brainsync"
  ```

Codex runs commands in a sandbox. These steps, and every brainsync command after them, need the network and write outside the current folder (to `~/.agents`, `~/.config/brainsync`, `~/.local/share/brainsync` and the notes folder). If the sandbox blocks a command, ask the person to approve running it with full access. Tell them it's only brainsync's own script talking to GitHub.

## 2. Find the script

Every later step runs one script, `brain.sh`.

**In Codex** it is at `~/.agents/skills/brainsync/scripts/brain.sh` (on Windows: `$HOME\.agents\skills\brainsync\scripts\brain.sh`). If Codex runs your commands in PowerShell, Git for Windows must be installed (see below), and every step runs through its bash.

**In Claude Code**, locate the newest copy (use `$CLAUDE_CONFIG_DIR` instead of `~/.claude` if it is set):

- **Bash** (macOS, Linux, or Windows with Git Bash):
  ```bash
  ls -d ~/.claude/plugins/cache/brainsync/brainsync/*/skills/brainsync/scripts/brain.sh | tail -n 1
  ```
- **Windows without a Bash tool** (PowerShell only): Git for Windows is missing, and it provides the bash that runs the script. Install it, then find bash:
  ```powershell
  winget install --id Git.Git -e --source winget --accept-package-agreements --accept-source-agreements
  ```
  Tell the person a Windows prompt may ask *"Do you want to allow this app to make changes?"* and to click **Yes**. Then use `& "$env:ProgramFiles\Git\bin\bash.exe" <path-to-brain.sh> <command>` for every step below. In Codex, `<path-to-brain.sh>` is the path above. In Claude Code it comes from:
  ```powershell
  (Get-ChildItem "$HOME\.claude\plugins\cache\brainsync\brainsync\*\skills\brainsync\scripts\brain.sh" | Select-Object -Last 1).FullName
  ```

Call the result `BRAIN`. Run it as `bash "$BRAIN" <command>`.

## 3. Install the tools it needs

```bash
bash "$BRAIN" install-tools
```

This needs no administrator rights. It checks for git and installs the GitHub helper (`gh`) for this user only if it's missing.

- **Exit code 3** means it's waiting for the person. On a Mac this is Apple's developer tools window: tell them to click **Install** and to let you know when it's finished (about 10 minutes). Then run `install-tools` again.
- **Exit code 1**: pass on the ✖ line in plain words.

## 4. Sign in to GitHub

```bash
bash "$BRAIN" signin
```

If they're already signed in, it says so. Go to step 5. Otherwise it **exits with code 3** after printing a one-time code such as `ABCD-1234`. Give the person that code and say:

> Your browser should open a GitHub page (if not, go to github.com/login/device). Type this code, click **Continue**, then **Authorize**. If you don't have a GitHub account yet, the page lets you create one for free. Tell me when you're done.

When they say they're done:

```bash
bash "$BRAIN" signin-wait
```

If the sign-in can't start in the background, run `gh auth login -h github.com -p https --web` as a **background** command, read the one-time code from its output, and continue in the same way. Never ask for a password or token.

## 5. Connect their team's notes

Ask: *"What's the name of your team's shared brain on GitHub? It looks like `team-name/notes`."* If they don't know, say the person who runs it can tell them, and that they need to accept GitHub's email invitation first. If they're the one starting it, see `docs/owner-guide.md` and help them create the repository on github.com.

```bash
bash "$BRAIN" setup <owner/repo>
```

Pass on the result. A ✖ about permission means they haven't been invited yet, or haven't accepted the invitation.

## 6. Finish

```bash
bash "$BRAIN" doctor
```

When it says everything is ready, tell them:

> All done! Your team's notes are in the **SecondBrain** folder in your home folder. Open them with any app. From now on, just tell me **"pull"** to get your teammates' latest notes and **"push"** to share yours.

- **Claude Code:** add *"Start a new conversation first so I pick up the new skill."* On Windows, if you used PowerShell in step 2, also tell them to close and reopen Claude Code once, so it can use Git Bash from then on.
- **Codex** picks up the new skill on its own. If "push" or "pull" isn't recognised, tell them to restart Codex.
