# Dove Man — rigged pilgrim scene

This adds an alternative Dove Man scene using your long-eared custom scanned character from Basic Locomotion Pack (1).zip.

Run: res://dove_man/pilgrim_variant/dove_man_rigged.tscn with F6 in the existing tagant-00 project.

The variant inherits dove_man_world.gd. Existing world scripts, scene files, configuration and animation assets are not overwritten. All fourteen pilgrims retain their original heights, individual circular paths, steering, pauses, impact reactions and burial timing. Each walk advances from actual distance travelled using the clip's measured root displacement. Horizontal animation root travel is removed from runtime animation copies to avoid double movement.

The mannequin's procedural shamble is replaced by the skeletal walk/idle. The original rigid fall/recovery envelope remains; this does not add a new skeletal fall/get-up animation. A matte brown material makes the untextured scan readable. Foot-bone alignment limits vertical floating; it is not terrain foot IK.

D: debug display. C: next camera. G: Godzilla crossing. V: car drop.

Original scene for comparison: res://dove_man/dove_man.tscn.

No Blender use, female model or changes to other characters' animation.
