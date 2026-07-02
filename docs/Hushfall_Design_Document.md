# Hushfall — Game Design Document

> **Working title:** Hushfall
> **Status:** Pre-production design reference (living document)
> **Purpose:** Single source of truth for development. Hand this to Claude Code at the start of every session so it stays oriented across the whole project.

---

## 1. Elevator pitch

**Hushfall** is a first-person online co-op horror-lite game for 8–12 players. You and your friends are little critters trying to keep a festival-night village lit before its lanterns go dark. One of you is secretly a **Mimic** — a creature that looks like a villager and can capture and replay snippets of real player voices to lure people into the dark and *hush* them. The catch that makes it terrifying: you can only hear players standing near you. The voice calling you around the corner might be your best friend… or the thing wearing his voice.

**The one-line hook:** *Among Us, but you can only hear who's next to you — and the impostor can sound like your friends.*

---

## 2. Pillars (never violate these)

1. **Light is safety, dark is the Mimic's.** Every system points at this single tension.
2. **Proximity voice is the game, not a feature.** You only hear who's near you. The Mimic weaponizes this. Everything is designed around it.
3. **The village forces the split, not a rule.** Players want to huddle for safety; tasks make them spread out. That self-reinforcing pressure is the core loop.
4. **Cute but faintly wrong.** Storybook-cozy on the surface, quietly eerie underneath. Goofy, not gory.

---

## 3. Tech & platform

- **Engine:** Godot 4.7 (native desktop)
- **Multiplayer + Steam:** GodotSteam (Steamworks integration). Use **Steam's networking** for free relay / NAT-punchthrough — **no self-hosted servers.**
- **Voice:** Steam voice API (via GodotSteam) for capture/transmit. Proximity attenuation (volume falls off with in-game distance) is **custom code we write** on top.
- **Platform:** Steam (Windows first; Mac/Linux later if feasible)
- **Price target:** ~$5–10
- **Players:** 8–12 per match

---

## 4. Art direction

- Goofy, simple **low-poly first person**. Round, charming critter avatars.
- **"Storybook-cute but faintly wrong"**: warm lantern glow, fireflies, cozy village — with the wrongness creeping in at the edges of the light.
- First person is **load-bearing**, not a preference: the dread of "is that really my friend around the corner?" only works when you're embodied and physically can't see past walls and into the dark.

---

## 5. The Mimic (the threat)

- **One** Mimic per match (a single player starts as it). It looks identical to a normal villager.
- **Voice mimicry:** it can capture short snippets of nearby player voices and replay them — e.g. luring someone with *"hey, over here, found a task!"* in a friend's real voice.
- **Hush:** when it catches a villager **alone**, it can hush them (removes them from the living game; they become a ghost — see §8).
- **Goal:** hush enough of the village to win before it's revealed and hunted down.
- **Open balance question:** is one Mimic enough tension at 12 players? Design intent is a single Mimic ("one person starts as it, has to hush everyone"). Treat scaling (e.g. a second Mimic at higher counts) as a **playtest dial**, not a launch decision.

---

## 6. Core loop

> **Alone = vulnerable. Grouped = safe. But tasks force the group to split.**

- Players instinctively clump in the light (the plaza).
- Keeping the lights alive requires sending people out to the dark spokes to do tasks.
- The Mimic works the gaps — peeling people off, luring them alone, hushing them unwitnessed.
- The push-pull between "we're safer together" and "we'll lose if we don't spread out" is the **main balancing dial** of the entire game.

---

## 7. Setting & the light system

**It's the night of a village festival, and the lanterns are going out.**

- The village runs on **light**. Lit areas are safe islands; the dark gaps between them belong to the Mimic.
- Over the round, lights slowly **fail or get snuffed**, the safe islands shrink, and the dark grows. This is a built-in **escalation timer** — by the hunt phase, the village is mostly dark.
- **Why night, not fog:** fog flattens dread (everything equally murky everywhere). Night gives **hard contrast** — pooled lantern light vs. black gaps — which turns light into a *resource* and expresses the alone-vs-grouped tension **spatially**, through level design, with no extra rules. Lantern placement is itself a balance lever.

---

## 8. Structure — three acts

### Act 1 — Task phase (paranoid)
Villagers spread out to keep the lights lit and complete chores. The Mimic hunts the gaps. **Villagers cannot kill during this phase** (otherwise paranoid players murder each other on suspicion and the social game collapses — this is why Among Us only lets the impostor kill).

### Act 2 — The reveal
The Mimic gets exposed one of two ways:
- **All tasks completed** → completing the final task **auto-reveals** the Mimic (it glows / glitches / drops the disguise).
- **Witnessed hush** → a living villager who actually sees the Mimic hush someone can expose it early.

> Note: there is **no Among Us-style meeting & vote** — that would break the proximity-voice premise. Identification is earned through play (finishing tasks or witnessing), not a global discussion.

### Act 3 — The hunt
Once revealed, **villagers can finally kill.** The Mimic is now hunted, but is racing to hush enough players first to flip the math. The mostly-dark late-game village makes this phase the scariest.

---

## 9. Win conditions

- **Villagers win** by reaching the reveal and then killing the Mimic during the hunt.
- **Mimic wins** if it hushes the village below a survivable number **before** either reveal trigger fires.
- (Exact survivable threshold = playtest dial.)

---

## 10. Village layout — hub & spokes

