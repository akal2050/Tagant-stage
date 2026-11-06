# TAGANT: scrap desert, lost figures and organised phasing

Open `res://dove_man/scrap_desert/dove_man_scrap.tscn` and press F6.

- J: wreckage hill close view.
- K: outer landscape overview.
- L: large injured bird figure.
- H: the existing crowd inspection cameras and original director.
- G: the existing water/petroleum Godzilla crossing.
- D: movement and phasing diagnostics.

## Wreckage landscape
Six permanent hills contain 798 stacked damaged vehicles; another 40 wrecks are scattered outside the central circulation, for 838 added cars. The hills also include 243 tyres, 244 barrels, 212 metal sheets and 231 beams. Their rust, dust and faded paint vary by instance. Three existing vehicle models were converted into crushed-roof, frontal-impact and flattened/twisted derivatives. Source models and the original falling-car system remain unchanged. These are static sculpted piles rather than rigid-body physics simulations.

The hills become steering obstacles for walkers and the new crowd groups. Godzilla's route planner also checks them. The three horizon approach regions remain open.

## Injured and lost figures
Nine additional injured figures are twice the 4.4-metre reference height: 8.8 metres. Three use your Myna FBX rig, three the long-eared rig, and three the hyena/camel rig. They use downloaded injured walking and hurting-idle clips, pause, change direction and sometimes head away toward the horizon. They yield during Godzilla's crossing.

`Male Injured Pack (1).zip` contains the hyena/camel model and matching injured motions. The long-eared model uses compatible bone names; the rendered transfer was checked. `Male Injured Pack.zip` contains `myna bird.fbx` and its matching motions. That Myna FBX uses a different rig from the native Myna GLB already in the crowd, so it is added as a separate character rather than replacing or overwriting the existing one. The existing Myna GLB also has an embedded `Idle Hurt` clip. White female/Nico assets are not used.

The supplied packs also contain injured runs, turns, backwards movement, stumbling and hurting idles. The runtime includes injured walk/run/hurting-idle/stumble-idle clips; the lost figures currently choose walking and hurting idle. Original animation files and existing normal-walk clips are preserved.

## Moving crowd and musical phasing
The original 99 personal circular routes remain. The three existing flocks and the arriving groups now preserve individual positions inside a gently changing organic group shape, instead of pulling every member into one centre. Groups anticipate obstacles and keep their centres apart. This addresses bunching and stepping on the spot.

Near the circulation, gait oscillators gradually converge on one rhythm, remain synchronized, then drift apart over the existing 96-second cycle. Animation rate and forward movement are separate GPU inputs, so phasing cannot reset an instance's position. Incoming groups outside the circulation and figures yielding to Godzilla use distance-driven gait rates. Animation source clips are unchanged; their sampling times are coordinated.

Population: 207 initially (198 regular figures plus nine injured figures), growing to 3,177 after the 30 existing waves of 99 arrivals.

## Validation
The ten-minute orbit simulation kept every circling figure moving at least 32.6 metres in each minute. A dense 2,970-member circulation test retained a minimum measured separation of 2.96 metres and every arrival moved at least 51.9 metres in the final minute. Separate phase samples changed from coherence 0.03 to 1.00 and back to 0.03. The hill route check found a clear Godzilla crossing.

The short full-capacity rendered test averaged about 14.4 FPS at 1280x720 on the RTX 3050 Laptop 6GB, including screenshot captures. This remains a visual prototype with occasional slow frames, not a performance guarantee. Existing base-world resource warnings appear at shutdown.

Dependencies: existing water_titan, horizon_variant, flock_variant, swarm_variant and horde_variant folders, plus the original Dove Man world. This additive scene does not change the project's default startup scene.

The updated evacuation test cleared all 723 arrivals initially inside the Godzilla corridor after 36 simulated seconds. The nine injured figures each moved at least 20 metres during a separate one-minute wandering test, including horizon-bound and wrong-turn states. Preview files: `phasing_motion.mp4` shows staggered steps converging into a shared rhythm; `injured_motion.mp4` shows the larger injured bird and long-eared figures.

## Current working revision: independent injured timing and slower growth
This is the latest working scene, not a final/polished release. Injured figures are excluded from the crowd's synchronization. Each has an individual idle phase, idle tempo, first decision time, walking speed, pause schedule and choice between hurting and stumbling idle. They no longer all begin with the same pause or reset every gesture to time zero. Occasional similar poses can still happen naturally; persistent shared gesture timing is removed.

World growth now uses `world_pacing.json`: a two-minute opening, then one wave of 99 arrivals every 75 seconds. The thirtieth wave starts at 38 minutes 15 seconds; walking in from the horizon adds several more minutes. The initial 207 figures remain. This slows population growth without globally slowing the existing walks or Godzilla.

The new scheduler and independent timing passed a 60-second pose-timing check. Actual scene updates verified no arrivals before 120 seconds, 99 at 120 seconds, and 198 at 195 seconds. `independent_injured.mp4` replaces the earlier injured-motion preview for this revision. Restart the running scene to load the new opening schedule.
