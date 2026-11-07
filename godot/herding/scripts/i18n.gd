class_name HTr
## English / Arabic interface. Arabic is right-to-left (Godot shapes it with its advanced text server).
## Fonts: Megrim (Latin titles), Tektur (Latin text), Handjet (Arabic) - all SIL Open Font License, in res://fonts.

static var lang := "en"

const UI := {
	"title": ["TAGANT  ·  HERDING KARAOKE", "TAGANT  ·  كاريوكي الرعاة"],
	"Listen": ["Listen", "استمع"],
	"Sing": ["Sing", "غنِّ"],
	"Rehearse": ["Rehearse", "تمرَّن"],
	"Dialogue": ["Dialogue", "حوار"],
	"sec_aitwadu": ["AIT WADU", "آيت وادو"],
	"sec_adu": ["ADU", "أضو"],
	"sec_aghanim": ["AGHANIM", "أغانيم"],
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
	"The great palm": "النخلة الكبيرة", "The river": "النهر", "The poppy field": "حقل شقائق النعمان",
	"Sheep mountain": "جبل الخروف", "Donkey mountain": "جبل الحمار", "The winds": "الرياح",
	"Saba": "الصَّبا", "Harmattan": "الهرمتان", "Chergui": "الشرقي", "Khamsin": "الخماسين", "Simoom": "السَّموم",
	"Shamal": "الشمال", "Dabur": "الدَّبور", "Ajaj": "العجاج", "Haboob": "الهبوب",
}

const VOICES := {
	"pipe_tune_1": "لحن ناي الراعي (١)", "pipe_tune_2": "لحن ناي الراعي (٢)", "tawat": "تاوات (مقطع)",
	"t2090r12": "أرشيف T2090 R12", "t2095r01": "أرشيف T2095 R01", "t2095r12": "أرشيف T2095 R12", "t2095r17": "أرشيف T2095 R17",
	"goatherd_1": "لحن راعي الماعز ١", "flock_into_field": "إدخال القطيع إلى الحقل", "scatter_flock": "تفريق القطيع",
	"sheep_to_hills": "إرسال الغنم إلى التلال", "sheep_down": "إنزال الغنم من التلال",
	"wolves_foxes": "صيحات لطرد الذئاب والثعالب",
	"wind_saba": "الصَّبا - ريح الشرق عند الفجر", "wind_harmattan": "الهرمتان - ريح الشمال الشرقي المغبرة",
	"wind_chergui": "الشرقي - ريح المغرب الحارّة", "wind_khamsin": "الخماسين - الأيام الخمسون",
	"wind_simoom": "السَّموم - الريح الحارّة", "wind_shamal": "الشمال - ريح الخليج",
	"wind_dabur": "الدَّبور - ريح الغرب الصرصر", "wind_ajaj": "العجاج - الغبار الدوّار",
	"wind_haboob": "الهبوب - جدار الغبار",
}

const BODIES := {
	"the giant date palm on the river bank": "نخلة التمر العملاقة على ضفة النهر",
	"the river of the Ait Wadu valley": "نهر وادي آيت وادو",
	"the poppies west of the river": "شقائق النعمان غرب النهر",
	"the mountain that is a sheep, to the south": "الجبل الذي هو خروف، في الجنوب",
	"the mountain that is a donkey, to the north": "الجبل الذي هو حمار، في الشمال",
	"nine winds of North Africa and Arabia, synthesised": "تسع رياح من شمال أفريقيا وجزيرة العرب، مُركَّبة",
	"east wind of dawn - a tent in a Hijaz wadi": "ريح الشرق عند الفجر - خيمة في وادٍ من الحجاز",
	"cool dusty north-east - the open Sahel in haze": "ريح شمالية شرقية باردة مغبرة - الساحل المفتوح في الضباب",
	"hot east wind - between the walls of a Draa kasbah": "ريح شرقية حارّة - بين جدران قصبة في درعة",
	"the fifty days - the Nile valley escarpment": "الأيام الخمسون - جرف وادي النيل",
	"the poison wind - a narrow sandstone gorge": "الريح الحارّة - مضيق ضيّق من الحجر الرملي",
	"north-west of the Gulf - open water, a harbour": "ريح الشمال الغربي في الخليج - الماء المفتوح، ميناء",
	"the howling west wind - the rock canyon of Aad": "ريح الغرب الصرصر - وادي عاد الصخري",
	"the whirling dust - the palm grove of an oasis": "الغبار الدوّار - نخيل واحة",
	"the wall of dust - inside it, Khartoum plain": "جدار الغبار - داخله، سهل الخرطوم",
}


static func ar() -> bool:
	return lang == "ar"


static func t(key: String) -> String:
	var lx: String = Lex.ui(key, "aitwadu", ar())
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
	return VOICES.get(id, HCatalog.VOICES.get(id, id)) if ar() else HCatalog.VOICES.get(id, id)


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
