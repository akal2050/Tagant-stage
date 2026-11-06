# Dove Man — crowd fix (25 Oct 2026)

AZ: "can you fix these problems?" — after the crowd check of 24 Oct
(`C:\Users\azoor\Documents\tagant-00\dove_man\scrap_desert\checks\DOVE_MAN_CROWD_CHECK_2026-10-24.md`).

**To play:** `C:\Users\azoor\Documents\tagant-00\dove_man\crowd_fix\PLAY_DoveMan_crowd_fix.bat`

**How it is built:** the fix is a new layer on top of the scrap desert.
- `crowd_fix_world.gd` extends `scrap_desert\scrap_world.gd`.
- The scene is `dove_man_crowd_fix.tscn`.
- No existing Dove Man file was edited. The old scene `scrap_desert\dove_man_scrap.tscn` still plays exactly as before.

## What changed

| # | Problem in the check | Fix |
|---|---|---|
| 1 | Crowds walk through each other and through things | One shared collision step for all four crowds. It also covers hills, loose wrecks, petrified figures, palms, rock camels, camels, dinosaurs, Godzilla and the base of Dove Man. |
| 2 | Crowd collapses into single file during a Godzilla crossing | People step aside into a wide band, 72–250 m from his path for groups and 72–100 m for the ring walkers. They keep their order, and only near Godzilla himself. Turning is smoothed. His three routes are moved to pass at least 165 m from Dove Man, outside the walkers' ring. |
| 3 | Arrivals look pasted on | They now cast shadows and use darker skin tones. |
| 4 | Feet slide | Step rate is held within 10 % of the real walking speed. Very slow figures stand still instead of stepping on the spot. |
| 5 | GPU crowd jumps twice a second | It is drawn one crowd tick behind its simulation, so it glides from where it was to where it is, with no guessing ahead. |
| 6 | Floating over / sinking into craters and footprints | The dune height is cached. Wherever a crater, a footprint or Godzilla's pit is live, the exact height is read again. |
| 7 | Old statues stuck in pairs | Fixed by the shared collision: the pairs are pushed apart. |
| 9 | Seam at the sand edge; injured giants crowd it | The step at the 450 m edge is gone. The injured giants stay between 250 and 400 m, turn before they walk, and animate at 30 fps near the camera. |
| 10 | Plane through the Dove Man body; mesh pop at 95 m | Aircraft keep 30 m more clearance. The near/far mesh swap has a margin: it switches at 110 m going away and 82 m coming back. Animation rate follows on-screen size. |

## Measured (15 simulated minutes, Godzilla forced to cross at 0:40, same test as the check)

Bodies touching, average per one-second sample:

| | before | after |
|---|---|---|
| arrival – arrival | 67.7 | 5.6 to 9.5 (varies by run) |
| arrival – flock | 11.7 | 0.1 to 0.8 |
| flock – flock | 15.0 | 0.4 to 0.6 |
| arrival – orbit walker | 3.6 | 0.3 to 0.5 |
| orbit – orbit | 1.3 | 0 (one run 3.0, with a slower collision step since put back) |

Other measurements:

| | before | after |
|---|---|---|
| Arrivals standing inside wrecks (per sample) | 1.5 | 0.4 to 0.7 |
| Steps off their speed by more than 15 % | 9.2 % | 0.1 to 0.4 % |
| Closest walker to the centre during a crossing | 20.9 m (inside the base) | 35.9 m |
| Furthest injured giant | 355 m | 320 m |

These numbers come from three runs of the final version. Runs still differ a little, because the base world randomises its set-up (see below).

**Frame cost:** measured headless, at the busiest point (2,970 arrivals).
- Average frame: 34 ms with the fix, against 30 ms without.
- Most of the collision work is spread over the frames between crowd ticks, so the tick itself costs about what it did before.
- This was measured in Claude's workspace, not on your PC.

## Not changed

- **The 85 added orbit walkers still turn together like one disc.** That shared rotation is how their phasing is designed, so it was kept.
- **Every run is not yet the identical hour.**
  - The layer seeds everything it draws.
  - The base world calls `rng.randomize()` while loading (in `dove_man_world.gd`), so the car layout still differs per run.
  - Fixing that is a one-line change in that file. It was left alone, so as not to edit the base.
- **The director's contre-jour shot is not used by the scrap scene,** so it was not touched.
- **A few touches remain** (about 0.3 % of arrivals at any moment), mostly inside dense groups at the moment a group joins the ring.

## Not yet tested

- **The scene has not been run on your PC.** All checks ran in Claude's workspace (Godot 4.6.3, Linux).
- **Still frames:** `C:\Users\azoor\Documents\tagant-00\dove_man\crowd_fix\DOVE_MAN_crowd_fix_2026-10-25.jpg` puts the old scene and the fix side by side at minute 2:20. The fix frames were simulated at a coarser step (2 per second) to render in time, and the camera spots follow the crowds, so the framings differ.
