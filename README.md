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

Latest gameplay revision: clicked blocks shake; spike supports are indestructible light gray stone; fatal collisions preserve the hazard. Each vein is accompanied by three single ore deposits. The ten enemy visuals are herbivores. Starting Depth adds 10, 20, 30, ... meters per purchase (10, 30, 60, ... total); version 4 saves migrate earlier depth selections by purchased level. First-run ability notices pause the mine until confirmed, and the first dangerous ledge teaches right-click placement with a glowing target. Death launches the miner in a rotating upward arc 0.2 seconds after the iris stops. Departure light is opaque and drawn behind the miner.

Run `tests/requested_changes.gd` for the new progression, deposit ratio, tutorial, fatal hazard, and death arc regressions, using the isolated APPDATA setup above.

Round-flow revision: starting airspace is five tiles high and fresh inventory capacity is seven. The placement lesson now stops the miner at the centre of the last safe tile and highlights a wall tile beside the miner; it recognizes lava, enemies, floor spikes, and bottom spikes. Single-tile ground enemies stop moving, turning, and advancing their animation until a route opens. Sell All occupies the bottom button and immediately becomes Dig Deeper; diving completes any remaining coin flights instantly. Inventory Full slides in from the left and out to the right on the side opposite the player; the leave button alternates between one- and two-game-pixel outlines.

Speedup is available at x3 from the first round. Its reminder starts on round two and repeats until W has been held continuously during active speedup for more than 1.5 real seconds. Speed upgrades have no level cap, add one multiplier each, and cost 200, 600, 1800, ... coins. Speed and reminder state persist in version 5 saves; existing upgrade purchases are preserved. Extra Lives is displayed from zero while the miner retains the base fatal hit internally. Run `tests/round_revision.gd` for these regressions.

Ore feedback revision: each fresh ore contact while the bag is full restarts Inventory Full (continuous contact does not restart it every frame). The leave outline alternates between one and three game pixels. The W reminder reads "You can hold W to speed up the game". Each death shake generates a distinct impact waveform; death launch and departure-circle closing have separate sounds triggered once at their animation transitions. The satchel lists quantity, unit coin value, row value, and total coin value. Every run requires a left-button release before mining is accepted.

Emeralds unlock at absolute depth 50 m, sell for 60 coins, and roll independently at 1% on ore-free destructible generated blocks. They are excluded from ordinary veins/single selection. Other ore/enemy unlocks are defined in `scripts/catalog.gd`; ordinary generation gates by section starting depth, so an unlocked species/ore need not appear immediately. Lava basins become eligible at section depth 360 m. Destructible generated and placed blocks currently have exactly two health at every depth: there are no extra-hit depth thresholds. Spike supports are indestructible. `tests/ore_feedback.gd` covers contact retriggers, the mining-release gate, emerald eligibility/rate, unique shake samples, and sound timing.

Freeze/discard revision: Inventory Size starts at 20 coins. Freeze is owned by default, including migrated saves. Its reminder starts two rounds after the round in which W is learned and repeats until Freeze is used for more than 1.5 continuous real seconds. Earlier Freeze use suppresses the reminder; version 6 saves preserve the learned state and schedule. Each satchel row has a red trash button that discards exactly one ore, updates value immediately, and stops full-bag leave reminders. After five real seconds with a full bag, the leave button shakes every two seconds until used or an ore is discarded. New effects accompany discarding, upward extraction movement, and fatal or survived enemy contact.

Block health is now `2 + floor(absolute_depth / 100)` for generated and placed blocks, before mining-power damage; spike supports remain indestructible. The first fifteen extra-hit boundaries are 100, 200, 300, 400, 500, 600, 700, 800, 900, 1000, 1100, 1200, 1300, 1400, and 1500 metres. Ruby unlocks at 70 metres and sells for 70 coins. Run `tests/freeze_discard.gd` for tutorial persistence, health boundaries, ruby eligibility, trash interactions, reminder timing, and new sound triggers.

Expedition expansion: death and voluntary extraction now open a results menu before the depot, with a single Continue button. Panels stagger every 0.2 seconds and text reveals one letter every 0.2 seconds. The report shows depth records, retained haul value, earned bonuses, newly affordable upgrades, the next discovery, and progress toward a tracked purchase. Clicking a shop card tracks that upgrade and purchases it if affordable. Helmets, backpacks, armour, and equipment straps change with purchases.

