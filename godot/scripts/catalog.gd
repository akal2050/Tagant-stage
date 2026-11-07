class_name Catalog
## The cast of the karaoke stage.
## Seven rammed-earth blocks (Gallery 3 cylinders, small to large) + the lake, the air above it, the gardens.
## Every place offers several creatures (TAGANT bodies) and every creature several voices
## (renders of the Pd patches in REAPER Media\TAGANT_pd\synth_animals, as ogg in res://songs).
## A creature's own voices come first in the voice list; every other voice can also be chosen (hybrids).

# ------------------------------------------------------------------ bodies
const BODIES := {
	"myna_hybrid": {"model": "res://models/myna_hybrid.glb", "height": 2.3, "material": "hybrid",
		"desc": "myna-headed hybrid from the Dove Man horde",
		"anims": {"idle": "Idle_Subtle", "sing": "Idle_Talking", "listen": "Idle Listening",
			"good": "Yes", "great": "Cheering_Two_Hands", "confused": "Confused", "dance": "Dance_Simple"}},
	"dove": {"model": "res://models/dove.glb", "height": 1.0, "hover": 1.2, "yaw": 180.0, "material": "keep",
		"desc": "flying pigeon of the Dove Man world", "anims": {"idle": "BirdRig|Flapping", "good": "BirdRig|Gliding"}},
	"dove_standing": {"model": "res://models/dove.glb", "height": 0.55, "material": "keep",
		"desc": "the same pigeon, standing", "anims": {"idle": "BirdRig|Standing Idle", "good": "BirdRig|Takeoff"}},
	"camel": {"model": "res://models/camel.glb", "height": 2.2, "material": "keep",
		"desc": "rigged camel of the Dove Man world", "anims": {"idle": "Idle", "sing": "Idle", "good": "Pace"}},
	"camel_v2": {"model": "res://models/camel_v2.glb", "height": 2.2, "yaw": 180.0, "material": "keep",
		"desc": "textured walking camel of the Dove Man world", "anims": {"idle": "Idle_01", "sing": "Idle_02", "good": "Walk"}},
	"goat_ait_wadu": {"model": "res://models/goat.glb", "height": 1.15, "yaw": 45.0, "material": "earth",
		"desc": "goat of the Ait Wadu halqa", "anims": {}},
	"hyena_spotted": {"model": "res://models/hyena.glb", "height": 1.05, "material": "keep",
		"desc": "spotted hyena of the Ait Wadu world", "anims": {}},
	"bear": {"model": "res://models/bear.glb", "height": 1.9, "material": "keep",
		"desc": "the dancing bear of the Ait Wadu halqa", "anims": {}},
	"salt_fennec": {"model": "res://models/salt_fennec.glb", "height": 0.9, "material": "salt",
		"desc": "salt fennec of the City of Salt and Blood", "anims": {}},
	"salt_horse": {"model": "res://models/salt_horse.glb", "height": 1.7, "material": "salt",
		"desc": "salt Barb horse of the City of Salt and Blood", "anims": {}},
	"salt_goat": {"model": "res://models/salt_goat.glb", "height": 1.1, "material": "salt",
		"desc": "salt goat of the City of Salt and Blood", "anims": {}},
	"salt_striped_hyena": {"model": "res://models/salt_striped_hyena.glb", "height": 1.0, "material": "salt",
		"desc": "salt striped hyena of the City of Salt and Blood", "anims": {}},
	"salt_oryx": {"model": "res://models/salt_oryx.glb", "height": 1.6, "material": "salt",
		"desc": "salt oryx of the City of Salt and Blood", "anims": {}},
	"salt_vulture": {"model": "res://models/salt_griffon_vulture.glb", "height": 1.1, "material": "salt",
		"desc": "salt griffon vulture of the City of Salt and Blood", "anims": {}},
	"salt_cobra": {"model": "res://models/salt_cobra.glb", "height": 1.0, "material": "salt",
		"desc": "salt cobra of the City of Salt and Blood", "anims": {}},
	"chimera_f01": {"model": "res://models/chimera_f01.glb", "height": 2.4, "hover": 4.2, "yaw": 180.0, "material": "keep",
		"desc": "Chimera family 01, The Eye and the Needle", "anims": {}},
	"chimera_f02": {"model": "res://models/chimera_f02.glb", "height": 1.1, "hover": 0.6, "material": "keep",
		"desc": "Chimera family 02, The Eye and the Needle", "anims": {}},
	"chimera_f03": {"model": "res://models/chimera_f03.glb", "height": 2.0, "yaw": 180.0, "material": "keep",
		"desc": "Chimera family 03, The Eye and the Needle", "anims": {}},
	"chimera_f04": {"model": "res://models/chimera_f04.glb", "height": 2.2, "yaw": 135.0, "material": "keep",
		"desc": "Chimera family 04, The Eye and the Needle", "anims": {}},
	"chimera_f05": {"model": "res://models/chimera_f05.glb", "height": 2.4, "yaw": 120.0, "material": "keep",
		"desc": "Chimera family 05, The Eye and the Needle", "anims": {}},
	"stork_flock": {"model": "res://models/storks.glb", "height": 1.3, "span": 2.4, "material": "keep",
		"desc": "the storks of the Ait Wadu village", "anims": {}},
	"drummer": {"model": "res://models/drummer.glb", "height": 1.8, "material": "keep",
		"desc": "the drummer of the Ait Wadu halqa", "anims": {}},
	"rock_camel": {"model": "res://models/rock_camel.glb", "height": 2.3, "material": "keep",
		"desc": "rock camel of the Dove Man world", "anims": {}},
	"walker_001": {"model": "res://models/bestiary/walker_001.glb", "height": 1.6, "material": "keep",
		"desc": "pentaradial walker 001, TAGANT Bestiary Lab", "anims": {"idle": "idle", "sing": "move"}},
	"walker_002": {"model": "res://models/bestiary/walker_002.glb", "height": 1.6, "material": "keep",
		"desc": "pentaradial walker 002, TAGANT Bestiary Lab", "anims": {"idle": "idle", "sing": "move"}},
	"walker_004": {"model": "res://models/bestiary/walker_004.glb", "height": 1.6, "material": "keep",
		"desc": "pentaradial walker 004, TAGANT Bestiary Lab", "anims": {"idle": "idle", "sing": "move"}},
	"walker_005": {"model": "res://models/bestiary/walker_005.glb", "height": 1.6, "material": "keep",
		"desc": "pentaradial walker 005, TAGANT Bestiary Lab", "anims": {"idle": "idle", "sing": "move"}},
	"walker_006": {"model": "res://models/bestiary/walker_006.glb", "height": 1.6, "material": "keep",
		"desc": "pentaradial walker 006, TAGANT Bestiary Lab", "anims": {"idle": "idle", "sing": "move"}},
	"walker_007": {"model": "res://models/bestiary/walker_007.glb", "height": 1.6, "material": "keep",
		"desc": "pentaradial walker 007, TAGANT Bestiary Lab", "anims": {"idle": "idle", "sing": "move"}},
	"serpent_001": {"model": "res://models/bestiary/serpent_001.glb", "height": 1.3, "span": 2.6, "material": "keep",
		"desc": "serpent with seven wing pairs 001, TAGANT Bestiary Lab", "anims": {"idle": "idle", "sing": "move"}},
	"serpent_002": {"model": "res://models/bestiary/serpent_002.glb", "height": 1.3, "span": 2.6, "material": "keep",
		"desc": "serpent with seven wing pairs 002, TAGANT Bestiary Lab", "anims": {"idle": "idle", "sing": "move"}},
	"serpent_003": {"model": "res://models/bestiary/serpent_003.glb", "height": 1.3, "span": 2.6, "material": "keep",
		"desc": "serpent with seven wing pairs 003, TAGANT Bestiary Lab", "anims": {"idle": "idle", "sing": "move"}},
	"serpent_004": {"model": "res://models/bestiary/serpent_004.glb", "height": 1.3, "span": 2.6, "material": "keep",
		"desc": "serpent with seven wing pairs 004, TAGANT Bestiary Lab", "anims": {"idle": "idle", "sing": "move"}},
	"serpent_005": {"model": "res://models/bestiary/serpent_005.glb", "height": 1.3, "span": 2.6, "material": "keep",
		"desc": "serpent with seven wing pairs 005, TAGANT Bestiary Lab", "anims": {"idle": "idle", "sing": "move"}},
	"serpent_006": {"model": "res://models/bestiary/serpent_006.glb", "height": 1.3, "span": 2.6, "material": "keep",
		"desc": "serpent with seven wing pairs 006, TAGANT Bestiary Lab", "anims": {"idle": "idle", "sing": "move"}},
	"serpent_007": {"model": "res://models/bestiary/serpent_007.glb", "height": 1.3, "span": 2.6, "material": "keep",
		"desc": "serpent with seven wing pairs 007, TAGANT Bestiary Lab", "anims": {"idle": "idle", "sing": "move"}},
	"drifter_001": {"model": "res://models/bestiary/drifter_001.glb", "height": 1.6, "hover": 0.9, "material": "keep",
		"desc": "wind drifter 001, TAGANT Bestiary Lab", "anims": {"idle": "idle", "sing": "move"}},
	"drifter_002": {"model": "res://models/bestiary/drifter_002.glb", "height": 1.6, "hover": 0.9, "material": "keep",
		"desc": "wind drifter 002, TAGANT Bestiary Lab", "anims": {"idle": "idle", "sing": "move"}},
	"drifter_003": {"model": "res://models/bestiary/drifter_003.glb", "height": 1.6, "hover": 0.9, "material": "keep",
		"desc": "wind drifter 003, TAGANT Bestiary Lab", "anims": {"idle": "idle", "sing": "move"}},
	"drifter_004": {"model": "res://models/bestiary/drifter_004.glb", "height": 1.6, "hover": 0.9, "material": "keep",
		"desc": "wind drifter 004, TAGANT Bestiary Lab", "anims": {"idle": "idle", "sing": "move"}},
	"drifter_005": {"model": "res://models/bestiary/drifter_005.glb", "height": 1.6, "hover": 0.9, "material": "keep",
		"desc": "wind drifter 005, TAGANT Bestiary Lab", "anims": {"idle": "idle", "sing": "move"}},
	"drifter_006": {"model": "res://models/bestiary/drifter_006.glb", "height": 1.6, "hover": 0.9, "material": "keep",
		"desc": "wind drifter 006, TAGANT Bestiary Lab", "anims": {"idle": "idle", "sing": "move"}},
	"drifter_007": {"model": "res://models/bestiary/drifter_007.glb", "height": 1.6, "hover": 0.9, "material": "keep",
		"desc": "wind drifter 007, TAGANT Bestiary Lab", "anims": {"idle": "idle", "sing": "move"}}
}

