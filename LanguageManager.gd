extends Node
## Менеджер языков для переключения локализации

signal language_changed(language_code: String)

var current_language: String = "ru"
var available_languages: Array[String] = ["ru", "en"]

func _ready() -> void:
	print("LanguageManager: инициализация...")
	# Принудительно загружаем переводы ПЕРВЫМИ
	_load_translations()
	# Загружаем сохраненный язык (включая определение языка браузера)
	_load_language_setting()
	# Применяем язык только если он еще не установлен
	if TranslationServer.get_locale() != current_language:
		print("LanguageManager: применяем язык: ", current_language)
		_set_language(current_language)
	else:
		print("LanguageManager: язык уже установлен: ", current_language)
	# Дополнительная проверка: убеждаемся, что язык действительно сохранен
	print("LanguageManager: финальная проверка - сохраняем язык еще раз для надежности")
	_save_language_setting()
	# Уведомляем о том, что язык готов
	language_changed.emit(current_language)
	print("LanguageManager: инициализация завершена, текущий язык: ", current_language)
	print("LanguageManager: текущая локаль TranslationServer: ", TranslationServer.get_locale())

func _load_translations() -> void:
	"""Принудительно загружает файлы переводов"""
	print("LanguageManager: загружаем переводы...")
	
	# Очищаем существующие переводы
	TranslationServer.clear()
	
	# Дополнительная очистка - удаляем все загруженные локали
	var loaded_locales = TranslationServer.get_loaded_locales()
	for locale in loaded_locales:
		print("LanguageManager: удаляем локаль: ", locale)
		TranslationServer.remove_translation(TranslationServer.get_translation_object(locale))
	
	var translations = [
		load("res://i18n/ui_en.po"),
		load("res://i18n/ui_ru.po")
	]
	
	for translation in translations:
		if translation:
			TranslationServer.add_translation(translation)
			print("LanguageManager: загружен перевод: ", translation.locale)
		else:
			print("LanguageManager: не удалось загрузить перевод")
	
	print("LanguageManager: переводы загружены, доступные локали: ", TranslationServer.get_loaded_locales())

func _load_language_setting() -> void:
	"""Загружает сохраненную настройку языка"""
	print("LanguageManager: начинаем загрузку настроек языка...")
	
	# Сначала пытаемся загрузить сохраненную настройку языка
	var config = ConfigFile.new()
	var config_path = "user://settings.cfg"
	
	print("LanguageManager: проверяем файл настроек: ", config_path)
	print("LanguageManager: файл существует: ", FileAccess.file_exists(config_path))
	
	# Проверяем, существует ли файл настроек
	if FileAccess.file_exists(config_path):
		var err = config.load(config_path)
		print("LanguageManager: результат загрузки конфига: ", err)
		print("LanguageManager: конфиг имеет секцию settings: ", config.has_section("settings"))
		
		if err == OK and config.has_section_key("settings", "language"):
			var saved_language = config.get_value("settings", "language")
			# Проверяем, что сохраненный язык поддерживается
			if saved_language in available_languages:
				current_language = saved_language
				print("LanguageManager: загружен сохраненный язык: ", current_language)
				print("LanguageManager: устанавливаем локаль в TranslationServer: ", current_language)
				# Устанавливаем локаль в TranslationServer
				TranslationServer.set_locale(current_language)
				print("LanguageManager: текущая локаль TranslationServer после загрузки: ", TranslationServer.get_locale())
				return
			else:
				print("LanguageManager: сохраненный язык не поддерживается: ", saved_language)
		else:
			print("LanguageManager: не удалось загрузить сохраненный язык")
	else:
		print("LanguageManager: файл настроек не существует")
	
	# Если сохраненной настройки нет, определяем язык браузера только при первом запуске
	print("LanguageManager: определяем язык браузера...")
	var browser_language = _detect_browser_language()
	if browser_language != "" and browser_language in available_languages:
		current_language = browser_language
		print("LanguageManager: определен язык браузера при первом запуске: ", browser_language)
	else:
		# Fallback: для веб-платформы используем английский, для других - русский
		if OS.has_feature("web"):
			current_language = "en"
			print("LanguageManager: используем английский язык по умолчанию для веб-платформы")
		else:
			current_language = "ru"
			print("LanguageManager: используем русский язык по умолчанию")
	
	# Сохраняем выбранный язык только если это первый запуск
	print("LanguageManager: сохраняем язык: ", current_language)
	_save_language_setting()
	
	# Также устанавливаем локаль в TranslationServer
	print("LanguageManager: устанавливаем локаль в TranslationServer: ", current_language)
	TranslationServer.set_locale(current_language)
	print("LanguageManager: текущая локаль TranslationServer: ", TranslationServer.get_locale())

