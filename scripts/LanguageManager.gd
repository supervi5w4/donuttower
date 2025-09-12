extends Node
## Менеджер языков для переключения локализации

signal language_changed(language_code: String)

var current_language: String = "ru"
var available_languages: Array[String] = ["ru", "en"]

func _ready() -> void:
	# Принудительно загружаем переводы ПЕРВЫМИ
	_load_translations()
	# Загружаем сохраненный язык
	_load_language_setting()
	# Применяем язык
	_set_language(current_language)

func _load_translations() -> void:
	"""Принудительно загружает файлы переводов"""
	var translations = [
		load("res://i18n/ui_ru.po"),
		load("res://i18n/ui_en.po")
	]
	
	for translation in translations:
		if translation:
			TranslationServer.add_translation(translation)
		else:
			pass

func _load_language_setting() -> void:
	"""Загружает сохраненную настройку языка"""
	# Принудительно устанавливаем русский язык по умолчанию
	current_language = "ru"
	# Также устанавливаем локаль в TranslationServer
	TranslationServer.set_locale("ru")

func _save_language_setting() -> void:
	"""Сохраняет настройку языка"""
	var config = ConfigFile.new()
	config.set_value("settings", "language", current_language)
	config.save("user://settings.cfg")

func _set_language(language_code: String) -> void:
	"""Устанавливает язык интерфейса"""
	if language_code in available_languages:
		current_language = language_code
		TranslationServer.set_locale(language_code)
		_save_language_setting()
		language_changed.emit(language_code)
	else:
		pass

func switch_language() -> void:
	"""Переключает между доступными языками"""
	var current_index = available_languages.find(current_language)
	var next_index = (current_index + 1) % available_languages.size()
	_set_language(available_languages[next_index])

func get_current_language() -> String:
	"""Возвращает текущий язык"""
	return current_language

func get_next_language() -> String:
	"""Возвращает следующий язык для переключения"""
	var current_index = available_languages.find(current_language)
	var next_index = (current_index + 1) % available_languages.size()
	return available_languages[next_index]

func get_language_display_name(language_code: String) -> String:
	"""Возвращает отображаемое название языка"""
	match language_code:
		"ru":
			return "RU"
		"en":
			return "ENG"
		_:
			return language_code.to_upper()
