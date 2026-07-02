# Hushfall — Production Plan & Build Roadmap

> **Companion to:** `Hushfall_Design_Document.md`
> The design doc is the **what** (the game). This is the **how** (building it).
> Hand both to Claude Code. Keep this updated as phases get done.

---

## How to read this

- **Part A** — one-time setup you do by hand, before any code.
- **Part B** — how to load the project into Claude Code so it stays oriented.
- **Part C** — who does what (you vs. Claude Code). Read this; it's the part people get wrong.
- **Part D** — the actual build roadmap, phase by phase, with prompts you can paste.
- **Part E** — how to test multiplayer as a solo dev.
- **Part F** — the very first prompt to give Claude Code.

---

## PART A — Phase 0: One-time setup (YOU, by hand)

Do these before Claude Code writes a single line of game code. These are mostly GUI/account tasks an AI can't click through for you.

1. **Install Godot 4.7 — the standard (GDScript) version, NOT the .NET/C# version.**
   GDScript is simpler, better documented, and what nearly all GodotSteam tutorials use. C# buys you nothing here and adds setup friction. Download from godotengine.org.

2. **Install the Steam client and log in.** Steam must be **running and logged in** whenever you test, or the Steam features won't initialize.

3. **Create your Godot project, then add the GodotSteam plugin.**
   Use the **GodotSteam GDExtension (4.4+)** from the Godot Asset Library — it's precompiled, so you do NOT have to compile anything from source. Install it into the project, then restart the editor. Once added, a `Steam` class is available in your scripts.
   - ⚠️ Don't mix the GDExtension version with the "module" version of GodotSteam — pick GDExtension and stick with it. When you eventually export, use the **normal** Godot export templates, not custom GodotSteam ones.