func _save_language_setting() -> void:
	"""Сохраняет настройку языка"""
	print("LanguageManager: сохраняем настройку языка: ", current_language)
	var config = ConfigFile.new()
	config.set_value("settings", "language", current_language)
	var err = config.save("user://settings.cfg")
	print("LanguageManager: результат сохранения конфига: ", err)
	if err != OK:
		print("LanguageManager: ошибка сохранения настроек языка!")
	else:
		print("LanguageManager: настройки языка успешно сохранены")

func _set_language(language_code: String) -> void:
	"""Устанавливает язык интерфейса"""
	if language_code in available_languages:
		current_language = language_code
		TranslationServer.set_locale(language_code)
		# Сохраняем язык сразу после установки
		_save_language_setting()
		print("LanguageManager: установлен язык: ", language_code)
		print("LanguageManager: текущая локаль TranslationServer: ", TranslationServer.get_locale())
		language_changed.emit(language_code)
	else:
		print("LanguageManager: неподдерживаемый язык: ", language_code)
		# Устанавливаем русский по умолчанию
		current_language = "ru"
		TranslationServer.set_locale("ru")
		_save_language_setting()
		print("LanguageManager: установлен язык по умолчанию: ru")
		language_changed.emit("ru")

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

func _detect_browser_language() -> String:
	"""Определяет язык браузера через JavaScript"""
	# Проверяем, что мы на веб-платформе
	print("LanguageManager: проверяем платформу...")
	print("LanguageManager: OS.has_feature('web') = ", OS.has_feature("web"))
	print("LanguageManager: OS.get_name() = ", OS.get_name())
	
	# Дополнительная проверка через JavaScript
	var is_web_js = JavaScriptBridge.eval("typeof window !== 'undefined'")
	print("LanguageManager: JavaScript проверка веб-платформы = ", is_web_js)
	
	# Если это не веб-платформа, но JavaScript доступен, все равно пытаемся определить язык
	if not OS.has_feature("web") and not is_web_js:
		print("LanguageManager: не веб-платформа, пропускаем определение языка браузера")
		return ""
	
	# Если JavaScript доступен, пытаемся определить язык браузера
	if not is_web_js:
		print("LanguageManager: JavaScript недоступен, пропускаем определение языка браузера")
		return ""
	
	print("LanguageManager: начинаем определение языка браузера...")
	
	# Используем JavaScript для получения языка браузера
	var js_code = """
		(function() {
			console.log('LanguageManager: определение языка браузера...');
			
			// Получаем язык браузера
			var lang = navigator.language || navigator.userLanguage;
			console.log('LanguageManager: navigator.language =', lang);
			
			// Извлекаем только код языка (например, "ru" из "ru-RU")
			if (lang) {
				var langCode = lang.split('-')[0].toLowerCase();
				console.log('LanguageManager: извлеченный код языка =', langCode);
				// Проверяем, поддерживается ли этот язык
				if (langCode === 'ru' || langCode === 'en') {
					console.log('LanguageManager: найден поддерживаемый язык =', langCode);
					return langCode;
				}
			}
			
			// Проверяем список предпочитаемых языков
			if (navigator.languages && navigator.languages.length > 0) {
				console.log('LanguageManager: проверяем navigator.languages =', navigator.languages);
				for (var i = 0; i < navigator.languages.length; i++) {
					var lang = navigator.languages[i];
					var langCode = lang.split('-')[0].toLowerCase();
					console.log('LanguageManager: проверяем язык из списка =', langCode);
					if (langCode === 'ru' || langCode === 'en') {
						console.log('LanguageManager: найден поддерживаемый язык в списке =', langCode);
						return langCode;
					}
				}
			}
			
			// Дополнительная проверка: если язык не определен, но браузер английский
			// Проверяем другие признаки английского языка
			var userAgent = navigator.userAgent.toLowerCase();
			var isEnglishBrowser = userAgent.includes('en-us') || userAgent.includes('en-gb') || 
								   userAgent.includes('english') || lang === 'en' || lang === 'en-US' || lang === 'en-GB';
			
			if (isEnglishBrowser) {
				console.log('LanguageManager: определен английский браузер по userAgent');
				return 'en';
			}
			
			// Если ничего не найдено, по умолчанию возвращаем английский для международных пользователей
			console.log('LanguageManager: не найден поддерживаемый язык, используем английский по умолчанию');
			return 'en';
		})();
	"""
	
	var result = JavaScriptBridge.eval(js_code)
	
	if result != null and result != "":
		print("LanguageManager: JavaScript вернул язык: ", result)
		return str(result)
	else:
		print("LanguageManager: не удалось определить язык браузера")
		return ""
