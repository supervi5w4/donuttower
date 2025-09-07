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
	
	# Инициализируем игрока для работы с лидербордом
	if YandexSDK:
		YandexSDK.init_player()
		await YandexSDK.player_initialized
		print("StartMenu: Игрок инициализирован для лидерборда")
	
	# Проверяем наличие MusicManager
	if has_node("/root/Music"):
		music_manager = get_node("/root/Music")
		print("StartMenu: MusicManager найден")
	else:
		music_manager = null
		print("StartMenu: MusicManager не найден! Проверьте настройки автозагрузки.")
	
	# Запускаем фоновую музыку
	if music_manager:
		print("StartMenu: Запуск музыки через MusicManager")
		music_manager.play_bgm("res://assets/music/music.mp3", -20.0, true)
	else:
		# Альтернативный способ - создаем локальный плеер
		_create_fallback_music()
	
	# Настраиваем элементы управления в любом случае
	_setup_music_controls()

func _on_start_button_pressed():
	# Запускаем первый уровень с превью
	LevelData.start_level(1)

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
	print("StartMenu: Настройка элементов управления музыкой")
	# Подключаем сигналы
	if mute_button:
		print("StartMenu: mute_button найден")
	else:
		print("StartMenu: mute_button не найден!")
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
	print("StartMenu: Кнопка звука нажата!")
	if music_manager:
		print("StartMenu: Используем MusicManager")
		music_manager.toggle_mute()
		_update_mute_button()
	else:
		# Fallback режим - переключаем локальное состояние
		print("StartMenu: Используем fallback режим")
		is_sound_muted = !is_sound_muted
		_update_fallback_sound()
		_update_mute_button()
		print("StartMenu: Переключение звука в fallback режиме: ", "ВЫКЛ" if is_sound_muted else "ВКЛ")

func _on_volume_slider_changed(value: float):
	"""Обработчик изменения слайдера громкости"""
	if music_manager:
		var volume_db = _linear_to_db(value)
		music_manager.set_volume_db(volume_db)
	else:
		print("StartMenu: MusicManager недоступен для изменения громкости")

func _update_mute_button():
	"""Обновляет текст кнопки мьюта"""
	if mute_button:
		if music_manager:
			# Используем состояние из MusicManager
			if music_manager.is_muted:
				mute_button.text = tr("ui.sound.off")
				print("StartMenu: Обновляем кнопку на ВЫКЛ (MusicManager)")
			else:
				mute_button.text = tr("ui.sound.on")
				print("StartMenu: Обновляем кнопку на ВКЛ (MusicManager)")
		else:
			# Используем локальное состояние для fallback режима
			if is_sound_muted:
				mute_button.text = tr("ui.sound.off")
				print("StartMenu: Обновляем кнопку на ВЫКЛ (fallback)")
			else:
				mute_button.text = tr("ui.sound.on")
				print("StartMenu: Обновляем кнопку на ВКЛ (fallback)")
	else:
		print("StartMenu: mute_button не найден!")

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
	var stream = load("res://assets/music/music.mp3") as AudioStream
	if stream:
		fallback_player.stream = stream
		fallback_player.volume_db = -20.0
		# Устанавливаем зацикливание для MP3/Ogg файлов
		if stream is AudioStreamOggVorbis or stream is AudioStreamMP3:
			stream.loop = true
		add_child(fallback_player)
		fallback_player.play()
		print("StartMenu: Запущен резервный плеер музыки")
	else:
		print("StartMenu: Не удалось загрузить файл музыки")

func _update_fallback_sound():
	"""Управляет состоянием fallback плеера"""
	if fallback_player:
		if is_sound_muted:
			fallback_player.volume_db = -80.0  # Практически беззвучно
		else:
			fallback_player.volume_db = -20.0  # Нормальная громкость