4. **Use Steam's free test App ID (480) for all development.**
   You do **not** need to pay the $100 Steam Direct fee or set up a Steamworks partner account to build and test. Use **App ID 480** ("Spacewar," Valve's public test app). Set it in **Project Settings → Steam → Initialization** (GodotSteam 4.14+), or via a `steam_appid.txt` file in your project root containing just `480`. You only register a real App ID and pay the fee when you're ready to publish.

5. **Install Claude Code.**
   The **native installer** is the current recommended path (no Node.js required). It needs a **paid Claude plan** (Pro, Max, or API/Console — the free plan doesn't include Claude Code). If you'd rather not use a terminal, the **Claude Desktop app** can run Claude Code with a graphical interface. Official setup guide: https://docs.claude.com (search "Claude Code setup").

6. **Set up version control (Git + a private GitHub repo).**
   This is your undo button across the whole project — non-negotiable for something this long. Claude Code can do almost all of this for you (init the repo, write a `.gitignore`, make commits); you just create the empty private repo on GitHub first.

7. **Put the design doc in the project folder** (e.g. `/docs/Hushfall_Design_Document.md`) and this plan next to it. Then create a `CLAUDE.md` (see Part B).

---

## PART B — Loading the project into Claude Code

Claude Code automatically reads a file called **`CLAUDE.md`** in your project root at the start of every session. That's how you keep it oriented across a long project instead of re-explaining the game each time.

**Create it** by running `/init` inside Claude Code (it scaffolds one), or just ask Claude Code to write it. Keep it **short** — it loads into every session, so don't dump the whole design into it. Point to the design doc for detail.

A good starter `CLAUDE.md`:

```markdown
# Hushfall

A first-person online co-op social-horror game. 8–12 players. Godot 4.7
(GDScript) + GodotSteam (GDExtension), shipping on Steam.

## Source of truth
The full game design is in `docs/Hushfall_Design_Document.md`. Read it before
working on gameplay. The build roadmap is in `docs/Hushfall_Production_Plan.md`.

## Golden rules
- Build the multiplayer + proximity-voice skeleton FIRST, before any gameplay.
- Keep balance values (lantern density, hush rules, ghost flicker, win
  thresholds) in easily-editable config, never hardcoded — they're playtest dials.
- Use Steam App ID 480 for all dev/testing.
- Always make a git commit before a big change.

## Stack notes
- GodotSteam GDExtension version (not module). Normal export templates.
- Proximity voice = Steam voice capture + custom distance-based volume.
```

**Session habit:** start each session by telling Claude Code which phase you're on and pointing it at the doc, e.g. *"We're on Phase 2 (proximity voice). Read the design doc and the production plan first."* Use Claude Code's **Plan Mode** for big features (it proposes a plan before editing), and `/clear` to reset context between unrelated tasks.

---

## PART C — Division of labor (important)

Godot is a visual engine, so this is a **partnership**, not "Claude Code builds the game while you watch." Roughly:

**YOU do (in the Godot editor + accounts):**
- Create and arrange scenes and nodes (the visual scene tree), since that's GUI work.
- Import art/audio, place lanterns and buildings, tune values by feel.
- Press Play to test; run multiple instances for multiplayer testing.
- Everything in the Steam dashboard later (store page, App ID, uploads).
- Trigger exports/builds.

**CLAUDE CODE does (the text files):**
- Write and edit all `.gd` scripts (game logic, networking, voice, roles).
- Edit `.tscn` scene files where it's faster in text than by hand.
- Scaffold systems, refactor, and **debug from errors you paste back to it**.
- Write your `.gitignore`, commits, and helper scripts.

**The loop you'll fall into:** ask Claude Code to build a system → it writes the scripts → you wire up/test in the Godot editor → you paste any errors or describe what went wrong → it fixes → repeat. Pasting exact error messages back is the single highest-value habit.

---

## PART D — The build roadmap

Build in this order. Each phase lists its goal, a sample ask for Claude Code, what you do by hand, and how you know it's done. **Do not skip ahead** — each phase rests on the last.

### Phase 1 — Networking skeleton ⭐ (THE FIRST THING) — ✅ DONE 2026-07-02
> **Completed.** Steam lobby (host/find/join over relay) via SteamMultiplayerPeer,
> per-player capsule avatars with WASD + mouselook, position/rotation sync via
> MultiplayerSynchronizer. Verified with two clients (Windows PC + Mac) seeing
> each other move in real time. Playtest dials live in `config/gameplay.cfg`.

**Goal:** A few cube-avatars in a shared space, joined over Steam, moving in sync.
**Ask Claude Code:** *"Set up a Steam lobby with GodotSteam: one player hosts, others join via Steam, using Steam's networking (relay) so there's no port-forwarding. Spawn a simple capsule avatar per player with WASD + mouselook first-person movement, and sync everyone's position. Keep it minimal."*
**You do:** create the test scene/nodes it specifies, run it, invite a second instance/account in.
**Done when:** two clients see each other move in real time.

### Phase 2 — Proximity voice ⭐ (the hard, core feature) — ✅ DONE 2026-07-02
> **Completed.** Steam voice capture -> unreliable RPC broadcast -> positional
> playback from the speaker's avatar (AudioStreamPlayer3D): distance falloff +
> stereo panning verified on PC + Mac ("walking away fades their voice out").
> Voice dials (`voice_max_distance`, `voice_unit_size`, `voice_mode` =
> push_to_talk/toggle/open) in `config/gameplay.cfg`. Speaking indicator,
> mic HUD, and M-key mute included. Solo echo test works outside lobbies.
**Goal:** You hear other players, and their volume falls off with in-game distance.
**Ask Claude Code:** *"Using GodotSteam's voice capture/playback, transmit each player's mic to others, and attenuate each incoming voice stream's volume based on the 3D distance between the two players, so far-away players are quiet/inaudible."*
**You do:** test with a second real Steam account or a friend (see Part E — voice needs real clients).
**Done when:** walking away from someone makes their voice fade out.

> Phases 1–2 are the scary 80%. Once they work, everything below is content on top.

### Phase 3 — The map + one solo task
**Goal:** The plaza-and-spokes village (greybox), lanterns as lit/unlit, and ONE simple solo task.
**Ask Claude Code:** *"Add a lantern object with a lit/unlit state and light. Add a simple 'relight the lantern' task: walk up, hold E, it lights. Track task completion across the network."*
**You do:** greybox the plaza + a couple of spoke buildings; place lanterns; make sure buildings sit out of voice range of each other.
**Done when:** any player can relight a lantern and everyone sees it.

### Phase 4 — The Mimic (disguise + hush)
**Goal:** One player is secretly the Mimic and can hush an isolated villager.
**Ask Claude Code:** *"At match start, secretly assign one player the Mimic role (only they know). Give the Mimic a 'hush' action usable on a villager when no other villager is nearby, which removes that villager from the living game."*
**You do:** test the role assignment and the "must be alone" condition.
**Done when:** the Mimic can hush a lone villager; can't when others are watching.

### Phase 5 — Voice capture & replay (the signature trick)
**Goal:** The Mimic can capture a short snippet of a nearby player's voice and replay it.
**Ask Claude Code:** *"Let the Mimic record a few seconds of a nearby player's transmitted voice and replay that clip on demand, played positionally from the Mimic's location."*
**You do:** playtest how creepy/abusable it is; note balance feelings.
**Done when:** the Mimic can make a friend's voice come from around a corner.

### Phase 6 — A two-person split task
**Goal:** One networked task that needs two players in different rooms at once.
**Ask Claude Code:** *"Build the windmill task: one player cranks a gear inside while another outside confirms alignment; it only completes when both do their part in sync. Sync this state reliably over the network."*
**You do:** build the windmill spaces far enough apart to be out of voice range.
**Done when:** two players can complete it from separate rooms; one player alone cannot.

### Phase 7 — Three-act game flow
**Goal:** Task phase → reveal → hunt, with win/lose.
**Ask Claude Code:** *"Implement match flow: Act 1 villagers can't kill; completing all tasks OR a villager witnessing a hush triggers the reveal; Act 3 villagers can kill the now-revealed Mimic. Villagers win by killing it; Mimic wins by hushing the village below a configurable threshold. Make all thresholds config values."*
**You do:** playtest full rounds; start tuning the dials.
**Done when:** a full match can be won by either side.

### Phase 8 — Ghosts
**Goal:** Hushed players become spirits that flicker lights and slowly aid tasks, but can't speak.
**Ask Claude Code:** *"Hushed players become ghosts: no voice/text, but near a lantern they can make it flicker/dim/flare on a cooldown, and near a living player cause a subtle chill effect. Let ghosts slowly partially-recharge dead lanterns. Keep flicker strength/cooldown/radius as config values."*
**You do:** tune ambiguity so ghosts *suggest* the Mimic but never *prove* it.
**Done when:** ghosts are engaged and atmospheric without trivializing deduction.

### Phase 9 — Polish, art, balance, ship
Art pass (low-poly critters, night lighting, the "cute but wrong" look), audio, menus, settings, lots of playtesting to tune dials. **Then** the Steam side: register the real App ID, pay the $100 Steam Direct fee, build the store page, and export with normal Godot templates. Confirm the name **Hushfall** is free on Steam search and that social handles are available before you announce.

---

## PART E — Testing multiplayer as a solo dev

- **Movement/networking** (Phases 1, 3–7): Godot can launch several copies of your game at once. In the editor: **Debug → Run Multiple Instances**, set 2–3. Great for testing sync by yourself.
- **Voice** (Phase 2, 5): proximity voice needs **real, separate Steam clients/accounts** to test properly — one machine logged into one Steam account can't fully fake two voices. Use a **second PC + second Steam account**, or grab a **friend**. Plan for this around Phase 2.
- **Recruit 2–3 friends as recurring playtesters early.** This genre lives or dies on *feel* (is the Mimic too strong? are tasks tense?), and you can only learn that from real humans. Their reactions are your most important balance tool.

---

## PART F — The very first prompt to paste into Claude Code

> I'm building a game called Hushfall in Godot 4.7 (GDScript) with the
> GodotSteam GDExtension, shipping to Steam. Full design is in
> `docs/Hushfall_Design_Document.md` and the build roadmap is in
> `docs/Hushfall_Production_Plan.md` — please read both first.
>
> We're starting at **Phase 1: the networking skeleton**. Before writing code,
> give me a short plan for: (a) a Steam lobby using GodotSteam where one player
> hosts and others join over Steam's relay networking (no port-forwarding), and
> (b) spawning a simple first-person capsule avatar per player with synced
> movement. Assume I have Godot, the GodotSteam plugin, and the Steam client
> installed, and that we're using Steam App ID 480 for testing. Keep this first
> build as minimal as possible. Once I approve the plan, implement it, and tell
> me exactly what I need to set up by hand in the Godot editor.

---

*Update this file as you finish phases so Claude Code always knows where you are.*
