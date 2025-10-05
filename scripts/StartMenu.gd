extends Control

@onready var language_button: Button = $LanguageButton
@onready var language_manager: Node = get_node("/root/LanguageManager")


func _ready() -> void:
	print("StartMenu: _ready() начал выполнение")
	
	# Подключаем сигнал смены языка ПЕРВЫМ
	if language_manager:
		print("StartMenu: подключаемся к LanguageManager")
		language_manager.language_changed.connect(_on_language_changed)
		# Ждем, пока LanguageManager полностью инициализируется
		await language_manager.ready
		print("StartMenu: LanguageManager готов, текущий язык: ", language_manager.get_current_language())
		
		# КРИТИЧНО: Проверяем синхронизацию LanguageManager с TranslationServer
		var current_locale = TranslationServer.get_locale()
		var manager_language = language_manager.get_current_language()
		print("StartMenu: проверка синхронизации - LanguageManager: ", manager_language, ", TranslationServer: ", current_locale)
		
		# Если языки не совпадают, используем язык из LanguageManager (он более актуальный)
		if current_locale != "" and current_locale != manager_language:
			print("StartMenu: языки не совпадают, используем язык из LanguageManager: ", manager_language)
			TranslationServer.set_locale(manager_language)
			print("StartMenu: TranslationServer синхронизирован с LanguageManager: ", manager_language)
		else:
			print("StartMenu: языки уже синхронизированы")
		
		# Ждем еще один кадр, чтобы все переводы точно загрузились
		await get_tree().process_frame
		
		# Обновляем кнопку языка
		_update_language_button()
		
		# Принудительно обновляем все тексты
		_update_all_texts()
	else:
		print("StartMenu: LanguageManager недоступен!")
		# Fallback: если LanguageManager недоступен, загружаем язык из файла
		print("StartMenu: fallback - принудительно загружаем сохраненный язык...")
		_force_load_saved_language()
	
	# Подключаем сигнал обновления сохранений от GameStateManager
	print("StartMenu: подключаемся к GameStateManager")
	GameStateManager.save_updated.connect(_on_save_updated)
	
	# Принудительно проверяем и устанавливаем язык
	print("StartMenu: проверяем правильность языка")
	_ensure_correct_language()
	
	# Принудительно обновляем все тексты при загрузке
	await get_tree().process_frame
	print("StartMenu: обновляем все тексты")
	_update_all_texts()
	
	print("StartMenu: подготовка завершена")
	
	# SDK инициализируется в Main.gd, здесь мы только настраиваем обработчики для StartMenu
	if YandexSDK and YandexSDK.is_working():
		print("StartMenu: подключаемся к уже инициализированному SDK")
		
		# Подключаем обработчики событий для StartMenu
		_setup_sdk_handlers()
		
		# Настраиваем обработчики паузы/возобновления для StartMenu
		_setup_pause_resume_handlers()
	else:
		print("StartMenu: не на платформе Yandex, работаем в режиме разработки")
	
	print("StartMenu: готов к работе")
	
	# Настраиваем кнопки игры сразу при загрузке
	_setup_game_buttons()


func _force_load_saved_language():
	"""Принудительно загружает сохраненный язык из файла настроек (fallback функция)"""
	print("StartMenu: принудительно загружаем сохраненный язык...")
	
	var config = ConfigFile.new()
	var config_path = "user://settings.cfg"
	
	if FileAccess.file_exists(config_path):
		var err = config.load(config_path)
		print("StartMenu: результат загрузки конфига: ", err)
		print("StartMenu: конфиг имеет секцию settings: ", config.has_section("settings"))
		if err == OK and config.has_section_key("settings", "language"):
			var saved_language = config.get_value("settings", "language")
			print("StartMenu: найден сохраненный язык: ", saved_language)
			
			# Проверяем, не установлен ли уже правильный язык
			var current_locale = TranslationServer.get_locale()
			if current_locale != saved_language:
				# Принудительно устанавливаем язык в TranslationServer
				TranslationServer.set_locale(saved_language)
				print("StartMenu: принудительно установлен язык: ", saved_language)
				print("StartMenu: текущая локаль TranslationServer: ", TranslationServer.get_locale())
			else:
				print("StartMenu: язык уже установлен правильно: ", saved_language)
			
			# Если LanguageManager доступен, обновляем его тоже
			if language_manager:
				language_manager.current_language = saved_language
				print("StartMenu: обновлен LanguageManager.current_language: ", saved_language)
		else:
			print("StartMenu: не удалось загрузить сохраненный язык из файла")
	else:
		print("StartMenu: файл настроек не существует")