There are now 45 ores and 40 animal enemies. Thirty ores are interleaved by unlock depth; existing ore IDs remain stable for old inventories. Later original ores move deeper: Gold 400m, Cobalt 800m, Nickel 1200m, Titanium 1600m, Sapphire 2800m, Diamond 3400m, Obsidian 4000m, Mythril 4600m, Eternium 5200m. New animals begin at 1800m and unlock every 160m through 6440m. Animals use grazing, fleeing, charging, bounding, herd-patrol, and gliding traits alongside the original movement families. Satchel and depot inventories scroll with the mouse wheel when needed.

Milestones at 100, 300, 360, 580, 920, 1640, 2600, and 4000 metres award one-time coin bonuses and introduce glow gardens, gilded treasure rooms, lava crossings, crystal groves, herd trails, ancient spires, prismatic caverns, and richer deep sanctuaries. Treasure caches can be mined for coins. Claims and tracked goals persist in version 7 saves; older saves retain ore quantities and already-reached milestones migrate without granting duplicate rewards.

Default Speedup is x2. Freeze is absent from the shop and remains free. The Freeze hint reads "You can press space to freeze the game". The light's initial departure sound is removed; upward movement and circle-closing sounds remain.

Desktop development shortcuts: hold Shift and Z, then M to delete/reset saved progress and start fresh, O to add ten metres of depth, or L to subtract ten metres (minimum zero). These handlers, including save reset, are disabled on web builds. Run `tests/expedition_expansion.gd` for the expanded catalogue, results flow, reward accounting, old-save migration, scrolling, treasure, and shortcut regressions.

Results satisfaction revision: the progression screen now follows one featured achievement, an animated vertical depth route, a large discovery specimen/animated animal/cave feature, and a staged earnings transfer into the tracked-upgrade bar. The route starts at the previous record for a new deepest run and pauses at each new ore, animal, and milestone. First discoveries have distinct chimes; new records and newly reached upgrade prices have their own feedback. A single featured headline prioritizes a depth record, first treasure, or newly affordable upgrade. Non-record and empty runs retain truthful feedback.

Panels remain staggered by 0.2 seconds. Ordinary text reveals at 0.03 seconds per letter, with 0.045 seconds for major headlines and milestone names. Clicking anywhere (or pressing Enter) finishes the current reveal without advancing; a subsequent Continue click/Enter opens the depot. Scrolling over the discovery card revisits unlocked discoveries without adding buttons. The displayed funds include the pre-run wallet/carried haul, this run's retained haul change, and awarded bonuses; the animation does not sell inventory or alter the wallet. Losses animate downward, and the exact remaining price is displayed.

The current and next equipment portraits use the same renderer as the live miner. Shop cards preview equipment and its practical benefit before buying; a successful purchase shows the actual before/after comparison for 2.5 seconds. Helmet reinforcements, backpack size/straps, armour, boots, insurance badges, compass, and block pouches reflect their upgrades. Version 8 saves remember the first treasure discovery. `tests/results_satisfaction.gd` covers timeline pauses, ordered discoveries, earnings arithmetic, losses, sound timing, reveal skipping, discovery browsing, featured achievements, purchase snapshots, and first-treasure persistence.

Material journal and milestone gates: the progression screen now shows Discovered Materials rather than a depth-unlock carousel. Only ores that have entered the inventory are recorded, including carried ores migrated from older saves. Hovering an icon shows the ore's icon, name, coin value, lifetime units sold, and minimum spawn depth. Selling, discarding, and later expeditions preserve discoveries. The footer points to the earliest uncollected material; a complete collection shows All materials discovered. Version 9 saves preserve discovered IDs and sold quantities; older, unrecorded sales cannot be reconstructed.

Every shop purchase requires a reached depth as well as its coin price. Starting Depth requires its next starting depth. Mining Power requires 10 + 30*level metres, Inventory Size 20 + 30*level, Ore Insurance 30 + 30*level, Speedup 30 + 90*level, Place Blocks 60 + 90*level, and Extra Lives 90 + 90*level. Coin prices retain their current scaling. Locked cards are transparent with Reach X meters to unlock overlays; current equipment occupies a full-size card before the first upgrade.

A one-time milestone occurs every 10 metres. Rewards are 5 coins at 10m, 10 at 20m, 15 at 30m, and so on. Feature milestones share that payout and are not paid twice. Previously reached depths migrate as already claimed. The next milestone and its reward replace the upgrade-funding panel; the depth map spans the expedition's starting depth to the next milestone, with Best: X above its dotted record line. The former equipment comparison panel draws one of 150 authored flavor messages, and the final panel draws one of 50 authored gameplay tips from `scripts/progression_text.gd`, chosen once per report.

