# TAGANT: arrivals from the horizon

Open `res://dove_man/horizon_variant/dove_man_horizon.tscn` and press F6.

The existing 99 circling figures and three species-pure flocks of 33 remain. Three more groups of 33 emerge from the fog every 12 seconds, up to 30 waves: 2,970 newcomers plus the initial 198, for 3,168 figures. Each incoming group contains only Myna, long-eared humanoids, or hyena/camel humanoids. Groups approach from three horizon regions, then circulate counter-clockwise around Dove Man at different radii. Their spacing responds locally to other arrivals and fixed scenery.

Animation clips are preserved. Nearby figures retain their skeletons and original selected clips. The added population uses 32 sampled poses of the same existing walk, interpolated on the GPU. Reduced mesh copies are used for distant figures. No source rig, source model or animation file was modified. Travel distance drives gait phase. GPU copies reuse the original walking motion rather than a newly generated animation.

Godzilla's actual crossing route opens a 144-metre corridor. Figures move aside while it is active, then gradually return to circulation. G triggers the existing Godzilla crossing; its animation is unchanged. H cycles close flock, wide and overhead cameras, then the original director. D shows population and corridor state.

The GPU arrival figures use walking only, without full per-agent skeletons, falls or score-recorder entries. The detailed figures retain the existing behavior available in their prior variants. The circling figures temporarily leave their personal routes to yield to Godzilla, then return. This is an artistic crowd prototype, not a calibrated Hajj or crowd-safety simulation.

Dependencies: the project's original Dove Man world plus the installed horde_variant, swarm_variant and flock_variant folders. Normal startup is intentionally gradual; reaching a fully populated circulation takes several minutes because figures physically walk in from the horizon.

Validation: 3,168-member capacity and species-pure cohorts checked; Godzilla clearance tested for both arriving figures and the retained circular procession. GPU pose textures contain 32 finite, visibly different samples per original walk. Short rendered stress preview: approximately 18 FPS average at 1280x720 on the RTX 3050 Laptop 6GB; occasional slow frames remain. Screenshots show an accelerated full-population preview, not the normal opening. Existing world shutdown resource-leak warnings remain.

Implementation uses loaded-model caching to avoid repeatedly loading the same source scenes, aggregate local density for distant spacing, persistent terrain samples, and two movement updates per second for the large arrival population. GPU walking and forward motion continue between movement updates. The detailed figures retain their faster pose updates.
