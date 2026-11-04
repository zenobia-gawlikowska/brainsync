# brainsync: "Now Git Does the Work" (motion storyboard)

| | |
| --- | --- |
| **Title** | brainsync: Now Git Does the Work |
| **Duration** | 90 seconds (11 scenes) |
| **Format** | Tool-agnostic storyboard for Claude Motion. 16:9, 1920x1080, 30 fps. Each scene can map to a composition, timeline section or sequence. |
| **Audience** | Team leads and non-technical knowledge workers who would use a shared "second brain", plus the engineers evaluating the spike. |
| **One-line pitch** | Say "push" or "pull" in Claude. Claude runs one script that saves your notes, shares them through GitHub, and sorts out overlapping edits. You never touch git. |

---

## Style guide

**Look.** A hand-drawn doodle style: a sketchbook page brought to life. White background and confident black ink lines with slight wobble. Characters are made of simple round shapes, with one soft grey shadow on one side. The ground is a few loose horizontal scribbles, not a solid floor. One accent color does the narrative work.

**Palette**

| Token | Hex | Use |
| --- | --- | --- |
| Paper | `#FFFFFF` | Background, always |
| Ink | `#111111` | Every outline, all hand-lettered text |
| Shadow grey | `#D6D6D6` | One-sided shading on characters |
| Git orange | `#F05032` | The GIT ball, the "under the hood" side, key highlights |
| Success green | `#2DA44E` | Check marks only (the "Shared!" tick) |
| Warning amber | `#E3A008` | The ⚠ heads-up badge and the storm scene only |
| Claude clay | `#D97757` (muted, used sparingly) | The helper's small glow or spark. Close to git orange, so keep it in a different role (soft glow, never a fill) |

**Line style.** 4-6 px stroke at 1080p, round caps and joins. Add a "boil" (redraw the lines with a slight jitter every 3 frames) so the drawings feel hand-made even when nothing moves. No gradients and no drop shadows besides the grey side-shade.

**Typography**
- Captions and speech bubbles: a hand-lettered, all-caps marker face (for example Gaegu, Patrick Hand or Caveat Brush). Write on stroke by stroke.
- Character labels (ME, GIT, ALICE, BOB): a bold, plain grotesque, like a label stuck under a doodle.
- Chat bubbles and terminal snippets: a clean monospace (for example JetBrains Mono) inside rounded hand-drawn bubbles. This is the only "digital" type, and it marks what the user actually sees.
- Keep on-screen text to 6 words or fewer per beat wherever possible.

**Motion principles**
1. **Squash and stretch, lightly.** The GIT ball is a soft physical object. It squashes when poked, bounces when it gets to work, and rolls on its own once it's helping.
2. **Draw-on reveals.** New objects ink themselves in (stroke reveal, 8-12 frames) instead of fading in.
3. **One thing moves at a time.** The audience is non-technical, so lead the eye. Use ease-in-out curves and hold for 0.5 s after each key beat.
4. **Calm hides busy.** The user's side is always still and calm. All the frantic motion lives behind the curtain.
5. **Transitions** are page-like: a pencil wipe, a page turn, or an ink line that sweeps across and becomes the next scene's ground.

---

## Recurring characters

| Character | Design | Personality |
| --- | --- | --- |
| **ME** | A blank-faced stick figure with a round head, soft grey shade on the left side, and a bold "ME" label below. Starts the film holding a long, knobbly stick. | Weary, then relieved. Stands in for any non-technical teammate. |
| **GIT** (the ball) | A bouncy git-orange ball with the white branching-node mark on its face (three dots joined by lines). No face at first. Later it gets two dot eyes so it can react. | Sulky and unmovable at first. Turns into a cheerful worker once Claude gives it instructions. |
| **ALICE** | A stick figure like ME, with a ponytail loop and an "ALICE" label. | A teammate who shares often and fast. |
| **BOB** | A stick figure like ME, with a little beanie and a "BOB" label. | A teammate who edits the same notes as Alice. |
| **Claude, the helper** | A small, friendly, generic helper doodle. A rounded speech bubble with a soft clay-colored spark or glow inside, with tiny arms. **Not a logo** and not a brand mark. | Calm, polite, quick. Speaks only in plain words. |
| **The Brain** | A shared folder drawn as a rounded cloud-shaped notebook labelled "TEAM BRAIN", with note cards sliding in and out. | The thing everyone cares about. |

