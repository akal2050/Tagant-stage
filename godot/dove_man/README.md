# TAGANT — DOVE MAN (Godot 4.6)

Open `res://dove_man/dove_man.tscn` and run it (F6). Nothing outside this folder is used or changed;
`world_000` still works as before.

## v8 — dinosaurs at the edges, quicker dissolves
- **Dinosaurs** walk further out, near the edges of the world (tracks around 300, 345, 390 and 470 m), and
  faster (1.45–1.9 m/s): each goes round Dove Man about 2.4 times an hour, so their travel is visible.
  The track is no longer a perfect circle: it swells and dips around the world and drifts in and out over
  the hour (each one ranges over 60–100 m). Shorter pauses (10–30 s).
- The walk shows in the body: a heave on each step and a slow roll from side to side.
- **Footprints**: every half stride, a diagonal pair of prints is pressed into the sand behind them. Fresh
  for about a minute, then the wind takes them (gone after ~3 minutes). `dinos → print_life_s, print_size_per_h`.
- **Camera dissolves** are quicker: 0.45 s into the dust, 0.6 s out, and the dust never goes fully white.
  (`FADE_OUT_S`, `FADE_IN_S`, `FADE_PEAK` at the top of `characters/director.gd`.)

## v7 — the tawaf, filling craters, three crossings
- **Mannequins walk the tawaf**: counter-clockwise around Dove Man, with him on their left, like the circling
  at the Kaaba. Seven at his feet (ring ≈ 37 m, about 3 laps an hour) and seven new, taller ones (4.6–7.4 m)
  on a middle ring at ≈ 118 m, between the near group and the dinosaurs (about 1.5 laps an hour).
  They walk like the undead: a forward slump, short dragged steps with a surge on each step and a drag
  between, the body rolling side to side, each with its own limp; now and then one stops and stands, dazed.
  Knocked down by a car or a step, they lie still for 40–100 s, then heave themselves up in three jerks and
  rejoin the circle (they stay down in the burial phase). They sink with the sand over the hour as before.
  Tune in `data → pilgrims` (rings, speeds, lean, roll, stalls, rising).
- **New shot "tawaf"**: the camera walks along with the outer circle at eye height.
- **Craters fill back in**: 20 s after an impact the wind starts filling the hole; after about 3.5 minutes the
  sand is level again (`cars → crater → fill_delay_s / fill_s`). The wreck stays, half buried.
- **More cars**: about 45 an hour, rising from one every ~2 minutes at the start to one every 30–60 s at the
  surreal peak, slower again in the burial phase; at most 7 wrecks lie on the sand at once.
- **Godzilla crosses exactly three times**: starting around minutes 9, 26 and 43 (±1 min), each crossing
  horizon to horizon (`godzilla → crossings_min`). The G key still calls one at once.

## v6 — horizon crossings, zenith, growing sky
- **Godzilla** no longer rises from or sinks into the sand. Each crossing starts about 700 m out, beyond the
  edge of the world, passes in front of Dove Man and walks on until 700 m out on the other side. He dissolves
  in between 580 and 430 m from Dove Man and out again the same way (dithered fade, `godzilla → fade`).
  A wider ring of far dunes carries him beyond the stage. About six crossings an hour.
- **Birds** grow all hour: 5 at the start → about 10 at minute 10, 30 at 30, 52 at 45, 77 at 60, always in
  flocks of at most 7; newcomers fly in from the haze (`birds → growth`).
- **Camera mix**: still tripod shots ("fixed", plus horizon, human, event) in about equal measure with moving
  ones (orbit, dolly, crane, follow, flock). New: **zenith** — straight above Dove Man at 420–560 m, his axis
  at the centre of the frame, the world slowly turning around it (the haze thins for this view), and
  **flock** — drifting alongside one of the flocks.

## v5 — circumambulation, smooth turning, growing flocks
- **Dinosaurs**: four, each on its own ring (≈200, 232, 268 m and a far one at 410 m in the haze), all walking
  counter-clockwise around Dove Man as the axis — a slow circumambulation; the inner ring takes about an hour
  per lap. They pause, step outward when Godzilla crosses their ring, and step round rock camels and wrecks.
  Rings, speeds and start angles: `data → dinos → list`.
