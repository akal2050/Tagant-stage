# TAGANT: water and petroleum titan

Open `res://dove_man/water_titan/water_preview.tscn` and press F6 for the lightweight material preview. Keys 1, 2 and 3 show front, back and close back views.

Open `res://dove_man/water_titan/dove_man_water.tscn` for the full desert with the existing horizon crowd. G triggers Godzilla using the existing crossing system. H retains the crowd inspection cameras.

This version replaces only Godzilla's displayed materials and adds 28 floating petrol blobs. Its source model, skin weights, animation tracks, walking clip and stride-controlled world movement are preserved.

The water shader has moving surface noise, small ripples, shallow/deep water colour, screen-space refraction, glossy petroleum patches with subtle interference colours, and crest foam concentrated on upward and dorsal surfaces. The floating oil blobs use selected original skinned surface vertices, including their original bone weights; they follow the existing animation and bob/drift near those surface points.

This is a shader-driven water appearance, not a volumetric fluid solver. Oil blobs are visual surface additions; they do not simulate oil/water chemistry or liquid collisions. The lightweight preview uses simple studio/desert lighting; colours differ under the full world's warm sky and fog. Source files and prior crowd scenes remain available.

Validation: isolated front/back renders and full desert render passed in Godot 4.6.3 Vulkan Forward+, with three skinned water surfaces and 28 finite moving anchors. The integrated scene retained the original walk and crowd system. Existing base-world resource warnings still appear at shutdown.

The full scene depends on the project's existing horizon_variant, flock_variant, swarm_variant and horde_variant folders. The lightweight preview requires only the original Godzilla asset and this water_titan folder.

Clarity revision: water transmission increased from 0.22 to 0.74, with stronger moving screen-space distortion, less absorption, reduced water roughness, and backlighting. Oil and foam retain opacity; Fresnel preserves reflective edges. Transmitted background colour is composed as radiance instead of being lit again as base colour. This provides a clearer refractive appearance without editing the original animation. It does not trace off-screen geometry or project physically refracted sunlight/caustics onto the sand.
