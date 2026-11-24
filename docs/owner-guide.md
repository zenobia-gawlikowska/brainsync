# Running a shared brain (for the owner)

One person creates the shared brain on GitHub and invites the team. This takes about 10 minutes.

## 1. Create the repository

1. Sign in at https://github.com and click **+** (top right) → **New repository**.
2. Give it a short name, for example `team-notes`.
3. Choose **Private** unless the notes should be public.
4. You can leave it empty. brainsync creates a first page the first time someone sets it up.
5. Click **Create repository**.

Your team's brain is now called `your-account/team-notes`. That's what everyone types when they set it up.

## 2. Invite teammates

Everyone who shares notes needs **write** access. Read-only access isn't supported yet.

1. Open the repository → **Settings** → **Collaborators** (for an organization: **Collaborators and teams**).
2. Click **Add people**, enter each person's GitHub username or email, and choose the **Write** role.
3. Each person gets an email from GitHub and must click **Accept invitation** before setting up.

Then send each person [First-time setup on a Mac](first-time-setup-mac.md) or [First-time setup on Windows](first-time-setup-windows.md), and the repository name.

## 3. Decide whether shares need approval

**By default, shares go straight in.** When someone says "push", their notes are added to the shared brain right away. This suits most teams.

If you want a teammate to approve each share first:

1. Repository → **Settings** → **Rules** → **Rulesets** (or **Branches** → **Add branch protection rule**) for the `main` branch.
2. Turn on **Require a pull request before merging** with at least **1 approval**.
3. Optional: under **Settings → General**, turn on **Allow auto-merge** so approved shares go in without anyone clicking Merge.

Shares then wait, and the person sharing gets a link to send to whoever approves. On private repositories this needs a paid GitHub plan. This approval flow hasn't been tested against real GitHub yet.

## 4. Good to know

- **Merge settings**: brainsync works with whichever merge methods the repository allows (Settings → General → Pull Requests).
- **Big files**: GitHub refuses single files over 100 MB.
- **History**: every share is kept, so a deleted or overwritten note can always be recovered from GitHub.
- **Removing someone**: remove them under Settings → Collaborators. Their copy stays on their computer, but they can no longer share or get updates.
