# Spring on Roblox

The Roblox version of the dolphin game "Spring". The Godot Mac game in `~/Projects/dolphin-ocean`
is the original and keeps developing on its own; this one is rebuilt step by step to match it.

## Play R3 "The story and Sam"

1. Open `build/Spring.rbxlx` in Roblox Studio (double-click it).
2. Press **Play** (F5). The ocean is already baked into the file, so the title comes up straight
   away (the far sea pops in over the first few seconds). If the file ever has no ocean or an old one,
   the server builds it at start ("Building the ocean...", about 6 seconds).
3. Press **Enter** to swim. The first time in each visit the story plays first (about 53 seconds;
   Space, Enter or a click skips it). **T** on the title plays it again.

R1 "First swim" gave: the Red Sea with its ten islands, reefs and beaches; Spring with her hurt tail
(slower at first, healing 8% a day, the scar fading); swimming, Boost, leaps, spins in the air and
slow motion; air and breathing at the surface; food and 16 schools of fish to catch; hearts; day and
night; 30 days of 2 minutes; Gentle (rescuers help) and Hard; English and Russian.

R2 adds, ported from the Godot game:
- Sharks: 4 in Gentle (none chase in the first 20 seconds, and they stay slower than her), 8 in Hard
  (faster every 25 fish). A shark within 30 m circles her before it comes in; a bite costs a heart.
- Hit: Spring charges the nearest shark within 42 m and rams it away (then rests 5 seconds). A red
  sight marks the shark Hit would charge.
- Her family finds her one by one: someone waits 60 to 140 m away on days 2, 5, 8, 11, 14, 17 and 21
  (a pink heart on the sonar) and joins her pod when she reaches them. Her mother waits on day 30, and
  finding her wins. The pod swims with her and catches fish for her too.
- Pod: her family dives under the nearest sharks and rams them from below; the camera rises above
  the fight, with a moment of slow motion at the first hit (then the pod rests 15 seconds). A bigger
  pod chases more sharks at once.
- A calf is born the morning after the third family member arrives. Feed it by catching fish near
  it; it grows up and joins the pod. Keep sharks away from it.
- The sonar (top right): islands, the edge of the world, fish, sharks (ringed while chasing),
  family waiting, and an arrow to the nearest fish.

R3 adds, ported from the Godot game:
- The story, shot for shot as in the Godot game's opening: Spring and her pod in a quiet bay, the
  hunt, her curiosity, the fishing net, the fishermen setting her free with a hurt tail, the storm,
  the beach where Sam and the rescuers find her, and her release from Sam's boat. Captions in English
  and Russian between black bars; clouds and a storm for the sad part.
- Sam's white-and-orange rescue boat, with Sam, a rescuer and a flag, 35 to 70 m from where she
  starts (a little boat on the sonar). She can't swim through it; they wave while she is near and
  Sam cheers when she leaps there. After a rescue she is brought back beside it.
- Sam's task each day (the panel under her hearts): catch 12 fish, three kinds of fish, five of one
  kind, find the lighthouse, three leaps, chase off a shark, feed the calf, leap by Sam's boat, or
  three spins. Each done task is a star, a heart back if she lost one, and full food. Tasks that need
  animals, healing corals, currents, nets, treasures or rings come with those steps.
- The red-and-white lighthouse on the first island, lit at night.

Not yet (later steps): magic, nets, treasures, rings, other animals, healing corals, other oceans
and currents, weather, diary, sound and music, saving.

