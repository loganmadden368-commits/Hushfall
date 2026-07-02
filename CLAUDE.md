# Hushfall

A first-person online co-op social-horror game. 8–12 players. Godot 4.7
(GDScript) + GodotSteam (GDExtension), shipping on Steam. Solo developer,
learning Godot while building — explain editor steps explicitly, write
beginner-readable, well-commented GDScript.

## Source of truth
- `docs/Hushfall_Design_Document.md` — the full game design (WHAT the game is).
- `docs/Hushfall_Production_Plan.md` — the phased build roadmap (HOW we build it).
Read both before working on gameplay. Update the production plan as phases finish.

## Current status
- Phase 1 (networking skeleton) — ✅ complete, verified 2026-07-02 with
  Windows + Mac clients over Steam relay.
- Phase 2 (proximity voice) — next up.

## Golden rules
- Build the multiplayer + proximity-voice skeleton FIRST, before any gameplay.
- Keep all balance values (lantern density, hush rules, ghost flicker, win
  thresholds, voice ranges) in easily-editable config in `config/`, never
  hardcoded — they're playtest dials.
- Use Steam App ID 480 (Spacewar) for all dev/testing.
- Always make a git commit before a big change, and at the end of each
  working milestone.

## Stack notes
- GodotSteam GDExtension version (NOT the module build). Normal Godot export
  templates when exporting.
- Steam networking (relay/NAT punchthrough) for multiplayer — no self-hosted
  servers, no port forwarding.
- Proximity voice = Steam voice capture + custom distance-based attenuation.

## Project layout
- `scenes/` — .tscn scene files
- `scripts/` — .gd scripts (autoloads and shared logic)
- `assets/` — art/audio (greybox placeholders until Phase 9)
- `config/` — balance/tuning values (playtest dials)
- `addons/` — GodotSteam GDExtension lives here
- `docs/` — design doc + production plan