Progression graphics render into a 240x400 transparent viewport with the crisp shader, then enlarge with nearest filtering while text remains at UI resolution. Continue grows and highlights on hover. Speedup/Freeze round-start reminders wait until the depot has been visited during the current app session; that visit flag is intentionally not saved. The freeze prompt is You can press space to freeze time. The desktop-only Shift+Z+I shortcut adds 1,000,000 coins through the same web-disabled debug dispatcher.

`tests/material_milestones.gd` covers all gate boundaries, journal/sale persistence, session reminder rules, milestone rewards, text counts/fitting, and the coin shortcut. Run `tests/materials_native.gd` with the native renderer to verify two-game-pixel material artwork, binary shader alpha, collection layout, Continue hover, and locked shop rendering.

The expedition recap now completes its reveal in three seconds, with click/Enter finishing it immediately. Statistics count upward and retained ore value lands with a short bounce and dedicated chime. The miner celebrates crossing the old best-depth line, and first-ever inventory finds pop into the journal with a persistent NEW tag. Earned milestones fill, stamp complete, and send their rewards to a bonus counter before the next goal appears; exceptionally deep runs group the payouts into five readable beats while preserving the exact sum. This presentation never sells ore or grants a reward twice.

Recap titles prioritize depth records, first treasure rooms, newly collected materials, and personal-best retained hauls; ordinary runs keep the motivational title pool. Record, treasure, empty-bag, narrow-escape, and death outcomes each have their own flavor messages. Death explicitly distinguishes retained ores/value from lost ores. A newly affordable purchase appears above the flavor message. Value and milestone depth share a 22-pixel font, and space recovered below Value is redistributed to the milestone and flavor sections. Richest-haul history persists in the save. Validate with `tests/results_rewards.gd` (28 checks), the existing regression suites, and `tests/materials_native.gd` (6 rendering checks).

The haul screen uses aligned material, quantity, per-ore, and subtotal columns with a fixed remaining-value total. Sell All quotes the exact payout; sold rows flash for 0.24 seconds and disappear, subtracting their subtotal immediately. Wallet flights settle independently and end with a dedicated chime; Dig Deeper can settle them immediately without duplicating money. New-material labels remain, while best-find highlights and empty-haul messages are omitted.

Shop cards show affordable borders and actual next prices. Depth-locked cards show only their unlock requirement, with the depth number in red. Purchase animations deduct the actual paid price, settle the current stat, and briefly highlight the newly equipped miner. Hover previews do not change ownership. The shop portrait and comparison miners walk in place through a 240�400 viewport with the pixel shader; the portrait has no title. Pins, tracking controls, and coin-shortage labels are omitted. No sale-to-upgrade message or additional benefit explanations were added. Validate these behaviors with `tests/haul_shop.gd` (25 checks) and `tests/haul_shop_native.gd` (9 native rendering checks).

Runs now keep terrain stationary until the first block is broken, while the miner and animals can move. Placement and cached rendering include the five starting air rows above the initial ground. Remaining placeable blocks appear as an icon/count at bottom right; depth appears in large type at bottom center. Both overlays fade below the seventh visible row. Extra lives are hidden until upgraded. Top boundary spikes emerge, retract, and damage the miner symmetrically with the bottom spikes. Header button tooltips show hotkeys (W, Space, E, and Q for leaving) above the world pixel filter so the small text stays legible.

Round-start W/Space popups have been removed. The first unlearned encounter with an enclosed, walkable corridor pauses for W; the first predicted hazard collision pauses for Space. Only the requested key acknowledges each prompt, activates the ability, and saves the learned state. The existing right-click placement lesson remains independent. Extraction is silent and takes 1.915 seconds, exactly half its previous length. After the death iris fully closes, large white lost-ore text holds for one second before results.

Death results display retained ore count, with a nonzero lost count immediately beside it. Value counts up and grows/shrinks around its own center; milestone filling begins after that animation ends. Newly earned milestone celebrations burst pixel-shaded confetti out of the bar with a reward chime. Ordinary results finish in three seconds; milestone results allow the later celebration to finish, and all reveals remain instantly skippable. `tests/run_hud_tutorials.gd` covers 32 behavior checks and `tests/run_hud_native.gd` covers six native rendering checks, with screenshots under `.test-data/run-*.png`.
