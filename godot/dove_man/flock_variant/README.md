# TAGANT: organic flocks

Open `res://dove_man/flock_variant/dove_man_flocks.tscn` and press F6.

198 figures total: the existing 99 personal circular routes remain, plus three surrounding flocks of 33. Each flock contains only one scanned species: Myna, long-eared humanoid, or hyena/camel humanoid. Individual earth tones and dusty surface variation remain.

The flocks use separation, local cohesion, velocity alignment, gentle meandering and temporary front-member leadership. Leaders change approximately every 26–34 seconds. Positions are not fixed formation slots; the bodies deform as members respond to companions and scenery. Actual distance travelled drives the unchanged walking clips.

H cycles a close flock view, a wide view of the procession and surrounding flocks, overhead, then the original camera director. D toggles diagnostics. The original 96-second delay/synchronization cycle remains on the circular procession. Added flocks walk at their actual individual speeds; their gait is not forced into the procession's phase cycle.

Dependencies: the installed `dove_man/swarm_variant` and `dove_man/horde_variant` folders. Original scenes and models are unchanged; no Blender use. The optimized skinned derivatives from the swarm variant are reused. This additive scene is separate from the existing swarm scene.

The added flocks have their own movement controller. The original fall/burial and score-recorder logic continues to track the 99 circling members; flock members are not yet part of those event systems.

## Reference direction
The JASSS review (https://www.jasss.org/22/2/9.html) distinguishes individual agent/social-force interactions from aggregate crowd flow. This implementation uses local steering and group cohesion; it is an artistic prototype, not a calibrated social-force/Hajj model.
The supplied Figure 7 (https://www.researchgate.net/figure/Simulation-of-the-Hajj-pilgrimage-a-3D-visualization-of-the-simulated-scenario-b_fig7_327027693) is from *Crowd Simulation Incorporating Thermal Environments and Responsive Behaviors*. It concerns a crowded junction and stopping due to heat, rather than a Tawaf circulation model. Heat-responsive speed, density feedback and propagated stopping waves are possible subsequent extensions; they are not implemented here.
