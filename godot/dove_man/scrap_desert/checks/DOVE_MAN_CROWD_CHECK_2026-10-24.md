# Dove Man — scrap desert — crowd check (24 Oct 2026)

**Version checked:** the latest scene, `C:\Users\azoor\Documents\tagant-00\dove_man\scrap_desert\dove_man_scrap.tscn`. Its code was last changed on 18–19 Oct; the last recorded run is from 22 Oct.

**Nothing in the world was changed.** The checks ran on a copy in Claude's workspace.

## What was run

- **Code reading:** every script in the chain (base world → swarm → flock → horizon → water titan → organised crowd → scrap world), traced frame by frame for each crowd type.
- **Simulation:** 15 simulated minutes, with Godzilla forced to cross at 0:40.
  - Bodies touching, measured every second across all crowd systems.
  - Bodies inside obstacles.
  - Foot sliding: forward speed against step rate.
  - Position jumps of the GPU crowd.
  - Ground height.
- **Natural hour:** a separate 25-minute run without forcing Godzilla.
- **Stills:** six frames rendered at minute 2:20 (contact sheet: `DOVE_MAN_crowd_check_2026-10-24.jpg`).

## Weird things, most visible first

1. **Crowds walk through each other and through things.**
   - Each system only avoids its own short list of obstacles:
     - the 99 orbit walkers;
     - the 3 flocks;
     - the arriving waves;
     - the 9 injured giants.
   - Measured over 15 minutes:
     - the arriving waves overlap each other constantly, with 10–14 % of them touching at any time;
     - the arrivals also overlap the flocks and the orbit walkers;
     - by minute 15, about 20 arrivals at any moment are standing inside car wrecks;
     - dinosaurs and camels walk through the crowds.
   - Loose wrecks and the petrified ruins are not obstacles for anyone.
2. **The arrivals look pasted on.**
   - The GPU crowd casts no shadows, while everything else does (see sheet, top left).
   - A few skins come out very pale or grey-white.
   - Their low-detail mesh reads as hooded blobs close up.
3. **During a Godzilla crossing the crowd collapses into lines.**
   - Everyone within 72 m of his path is pushed onto exactly 72 m, so flocks march in single file with bodies merging (sheet, top middle).
   - They also snap their facing by up to about 70° when the crossing starts and ends.
   - A crossing lasts about 7 minutes, so this line formation is on screen for a long time.
   - In the natural hour the first crossing comes at about 9:00.
4. **Feet slide sometimes.**
   - 96.8 % of arrival steps match their speed.
   - About 3 % are off by more than 15 %, mostly too fast for the step (skating), at the moment a group switches from walking in to joining the circle.
   - Slow figures can step on the spot.
5. **The GPU crowd jumps a little twice a second.**
   - Positions are only recomputed every 0.5 s, and the shader guesses in between.
   - The largest measured jump was 1.7 m; 0.5 % of updates jump more than 30 cm.
6. **Arrivals float over or sink into fresh craters and footprints.**
   - Ground height is cached forever per 3 m cell.
   - The largest measured error was 2.1 m; 0.5 % of checks are more than 30 cm off.
7. **The original statues are stuck in pairs.** Two pairs of the old mannequin slots walk shoulder to shoulder for about 70 % of the hour (sheet, bottom left).
8. **The 85 added orbit walkers turn together like one rigid disc.**
   - They all share the same angular speed.
   - Their size grows with ring radius, so from above they read as size-sorted rings.
9. **There is a straight seam across the desert.**
   - The 900 m sand plane ends in a hard edge (sheet, top right).
   - The injured giants gather near that edge (they are pushed back at 455 m) and pop 0.8 m in height when they cross it.
10. **Smaller things:**
    - a plane flies through or very close to the Dove Man body (sheet, bottom middle);
    - figures are swapped for a lighter mesh at exactly 95 m from the camera, with no blend, so you may see a pop;
    - the injured giants animate at 12 frames per second even in close-up;
    - the director's contre-jour shot can put the camera inside a flock;
    - each run differs, because Godzilla and the cars are not seeded.

## Not a problem

- **Dove Man's feet:** the body is about 30 m wide at the ground, and the walkers keep at least 35 m from the centre, so nobody walks into the base.
- **Loading:** the scene loads with no script errors.
- **Godzilla:** the crossing itself reads well.

## Fixes, if you want them

These are listed in order of effect; they are not done yet.

1. One shared collision step for all crowds plus wrecks, ruins and hills.
2. Lanes instead of a single 72 m line during Godzilla, with smoothed turning.
3. Shadows on for the arrivals, and a darker skin-tone range.
4. Update the GPU crowd every frame in slices, and drop the height cache near craters.
5. Hide the sand-plane edge.
6. Seed Godzilla and the cars, so every run is the same hour.

## Update 25 Oct 2026

The fixes above are done as a new layer (nothing here was edited). Play: `C:\Users\azoor\Documents\tagant-00\dove_man\crowd_fix\PLAY_DoveMan_crowd_fix.bat`. Notes and measurements: `C:\Users\azoor\Documents\tagant-00\dove_man\crowd_fix\DOVE_MAN_CROWD_FIX_2026-10-25.md`.