- **Central plaza:** the bright, safe heart — bonfire, the big lantern, fireflies. Where the group instinctively clumps.
- **4–6 spoke outbuildings** off the plaza: e.g. the well, greenhouse, bell tower, mushroom cellar, boathouse, windmill.
- **Critical rule:** outbuildings are **out of voice range** of the plaza and of each other. Doing a task means leaving the sound of the group.
- **Keep it tight and dense**, not sprawling. A small, well-lit, readable village beats a big one a solo dev can't fill or light.

---

## 11. Tasks — "keep the light alive"

Chores ladder from safe to scary; that ladder **is** the difficulty curve.

**Solo-but-safe (in / near the plaza):**
- Refill the central lantern with oil
- Wind the music box
- Sweep embers back into the bonfire
- *(Low tension; lets nervous players contribute without leaving the light.)*

**Spoke tasks (force one person out, alone):**
- Relight the lantern at the well
- Ring the bell once at the tower
- Fetch glow-mushrooms from the cellar
- *(Bread-and-butter risk moments: you have to briefly leave the group, in the dark.)*

**Two-person split tasks (the stars — where proximity voice sings):**
- **Windmill:** one person cranks the gear inside while another outside calls out when the sails line up — but they're far enough apart they **can't hear each other normally** and must shout across the gap or pre-agree a plan and trust it.
- **Boathouse bridge:** two levers pulled at once, in different rooms.
- **Bell tower grand relight:** someone at the base feeds rope while someone up top lights the wick.
- *(Coordinating across a distance you can't talk over is the exact feeling no other game gives — and the Mimic feasts here, because "your partner" on the far lever might not be your partner.)*

> **Build note:** split tasks are the highest-value **and** highest-difficulty pieces (reliable networked state between two players in different places). Build a simple **solo** task first to prove the task system, *then* graduate to a split task. Don't start there.

---

## 12. Ghosts (hushed players)

**Core rule: ghosts cannot speak words. They can only make the light flicker.**

When hushed, you become a drifting spirit. Your only way to touch the living world is **proximity-based, non-verbal interference:**
- Drift near a lantern → make it flutter, dim, or briefly flare.
- Drift near a living player → they feel a cold shudder, hear a faint wind, see their lantern gutter.
- **No voice, no text.**

**Why this works:**
- A ghost who saw who hushed them is desperate to scream "IT'S DAVE!" — and literally **can't.** They can only *point with light*: follow the suspect making lanterns flicker, or wave a friend away from a dark corner. The living must **interpret** it ("why does my lantern die whenever I'm near Greg…?"). The info is **real but lossy** — exactly the calibration deduction needs. Ghosts **haunt you toward** the answer; they never hand it over.
- **Atmosphere for free:** as the hushed pile up, the lights misbehave more and more. The map literally gets *more haunted as you lose* — a horror progression bar made of pure side-effect.

**Keeping ghosts engaged — "spirit tasks":**
- A ghost lingering at a dead lantern can slowly, **partially** recharge it (e.g. to half), so a living villager finishes it faster.
- Keeps the hushed contributing and **present in the world** instead of booted to a spectator cam. Creates lovely moments where living and dead work the same lantern from opposite sides of the veil.

**Balance lever to watch:**
- Ghost flicker-power must be **limited and ambiguous** — short cooldown, small radius, effects subtle enough to *suggest* the Mimic but never *prove* it. Too precise/frequent and the living crack it instantly; the Mimic never survives.
- **Start it weak; make it adjustable from day one.** This is a playtest-only calibration.

---

## 13. Build order & scope notes

Solo developer building with **Claude Code**. Long-term project, no deadline.

**Golden rule: build the multiplayer + proximity-voice skeleton FIRST**, before any gameplay. A few blocky avatars in a room who can move and hear each other get louder/quieter by distance. This de-risks the scary 80% up front; once it works, everything else is content layered on top.

Suggested high-level order:
1. **Networking skeleton** — a shared room, a few avatars that move, state synced via Steam networking.
2. **Proximity voice** — Steam voice capture/transmit + custom distance-based volume attenuation.
3. **One solo task** — prove the task system end to end.
4. **The light/dark map** — plaza + a couple of spokes; lanterns as lit/unlit state.
5. **The Mimic role** — disguise, hush, basic voice capture/replay.
6. **A two-person split task** — the hard networked-coordination piece.
7. **Three-act flow** — task phase → reveal triggers → hunt.
8. **Ghosts** — flicker interference + spirit tasks.
9. **Polish, art pass, balance dials, Steam build.**

**Things to keep adjustable from day one (playtest dials):** lantern placement/density, hush conditions, Mimic count, ghost flicker strength/cooldown/radius, the "survivable number" win threshold, round length, light-decay rate.

---

## 14. Open questions (not yet decided)

- Exact mechanics of the hush (instant? requires a few seconds alone? a struggle?).
- Mimic voice-capture specifics (how long a snippet, how often, any tell?).
- Round length / pacing targets.
- Player ratios and whether to scale Mimic count with lobby size.
- Respawn rules — is a hush permanent for the match, or can ghosts ever return?
- Movement feel, sprint/stamina, can the Mimic move differently?
- Cosmetics / progression (likely post-launch).

---

## 15. Business / publishing notes

- **Steam Direct fee:** $100 one-time per title, **recoupable** after $1,000 in revenue.
- Confirm the name **Hushfall** is clear on Steam search and that matching social handles are free before committing publicly.
