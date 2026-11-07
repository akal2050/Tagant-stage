class_name Tr
## English / Arabic interface. Arabic is right-to-left (Godot shapes it with its advanced text server).
## Fonts: Megrim (Latin titles), Tektur (Latin text), Handjet (Arabic) - all SIL Open Font License, in res://fonts.

static var lang := "en"

const UI := {
	"title": ["TAGANT  ·  ANIMAL KARAOKE", "TAGANT  ·  كاريوكي الحيوانات"],
	"Listen": ["Listen", "استمع"],
	"Sing": ["Sing", "غنِّ"],
	"Rehearse": ["Rehearse", "تمرَّن"],
	"Dialogue": ["Dialogue", "حوار"],
	"sec_animals": ["ANIMALS", "الحيوانات"],
	"sec_bestiary": ["BESTIARY", "الكائنات المتخيَّلة"],
	"play": ["▶  Play", "▶  تشغيل"],
	"stop": ["■  Stop", "■  إيقاف"],
	"fold": ["Fold to my voice", "على مقاس صوتي"],
	"prev_phrase": ["◀ phrase", "◀ مقطع"],
	"next_phrase": ["phrase ▶", "مقطع ▶"],
	"loop": ["Loop", "تكرار"],
	"speed": ["speed", "السرعة"],
	"rec": ["●  Record take", "●  سجِّل"],
	"rec_stop": ["■  Stop take", "■  أوقف التسجيل"],
	"hear": ["▷  Hear take", "▷  اسمع التسجيل"],
	"dlg_start": ["Start the dialogue", "ابدأ الحوار"],
	"dlg_stop": ["Stop the dialogue", "أوقف الحوار"],
	"calls": ["%s calls…  (phrase %d)", "%s ينادي…  (المقطع %d)"],
	"your_turn": ["Your turn — answer the call", "دورك — أجب النداء"],
	"heard": ["%s heard you (%d%%) — it goes on", "%s سمعك (%d%%) — ويُكمل"],
	"almost": ["Almost (%d%%) — it calls again", "قريب (%d%%) — ينادي من جديد"],
	"not_yet": ["Not yet (%d%%) — listen once more", "ليس بعد (%d%%) — استمع مرة أخرى"],
	"no_phrases": ["This song has no phrases to answer.", "لا مقاطع في هذا الصوت للإجابة عنها."],
	"take_saved": ["take saved: ", "حُفظ التسجيل: "],
	"other_voices": ["other voices", "أصوات أخرى"],
	"mic": ["mic", "الميكروفون"],
	"lang_button": ["عربي", "EN"],
	"style_clay": ["style · clay", "الأسلوب · طين"],
	"style_salt": ["style · salt", "الأسلوب · ملح"],
	"style_oil": ["style · oil", "الأسلوب · نفط"],
	"style_bronze": ["style · bronze", "الأسلوب · برونز"],
	"style_natural": ["style · natural", "الأسلوب · طبيعي"],
	"style_sky": ["glaze · sky", "زليج · سماوي"],
	"style_majorelle": ["glaze · majorelle", "أزرق ماجوريل"],
	"style_lapis": ["glaze · lapis", "لازورد"],
	"style_indigo": ["glaze · indigo", "نيلي"],
}

const CREATURES := {
	"Dove": "حمامة", "Dove (standing)": "حمامة واقفة", "Vulture (salt)": "نسر من الملح",
	"Cobra (salt)": "كوبرا من الملح", "Jackal (salt fennec)": "ابن آوى (فنك من الملح)",
	"Fennec (salt)": "فنك من الملح", "Chimera 02": "خيميرا ٠٢", "Goat (Ait Wadu)": "عنزة آيت وادو",
	"Goat (salt)": "عنزة من الملح", "Oryx (salt)": "مها من الملح", "Hyena (spotted)": "ضبع مرقَّط",
	"Striped hyena (salt)": "ضبع مخطَّط من الملح", "Chimera 03": "خيميرا ٠٣", "Myna (hybrid)": "المينا الهجين",
	"Bear (Ait Wadu)": "دب آيت وادو", "Chimera 04": "خيميرا ٠٤", "Donkey (salt horse)": "حمار (حصان من الملح)", "Horse (salt)": "حصان من الملح",
	"Camel (walking)": "جمل يمشي", "Camel": "جمل", "Chimera 05": "خيميرا ٠٥",
	"Imaginary species": "كائنات متخيَّلة", "Storks (Ait Wadu)": "لقالق آيت وادو",
	"Drummer (Ait Wadu)": "طبّال آيت وادو", "Rock camel (Dove Man)": "جمل صخري (رجل الحمامة)", "Frogs": "ضفادع", "Cicadas & crickets": "زيز وصراصير الليل",
}

