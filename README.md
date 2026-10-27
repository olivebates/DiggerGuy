# Digger Guy

A native Godot 4 game about guiding a tiny, automatic miner through a rising underground world. Every terrain tile, character, ore, icon, and effect is generated from vector primitives. Sound effects are synthesized in code; there are no external graphics or audio dependencies.

## Play

On Windows, double-click **Play.bat** to use the Godot executable included in this repository. Alternatively, open **project.godot** in Godot 4.3 or newer and press **F5** to run the project.

The miner walks slowly by himself and reverses when he hits a wall. Gravity pulls him into the paths you dig. Keep him below the rising ceiling and away from the spikes at the bottom.

Walking eases up to speed over about 0.2 seconds. The miner leans back for a 0.1-second wall turn. Each ledge gets one hesitation roll: a 30% chance of a 0.15-second pause at the final foothold before dropping. The orange triangle ears and helmet share a rigid pivot, without independent bobbing or inner ear shapes. The eye remains one native pixel wide even during rotation. The backpack is visible; the body has no arm or belt line. The miner has no lamp dot, light cone, or surrounding light. Landings produce squash, dust, a contact ring, and sound scaled to the fall, while the physical collision box stays steady. Freeze suspends these animations while leaving mouse digging live.

| Control | Action |
| --- | --- |
| Left mouse | Damage every block touched by the 24 px radius brush |
| Right mouse | Place in an empty cell; hold and drag to fill crossed cells once per drag; three placements per run before upgrades |
| Hold and sweep | Hit new blocks; sweep completely away and back to hit the same block again |
| Release and click again | Hit the same blocks again without moving the brush |
| Space, held | Freeze the world while continuing to dig |
| Snowflake button | Toggle freeze; Space also freezes independently |
| W, held / Speedup button | Use the selected purchased speed (2×, 3×, or 4×); the button toggles it |
| E / satchel button | Open inventory and pause the entire game |
| Leave button | Return safely to sell ores and buy upgrades |
| M | Toggle generated sound effects |
| Shop, in depot | Open the separate upgrades screen |
| Enter, in depot | Activate Sell All or Dig Deeper |
| Escape, in shop | Return to the depot |

The top HUD has five evenly spaced indicators: Depth, Value, Ores (carried/capacity), Blocks, and Lives. The four action buttons occupy a separate row. GUI backgrounds are very dark brown, panels are slightly lighter brown, and outlines are bright brown; text and icons retain their pale cream color. The placement budget sits in the top HUD to the right of Ores. At zero it turns red; attempting placement makes it pulse over 0.5 seconds. All five indicator columns use the same spacing. Exhausted right-click attempts display red **No more blocks** text floating up from the cursor. Buttons run left to right: Speedup, Freeze, Inventory, Leave. A full bag displays **Inventory Full** for two real seconds and makes Leave glow until clicked. Each vector object uses a binary-coverage material: pixels are opaque or transparent, MSAA is disabled, and original RGB colors are preserved without posterization. Ordered coverage produces faded effects without partial-alpha pixels. Freeze costs 200 coins; speed tiers must also be purchased. Freeze and inventory pause override speedup; death effects use real time. F and Q have no action.

## The mine