---

## Scene-by-scene

### Scene 1: The Poke (cold open)
**Duration:** 7 s (0:00-0:07)

- **VISUAL:** Fade up from white. ME stands on the scribbled ground and prods the GIT ball with a long stick. Each poke makes the ball squash a little and wobble back, and it doesn't go anywhere. A speech bubble ink-draws itself above ME with a short "come on, do the work" plea. Three pokes, getting more tired. On the third, ME's shoulders sag.
- **ON-SCREEN TEXT:** Speech bubble: "C'MON… DO THE WORK." Labels: "ME", "GIT".
- **VOICE-OVER:** "Sharing notes through GitHub should be easy. For most of us, it feels like this."
- **SFX / TRANSITION:** Soft rubbery *boink* on each poke. A tired exhale on the last one. Hold 0.5 s, then a pencil wipe from left to right.

### Scene 2: Why it's hard
**Duration:** 7 s (0:07-0:14)

- **VISUAL:** ME by the ball, with a ring of jargon words orbiting their head and ink-writing one after another: *commit, branch, rebase, pull request, merge conflict, HEAD*. A scary `<<<<<<<` conflict marker crawls across the ground like a bug. ME's head shrinks a little under the pile of words.
- **ON-SCREEN TEXT:** "Git words. So many git words."
- **VOICE-OVER:** "Commits, branches, pull requests, conflicts. Most teams just want one shared folder of notes that stays up to date."
- **SFX / TRANSITION:** Each word lands with a small paper *tick*. The words get swept off-screen by one horizontal ink stroke, which becomes the ground for Scene 3.

### Scene 3: Enter the helper
**Duration:** 8 s (0:14-0:22)

- **VISUAL:** The Claude helper bubble pops up beside ME with a soft spark. ME drops the stick, and it clatters. A chat window draws itself (a rounded hand-drawn rectangle). ME types a single word, and the GIT ball gets two dot eyes and perks up.
- **ON-SCREEN TEXT:** Chat: `You: push`. Title card under the chat: "brainsync".
- **VOICE-OVER:** "brainsync is a Claude skill that turns a GitHub repository into your team's shared second brain. You just say 'push' or 'pull'. Claude does the rest."
- **SFX / TRANSITION:** Stick clatter, then a gentle *pop* for the helper. A keyboard click for each letter of "push". Quick zoom into the chat window to cut to Scene 4.

### Scene 4: What you see
**Duration:** 7 s (0:22-0:29)

- **VISUAL:** Full-frame chat, very calm and spacious. Claude's reply draws on with a green tick. Next to the chat, a note card labelled "call notes" slides into the TEAM BRAIN notebook. ME does a tiny satisfied nod.
- **ON-SCREEN TEXT:** Chat: `You: push. I added notes from today's customer call` then `Claude: ✔ Shared! Your call notes are now in the team brain.`
- **VOICE-OVER:** "Say 'push', and your notes are shared. That's the whole experience."
- **SFX / TRANSITION:** Soft chime on the tick. A vertical ink line draws down the center of the frame, splitting it for Scene 5.

### Scene 5: Behind the curtain (split screen)
**Duration:** 11 s (0:29-0:40)