func _on_start_button_pressed():
	# GameplayAPI.start() будет вызван в Game.gd при начале игры
	# Запускаем первый уровень напрямую
	print("StartMenu: нажата кнопка старта игры")
	
	# Завершаем текущую игру если она есть (для новой игры)
	if GameStateManager.has_game_in_progress():
		print("StartMenu: завершаем текущую игру для начала новой")
		GameStateManager.end_game()
	
	LevelData.set_current_level(1)
	GameStateManager.reset_for_level(1)
	GameStateManager.start_game(1)  # Сохраняем начало новой игры
	get_tree().change_scene_to_file("res://scenes/Game.tscn")

func _on_language_button_pressed():
	"""Обработчик нажатия кнопки смены языка"""
	print("StartMenu: нажата кнопка смены языка")
	if language_manager:
		var current_lang = language_manager.get_current_language()
		var next_lang = language_manager.get_next_language()
		print("StartMenu: текущий язык: ", current_lang, ", переключаемся на: ", next_lang)
		language_manager.switch_language()
		print("StartMenu: switch_language() вызван")
	else:
		print("StartMenu: LanguageManager недоступен!")

func _on_language_changed(_language_code: String):
	"""Обработчик смены языка"""
	print("StartMenu: получен сигнал смены языка на: ", _language_code)
	
	# Ждем один кадр, чтобы TranslationServer успел обновиться
	await get_tree().process_frame
	
	# Обновляем кнопку языка
	_update_language_button()
	
	# Принудительно обновляем все тексты в интерфейсе
	_update_all_texts()
	
	# Убеждаемся, что язык сохранен в настройках
	if language_manager:
		language_manager._save_language_setting()
		print("StartMenu: язык сохранен в настройках после смены")
	
	# Дополнительная проверка синхронизации
	print("StartMenu: проверка после смены языка - LanguageManager: ", language_manager.get_current_language())
	print("StartMenu: проверка после смены языка - TranslationServer: ", TranslationServer.get_locale())

func _on_save_updated():
	"""Обработчик обновления сохранений от GameStateManager"""
	print("StartMenu: получен сигнал обновления сохранений, обновляем кнопки игры")
	_setup_game_buttons()

func _update_language_button():
	"""Обновляет текст кнопки языка"""
	if language_button and language_manager:
		var current_lang = language_manager.get_current_language()
		# Показываем СЛЕДУЮЩИЙ язык, на который переключимся
		var next_lang = language_manager.get_next_language()
		var display_name = language_manager.get_language_display_name(next_lang)
		language_button.text = display_name
		print("StartMenu: обновлена кнопка языка - показывает: ", display_name, " (текущий: ", current_lang, ", следующий: ", next_lang, ")")

func _ensure_correct_language():
	"""Принудительно проверяет и устанавливает правильный язык"""
	if language_manager:
		var current_lang = language_manager.get_current_language()
		print("StartMenu: проверяем язык - LanguageManager: ", current_lang)
		print("StartMenu: проверяем язык - TranslationServer: ", TranslationServer.get_locale())
		
		# КРИТИЧНО: Если языки не совпадают, принудительно устанавливаем правильный
		if TranslationServer.get_locale() != current_lang:
			print("StartMenu: языки не совпадают, принудительно устанавливаем: ", current_lang)
			TranslationServer.set_locale(current_lang)
			print("StartMenu: локаль TranslationServer после принудительной установки: ", TranslationServer.get_locale())
		
		# Проверяем, что переводы работают правильно
		var test_translation = tr("ui.start.button")
		print("StartMenu: тестовый перевод 'ui.start.button': '", test_translation, "'")
		
		# Если перевод не работает, принудительно перезагружаем переводы
		if test_translation == "ui.start.button":
			print("StartMenu: переводы не работают, принудительно перезагружаем...")
			language_manager._load_translations()
			TranslationServer.set_locale(current_lang)
			print("StartMenu: локаль TranslationServer после перезагрузки переводов: ", TranslationServer.get_locale())
			
			# Проверяем еще раз
			test_translation = tr("ui.start.button")
			print("StartMenu: повторный тестовый перевод: '", test_translation, "'")
		
		# Дополнительная проверка: убеждаемся, что язык действительно сохранен
		# и не будет переопределен при следующей загрузке
		print("StartMenu: убеждаемся, что язык сохранен в настройках")
		language_manager._save_language_setting()
		
		# Финальная проверка
		print("StartMenu: финальная проверка - LanguageManager: ", language_manager.get_current_language())
		print("StartMenu: финальная проверка - TranslationServer: ", TranslationServer.get_locale())
		print("StartMenu: финальная проверка - тестовый перевод: '", tr("ui.start.button"), "'")
		
		# Дополнительная защита: если язык все еще неправильный, принудительно исправляем
		var final_lang = language_manager.get_current_language()
		if TranslationServer.get_locale() != final_lang:
			print("StartMenu: КРИТИЧЕСКАЯ ОШИБКА: язык не совпадает после всех проверок!")
			print("StartMenu: принудительно исправляем: ", final_lang)
			TranslationServer.set_locale(final_lang)
			language_manager._save_language_setting()
			print("StartMenu: исправление завершено")
		
		# КРИТИЧНО: Принудительно обновляем все тексты еще раз
		print("StartMenu: принудительно обновляем все тексты после проверки языка")
		_update_all_texts()
	else:
		print("StartMenu: LanguageManager недоступен, используем язык по умолчанию")
		# Fallback: загружаем язык из файла настроек
		_force_load_saved_language()

