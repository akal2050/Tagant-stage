# TAGANT — 99-member phasing swarm

In the existing `tagant-00` Godot project, open `res://dove_man/swarm_variant/dove_man_swarm.tscn` and press **F6**.

There are **33 Myna, 33 long-eared figures and 33 hyena/camel hybrids: 99 total**. The fourteen previously placed pilgrims are included in these counts and retain their original personal ring radii and heights. Eighty-five additional walkers fill the inner annulus. Every member has a distinct nominal orbit and travels counter-clockwise around Dove Man. The inherited outer orbits bend slightly around fixed scenery rather than passing through it.

## Phasing

The existing skeletal walk clips remain intact. Travel speed and animation phase are coordinated, rather than adding an arbitrary animation offset while bodies slide forward. Footfall phase is aligned across the three rigs. Added walkers' sizes are matched to stride/orbit proportions to reduce overtaking conflicts; existing fourteen heights are preserved. Native Myna stride length remains an estimate for its in-place clip, so this is not full foot IK.

The repeating **96-second** cycle is:

- 0–16 seconds: staggered delays.
- 16–40 seconds: gradually converge.
- 40–56 seconds: hold a shared rhythm.
- 56–88 seconds: gradually spread into delays again.
- 88–96 seconds: hold staggered timing, then repeat.

Small changes of tempo produce the phasing. Nearby walkers can yield, which may briefly interrupt synchrony locally. Impacts, falls, recovery, the world's burial phase and the other creatures continue through the inherited world controller.

## Views and controls

**H** cycles low procession → oblique crowd → overhead plan → original cinematic director. **D** shows the existing debug overlay plus phasing stage and a coherence measure. **C**, **G** and **V** retain their original camera-cut, Godzilla and car-drop controls.

The default camera remains the world's cinematic director. Use H to inspect the circular mass directly.

## Individual variation

Each member has seeded colour variation, dust coverage, grain scale and grain strength. Six earth-tone palettes are mixed through the three species. These are procedural materials, not recovered photographic textures. The source scans and animation files are unchanged.

## Crowd rendering

New crowd-only meshes retain the original skeleton/skin bindings while reducing approximately 300,000–400,000 source triangles per model to approximately 9,500–12,300. Original models are not overwritten.

The balanced swarm settings use FSR upscaling at 75% internal resolution, automatic mesh detail, two directional shadow cascades, and ordinary distance fog. Volumetric fog is off in this scene for performance; the existing scenes are unchanged. Animation sampling is reduced at distance and outside the camera view. Set `render_scale` to 1.0 and `volumetric_fog` to true in `swarm_config.json` for the heavier rendering options. Population, cycle durations, cadence, palettes and other settings are in the same file.

A short 1280×720 Vulkan Forward+ test on the RTX 3050 Laptop averaged approximately **30 FPS** with the balanced settings. Earlier heavier rendering configurations were substantially slower. This is a prototype measurement, not an hour-long guarantee or a claim that larger populations are ready.

## Validation

The deterministic 192-second movement test verified 99 members, exactly 33 of each species, 99 distinct orbit values, nonnegative travel, unchanged original ring values and repeatable phasing. Coherence was approximately 0.006 initially, 1.000 in the first synchronization hold, 0.003 after renewed delay, 0.980 in the second hold and 0.013 after the next separation. These are gait-phase measurements; differences between the source clips remain visible.

Rendered checks covered low, oblique and overhead views and sampled synchronized/delayed poses. Existing shutdown resource warnings from the world remain. No script or shader runtime errors occurred in the completed rendered checks.

This new folder depends on the already installed `dove_man/horde_variant` character loader and source assets. It adds a new scene and does not overwrite the original world, the long-eared-only variant or the wandering-band variant. Blender was not used.