| Action | Keys | Mouse |
|---|---|---|
| Swim | W A S D or arrows | Hold left and drag |
| Boost | Space or Shift | Right button, hold |
| Hit (ram a shark) | X or Q | Left click (without dragging) |
| Pod (call your family) | F or E | |
| Jump | J or Enter | Wheel click |
| Back (look behind) | B | |
| View (through Spring's eyes) | V | |
| Pause | P (the game also pauses when the Roblox menu opens with Esc) | |
| Language, difficulty (title and pause) | L, H | Click the button |
| Watch the story (title) / skip it | T / Space, Enter | Click |

## For the next session

- Rules (no Roblox needed) are in `src/shared` and are ports of the Godot scripts named in each file.
  Game logic works in metres in Godot's coordinates (sea level y = 18); views turn them into studs
  (`Rules.STUDS` = 3, sea level y = 0).
- Tests: `tools/luau tests/run.luau` (211 checks).
- Build the place while Studio is closed: `python3 build_place.py`. It builds the scripts with Rojo
  and carries the baked ocean (the Terrain item and the shared strings it refers to) over from the
  old file, which it keeps as `build/Spring-before.rbxlx`. Never `tools/rojo build` straight over
  `build/Spring.rbxlx`: that drops the ocean. `build/Spring-R1.rbxlx` is the R1 place.
- `tools/` (Rojo 7.7.1, Luau 0.748) is not in git; both come from their GitHub releases.

### R2 tested in Studio (2026-11-23)

Played through the Studio MCP tools, with Studio-only test commands (below): the title, sharks
circling and coming in, the tip about Hit and Pod, the red sight, Hit charging and driving a shark
off, a shark bite, the shallows tip, day 2 with the pink heart on the sonar, her cousin joining and
following, the pod's charge from above with bubbles, two sharks chased by a pod of four, the calf and
its meter, the rescue, day 30 and finding her mother (the end screen with family found and sharks
driven off), and Russian throughout. No script errors.

Fixed on the way:
- Client modules required their neighbours without waiting, so the game sometimes never started
  ("World is not a valid member of PlayerScripts"). They all use `WaitForChild` now.
- The rescue screen did not cover Roblox's top bar; sharks hung still behind the title.

Known and left for later:
- Distant water sometimes shows dark blue rounded boxes on the horizon under water. They are far
  terrain Roblox has not drawn in detail yet (they thin out after a while and come back elsewhere).
  The open sea out to 4096 studs is 251 million terrain cells; a smaller open sea with a floor that
  rises toward its edge, or checking how a published game (not Studio) draws it, are the next things
  to try.
- R2 has no sound and no round on-screen buttons (the Godot game's touch buttons); Hit and Pod show
  in the key strip and fade while they rest. The pod's fight uses the Godot game's newest camera
  (rising above the fight), not the older split screen.
- The bubbles use Roblox's sparkle picture and look a little like stars.

Studio-only test commands (playtest, Client): set the player's `SpringCheat` attribute to
`day N`, `shark` (one 18 m ahead, calm over), `meet` (the waiting family member comes to her),
`pod N` (N more family members), `calf`, `calm N` (no chases for N seconds) or `air`. The player's
`SpringState` attribute shows a one-line summary four times a second. None of this runs in a
published game (`RunService:IsStudio()`).

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
  (`ScriptEditorService:GetEditorSource`) with the files. For a big change, close Studio, run
  `python3 build_place.py` and open the place again (ask the user first: Studio takes focus).
- To rebake the ocean after changing `TerrainBuilder`, `require` a fresh `Clone()` of the module (the
  Edit context keeps the old one cached) and run `.build(0)` in a `task.spawn`, then `save_place`.
- Tell the user before a playtest (it uses their Studio window). Keys go in with
  `user_keyboard_input`; the client's camera overrides `screen_capture`'s camera during play, so look
  at models from set angles in Edit mode instead.

### R3 tested in Studio (2026-11-23)

Played through the Studio MCP tools, no script errors: the title (Watch the story [T]); the story
before the first swim and from T, every scene (the bay, the hunt, the net, caught, freed, the storm by
the lighthouse, the beach with Sam and the rescuers, the release from Sam's boat with the crew
waving); skipping it; Sam's task panel and "Sam asks"; a leap 15 m from Sam's boat (he cheers, the
task's star); the lighthouse task; Sam's boat on the sonar; Russian for all of it.

Fixed on the way: a key press could start and skip the story at once (skips are ignored in its first
half second); the net's twine is thinner; the storm is darker; Sam's cheer no longer hides the "Task
done!" message.

Left as it is: people are simple block figures (the Godot game has sculpted ones); there is no
weather in the game itself yet, only in the story.

New Studio-only test commands: `task <kind>`, `sam` (his boat 25 m ahead), `light` (the lighthouse
task, 50 m from its island) and `story N` (jump the story to second N).

### Next: R4 (magic)

After it: nets, treasures and rings, other oceans and currents, looks, saves (DataStore needs
publishing), sound, publishing.
