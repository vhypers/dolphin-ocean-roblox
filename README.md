# Spring on Roblox

The Roblox version of the dolphin game "Spring". The Godot Mac game in `~/Projects/dolphin-ocean`
is the original and keeps developing on its own; this one is rebuilt step by step to match it.

## Play R1 "First swim"

1. Open `build/Spring.rbxlx` in Roblox Studio (double-click it).
2. Press **Play** (F5). The ocean is already baked into the file, so the title comes up straight
   away (the far sea pops in over the first few seconds). If the file ever has no ocean or an old one,
   the server builds it at start ("Building the ocean...", about 6 seconds).
3. Press **Enter** to swim.

What R1 has: the Red Sea with its ten islands, reefs and beaches; Spring with her hurt tail (slower
at first, healing 8% a day, the scar fading); swimming, Boost, leaps, spins in the air and slow
motion; air and breathing at the surface; food and 16 schools of fish to catch; hearts; day and
night; 30 days of 2 minutes; Gentle (rescuers help) and Hard; English and Russian.

Not yet (later steps): sharks and the pod, Sam and his boat, the opening story, family, tasks,
magic, nets, treasures, rings, other oceans and currents, sonar, diary, sound and music, saving.

| Action | Keys | Mouse |
|---|---|---|
| Swim | W A S D or arrows | Hold left and drag |
| Boost | Space or Shift | Right button, hold |
| Jump | J or Enter | Wheel click |
| Back (look behind) | B | |
| View (through Spring's eyes) | V | |
| Pause | P (the game also pauses when the Roblox menu opens with Esc) | |
| Language, difficulty (title and pause) | L, H | Click the button |

## For the next session

- Rules (no Roblox needed) are in `src/shared` and are ports of the Godot scripts named in each file.
  Game logic works in metres in Godot's coordinates (sea level y = 18); views turn them into studs
  (`Rules.STUDS` = 3, sea level y = 0).
- Tests: `tools/luau tests/run.luau` (123 checks).
- Build the place: `tools/rojo build -o build/Spring.rbxlx`. Once Studio has a saved ocean in that
  file, don't rebuild over it; use `tools/rojo serve` with the Rojo plugin instead.
- `tools/` (Rojo 7.7.1, Luau 0.748) is not in git; both come from their GitHub releases.

### R1 tested in Studio (2026-11-23)

Played through the Studio MCP tools: title, swimming, steering, Boost, leaps with slow motion and
spins, breathing, losing a heart to no air, a fish caught, day 1 to day 3 with night, the world edge
message, pause, English and Russian, Back and Spring's eyes. No script errors. Spring's nose leads,
the dorsal fin's slope leads and she banks right side down on D (checked in numbers and pictures).

Fixed on the way:
- The server script died on `Terrain.Decoration` (only Studio may set it), so the game hung on
  "Building the ocean... 0%". It is now set in a `pcall` and saved with the baked ocean.
- Roblox has almost no fog under water, so the end of the terrain showed as huge blue walls. The
  shaped floor now reaches 480 m, its rim blends into a flat floor at -204 studs, and plain open sea
  runs out to 4096 studs (`TerrainBuilder.openSea`, terrain version 2). The place file is now 17 MB.
- A banner's dark outline stayed on screen after its text faded (a UIStroke does not fade with its
  text). The key hints were hard to read on white sand; they now sit on a dark strip. The loading
  screen now also covers Roblox's top bar.

Small things seen but left: the title's Gentle note still mentions sharks and Sam (R1 has neither);
the sky near the horizon stays light at dusk.

### Working with the open place

Use the Roblox Studio MCP tools (server `Roblox_Studio`). Studio must be open on
`build/Spring.rbxlx` with "Enable Studio as MCP server" on.

- Fix bugs in `src/` (the source of truth) and push the same edits into the open place with
  `multi_edit`. Check that Studio matches `src/` by comparing a checksum of each script's source
  (`ScriptEditorService:GetEditorSource`) with the files. Don't `rojo build` over the place: it would
  drop the baked ocean.
- To rebake the ocean after changing `TerrainBuilder`, `require` a fresh `Clone()` of the module (the
  Edit context keeps the old one cached) and run `.build(0)` in a `task.spawn`, then `save_place`.
- Tell the user before a playtest (it uses their Studio window). Keys go in with
  `user_keyboard_input`; the client's camera overrides `screen_capture`'s camera during play, so look
  at models from set angles in Edit mode instead.

### Next: R2 (sharks and the pod)

Not started. After it: the story and Sam, magic, nets, treasures and rings, other oceans and
currents, looks, saves (DataStore needs publishing), sound, publishing.