- Vector terrain and characters designed at 16×16 and displayed at 2× zoom: 32 px blocks, 15 columns, and solid indestructible boundaries just outside the screen. The miner has orange skin and ears protruding from his helmet.
- Blocks start at two health: one hit reveals cracks, and the second breaks them. Mining Power upgrades increase damage, allowing one-hit breaks from the first upgrade.
- Every expedition generates new sections of connected rooms and gradually widening curved tunnels. Layouts mix narrow shafts, broad chambers, angular branches, stepped terraces, landing rooms, and enclosed pockets. Each section has a route with supported steps alongside a riskier chamber with a nearby ore vein. Catch shelves limit uninterrupted vertical openings to five blocks, including between sections.
- Five depth regions favor different cave proportions and add slate formations, crystals, or glowing ember seams. There is no starting grass strip; inset randomized clay fragments add dirt texture. Rock colors blend continuously over depth using a separate fixed color seed, including below the last region. The same absolute depth and column have identical colors in every expedition, while cave layouts remain random. Each dirt tile has a one-pixel border with flush highlights and shadows. Lava becomes more frequent in deeper regions.
- Terrain rises 2.5× as fast as its former rate, before any purchased speed multiplier. A remainder accumulator advances it one whole game pixel (two screen pixels) at a time without losing speed. Supported entities receive exactly the same rise step. Ore drops receive randomized full-circle rotations and launch velocities, fall and bounce, and must touch the miner to be collected. Pickups fly toward the Ores counter and briefly pulse that counter when they arrive. A full bag leaves new ore on the ground.
- Fifteen ores: iron, copper, tin, silver, gold, cobalt, nickel, titanium, emerald, ruby, sapphire, diamond, obsidian, mythril, and eternium. Connected veins of two to five blocks replace isolated ore dots, retaining about 6% ore overall (twice the previous frequency). Veins beside the riskier chamber favor more valuable unlocked ores. Only iron and copper appear at the start; further tiers unlock from 60 m through 2,080 m. Inventory and depot show only ore currently carried.
- Ten enemies: pebble slime, cave beetle, dust bat, rock hopper, tunnel spider, ember wisp, crystal crab, deep burrower, void watcher, and eternium sentinel. Each has its own vector silhouette and movement behavior. Walking enemies are placed on usable floors, flying enemies in open chamber space, and both start clear of lava. Enemies in upcoming rooms wait offscreen until their chamber approaches. Only slime and beetle spawn initially.
- Lava starts appearing at 360 m in supported basins on the riskier side of a section, leaving the alternate route dry. Mine a basin wall or floor to release it. A finite-volume grid simulation makes it fall, pool, equalize, and spill; lava can also consume loose ore and most enemies. Freeze gives you time to carve a route around the basin and its ore vein before flow resumes.
- Exposed dirt blocks have a 7% chance to carry spikes. They avoid the starting platform, lava, and enemy spawn points. Destroying their supporting block turns the spikes into debris alongside the dirt. Bottom spikes are anchored at the actual 800 px screen edge and capped at 16 screen pixels (eight game pixels). Placement and mining also extend to that edge.
- Enemy, lava, ceiling, or spike contact triggers a frozen death animation followed by the separate trading-depot scene.

## Depot and progression

Return voluntarily to keep your entire haul. Leaving freezes the mine, lowers a glowing beam over 0.5 seconds, waits 0.7 seconds, floats and gently rotates the miner for two seconds, then starts closing the iris while floating continues and slides the depot in. On death, the three rarest pieces are kept, plus one per Ore Insurance upgrade. The mine freezes and shakes three or four times at 0.2-second intervals; if carrying fewer than three ores, it shakes once per carried piece. Each shake plays a sound and releases a batch of lost ore. After a 0.6-second pause, the iris closes to a player-sized spotlight, holds for 1.5 seconds, then closes fully. The depot slides down from above. Kept pieces stay in the bag. Destruction sounds play at most once every 0.2 seconds, including during freeze.

The haul is a full-width list with one separator between entries and each ore stack's total value aligned right. Rows are compact and top aligned. Labels type one character at a time, with each row starting 0.2 seconds after the previous one. Empty hauls have no placeholder icon. The same three action slots are reserved on both menus: **Sell All**, **Shop/Back**, **Dig Deeper**. Dig Deeper is hidden until selling completes. Sold pieces fly into the coin counter with rising chimes. Sales save immediately; the counter animates as pieces arrive. You can open the shop and buy upgrades during the animation.

The **Shop** button opens an interface with larger icons and arrows, green next values, red unaffordable prices, press animations, and purchase feedback. Content slides fully offscreen as the opposite page enters; the top bar and action buttons stay in place. Both screens retain the same action positions and sliders for purchased depth/speed settings. The depot list, action buttons, and settings use the available height. Credits, carried ore, upgrades, selected settings, and mute preference persist in `user://digger_guy_save.json`.

