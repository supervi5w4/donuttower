extends Control

@onready var language_button: Button = $LanguageButton
@onready var language_manager: Node = get_node("/root/LanguageManager")
@onready var mute_button: Button = $MusicControls/MuteButton
@onready var volume_slider: HSlider = $MusicControls/VolumeSlider

var music_manager: Node
var is_sound_muted: bool = false  # Локальное состояние звука для fallback режима
var fallback_player: AudioStreamPlayer  # Резервный плеер музыки

func _ready() -> void:
	# Подключаем сигнал смены языка
	if language_manager:
		language_manager.language_changed.connect(_on_language_changed)
		_update_language_button()
	
	# Принудительно обновляем все тексты при загрузке
	await get_tree().process_frame
	_update_all_texts()
	
	# Инициализируем игрока для работы с лидербордом
	if YandexSDK:
		YandexSDK.init_player()
		await YandexSDK.player_initialized
	
	# Ждем один кадр, чтобы автозагружаемые синглтоны успели инициализироваться
	await get_tree().process_frame
	
	# Получаем MusicManager (автозагружаемый синглтон)
	music_manager = Music
	
	# Отладочная информация
	
	# Запускаем фоновую музыку
	if music_manager:
		music_manager.play_bgm("res://assets/music/music.mp3")
	else:
		# Альтернативный способ - создаем локальный плеер
		_create_fallback_music()
	
	# Настраиваем элементы управления в любом случае
	_setup_music_controls()
	
	# Тестируем музыку через 2 секунды
	await get_tree().create_timer(2.0).timeout
	_test_music()

func _on_start_button_pressed():
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

func _update_all_texts():
	"""Принудительно обновляет все тексты в интерфейсе"""
	
	# Обновляем кнопку "Начать играть"
	var start_button = $MainContainer/StartButton
	if start_button:
		var new_text = tr("ui.start.button")
		start_button.text = new_text
	else:
		pass
	
	# Обновляем описание
	var description_label = $MainContainer/DescriptionLabel
	if description_label:
		var new_text = tr("ui.start.description")
		description_label.text = new_text
	else:
		pass
	
	# Обновляем кнопку звука
	_update_mute_button()

func _setup_music_controls():
	"""Настройка элементов управления музыкой"""
	# Подключаем сигналы
	if mute_button:
		mute_button.pressed.connect(_on_mute_button_pressed)
	if volume_slider:
		volume_slider.value_changed.connect(_on_volume_slider_changed)
	
	if music_manager:
		# Устанавливаем начальные значения
		volume_slider.value = _db_to_linear(music_manager.get_volume_db())
		_update_mute_button()
	else:
		# Устанавливаем значения по умолчанию
		if volume_slider:
			volume_slider.value = _db_to_linear(-20.0)
		if mute_button:
			mute_button.text = tr("ui.sound.on")

func _on_mute_button_pressed():
	"""Обработчик нажатия кнопки мьюта"""
	if music_manager:
		music_manager.toggle_mute()
		_update_mute_button()
	else:
		# Fallback режим - переключаем локальное состояние
		is_sound_muted = !is_sound_muted
		_update_fallback_sound()
		_update_mute_button()

func _on_volume_slider_changed(value: float):
	"""Обработчик изменения слайдера громкости"""
	if music_manager:
		var volume_db = _linear_to_db(value)
		music_manager.set_volume_db(volume_db)
	else:
		pass

func _update_mute_button():
	"""Обновляет текст кнопки мьюта"""
	if mute_button:
		if music_manager:
			# Используем состояние из MusicManager
			var is_muted = music_manager.get_is_muted()
			if is_muted:
				mute_button.text = tr("ui.sound.off")
			else:
				mute_button.text = tr("ui.sound.on")
		else:
			# Используем локальное состояние для fallback режима
			if is_sound_muted:
				mute_button.text = tr("ui.sound.off")
			else:
				mute_button.text = tr("ui.sound.on")
	else:
		pass

func _linear_to_db(linear: float) -> float:
	"""Конвертирует линейное значение (0-1) в dB"""
	if linear <= 0.0:
		return -60.0
	return 20.0 * log(linear) / log(10.0)

func _db_to_linear(db: float) -> float:
	"""Конвертирует dB в линейное значение (0-1)"""
	if db <= -60.0:
		return 0.0
	return pow(10.0, db / 20.0)

func _create_fallback_music():
	"""Создает резервный плеер музыки если MusicManager недоступен"""
	fallback_player = AudioStreamPlayer.new()
	
	# Убеждаемся, что шина Music существует
	var music_bus = AudioServer.get_bus_index("Music")
	if music_bus == -1:
		AudioServer.add_bus(1)
		AudioServer.set_bus_name(1, "Music")
		music_bus = 1
	
	fallback_player.bus = "Music"
	
	var stream = load("res://assets/music/music.mp3") as AudioStream
	if stream:
		fallback_player.stream = stream
		fallback_player.volume_db = -20.0
		# Устанавливаем зацикливание для MP3/Ogg файлов
		if stream is AudioStreamOggVorbis or stream is AudioStreamMP3:
			stream.loop = true
		add_child(fallback_player)
		fallback_player.play()
	else:
		pass

func _update_fallback_sound():
	"""Управляет состоянием fallback плеера"""
	if fallback_player:
		if is_sound_muted:
			fallback_player.volume_db = -80.0  # Практически беззвучно
		else:
			fallback_player.volume_db = -20.0  # Нормальная громкость

func _test_music():
	"""Тестирует работу музыки"""
	pass