# ------------------------------------------------------------------ voices (Pd renders)
const VOICES := {
	"myna_flock_01": "Myna flock 01",
	"myna_clean_ab": "Myna, one bird (clean A/B)",
	"hybrid_human_animal_01": "Hybrid human-animal 01",
	"dove_flock_01": "Dove flock 01",
	"camel_flock_05": "Camel flock 05",
	"camel_choir_04": "Camel choir 04",
	"camel_one_call": "Camel, one call",
	"goat_herd_01": "Goat herd 01 (bells)",
	"hyena_02": "Hyena 02",
	"hyena_01": "Hyena 01",
	"jackal_night_01": "Jackal night 01",
	"donkey_valley_01": "Donkey valley 01",
	"imaginary_species_01": "Imaginary species 01",
	"frogs_01": "Frogs 01",
	"cicadas_crickets_01": "Cicadas & crickets day cycle",
}

# ------------------------------------------------------------------ places
# slot: 0..6 = Gallery 3 cylinders (small -> large); "above" over the lake; "pool" the lake; "grass" the gardens
# Two sections share the stage: ANIMALS (real animals only) and BESTIARY (imaginary / speculative creatures).
# Voices that are borrowed from another animal stay listed until each creature has its own Pd render.
const SLOTS_ANIMALS := [
	{"id": "b1", "slot": 0, "options": [
		{"body": "dove", "name": "Dove", "voices": ["dove_flock_01"]},
		{"body": "dove_standing", "name": "Dove (standing)", "voices": ["dove_flock_01"]},
		{"body": "stork_flock", "name": "Storks (Ait Wadu)", "voices": ["dove_flock_01"]},
		{"body": "salt_vulture", "name": "Vulture (salt)", "voices": ["dove_flock_01"]}]},
	{"id": "b2", "slot": 1, "options": [
		{"body": "salt_fennec", "name": "Jackal (salt fennec)", "voices": ["jackal_night_01"]},
		{"body": "salt_cobra", "name": "Cobra (salt)", "voices": ["jackal_night_01"]}]},
	{"id": "b3", "slot": 2, "options": [
		{"body": "goat_ait_wadu", "name": "Goat (Ait Wadu)", "voices": ["goat_herd_01"]},
		{"body": "salt_goat", "name": "Goat (salt)", "voices": ["goat_herd_01"]},
		{"body": "salt_oryx", "name": "Oryx (salt)", "voices": ["goat_herd_01"]}]},
	{"id": "b4", "slot": 3, "options": [
		{"body": "hyena_spotted", "name": "Hyena (spotted)", "voices": ["hyena_02", "hyena_01"]},
		{"body": "salt_striped_hyena", "name": "Striped hyena (salt)", "voices": ["hyena_01", "hyena_02"]}]},
	{"id": "b5", "slot": 4, "options": [
		{"body": "bear", "name": "Bear (Ait Wadu)", "voices": ["hybrid_human_animal_01"]}]},
	{"id": "b6", "slot": 5, "options": [
		{"body": "salt_horse", "name": "Horse (salt)", "voices": ["donkey_valley_01"]}]},
	{"id": "b7", "slot": 6, "options": [
		{"body": "camel", "name": "Camel", "voices": ["camel_flock_05", "camel_choir_04", "camel_one_call"]},
		{"body": "camel_v2", "name": "Camel (walking)", "voices": ["camel_one_call", "camel_flock_05"]},
		{"body": "rock_camel", "name": "Rock camel (Dove Man)", "voices": ["camel_choir_04", "camel_flock_05"]}]},
	{"id": "frogs", "slot": "pool", "height": 2.5, "options": [
		{"body": "", "name": "Frogs", "desc": "voices in the oil lake", "voices": ["frogs_01"]}]},
	{"id": "cicadas", "slot": "grass", "height": 5.0, "options": [
		{"body": "", "name": "Cicadas & crickets", "desc": "voices in the Qur'anic gardens beyond the seventh circle", "voices": ["cicadas_crickets_01"]}]},
]

