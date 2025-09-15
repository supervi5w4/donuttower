extends Control

@onready var language_button: Button = $LanguageButton
@onready var language_manager: Node = get_node("/root/LanguageManager")


func _ready() -> void:
	print("StartMenu: _ready() начал выполнение")
	
	# Подключаем сигнал смены языка
	if language_manager:
		language_manager.language_changed.connect(_on_language_changed)
		# Ждем, пока LanguageManager полностью инициализируется
		await language_manager.ready
		_update_language_button()
	
	# Принудительно проверяем и устанавливаем язык
	_ensure_correct_language()
	
	# Принудительно обновляем все тексты при загрузке
	await get_tree().process_frame
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


func _on_start_button_pressed():
	# GameplayAPI.start() будет вызван в Game.gd при начале игры
	# Запускаем первый уровень напрямую
	LevelData.set_current_level(1)
	GameStateManager.reset_for_level(1)
	get_tree().change_scene_to_file("res://scenes/Game.tscn")

func _on_language_button_pressed():
	"""Обработчик нажатия кнопки смены языка"""
	if language_manager:
		language_manager.switch_language()

func _on_language_changed(_language_code: String):
	"""Обработчик смены языка"""
	print("StartMenu: получен сигнал смены языка на: ", _language_code)
	_update_language_button()
	# Принудительно обновляем все тексты в интерфейсе
	_update_all_texts()

func _update_language_button():
	"""Обновляет текст кнопки языка"""
	if language_button and language_manager:
		var _current_lang = language_manager.get_current_language()
		# Показываем следующий язык, на который переключимся
		var next_lang = language_manager.get_next_language()
		var display_name = language_manager.get_language_display_name(next_lang)
		language_button.text = display_name

func _ensure_correct_language():
	"""Принудительно проверяет и устанавливает правильный язык"""
	if language_manager:
		var current_lang = language_manager.get_current_language()
		print("StartMenu: проверяем язык - LanguageManager: ", current_lang)
		print("StartMenu: проверяем язык - TranslationServer: ", TranslationServer.get_locale())
		
		# Если языки не совпадают, принудительно устанавливаем правильный
		if TranslationServer.get_locale() != current_lang:
			print("StartMenu: языки не совпадают, принудительно устанавливаем: ", current_lang)
			TranslationServer.set_locale(current_lang)
		
		# Проверяем, что переводы работают правильно
		var test_translation = tr("ui.start.button")
		print("StartMenu: тестовый перевод 'ui.start.button': '", test_translation, "'")
		
		# Если перевод не работает, принудительно перезагружаем переводы
		if test_translation == "ui.start.button":
			print("StartMenu: переводы не работают, принудительно перезагружаем...")
			language_manager._load_translations()
			TranslationServer.set_locale(current_lang)
	else:
		print("StartMenu: LanguageManager недоступен, используем язык по умолчанию")

func _update_all_texts():
	"""Принудительно обновляет все тексты в интерфейсе"""
	
	# Получаем текущий язык для отладки
	var current_lang = TranslationServer.get_locale()
	print("StartMenu: обновляем тексты для языка: ", current_lang)
	
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

# Обработчики событий SDK
func _setup_sdk_handlers():
	"""Настраивает обработчики событий SDK для StartMenu"""
	if YandexSDK:
		# Здесь можно добавить специфичные для StartMenu обработчики
		print("StartMenu: обработчики SDK настроены")

# Обработчики событий SDK теперь находятся в Main.gd

func _setup_pause_resume_handlers():
	"""Настраивает обработчики паузы и возобновления игры"""
	if YandexSDK and YandexSDK.is_working():
		# Настраиваем обработчики через SDK
		YandexSDK.setup_pause_resume_handlers()
		print("StartMenu: обработчики паузы/возобновления настроены")
	
	# Также настраиваем обработчики фокуса окна
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
	