func _update_all_texts():
	"""Принудительно обновляет все тексты в интерфейсе"""
	
	# Получаем текущий язык для отладки
	var current_lang = TranslationServer.get_locale()
	print("StartMenu: обновляем тексты для языка: ", current_lang)
	
	# КРИТИЧНО: Принудительно устанавливаем язык еще раз
	if language_manager:
		var manager_lang = language_manager.get_current_language()
		if manager_lang != current_lang:
			print("StartMenu: принудительно синхронизируем TranslationServer с LanguageManager: ", manager_lang)
			TranslationServer.set_locale(manager_lang)
			current_lang = manager_lang
	
	# Обновляем кнопку "Начать играть"
	var start_button = $MainContainer/StartButton
	if start_button:
		var new_text = tr("ui.start.button")
		print("StartMenu: обновляем кнопку старта: '", new_text, "'")
		start_button.text = new_text
	else:
		print("StartMenu: кнопка старта не найдена")
	
	# Обновляем описание
	var description_label = $MainContainer/DescriptionLabel
	if description_label:
		var new_text = tr("ui.start.description")
		print("StartMenu: обновляем описание: '", new_text, "'")
		description_label.text = new_text
	else:
		print("StartMenu: лейбл описания не найден")
	
	# КРИТИЧНО: Обновляем кнопку языка тоже
	_update_language_button()
	
	print("StartMenu: все тексты обновлены для языка: ", current_lang)

# Обработчики событий SDK
func _setup_sdk_handlers():
	"""Настраивает обработчики событий SDK для StartMenu"""
	if YandexSDK:
		# Здесь можно добавить специфичные для StartMenu обработчики
		print("StartMenu: обработчики SDK настроены")

# Обработчики событий SDK теперь находятся в Main.gd

func _setup_pause_resume_handlers():
	"""Настраивает обработчики паузы и возобновления игры"""
	# Настраиваем обработчики фокуса окна
	get_window().focus_entered.connect(_on_window_focus_entered)
	get_window().focus_exited.connect(_on_window_focus_exited)
	get_window().visibility_changed.connect(_on_window_visibility_changed)

func _on_window_focus_entered():
	"""Обработчик получения фокуса окном"""
	print("StartMenu: окно получило фокус")
	if YandexSDK and YandexSDK.is_working():
		# Если игра была на паузе, возобновляем геймплей
		YandexSDK.gameplay_started()
		print("StartMenu: GameplayAPI.start() вызван при получении фокуса")

func _on_window_focus_exited():
	"""Обработчик потери фокуса окном"""
	print("StartMenu: окно потеряло фокус")
	if YandexSDK and YandexSDK.is_working():
		# Приостанавливаем геймплей при потере фокуса
		YandexSDK.gameplay_stopped()
		print("StartMenu: GameplayAPI.stop() вызван при потере фокуса")

func _on_window_visibility_changed():
	"""Обработчик изменения видимости окна"""
	if not get_window().visible:
		print("StartMenu: окно стало невидимым")
		if YandexSDK and YandexSDK.is_working():
			YandexSDK.gameplay_stopped()
			print("StartMenu: GameplayAPI.stop() вызван при скрытии окна")
	else:
		print("StartMenu: окно стало видимым")
		if YandexSDK and YandexSDK.is_working():
			YandexSDK.gameplay_started()
			print("StartMenu: GameplayAPI.start() вызван при показе окна")

# ===== Функции для работы с сохраненной игрой =====

