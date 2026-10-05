extends Node
## Check the exported catalog and the Japanese source-language fallback together.

func _ready() -> void:
	var failures: Array[String] = []
	if ProjectSettings.get_setting("internationalization/locale/fallback") != "ja":
		failures.append("the source-language fallback is Japanese")
	TranslationServer.set_locale("ja")
	if TranslationServer.translate("メロスゲーム") != "メロスゲーム":
		failures.append("Japanese devices keep Japanese source text")
	if TranslationServer.translate("GREENFIELD PLAINS") != "みどりの草原":
		failures.append("Japanese devices see localized stage names")
	TranslationServer.set_locale("en")
	if TranslationServer.translate("メロスゲーム") != "Melos Game":
		failures.append("English devices use the English catalog")
	if TranslationServer.translate("GREENFIELD PLAINS") != "GREENFIELD PLAINS":
		failures.append("English devices keep English stage names")
	for text in ["選択中", "左下をドラッグ", "右下をドラッグ"]:
		if TranslationServer.translate(text) == text:
			failures.append("English control text is translated: " + text)
	for failure in failures:
		push_error("locale probe: " + failure)
	print("locale probe: %d failures" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