## Upgrade progression

The bag starts at **7** spaces, and each Inventory Size upgrade adds **1**. Each Ore Insurance upgrade saves **1** additional piece beyond the starting three. Life upgrades permanently increase the maximum lives per expedition by one; every dive refills them. Contact removes the enemy, the touched spike cluster, or the connected lava puddle and costs one life. A short protection window prevents repeated hits in the same moment. Only the final lost life triggers the death sequence. Surviving bottom/ceiling hazards relocates the miner onto a safe floor.

| Upgrade | First price | Later prices / effect |
| --- | --- | --- |
| Inventory Size | 30 | +1 space; 30, 37, 46, 57… |
| Starting Depth | 60 | +20 m unlocked; 60, 75, 93, 116… |
| Mining Power | 200 | +1 damage per level |
| Ore Insurance | 500 | +1 saved piece; 500, 625, 781… |
| Freeze | 200 | One permanent unlock; Space or snowflake button |
| Speedup | 50 / 500 / 1,200 | Sequential 2× / 3× / 4× unlocks; W or Speedup button |
| Extra Lives | 1,200 | +1 maximum life per dive; each next price triples |
| Place Blocks | 100 | +1 placement per run; normal 25% price growth |

Inventory, depth, click damage, and Ore Insurance prices use the previous price multiplied by 1.25 and rounded down at every step. Life prices triple at every step. First-time Freeze and Speedup purchases show a shortcut popup with **Confirm**. Unconfirmed tutorials, unlocks, slider choices, and existing carried ore persist across restarts. Older saves retain their ore even if it temporarily exceeds the new bag capacity.
## Development and verification

`scripts/game.gd` owns the gameplay and input loop. `world.gd` owns procedural terrain and lava, `catalog.gd` defines progression, `synth.gd` generates sounds, and `ink.gd` draws common vector UI. The separate depot scene lives in `scenes/depot.tscn` with `scripts/depot.gd`.

Run the regression checks in PowerShell, with test saves isolated from real progress:

```powershell
$env:APPDATA = Join-Path (Get-Location) '.test-data'
& ./Godot_v4.7.2-stable_win64.exe --headless --path . --script res://tests/smoke.gd
```

To render screenshots of the game, inventory, depot, shop, sale animation, deep mine, and death animation:

```powershell
$env:APPDATA = Join-Path (Get-Location) '.test-data'
& ./Godot_v4.7.2-stable_win64.exe --path . --script res://tests/capture.gd
```

Screenshots and isolated test data are written under `.test-data/`, which is ignored by Git. Run these commands in a separate terminal; the `APPDATA` override lasts for that terminal session.

The regression suite also checks acceleration, turn and ledge anticipation, landing strength, frozen animation state, connected ore veins, enemy placement, basin support, short drops, deterministic seeds, sparse ore density, and metadata cleanup across 100 generated mines. To capture all five depth regions plus turning, ledge peeking, and landing poses, run:

```powershell
$env:APPDATA = Join-Path (Get-Location) '.test-data'
& ./Godot_v4.7.2-stable_win64.exe --path . --script res://tests/feel_preview.gd
```

Run the additional progression and hazard tests:

```powershell
$env:APPDATA = Join-Path (Get-Location) '.test-data/progression'
& ./Godot_v4.7.2-stable_win64.exe --headless --path . --script res://tests/progression.gd
```

Preview the unlock popups, both slider menus, and Inventory Full warning, and verify the rendered color palette:

```powershell
$env:APPDATA = Join-Path (Get-Location) '.test-data'
& ./Godot_v4.7.2-stable_win64.exe --path . --script res://tests/progression_preview.gd
```

