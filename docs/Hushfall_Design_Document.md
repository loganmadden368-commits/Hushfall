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

## 10. Village layout — the harbor village (rebuilt 2026-07-02)

> **Compass convention (binding): north = −Z, east = +X.** All walk-test
> directions, coordinates, and audit output use this mapping.

The literal hub-and-spokes wheel was replaced with an organic harbor village
("Hushfall grew uphill from the water"). Functional skeleton preserved;
geometry now governed by Appendix A doctrine and verified by the boot map
audit. Greybox lives in `scenes/world.tscn` + `scripts/terrain.gd`
(height(x,z) IS the terrain spec).

- **Enclosed plaza** (bonfire, spawn) ringed by houses, with four gates:
  E (east lane), N (to the Rise), W (well lane), S (south lane). Three
  trunk lanes; every site hangs off one.
- **Districts:** Market Lanes (NE: bent street, back alley, two breezeway
  tunnels, two pass-through shells, the map's one baited dead-end nook);
  the Rise (N: smooth hill, +4m crown, sheer NE faces — Bell Tower + spire);
  West fields (well yard, post-marked field crossings, windmill lane fork);
  Waterfront (S: shore easing into water, boardwalk, Boathouse, causeway
  spit to the Lighthouse).
- **Seven task sites, tiered by real walk time** (near ≤9s / mid ≤14s /
  far ≤22s / ceiling 25s, config dials): Well & Greenhouse (near),
  Bell Tower & Boathouse (mid), Cellar, Windmill (far), Lighthouse
  (farthest ~21.5s — the sanctioned single-approach causeway, the
  scariest walk in the game).
- **Two routes per site from different gates** (Lighthouse excepted);
  voice rules hold: every site >25m from the plaza, all pairs >28m apart
  (closest 31.3m). Three skyline landmarks: Bell spire (N), Lighthouse
  beacon (SE), Windmill blades (NW).
- **Playtest watch item:** if rounds consistently end with the Lighthouse
  as the last task, the Mimic learns to camp the causeway endgame. Likely
  lever is task-set randomization (game-design fix, not a map fix).

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
- Jumping and crouching (dev note, Phase 1): both deliberately left out of the
  networking skeleton. Crouching should slow the player; could double as a
  "hide in the dark" verb. Add when movement/gameplay phases need them —
  speeds become config dials like move_speed.
- Cosmetics / progression (likely post-launch).

---

## 15. Business / publishing notes

- **Steam Direct fee:** $100 one-time per title, **recoupable** after $1,000 in revenue.
- Confirm the name **Hushfall** is clear on Steam search and that matching social handles are free before committing publicly.

---

## Appendix A — Map design principles (research pass, 2026-07-02)

Extracted from the reference class (Among Us, Counter-Strike/Valve, Lethal
Company/Phasmophobia, RE4's village, Dark Souls, Disney wayfinding). These
govern every future map decision. Principles only — no layout was copied.

1. **Three lanes you can hold in your head** (Skeld). Exactly three trunk
   lanes leave the plaza (East, North-via-Upper, South); every task site
   hangs off a trunk. Never add a fourth trunk.
2. **Isolation lives at the end of chains** (Skeld's Electrical). Far sites
   are deliberately end-of-chain with narrow entries — but every one gets a
   single escape affordance (second exit/gap) so being cornered is tense,
   not automatic death.
3. **Loops and connectors, not corridors** (dust2). Every major journey is a
   loop or has two approaches of different length/danger; connectors give
   pursuit counterplay. No out-and-back corridors to task sites.
4. **Chokepoints are scheduled meetings** (Valve). Exactly three chokes —
   kiosk corner (E), Rise ramp landing (N), boardwalk mouth (S) — kept ~4m
   wide, each with a lantern. Act 3's fair-fight rooms.
5. **Light is the real level geometry** (Lethal Company/Phasmophobia).
   Lantern pools only at decision points (plaza, sites, chokes, 1–2 forks);
   mid-segment darkness stays true dark. Dying lanterns rewire the map —
   escalation expressed spatially. Lantern-death ORDER is a balance dial,
   not pure random.
6. **A town fights back when you can cut through it** (RE4 village). Some
   market fillers are pass-through breezeways; task buildings get two exits
   where fiction allows. This is what makes Act 3 hunts playable in town.
7. **Shortcuts are the map-knowledge reward** (Dark Souls). Every alley must
   be faster AND darker or it gets cut. Exactly ONE dead end on the whole
   map, and it is baited (lantern/pickup) so entering is a choice.
8. **Navigate by silhouette** (Disney's "weenie"). Three distinct skyline
   landmarks: Bell Tower (square, N), Lighthouse (round + glow, SE),
   Windmill (bladed, NW). Rule: from every lane intersection at least one
   weenie is visible; market roofs capped at 5m to guarantee it.

*Applied 2026-07-02: south boardwalk loop added (P3), market back alley
added (P3/P7), two breezeway houses (P6), dead ends cut from two to one
baited nook (P7).*

### A2 — Flow doctrine (binding acceptance criteria, adopted 2026-07-02)

The principles above became measurable rules, checked by the boot-time map
audit (`scripts/map_audit.gd`, gated by `[debug] map_audit`):

- **F1 two-route rule:** every site reachable by two distinct routes
  (different danger profiles). *Amendment 1:* shared-path measured from the
  plaza gates, not the bonfire. *Rider R1:* the two routes depart from
  DIFFERENT gates; audit prints departure gates and flags shared ones.
  *Sanctioned exception:* the Lighthouse causeway is the map's one
  single-approach site.
- **F2 dead ends:** 3–5 total, alley/pocket only, shallow or deliberate.
  Current: 3 (market nook = deep + baited, plaza SW pocket, windmill
  tower corner).
- **F3 chokepoints:** 3–6, reading as decisions. Current: 6; the three on
  primary routes (kiosk corner, market north gate, causeway mouth) carry
  lantern dials in `[lanterns] choke_positions`.
- **F4 walk-time tiers** (config dials): near ≤9s, mid ≤14s, far ≤22s,
  one-way ceiling 25s. *Amendment 3:* Lighthouse exempt from the far/near
  ratio, governed by the ceiling only (currently 21.5s).
- **F5 perception bands:** engineered see-but-can't-hear straightaways
  (plaza, boardwalk 38m, market street 31m — the sanctioned F5a list per
  *Amendment 2*) and hear-before-you-see corners in every district.
- **F6 sightline rhythm:** no unsanctioned lane straight >25m. Flagged
  deviations: back path (28m) and shore path (35m) — re-check at the night
  milestone, where darkness may be the intended break.
- **F7 landmark visibility:** raycast grid; current: Bell spire 59%,
  Lighthouse beacon 76%, plaza glow proxy 23%, at-least-one 89%. Blind
  pockets cluster in the NW fields — acceptable (deliberate disorientation
  zone) pending the night-milestone re-run with real light sources
  (*Amendment 4*).
- **F8 pass-through shells:** Shell1 (east lane ↔ back path) and Shell5
  (market street ↔ nook approach).
- **F9 street-fronting:** doors face lanes; districts keep distinct
  silhouettes (spire, blades, beacon, low market rows).
- **F10 voice invariants:** every site >25m from plaza (min margin +3.7m,
  the Well), all site pairs >28m (closest 31.3m). Re-verified every boot.
- **R2:** the Well field crossing is post-marked (discoverable in the
  dark), as is the windmill north-field route.
- **R3:** the baited nook's mouth is covered from the market street
  (max 13.4m line of sight); nearest lantern dial 8.9m away — nook danger
  tunes with that lantern, never absolute.
- **F1 note:** Cellar's two routes differ only ~5% in length (<25%
  target) — accepted deviation: equal time, opposite danger profiles makes
  the choice pure risk-preference.
- **Standing flag:** when sprint lands, re-print the walk-time matrix at
  sprint speed and re-check the 25s ceiling.

### A3 — Audit integrity (root-cause postmortem, 2026-07-02)

A walk-test found floating structures, paths through buildings, and a site
with no path — all while audits reported passing. Causes, recorded so the
failure mode stays dead:
1. The flow audit validated AUTHORED ROUTE DATA, not scene geometry — a
   route could pass with zero paving (the Bell Tower did).
2. Path clearance was manual coordinate arithmetic presented as an audit.
3. The foundation audit sampled one point (the node origin); footprints
   straddling slopes floated at their corners while printing 0.00.
Remedy (audit v2): paths are GENERATED from `scripts/path_network.gd` —
the audited data and the walked geometry are the same object. Boot audits:
A path-structure intersection (0.5m samples vs. actual collision shapes),
B terrain conformance + slope standard, C connectivity graph (all gates +
doors, one component), D universal footprint seating with auto-plinths.
Rule of trust: a verification claim counts only if a printed boot-audit
line proves it. **Scope (2026-07-02): project-wide law** — networking,
tasks, roles, and voice included, not just the map.

### A4 — Style rules (binding)

- **The glow rule:** the lantern-glow accent (`FFB55C` and near hues —
  warm saturated oranges/ambers) may appear ONLY on genuine light sources
  (lanterns, bonfire, beacon, lit windows), map-wide, forever. Warm glow
  = light = safety must never lie. A boot-audit line scans materials for
  near-glow hues on bodies without a light and flags violations.
- **Window-glow watch item (night-lighting milestone):** once every house
  window glows village-wide, dozens of windows may dilute "warm = safe."
  Likely lever: dimmer and/or cooler window glow relative to lanterns.
  Decide when real lighting lands.