const VOICES := {
	"myna_flock_01": "سرب المينا ٠١", "myna_clean_ab": "مينا واحدة (نقي A/B)",
	"hybrid_human_animal_01": "هجين إنسان-حيوان ٠١", "dove_flock_01": "سرب الحمام ٠١",
	"camel_flock_05": "قطيع الإبل ٠٥", "camel_choir_04": "جوقة الإبل ٠٤", "camel_one_call": "جمل، نداء واحد",
	"goat_herd_01": "قطيع الماعز ٠١ (أجراس)", "hyena_02": "الضبع ٠٢", "hyena_01": "الضبع ٠١",
	"jackal_night_01": "ليل بنات آوى ٠١", "donkey_valley_01": "وادي الحمير ٠١",
	"imaginary_species_01": "كائنات متخيَّلة ٠١", "frogs_01": "الضفادع ٠١",
	"cicadas_crickets_01": "الزيز والصراصير، دورة نهار",
}

const BODIES := {
	"myna-headed hybrid from the Dove Man horde": "هجين برأس مينا من حشد رجل الحمامة",
	"flying pigeon of the Dove Man world": "حمامة طائرة من عالم رجل الحمامة",
	"the same pigeon, standing": "الحمامة نفسها، واقفة",
	"rigged camel of the Dove Man world": "جمل من عالم رجل الحمامة",
	"textured walking camel of the Dove Man world": "جمل يمشي من عالم رجل الحمامة",
	"goat of the Ait Wadu halqa": "عنزة من حلقة آيت وادو",
	"spotted hyena of the Ait Wadu world": "ضبع مرقَّط من عالم آيت وادو",
	"the dancing bear of the Ait Wadu halqa": "الدب الراقص في حلقة آيت وادو",
	"salt fennec of the City of Salt and Blood": "فنك من الملح من مدينة الملح والدم",
	"salt Barb horse of the City of Salt and Blood": "حصان بربري من الملح من مدينة الملح والدم",
	"salt goat of the City of Salt and Blood": "عنزة من الملح من مدينة الملح والدم",
	"salt striped hyena of the City of Salt and Blood": "ضبع مخطَّط من الملح من مدينة الملح والدم",
	"salt oryx of the City of Salt and Blood": "مها من الملح من مدينة الملح والدم",
	"salt griffon vulture of the City of Salt and Blood": "نسر أسمر من الملح من مدينة الملح والدم",
	"salt cobra of the City of Salt and Blood": "كوبرا من الملح من مدينة الملح والدم",
	"Chimera family 01, The Eye and the Needle": "عائلة الخيميرا ٠١، العين والإبرة",
	"Chimera family 02, The Eye and the Needle": "عائلة الخيميرا ٠٢، العين والإبرة",
	"Chimera family 03, The Eye and the Needle": "عائلة الخيميرا ٠٣، العين والإبرة",
	"Chimera family 04, The Eye and the Needle": "عائلة الخيميرا ٠٤، العين والإبرة",
	"Chimera family 05, The Eye and the Needle": "عائلة الخيميرا ٠٥، العين والإبرة",
	"voices in the oil lake": "أصوات في بحيرة النفط",
	"the storks of the Ait Wadu village": "لقالق قرية آيت وادو",
	"the drummer of the Ait Wadu halqa": "طبّال حلقة آيت وادو",
	"rock camel of the Dove Man world": "جمل صخري من عالم رجل الحمامة",
	"voices in the Qur'anic gardens beyond the seventh circle": "أصوات في الحدائق القرآنية وراء الدائرة السابعة",
}


static func ar() -> bool:
	return lang == "ar"


static func t(key: String) -> String:
	var lx: String = Lex.ui(key, "circles", ar())
	if lx != "":
		return lx
	var v: Array = UI.get(key, [key, key])
	return v[1] if ar() else v[0]


static func creature(name_en: String) -> String:
	if not ar():
		return name_en
	if CREATURES.has(name_en):
		return CREATURES[name_en]
	for pre in [["Wind drifter ", "سابح الريح "], ["Winged serpent ", "ثعبان مجنَّح "], ["Pentaradial walker ", "ماشٍ خماسي "]]:
		if name_en.begins_with(pre[0]):
			return pre[1] + num(name_en.substr(pre[0].length()))
	return name_en


static func voice(id: String) -> String:
	if Lex.has_voice(id):
		return Lex.voice(id, ar())
	return VOICES.get(id, Catalog.VOICES.get(id, id)) if ar() else Catalog.VOICES.get(id, id)


static func body(desc_en: String) -> String:
	if not ar():
		return desc_en
	if BODIES.has(desc_en):
		return BODIES[desc_en]
	if desc_en.ends_with("TAGANT Bestiary Lab"):
		for pre in [["pentaradial walker", "ماشٍ خماسي الأطراف"], ["serpent with seven wing pairs", "ثعبان بسبعة أزواج من الأجنحة"], ["wind drifter", "سابح الريح"]]:
			if desc_en.begins_with(pre[0]):
				return "%s %s، مختبر كائنات TAGANT" % [pre[1], num(desc_en.substr(pre[0].length() + 1, 3))]
	return desc_en


## Eastern Arabic digits for numbers shown in Arabic mode.
static func num(s: String) -> String:
	if not ar():
		return s
	var out := ""
	for ch in s:
		var c := ch.unicode_at(0)
		out += char(0x0660 + c - 48) if c >= 48 and c <= 57 else ch
	return out
