extends Node
## Менеджер языков для переключения локализации

signal language_changed(language_code: String)

var current_language: String = "ru"
var available_languages: Array[String] = ["ru", "en"]

func _ready() -> void:
	print("LanguageManager: Инициализация...")
	# Загружаем сохраненный язык
	_load_language_setting()
	# Принудительно загружаем переводы
	_load_translations()
	# Применяем язык
	_set_language(current_language)
	print("LanguageManager: Инициализация завершена")

func _load_translations() -> void:
	"""Принудительно загружает файлы переводов"""
	var translations = [
		load("res://i18n/ui_ru.po"),
		load("res://i18n/ui_en.po")
	]
	
	for translation in translations:
		if translation:
			TranslationServer.add_translation(translation)
			print("Загружен перевод: ", translation.locale)
		else:
			print("Ошибка загрузки перевода: ", translation)

func _load_language_setting() -> void:
	"""Загружает сохраненную настройку языка"""
	# Принудительно устанавливаем русский язык по умолчанию
	current_language = "ru"
	print("Установлен язык по умолчанию: ", current_language)

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
		print("Язык изменен на: ", language_code)
		print("Текущая локаль TranslationServer: ", TranslationServer.get_locale())
		print("Доступные переводы: ", TranslationServer.get_loaded_locales())
		
		# Тестируем переводы
		print("Тест перевода 'ui.menu.button': ", tr("ui.menu.button"))
		print("Тест перевода 'ui.gameover.title': ", tr("ui.gameover.title"))

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