func _setup_game_buttons():
	"""Настраивает кнопки игры - показывает кнопку продолжения если есть сохраненная игра"""
	print("StartMenu: настраиваем кнопки игры...")
	
	# Удаляем существующую кнопку продолжения если она есть
	_remove_continue_button()
	
	# Проверяем, есть ли сохраненная игра
	if GameStateManager.has_game_in_progress():
		var saved_level = GameStateManager.get_game_level()
		var saved_score = GameStateManager.get_game_score()
		var saved_state = GameStateManager.get_game_state()
		
		print("StartMenu: найдена сохраненная игра - уровень: ", saved_level, ", счет: ", saved_score, ", состояние: ", saved_state)
		
		# Показываем кнопку "Продолжить игру" если есть сохраненная игра
		_show_continue_button(saved_level, saved_score, saved_state)
		
		# Переименовываем кнопку "Начать играть" в "Новая игра"
		_rename_start_button_to_new_game()
	else:
		print("StartMenu: сохраненной игры нет, оставляем стандартную кнопку")
		_restore_start_button()

func _remove_continue_button():
	"""Удаляет кнопку продолжения игры если она существует"""
	var continue_button = $MainContainer/ContinueButton
	if continue_button:
		print("StartMenu: удаляем существующую кнопку продолжения")
		continue_button.queue_free()

func _show_continue_button(level: int, score: int, state: String):
	"""Показывает кнопку продолжения игры"""
	print("StartMenu: создаем кнопку продолжения для уровня ", level, " со счетом ", score)
	
	# Получаем кнопку "Начать играть"
	var start_button = $MainContainer/StartButton
	if not start_button:
		print("StartMenu: кнопка StartButton не найдена!")
		return
	
	print("StartMenu: кнопка StartButton найдена, создаем кнопку продолжения")
	
	# Создаем кнопку "Продолжить игру"
	var continue_button = Button.new()
	continue_button.name = "ContinueButton"
	continue_button.text = tr("ui.continue.button") + " (Ур. " + str(level) + ", " + str(score) + " очков)"
	continue_button.custom_minimum_size = Vector2(400, 80)
	continue_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	continue_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	
	# Стилизация кнопки в том же стиле, что и StartButton
	continue_button.add_theme_color_override("font_hover_color", Color(0.2, 0.1, 0.05, 1))
	continue_button.add_theme_color_override("font_color", Color(0.2, 0.1, 0.05, 1))
	continue_button.add_theme_color_override("font_pressed_color", Color(0.2, 0.1, 0.05, 1))
	continue_button.add_theme_font_size_override("font_size", 24)
	
	# Копируем стили от StartButton
	continue_button.add_theme_stylebox_override("hover", start_button.get_theme_stylebox("hover"))
	continue_button.add_theme_stylebox_override("pressed", start_button.get_theme_stylebox("pressed"))
	continue_button.add_theme_stylebox_override("normal", start_button.get_theme_stylebox("normal"))
	
	# Добавляем кнопку в MainContainer перед StartButton
	var main_container = $MainContainer
	main_container.add_child(continue_button)
	main_container.move_child(continue_button, start_button.get_index())
	
	# Подключаем сигнал
	continue_button.pressed.connect(_on_continue_button_pressed)
	
	print("StartMenu: кнопка продолжения создана и добавлена в интерфейс")

func _on_continue_button_pressed():
	"""Обработчик нажатия кнопки продолжения игры"""
	if not GameStateManager.has_game_in_progress():
		print("StartMenu: нет сохраненной игры для продолжения!")
		return
	
	var saved_level = GameStateManager.get_game_level()
	var saved_score = GameStateManager.get_game_score()
	
	print("StartMenu: продолжаем игру - уровень: ", saved_level, ", счет: ", saved_score)
	
	# Устанавливаем текущий уровень
	LevelData.set_current_level(saved_level)
	GameStateManager.reset_for_level(saved_level)
	
	# Загружаем соответствующий уровень
	match saved_level:
		1:
			get_tree().change_scene_to_file("res://scenes/Game.tscn")
		2:
			get_tree().change_scene_to_file("res://scenes/Game_level_2.tscn")
		3:
			get_tree().change_scene_to_file("res://scenes/Game_level_3.tscn")
		4:
			get_tree().change_scene_to_file("res://scenes/Game_level_4.tscn")
		5:
			get_tree().change_scene_to_file("res://scenes/Game_level_5.tscn")
		6:
			get_tree().change_scene_to_file("res://scenes/Game_level_6.tscn")
		_:
			get_tree().change_scene_to_file("res://scenes/Game.tscn")

func _rename_start_button_to_new_game():
	"""Переименовывает кнопку 'Начать играть' в 'Новая игра'"""
	var start_button = $MainContainer/StartButton
	if start_button:
		start_button.text = tr("ui.new_game.button")
		print("StartMenu: кнопка переименована в 'Новая игра'")

func _restore_start_button():
	"""Восстанавливает стандартный текст кнопки 'Начать играть'"""
	var start_button = $MainContainer/StartButton
	if start_button:
		start_button.text = tr("ui.start.button")
		print("StartMenu: кнопка восстановлена в 'Начать играть'")
	