const _IMAG := ["imaginary_species_01", "hybrid_human_animal_01"]
const SLOTS_BESTIARY := [
	{"id": "x1", "slot": 0, "options": [
		{"body": "drifter_001", "name": "Wind drifter 1", "voices": _IMAG},
		{"body": "drifter_002", "name": "Wind drifter 2", "voices": _IMAG},
		{"body": "drifter_003", "name": "Wind drifter 3", "voices": _IMAG},
		{"body": "drifter_004", "name": "Wind drifter 4", "voices": _IMAG}]},
	{"id": "x2", "slot": 1, "options": [
		{"body": "serpent_001", "name": "Winged serpent 1", "voices": _IMAG},
		{"body": "serpent_002", "name": "Winged serpent 2", "voices": _IMAG},
		{"body": "serpent_003", "name": "Winged serpent 3", "voices": _IMAG},
		{"body": "serpent_004", "name": "Winged serpent 4", "voices": _IMAG}]},
	{"id": "x3", "slot": 2, "options": [
		{"body": "walker_001", "name": "Pentaradial walker 1", "voices": _IMAG},
		{"body": "walker_002", "name": "Pentaradial walker 2", "voices": _IMAG},
		{"body": "walker_004", "name": "Pentaradial walker 4", "voices": _IMAG}]},
	{"id": "x4", "slot": 3, "options": [
		{"body": "chimera_f02", "name": "Chimera 02", "voices": _IMAG},
		{"body": "chimera_f03", "name": "Chimera 03", "voices": _IMAG}]},
	{"id": "x5", "slot": 4, "options": [
		{"body": "myna_hybrid", "name": "Myna (hybrid)", "voices": ["myna_flock_01", "myna_clean_ab", "hybrid_human_animal_01"]}]},
	{"id": "x6", "slot": 5, "options": [
		{"body": "walker_005", "name": "Pentaradial walker 5", "voices": _IMAG},
		{"body": "walker_006", "name": "Pentaradial walker 6", "voices": _IMAG},
		{"body": "walker_007", "name": "Pentaradial walker 7", "voices": _IMAG}]},
	{"id": "x7", "slot": 6, "options": [
		{"body": "chimera_f04", "name": "Chimera 04", "voices": _IMAG},
		{"body": "chimera_f05", "name": "Chimera 05", "voices": _IMAG}]},
	{"id": "above", "slot": "above", "options": [
		{"body": "chimera_f01", "name": "Imaginary species", "voices": _IMAG},
		{"body": "drifter_005", "name": "Wind drifter 5", "voices": _IMAG},
		{"body": "drifter_006", "name": "Wind drifter 6", "voices": _IMAG},
		{"body": "drifter_007", "name": "Wind drifter 7", "voices": _IMAG},
		{"body": "serpent_005", "name": "Winged serpent 5", "voices": _IMAG},
		{"body": "serpent_006", "name": "Winged serpent 6", "voices": _IMAG},
		{"body": "serpent_007", "name": "Winged serpent 7", "voices": _IMAG}]},
	{"id": "frogs", "slot": "pool", "height": 2.5, "options": [
		{"body": "", "name": "Frogs", "desc": "voices in the oil lake", "voices": ["frogs_01"]}]},
	{"id": "cicadas", "slot": "grass", "height": 5.0, "options": [
		{"body": "", "name": "Cicadas & crickets", "desc": "voices in the Qur'anic gardens beyond the seventh circle", "voices": ["cicadas_crickets_01"]}]},
]