All text uses the supplied `PixelifySans.ttf` with font antialiasing disabled. The miner renders into a 64×64 transparent viewport and scales up with nearest filtering, preserving crisp pixels during rotation; the miner and enemies occasionally blink. All upgrades except Freeze and Speedup have no level cap. Run `tests/menu_revision.gd` for menu, unlimited-upgrade, departure, and counter regressions.

The shader is `shaders/crisp.gdshader`. It preserves thin vector outlines and uses an 8×8 binary-coverage pattern measured in game pixels for fades. A separate nearest-sampled world pass (`shaders/global_pixels.gdshader`) aligns every world shape to one shared 240×400 grid: each 32 px tile occupies 16×16 game pixels. HUD text and depot/shop menus keep their text resolution. GUI outlines use aligned two-screen-pixel filled strips; icons are vector-rasterized once into a native pixel atlas and displayed at exactly 2×. Neither pass quantizes RGB. Both shaders fetch exact texture pixels directly so moving or rotated shapes cannot pick up filtered edge colors. Sprite presentation snaps to the global grid, and all rendering viewports explicitly disable filtering and antialiasing.

Additional placement, haul animation, death timing, and object-rendering checks:

```powershell
$env:APPDATA = Join-Path (Get-Location) '.test-data/placement'
& ./Godot_v4.7.2-stable_win64.exe --headless --path . --script res://tests/placement_depot.gd
& ./Godot_v4.7.2-stable_win64.exe --path . --script res://tests/object_pixels.gd
& ./Godot_v4.7.2-stable_win64.exe --path . --script res://tests/latest_preview.gd
```

The renderer probe checks independent vectors and text in a transparent viewport: every pixel must have alpha 0 or 1, and opaque pixels must retain their source RGB values.


Placement previews appear only on valid, affordable placement cells and use neutral gray at 50% opacity. Invalid targets have no preview. This guide has its own blending material; world shapes remain fully opaque or transparent. Successful placement settles over 0.12 seconds with a distinct generated thud and dirt particles. Fast drags sample every crossed cell, avoiding gaps; no cell is retried until the next press. Terrain is generated at least 50 rows below the full screen, and background and terrain continue to the bottom of the window.

Terrain uses cached vector rows (scripts/terrain_row.gd): ordinary scrolling changes transforms, while digging, placement, and settling invalidate only affected rows. The simulation culls once per row crossed and defers distant lava flow. Offscreen sprite/terrain viewports are disabled in the depot. Run the native 	ests/placement_feel.gd to verify drag placement, cache reuse, one-pixel eyes, generation margin, and exact global 2×2 pixel alignment.

The native rendering check in `tests/crisp_motion.gd` moves and rotates a textured sprite through fractional positions with an intentionally linear inherited filter. It verifies unchanged shape colors and binary alpha, then checks the gray preview against a measured 50% blend and verifies that invalid targets draw nothing.

The cave backdrop stays steady during landing shakes; snapped foreground shake and grid-sized dithering prevent the background from cycling through dither phases. The player emits no light. Actor, ore, particle, and menu movement is presented on the shared integer grid. The mute button is removed; M still toggles audio.

Run `tests/pixel_grid_ui.gd` with the native renderer to verify steady background pixels after heavy landings, absence of player lighting, exact icon/border alignment, one-pixel scrolling without speed loss, and bottom-edge placement/hazards.

Enemy wings, legs, and body offsets hold fixed poses and switch directly at animation frame boundaries. Cursor movement snaps to the shared grid and its cached pixel ring has a one-game-pixel outline. Hovering buttons expands them by one game pixel on every side. Affordable upgrade costs are green, and unaffordable costs are red. Hovering any upgrade opens its explanation over the lower sliders/buttons; moving off the card restores those controls immediately.

Starting Depth levels and sliders now advance in 20-meter steps. Version 3 saves preserve these selections; older saves retain their purchased level count and migrate their selected depth proportionally to the new step size. The native `tests/brown_gui.gd` checks save migration, prices, HUD spacing, pickup destinations, cursor thickness, discrete enemy poses, button growth, and tooltip visibility.