- **Turning like an animal** (camels and dinosaurs): no turning while standing still; turning happens only while
  walking, along a turning circle about one body height (dinos 1.5 heights); the desired direction and the turn
  rate are both eased, so obstacles and changes of mood never make the body snap. A big change of direction
  becomes a slow curving walk. Measured over an hour: camels ≤ 14–19°/s, dinosaurs ≤ 1°/s, 0°/s while still.
  (Same principles as GDQuest's Steering AI Framework — arrive, avoid, look-where-you-go with limited angular
  acceleration — written for Godot 4.6, since that framework targets Godot 3.)
- **Bird community** (as in the TAGANT score): at most 7 birds a flock (growth rate: see v6). A newcomer flies in from the haze and searches out the youngest flock with room; when all flocks
  are full it founds a new one. Now and then two flocks meet and fly together for a while.

## v4 — one hour, cinematic
- **The hour.** The world runs 60 minutes, then breathes out to white and starts again. Seven phases in
  `data/dove_man_world.json → timeline` (edit minutes and values there): 0 silence · 8 first traces ·
  20 crossings · 35 accumulation · 45 surreal peak (green sky, cold low sun, Godzilla slowed) · 53 burial
  (mannequins sinking) · 60 stillness. Sun, fog, volumetric haze, sky colour, debris, Godzilla's rhythm and
  speed, car rhythm and Boeing altitude all glide between phases. Car and Godzilla rhythms switch per phase
  (no cars during silence, at least 20 s between drops).
- **Director** (`characters/director.gd`) replaces the fixed cameras. Shot types: wide orbit, slow dolly,
  crane rise, long-lens horizon (16–22°, lens at knee height, 300–390 m out), high, follow (while Godzilla
  walks), event (a car about to fall), and human — standing eye height 1.65 m, breathing, looking up; it comes
  back about every 4–5 shots. Composition rule for every shot: horizon in the lower third, subject on a third;
  wide, dolly and crane shots pick the lens that holds Dove Man's whole height. Before committing to a shot,
  the director looks through the lens at its start, middle and end and rejects it if a camel, dino or rock
  camel would fill the frame. While a shot runs, things may cross the frame; it only cuts early (after 10 s
  minimum) if something comes right into the lens. Most transitions dissolve through dust; some are hard cuts.
  Long lenses get depth of field; quakes reach the lens (more on foot).
- **Birds** (`characters/birds.gd`) are flocks, not loose pigeons: they fly as boids around a wandering goal,
  glide or flap depending on effort, bank into turns, land on Dove Man's head, wreck roofs, rock-camel humps
  and palm crowns, and burst off when a quake, a car impact, Godzilla or the Boeing comes near. The flocks
  grow through the hour. Model: your original `res://assets/flying_pigeon` (all five clips).
- **Rocks** accumulate all hour (up to 2500, about 22 per close step).

## v3 — relationships
- Every body is a disc on the sand (`obstacles()` in the world script): Dove Man, rock camels, palms,
  mannequins, cameras, wrecks, camels, dinosaurs, Godzilla. Walkers steer around them (`steer()`) and a hard
  rule pushes anyone back out of anything solid after every move (`resolve()`).
- Godzilla plans each crossing (`plan_godzilla_route()`): on the camera side of Dove Man, never closer than
  80 m to him, clear of rock camels, cameras and wrecks.
- Cars only land on free sand, away from cameras and Godzilla's route.
- Reactions (`react_to_impact()`): a foot landing beside a palm flattens it, a car impact topples nearby
  mannequins, a step near a wreck makes it jolt, impacts startle camels.
- Cameras never go under the sand (CPU twin of the sand surface: `sand_height()`).
- Camel: new rigged model `models/camel_v2.glb` (Walk / Idle_01 graze / Idle_02 stand) — by E.A.Cornell,
  Sketchfab, CC-BY. Set `camels.gait.show_coat` to false to remove the woven blanket.