- **VISUAL:** The screen splits down the middle. A theatre curtain hangs over the right half and is drawn back just for the viewer, with a little "only you, the viewer, can see this" eye icon.
  - **LEFT (what the user sees):** The same calm chat. `You: push`, a small "…" typing indicator, then `✔ Shared!` Nothing else moves. ME is sipping a coffee.
  - **RIGHT (under the hood, git orange):** The GIT ball, now with eyes and a hard hat, runs a conveyor belt of hand-drawn steps. Each lights up orange as the ball bounces onto it:
    1. **Save** local edits (a note card gets a stamp)
    2. **Get teammates' updates** (cards fly in from above)
    3. **Personal branch** `brain/<login>` (a twig sprouts off the main trunk)
    4. **Open a share request**, or reuse the one that's already open (an envelope, labelled "PR" in small type)
    5. **Auto-merge** (the twig folds back into the trunk; a small dial shows *merge → squash → rebase*, whichever the repo allows)
    6. **Delete the branch** (the twig is snipped and drifts away)
    7. **Done** (the ball flashes a green tick that goes across to the left side as the user's "Shared!")
  - The curtain swings back across the right side. Only the calm left side remains.
- **ON-SCREEN TEXT:** Left header: "WHAT YOU SEE". Right header: "WHAT CLAUDE DOES". Step labels as listed (short). Final caption: "You never see this side."
- **VOICE-OVER:** "Behind the curtain, one script saves your edits, picks up your teammates' changes, opens a pull request on your own branch, merges it, and tidies up. Git words are allowed here, because you'll never see them."
- **SFX / TRANSITION:** Left side: quiet room tone. Right side: busy factory clanks and boings, in time with the steps. The curtain *whoosh* cuts the busy sound off at once. Silence, then a page turn.

### Scene 6: Alice and Bob edit the same note
**Duration:** 10 s (0:40-0:50)

- **VISUAL:** ALICE and BOB stand on either side of one note card labelled "pricing.md". Both scribble on it at the same time. The card shivers and two versions pull apart like taffy. The GIT ball rolls in and calmly sorts them:
  - Alice's version (she shared first) lands in the brain with the original name, "pricing.md".
  - Bob's lands next to it, labelled **"pricing (your version).md"**.
  - A quick sidebar vignette (three small panels, 1 s each):
    - (a) Two people edit *different lines* of the same note, and the lines zip together silently.
    - (b) Alice deletes a note Bob edited. The note goes, and Bob's copy stays as "(your version)".
    - (c) A picture file (a little photo icon) gets the same safe treatment.
  - A big `<<<<<<<` marker tries to crawl in, and the ball flicks it away.
- **ON-SCREEN TEXT:** "Same note, same moment?" then "Nothing is lost." then "No conflict markers. Ever."
- **VOICE-OVER:** "When two people change the same note at once, nobody loses anything. The teammate's version keeps the name, and yours is saved right next to it. Edits to different parts just merge. Deleted notes, images, PDFs: all handled."
- **SFX / TRANSITION:** Stretchy taffy *twang* as the versions split. A tidy *shuffle-snap* for each sorted card. A flick sound for the conflict marker.

### Scene 7: The new trick, Claude combines them
**Duration:** 8 s (0:50-0:58)

- **VISUAL:** Bob's chat. Claude gives an amber ⚠ heads-up and offers to combine the two versions. Bob nods. The helper lifts both cards, overlays them, and they fuse into one neat card (Alice's lines and Bob's lines interleaved, each with a tiny marker of whose they are). The "(your version)" card puffs away. A small speech bubble from the helper asks one question where the two really disagree.
- **ON-SCREEN TEXT:** Chat: `Claude: ⚠ You and Alice both edited pricing.md. Hers is the main copy, yours is saved as "pricing (your version).md". Want me to combine them?` Caption: "NEW: Claude combines both."
- **VOICE-OVER:** "Then Claude does something the old tool couldn't. It offers to combine both versions sensibly, and only asks you when the two really disagree."
- **SFX / TRANSITION:** Magnetic *thunk* as the cards fuse, then a sparkle. Cut on the puff.

### Scene 8: Life gets messy (edge-case montage)
**Duration:** 9 s (0:58-1:07)

- **VISUAL:** A quick montage of four small panels laid out like a comic page, each drawing on and lighting up in turn (about 2 s each):
  1. **Same moment:** Alice and Bob hit "share" together. The ball juggles both, combines them, and tries again. Tick.
  2. **Needs approval:** A small gate with a padlock (review required). The share request waits at the gate, and the user gets an "approval link" ticket to hand to a teammate.
  3. **Two computers:** ME with a laptop and a desktop. The ball checks both before sharing, so neither overwrites the other.
  4. **Interrupted:** A laptop lid slams shut mid-task. When it opens again, the ball finishes the half-done job. Also: a plain-English sign in place of an error code ("You don't have permission yet").
- **ON-SCREEN TEXT:** Panel captions: "Same moment" / "Needs approval" / "Two computers" / "Laptop closed mid-way". Final: "Errors in plain English."
- **VOICE-OVER:** "Teammates sharing at the same moment, repos that require a review, the same person on two computers, a laptop closed halfway through. It's handled, and anything that goes wrong is explained in plain words."
- **SFX / TRANSITION:** A comic-panel *slap* as each panel lands. A page turn into Scene 9.

### Scene 9: Tested with two pretend teammates
**Duration:** 6 s (1:07-1:13)

- **VISUAL:** A doodled lab bench. ALICE and BOB are wind-up toy versions (with keys in their backs) next to a cardboard cutout of the GitHub mark labelled "fake GitHub". A tally board fills up with 31 ticks in quick bursts, ending in "31 / 31".
- **ON-SCREEN TEXT:** "31 / 31 end-to-end checks passed." Small: "two simulated users, a fake GitHub CLI."
- **VOICE-OVER:** "First, we tested it locally: two simulated teammates, Alice and Bob, sharing through a stand-in for GitHub. Thirty-one out of thirty-one checks passed."
- **SFX / TRANSITION:** Wind-up clicks and a rapid tally *tick-tick-tick*. Thunder rumbles faintly at the end and cuts into Scene 10.

### Scene 10: Tested in a real storm
**Duration:** 10 s (1:13-1:23)

- **VISUAL:** The sky over the scene goes grey-scribbled. A storm cloud labelled "GitHub incident: pull requests partial outage" rains on a real GitHub repository (a little house labelled "private repo"). The GIT ball wears a raincoat and bounces through three lightning strikes, each one a real bug that the fake never showed:
  1. ⚡ "502 Bad Gateway". The ball looks behind it and finds the share request *was* created anyway. It carries on and doesn't make a duplicate.
  2. ⚡ "Merge already in progress". The ball checks the real state and sees it merged. Carries on.
  3. ⚡ "remote rejected (failure)". The ball waits a beat, retries, and gets through.
  The ball comes out with a repair kit labelled "retries + check the real state". Then a calm card for the user, in case GitHub stays down: the chat message below. A scoreboard draws on: **17 / 21 passed**. The 4 misses are drawn as one grouped bracket labelled "1 race scenario, blocked by GitHub's stuck merge check during the outage. Failed safely, nothing lost."
- **ON-SCREEN TEXT:** "Live test, during a real GitHub outage." Chat: `Claude: ✖ GitHub is having trouble right now (not your fault). Your notes are saved on this computer.` Scoreboard: "17 / 21 live checks. 4 misses = 1 race test, failed safely."
- **VOICE-OVER:** "Then we tested it live on a real GitHub repository, and it happened to be during an actual GitHub outage. That storm turned up real bugs no simulation could: false errors, stuck merges, rejected uploads. We fixed them all. Seventeen of twenty-one live checks passed. The four misses were one race test that GitHub's outage blocked, and even then nothing was lost."
- **SFX / TRANSITION:** Rain bed, thunder on each lightning strike, a rubbery bounce for the ball's recovery. The rain stops, birds chirp once, and the clouds roll off to the right, revealing a clear white page.

### Scene 11: The payoff and end card
**Duration:** 7 s (1:23-1:30)

- **VISUAL:** A mirror of Scene 1. ME stands in the same spot and the same pose, but empty-handed: the stick lies on the ground. The GIT ball rolls *on its own*, happily pushing a stack of note cards into the TEAM BRAIN notebook, and does a little hop. ALICE and BOB wave from the far side. ME's speech bubble now just says thanks. The scene ink-wipes into the end card: white page, the GIT ball sitting quietly in the corner.
- **ON-SCREEN TEXT:** Speech bubble: "…OH. THANKS." End card, large hand-lettered: **"Just say push. Just say pull."** Below: **brainsync**. Small: "A Claude Code skill. The chat-native successor to AcceleraTTy."
- **VOICE-OVER:** "Now git does the work. Just say push. Just say pull."
- **SFX / TRANSITION:** A happy *boing* from the ball (the same sound as the pokes in Scene 1, pitched up). A single soft chime on the end card. Hold for 1.5 s, then fade to white.

---

## Runtime check

| Scene | Seconds | Running total |
| --- | --- | --- |
| 1 The Poke | 7 | 0:07 |
| 2 Why it's hard | 7 | 0:14 |
| 3 Enter the helper | 8 | 0:22 |
| 4 What you see | 7 | 0:29 |
| 5 Behind the curtain | 11 | 0:40 |
| 6 Same note | 10 | 0:50 |
| 7 Claude combines | 8 | 0:58 |
| 8 Messy life montage | 9 | 1:07 |
| 9 31/31 | 6 | 1:13 |
| 10 Real storm | 10 | 1:23 |
| 11 Payoff + end card | 7 | 1:30 |

Total is 90 s. If the VO runs long, Scene 10 is the first place to tighten (keep the honest 17/21 line).

---

## Production notes

### Asset list
**Characters (rigged, with line-boil)**
- ME: idle, poke (holding stick), slumped, typing, coffee-sip, nod, empty-handed relieved pose
- GIT ball: no-face version (Scenes 1-2), eyes version, hard hat, raincoat; squash/stretch rig; hop and roll cycles
- ALICE and BOB: idle, scribbling, waving; wind-up toy variant (Scene 9)
- Claude helper bubble: pop-in, idle bob, "lift" arms, question bubble

**Props and set pieces**
- Scribbled ground strip (looping boil)
- Long knobbly stick
- Chat window frame and message bubble component (user / Claude), with ✔ ⚠ ✖ badges
- TEAM BRAIN notebook and note card component (with a text label slot)
- Branch twig (sprout, fold-back, snip), envelope "PR", merge-mode dial
- Conveyor belt with 7 step tiles
- Theatre curtain (open / close)
- Conflict-marker "bug" (`<<<<<<<`)
- Comic 4-panel layout frame
- Padlock gate, approval ticket, laptop + desktop, slamming laptop lid
- Lab bench, wind-up keys, cardboard "fake GitHub" cutout, tally board
- Storm cloud, rain, lightning bolts, "private repo" house, repair kit, scoreboard with bracket
- End-card lettering

**Audio**
- VO (one warm, unhurried narrator)
- SFX: boink (normal and pitched up), paper ticks, pop, keyboard clicks, chime, factory clanks, curtain whoosh, taffy twang, card snap, flick, panel slap, wind-up clicks, rain/thunder, birdsong
- Optional music bed: light pizzicato or ukulele, ducked under VO, silent in Scene 5's curtain-close beat and in the storm

### Asset reuse
- **Scene 1 ↔ Scene 11:** Same framing, ground and ME rig. Scene 11 is Scene 1 with the stick dropped and the ball's roll cycle. Build both from one composition.
- **Chat window component:** Scenes 3, 4, 5 (left), 7 and 10. One component with swappable message text.
- **Note card + TEAM BRAIN notebook:** Scenes 4, 5, 6, 7 and 11.
- **GIT ball rig:** Every scene. Costume layers (hard hat, raincoat) toggle on top of the same rig.
- **ALICE / BOB rigs:** Scenes 6, 8, 9 (toy variant = the same rig plus a key layer) and 11.
- **Branch twig animation:** Built for Scene 5, reused as the background flourish in Scene 8 panel 3.
- **Scoreboard / tally board:** One component for Scene 9 (31/31) and Scene 10 (17/21).
- **Conflict-marker bug:** Scenes 2 and 6.

### Optional 30-second cut-down
For social media and quick intros, aimed at non-technical viewers:

| Order | Source | Length | Notes |
| --- | --- | --- | --- |
| 1 | Scene 1 The Poke | 4 s | Two pokes only |
| 2 | Scene 3 Enter the helper | 4 s | VO: "Meet brainsync. Just say push." |
| 3 | Scene 5 Behind the curtain | 8 s | Play the conveyor at 1.5x; keep the curtain close |
| 4 | Scene 6 + 7 merged | 6 s | Taffy split, then Claude combines; skip the sidebar vignettes |
| 5 | Scene 10 Storm | 4 s | One lightning strike, then the "not your fault" card |
| 6 | Scene 11 End card | 4 s | Payoff pose, then "Just say push. Just say pull." |

For an engineering-audience cut, swap step 4 for Scene 9 + 10 at full length and drop Scene 3.
