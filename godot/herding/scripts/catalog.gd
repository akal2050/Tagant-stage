class_name HCatalog
## TAGANT Herding Karaoke - the places of the Ait Wadu valley and the herding tunes sung at each.
## Places are spots in the valley (no bodies on them): the camera goes there, its tunes fill the song menu.
## Songs: C:\Users\azoor\Desktop\wind thieves archives (archive recordings), converted to songs/*.ogg.

const BODIES := {}

const VOICES := {
	"pipe_tune_1": "Shepherd's pipe tune (I)",
	"pipe_tune_2": "Shepherd's pipe tune (II)",
	"tawat": "Tawat (fragment)",
	"t2090r12": "Archive T2090 R12",
	"t2095r01": "Archive T2095 R01",
	"goatherd_1": "Goatherd tune 1",
	"flock_into_field": "Putting the flock into the field",
	"scatter_flock": "Scattering the flock",
	"t2095r12": "Archive T2095 R12",
	"sheep_to_hills": "Sending the sheep to the hills",
	"sheep_down": "Bringing the sheep down from the hills",
	"t2095r17": "Archive T2095 R17",
	"wolves_foxes": "Shouts to drive away wolves and foxes",
	# synthesised winds (Pd: REAPER Media\TAGANT_pd\synth_animals\winds)
	"wind_saba": "Saba - east wind of dawn",
	"wind_harmattan": "Harmattan - cool dusty north-east",
	"wind_chergui": "Chergui - hot east wind of Morocco",
	"wind_khamsin": "Khamsin - the fifty days",
	"wind_simoom": "Simoom - the poison wind",
	"wind_shamal": "Shamal - north-west of the Gulf",
	"wind_dabur": "Dabur - the howling west wind",
	"wind_ajaj": "Ajaj - the whirling dust",
	"wind_haboob": "Haboob - the wall of dust",
}

# slot = a place in the valley (valley.gd knows where and how the camera looks at it)
# Three sections, AZ OOR's names:
#   AIT WADU - the people of the wind: calling the animals (social life, polyglossia)
#   ADU      - wind: listening to the winds (synthesised, each in its own place)
#   AGHANIM  - tuning the wind: the shepherd's pipe and the flock tunes
const SLOTS_AITWADU := [
	{"id": "donkey", "slot": "donkey", "options": [
		{"body": "", "name": "Donkey mountain", "desc": "the mountain that is a donkey, to the north", "voices": ["wolves_foxes"]}]},
	{"id": "river", "slot": "river", "options": [
		{"body": "", "name": "The river", "desc": "the river of the Ait Wadu valley", "voices": ["t2090r12", "t2095r01"]}]},
	{"id": "field", "slot": "field", "options": [
		{"body": "", "name": "The poppy field", "desc": "the poppies west of the river", "voices": ["t2095r12"]}]},
	{"id": "sheep", "slot": "sheep", "options": [
		{"body": "", "name": "Sheep mountain", "desc": "the mountain that is a sheep, to the south", "voices": ["t2095r17"]}]},
]
const WINDS := ["wind_saba", "wind_harmattan", "wind_chergui", "wind_khamsin", "wind_simoom", "wind_shamal", "wind_dabur", "wind_ajaj", "wind_haboob"]
const SLOTS_ADU := [
	{"id": "w_saba", "slot": "sky_saba", "options": [
		{"body": "", "name": "Saba", "desc": "east wind of dawn - a tent in a Hijaz wadi", "voices": ["wind_saba"]}]},
	{"id": "w_harmattan", "slot": "sky_harmattan", "options": [
		{"body": "", "name": "Harmattan", "desc": "cool dusty north-east - the open Sahel in haze", "voices": ["wind_harmattan"]}]},
	{"id": "w_chergui", "slot": "sky_chergui", "options": [
		{"body": "", "name": "Chergui", "desc": "hot east wind - between the walls of a Draa kasbah", "voices": ["wind_chergui"]}]},
	{"id": "w_khamsin", "slot": "sky_khamsin", "options": [
		{"body": "", "name": "Khamsin", "desc": "the fifty days - the Nile valley escarpment", "voices": ["wind_khamsin"]}]},
	{"id": "w_simoom", "slot": "sky_simoom", "options": [
		{"body": "", "name": "Simoom", "desc": "the poison wind - a narrow sandstone gorge", "voices": ["wind_simoom"]}]},
	{"id": "w_shamal", "slot": "sky_shamal", "options": [
		{"body": "", "name": "Shamal", "desc": "north-west of the Gulf - open water, a harbour", "voices": ["wind_shamal"]}]},
	{"id": "w_dabur", "slot": "sky_dabur", "options": [
		{"body": "", "name": "Dabur", "desc": "the howling west wind - the rock canyon of Aad", "voices": ["wind_dabur"]}]},
	{"id": "w_ajaj", "slot": "sky_ajaj", "options": [
		{"body": "", "name": "Ajaj", "desc": "the whirling dust - the palm grove of an oasis", "voices": ["wind_ajaj"]}]},
	{"id": "w_haboob", "slot": "sky_haboob", "options": [
		{"body": "", "name": "Haboob", "desc": "the wall of dust - inside it, Khartoum plain", "voices": ["wind_haboob"]}]},
]
const SLOTS_AGHANIM := [
	{"id": "palm", "slot": "palm", "options": [
		{"body": "", "name": "The great palm", "desc": "the giant date palm on the river bank", "voices": ["pipe_tune_1", "pipe_tune_2", "tawat"]}]},
	{"id": "field", "slot": "field", "options": [
		{"body": "", "name": "The poppy field", "desc": "the poppies west of the river", "voices": ["flock_into_field", "scatter_flock"]}]},
	{"id": "sheep", "slot": "sheep", "options": [
		{"body": "", "name": "Sheep mountain", "desc": "the mountain that is a sheep, to the south", "voices": ["sheep_to_hills", "sheep_down"]}]},
	{"id": "river", "slot": "river", "options": [
		{"body": "", "name": "The river", "desc": "the river of the Ait Wadu valley", "voices": ["goatherd_1"]}]},
]
const SECTIONS := {"aitwadu": SLOTS_AITWADU, "adu": SLOTS_ADU, "aghanim": SLOTS_AGHANIM}
const SECTION_ORDER := ["aitwadu", "adu", "aghanim"]
const SLOTS_BESTIARY := SLOTS_ADU          # kept for older code paths (section tabs are shown when there is more than one)

static var section := "aitwadu"
static var SLOTS: Array = SLOTS_AITWADU


static func set_section(sec: String) -> void:
	section = sec if SECTIONS.has(sec) else "aitwadu"
	SLOTS = SECTIONS[section]


## every voice used anywhere in the current section
static func section_voices() -> Array:
	var out: Array = []
	for s in SLOTS:
		for o in s.options:
			for v in o.voices:
				if not out.has(v):
					out.append(v)
	return out


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
	if section == "adu":
		return out                       # each wind is a character with its own voice
	for v in section_voices():           # each section offers only its own recordings
		if not out.has(v):
			out.append(v)
	return out
