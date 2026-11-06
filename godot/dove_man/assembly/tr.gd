extends RefCounted
## English / Arabic. The app runs in one language, chosen by the launcher:
##   PLAY_AssemblyKaraoke_EN.bat  /  PLAY_AssemblyKaraoke_AR.bat   (passes --lang=ar)
## Fonts: Noto Sans (Latin), Noto Naskh Arabic, Noto Sans Tifinagh (SIL OFL, see fonts/OFL_noto.txt).

static var lang := ""
static var _font: Font

const AR := {
	"THE ASSEMBLY · claiming water": "الجَمْع · المطالبة بالماء",
	"the crowd is gathering": "الحشد يتجمّع",
	"round %d / %d": "الجولة %d / %d",
	"listen: %s calls": "استمع: %s يُنادي",
	"your turn: sing your line about water - the crowd joins": "دورك: غنِّ سطرك عن الماء — والحشد ينضمّ إليك",
	"the titan turns its water on the crowd": "العملاق يصوّب ماءه على الحشد",
	"they scatter - keep singing to bring them back": "تفرّقوا — واصل الغناء لتعيدهم",
	"all together": "معًا",
	"the titan enters": "العملاق يدخل",
	"LISTEN": "استمع",
	"YOUR TURN — sing it": "دورك — غنِّ",
	"THE WATER CANNON — keep singing": "مدفع الماء — واصل الغناء",
	"sing them back together": "غنِّ ليعودوا معًا",
	"ALL TOGETHER": "معًا",
	"the crowd is gathering…": "الحشد يتجمّع…",
	"next, you sing:": "ستغنّي بعدها:",
	"you sang: %d%%": "غنّيت: %d٪",
	"you": "أنت",
	"no mic": "لا ميكروفون",
	# the chant
	"gathering": "التجمّع",
	"call · mynas": "نداء · طيور المَينا",
	"response": "الردّ",
	"call · hyenas": "نداء · الضباع",
	"call · snake-heads": "نداء · رؤوس الأفاعي",
	"call · camels and the wounded giants": "نداء · الجمال والعمالقة الجرحى",
	"the titan attacks - its water cannon": "العملاق يهاجم — مدفع مائه",
	"they come back together · the doves": "يعودون معًا · الحمام",
	"breath": "نَفَس",
}


static func setup() -> void:
	if lang != "":
		return
	lang = "en"
	for a in OS.get_cmdline_user_args() + OS.get_cmdline_args():
		if a == "--lang=ar":
			lang = "ar"
	if OS.has_environment("ASM_LANG"):
		lang = OS.get_environment("ASM_LANG")


static func ar() -> bool:
	setup()
	return lang == "ar"


static func t(en: String) -> String:
	setup()
	if lang == "ar":
		return AR.get(en, en)
	return en


# One font with fallbacks, so Latin, Arabic and Tifinagh can sit in the same line.
static func font() -> Font:
	if _font != null:
		return _font
	setup()
	var dir := "res://dove_man/assembly/fonts/"
	var latin: FontFile = load(dir + "NotoSans-latin.woff2")
	var latin_ext: FontFile = load(dir + "NotoSans-latin-ext.woff2")
	var arabic: FontFile = load(dir + "NotoNaskhArabic.woff2")
	var tif: FontFile = load(dir + "NotoSansTifinagh.woff2")
	var fv := FontVariation.new()
	if lang == "ar":
		fv.base_font = arabic
		fv.fallbacks = [latin, latin_ext, tif]
	else:
		fv.base_font = latin
		fv.fallbacks = [latin_ext, arabic, tif]
	_font = fv
	return _font