static var section := "animals"
static var SLOTS: Array = SLOTS_ANIMALS


static func set_section(sec: String) -> void:
	section = sec
	SLOTS = SLOTS_BESTIARY if sec == "bestiary" else SLOTS_ANIMALS


static var choice := {}      # slot id -> chosen option index


static func slot(id: String) -> Dictionary:
	for s in SLOTS:
		if s.id == id:
			return s
	return {}


## Everything needed to build and describe what stands on a place right now.
static func by_id(id: String, opt: int = -1) -> Dictionary:
	var s := slot(id)
	if s.is_empty():
		return {}
	var k: int = opt if opt >= 0 else int(choice.get(id, 0))
	k = clampi(k, 0, s.options.size() - 1)
	var o: Dictionary = s.options[k]
	var info := {"id": id, "slot": s.slot, "name": o.name, "songs": o.voices, "option": k,
		"model": "", "height": s.get("height", 1.2), "hover": 0.0, "material": "keep", "anims": {}, "yaw": 0.0}
	if o.body != "":
		var b: Dictionary = BODIES[o.body]
		info.merge(b, true)
		info["body"] = b.get("desc", "")
	else:
		info["body"] = o.get("desc", "")
	info["name"] = o.name
	info["songs"] = o.voices
	return info


## The creature's own voices first, then every other voice.
static func voice_list(id: String) -> Array:
	var own: Array = by_id(id).songs.duplicate()
	var out: Array = own.duplicate()
	for v in VOICES:
		if own.has(v):
			continue
		if section == "animals" and _IMAG.has(v):
			continue                      # the real-animal section only offers real-animal voices
		out.append(v)
	return out