- Sand: pale, realistic desert sand with slope shading, wind ripples near the camera, churned sand in prints.

## Characters (v2)
- `characters/camel.gd` — every camel is its own character: personal stride, tempo, limp, neck bob,
  moods (wander / pause / graze with the head down / look around / flee). Legs are driven bone by bone
  from the distance walked, so hooves don't slide. Feet calibrated on the mesh, lowest sole 20 cm in the sand.
- `characters/falling_rocks.gd` — rocks break off Dove Man after each nearby step, fall, bounce and stay;
  piles grow (the 900 newest rocks are kept).
- Godzilla uses the original `res://assets/godzilla/scene.gltf` (read only, untouched) placed with Blender's
  exact fit — the re-exported `models/godzilla.glb` is no longer used and can be deleted.
- Cars are world-scale wrecks (`cars.scale` in the JSON, 3.5 = about 17 m); craters scale with them.

## Folder
- `dove_man_world.gd` — the whole world, live (no baked animation).
- `data/dove_man_world.json` — everything measured in Blender (`Desktop/webcore/dove man.blend`):
  placements, Godzilla's foot path and stride, camel gait, dino foot pads, Boeing clearance grid,
  car-fall physics, the quake model, cameras. Tune numbers here, not in the script.
- `models/*.glb` — exported from Blender with skeletons, animations and textures:
  - `camel_rigged.glb` — skeleton + `Idle` (original) + `Pace` (new walk; legs on the same side move together)
  - `godzilla.glb` — skeleton + `Walk`
  - `dino.glb` — shape-key animation `Graze`
  - `pigeon.glb` — skeleton + `BirdRig|Flapping`
  - `dove_man_mountain.glb` — Dove Man with the eroded gullies baked into the geometry, already in place (scale 90)
  - `rock_camel.glb` — the sandstone camel (craggy relief baked in)
  - `car_peugeot504.glb`, `car_pickup.glb`, `car_landcruiser.glb` — Sketchfab, CC-BY (credit below), textures reduced to 1024 px
  - `palm.glb`, `mannequin.glb`, `boeing.glb`, `debris_rocks.glb`
- `shaders/` — `sand` (dunes + Godzilla bowl + 32 footprints + 8 craters), `dove_mountain` (rock, strata, snow),
  `desert_skin` (shared skin for every animal and car), `rock_sand` (rock camels).

## How it behaves
- Godzilla's walk is stride-locked: the animation is advanced by the distance he covers (35.7 m per cycle),
  and his height comes from the standing foot, which sits 1.9 m down in its own fresh footprint.
  Each step: footprint, quake, dust, and rock + sand falling from Dove Man (more when he is close).
- Camels: idle and pace blend by speed; the pace advances one cycle per stride. At start-up the script finds
  the four soles on the camel mesh, then keeps the lowest one 20 cm under the sand every frame.
  They flee sideways off Godzilla's path while he is up.
- Dinosaurs graze along the rim (radius 200–255 m), drift slowly, and move away if Godzilla rises near them.
- Cars fall from 380 m every 20–60 s (first at 10 s), hit at ~86 m/s, punch a crater, bounce once and settle
  at a broken angle. With more than 5 wrecks, the oldest is swallowed by the dune.
- Boeing orbits Dove Man's head and shoulders; the JSON grid holds the minimum radius per angle/altitude,
  measured against the real mountain so it never clips the rock.
- The microphone climate (fog, sway, camel hesitation) is the same as world_000.

Keys: `D` debug overlay (minute, phase, shot, birds) · `C` cut to the next shot · `G` call Godzilla now · `V` drop a car now.

## Credits (CC-BY)
- Peugeot 504 — 3d_engineer (Sketchfab)
- Muteki Taiga Pickup Rusty [Low Poly] — Scigh-on (Sketchfab)
- Older Matte Land Cruiser — jtressle (Sketchfab)
- Camel — E.A.Cornell (Sketchfab)
