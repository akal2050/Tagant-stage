# TAGANT — mixed hybrid population

Run `res://dove_man/horde_variant/dove_man_horde.tscn` with F6 in the existing tagant-00 Godot project.

This additive scene contains thirty hybrids: fourteen pilgrims on their existing individual circular paths, plus sixteen wanderers in three mixed bands. The species are the user's Myna, long-eared figure, and hyena/camel hybrid. The checked Dove Man exports are static and are not converted into animated characters.

The circling pilgrims retain their original heights, personal routes, pauses, steering, impacts and burial. Their mannequin motion is replaced by compatible skeletal clips. The new bands walk, occasionally run, rest and use supported idle poses. Nearby car impacts and Godzilla footfalls trigger fleeing or freezing; after the alarm passes, they move toward their band again. Separation and the existing obstacle system help them avoid other bodies and wreckage. These are authored behaviours, not an AI dialogue or social simulation.

**H** cycles views of the three wandering bands, then returns to the cinematic director. **D**, **C**, **G**, and **V** retain the existing debug, camera-cut, Godzilla and car-drop controls. The original scenes and the earlier long-eared-only variant remain available.

The shared procedural material adds mottled earth colours, surface grain, dust on upward-facing surfaces, and sand around the feet and lower legs. Four individual palettes retain variation. Dust increases over the world's hour. This is generated shading; it does not recover missing photographic scan textures.

Animation libraries are shared by species. Nearby animation is sampled at 30 Hz, then 20 Hz and 12 Hz farther away. Walk/run phases follow distance travelled; transitions blend over 0.32 seconds. The native Myna clips are in place, so their stride is estimated from height. FBX strides use measured root travel when present. A rendered-mesh calibration handles export offsets; subsequent foot-bone alignment is not terrain foot IK.

Myna uses seven embedded clips: walking, sprinting, idle, folded arms, crouching, bowing and talking. The other two rigs use five tested clips each: walking, running, idle, a hunched idle and a scratching idle. They retain their original motions. The running and expressive clips are from the existing compatible Mixamo packs. Unsupported poses fall back to idle.

Change population, seed, band radii, speeds, timing and colours in `horde_config.json`. The first configuration is deliberately thirty creatures. Larger counts need fresh performance checks.

Validation: all seventeen selected clips matched their skeletons; ground-baseline samples, unchanged pilgrim ring values, all three species in each band, fleeing/recovery and finite positions passed. The full world rendered the walk, run and rest views. A short warm test on the RTX 3050 Laptop at 1280×720 with Vulkan Forward+ averaged approximately 31–33 FPS across two short runs. This is not a complete hour-long performance guarantee. Existing world shutdown resource warnings remain; no script or shader errors occurred in the successful checks.

No Blender session was used. No female model was included. Installation adds only `dove_man/horde_variant` and does not overwrite the original world or earlier variant.

