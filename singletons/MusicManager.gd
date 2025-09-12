extends Node

# Система управления музыкой с кросс-фейдом и персистентностью
class_name MusicManager

# Сигналы
signal music_started(track_name: String)
signal music_stopped()
signal volume_changed(volume_db: float)
signal mute_toggled(is_muted: bool)

# Настройки
const CROSSFADE_DURATION = 2.0
const DEFAULT_VOLUME_DB = -20.0
const MIN_VOLUME_DB = -60.0
const MAX_VOLUME_DB = 0.0

# Текущее состояние
var current_track: String = ""
var is_muted: bool = false
var target_volume_db: float = DEFAULT_VOLUME_DB
var is_crossfading: bool = false

# AudioStreamPlayer узлы для кросс-фейда
var player1: AudioStreamPlayer
var player2: AudioStreamPlayer
var active_player: AudioStreamPlayer
var fade_player: AudioStreamPlayer

# Таймеры для кросс-фейда
var fade_in_timer: Timer
var fade_out_timer: Timer

func _ready() -> void:
	# Настройка аудио шины с fallback на Master
	_setup_audio_bus()
	
	# Инициализация плееров
	player1 = AudioStreamPlayer.new()
	player2 = AudioStreamPlayer.new()
	
	# Настройка плееров
	player1.bus = _get_music_bus_name()
	player2.bus = _get_music_bus_name()
	player1.volume_db = MIN_VOLUME_DB
	player2.volume_db = MIN_VOLUME_DB
	
	add_child(player1)
	add_child(player2)
	
	active_player = player1
	fade_player = player2
	
	# Настройка таймеров
	fade_in_timer = Timer.new()
	fade_out_timer = Timer.new()
	fade_in_timer.wait_time = CROSSFADE_DURATION
	fade_out_timer.wait_time = CROSSFADE_DURATION
	fade_in_timer.one_shot = true
	fade_out_timer.one_shot = true
	
	fade_in_timer.timeout.connect(_on_fade_in_complete)
	fade_out_timer.timeout.connect(_on_fade_out_complete)
	
	add_child(fade_in_timer)
	add_child(fade_out_timer)
	
	# Загружаем сохраненные настройки
	_load_settings()
	
	# Устанавливаем начальную громкость
	set_volume_db(target_volume_db)
	
	# Автоматически запускаем стартовую музыку
	_auto_start_music()

# Воспроизведение музыки с кросс-фейдом
func play_bgm(track_path: String, volume_db: float = DEFAULT_VOLUME_DB, loop: bool = true) -> void:
	
	# Предотвращаем дублирование - если тот же трек уже играет, не перезапускаем
	if current_track == track_path and active_player.playing:
		return
	
	var stream = load(track_path) as AudioStream
	if not stream:
		push_error("Не удалось загрузить трек: " + track_path)
		return
	
	
	current_track = track_path
	target_volume_db = volume_db
	
	# Если музыка уже играет, делаем кросс-фейд
	if active_player.playing and not is_crossfading:
		_crossfade_to_new_track(stream, loop)
	else:
		# Простое воспроизведение
		active_player.stream = stream
		_set_stream_loop(stream, loop)
		active_player.play()
		_fade_in(active_player)
	
	music_started.emit(track_path)

# Остановка музыки с кросс-фейдом
func stop_bgm() -> void:
	if not active_player.playing:
		return
	
	_fade_out(active_player)
	current_track = ""
	music_stopped.emit()

# Кросс-фейд к новому треку
func _crossfade_to_new_track(stream: AudioStream, loop: bool) -> void:
	is_crossfading = true
	
	# Настраиваем новый плеер
	fade_player.stream = stream
	_set_stream_loop(stream, loop)
	fade_player.volume_db = MIN_VOLUME_DB
	fade_player.play()
	
	# Запускаем кросс-фейд
	_fade_in(fade_player)
	_fade_out(active_player)
	
	# Меняем активные плееры
	var temp = active_player
	active_player = fade_player
	fade_player = temp

# Плавное появление
func _fade_in(player: AudioStreamPlayer) -> void:
	player.volume_db = MIN_VOLUME_DB
	fade_in_timer.start()
	
	var tween = create_tween()
	tween.tween_method(
		func(vol): player.volume_db = vol,
		MIN_VOLUME_DB,
		target_volume_db,
		CROSSFADE_DURATION
	)

# Плавное затухание
func _fade_out(player: AudioStreamPlayer) -> void:
	fade_out_timer.start()
	
	var tween = create_tween()
	tween.tween_method(
		func(vol): player.volume_db = vol,
		player.volume_db,
		MIN_VOLUME_DB,
		CROSSFADE_DURATION
	)

# Завершение появления
func _on_fade_in_complete() -> void:
	if is_crossfading:
		is_crossfading = false

# Завершение затухания
func _on_fade_out_complete() -> void:
	fade_player.stop()

# Установка громкости
func set_volume_db(volume_db: float) -> void:
	volume_db = clamp(volume_db, MIN_VOLUME_DB, MAX_VOLUME_DB)
	target_volume_db = volume_db
	
	if not is_muted:
		active_player.volume_db = volume_db
		if is_crossfading:
			fade_player.volume_db = volume_db
	
	volume_changed.emit(volume_db)
	_save_settings()

# Переключение мьюта
func toggle_mute() -> void:
	is_muted = !is_muted
	
	# Мьютируем/размьютируем шину
	var bus_index = AudioServer.get_bus_index(_get_music_bus_name())
	AudioServer.set_bus_mute(bus_index, is_muted)
	
	if is_muted:
		active_player.volume_db = MIN_VOLUME_DB
		if is_crossfading:
			fade_player.volume_db = MIN_VOLUME_DB
	else:
		active_player.volume_db = target_volume_db
		if is_crossfading:
			fade_player.volume_db = target_volume_db
	
	mute_toggled.emit(is_muted)
	_save_settings()

# Получение текущей громкости
func get_volume_db() -> float:
	return target_volume_db

# Получение состояния мьюта
func get_is_muted() -> bool:
	return is_muted

# Проверка, играет ли музыка
func is_playing() -> bool:
	return active_player.playing

# Получение текущего трека
func get_current_track() -> String:
	return current_track

# Сохранение настроек
func _save_settings() -> void:
	var settings = {
		"volume_db": target_volume_db,
		"is_muted": is_muted,
		"current_track": current_track
	}
	
	var file = FileAccess.open("user://music_settings.dat", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(settings))
		file.close()

# Настройка аудио шины с fallback
func _setup_audio_bus() -> void:
	var music_bus_index = AudioServer.get_bus_index("Music")
	if music_bus_index == -1:
		# Создаем шину Music если её нет
		AudioServer.add_bus(1)
		AudioServer.set_bus_name(1, "Music")
	else:
		pass

# Получение имени аудио шины с fallback
func _get_music_bus_name() -> String:
	var music_bus_index = AudioServer.get_bus_index("Music")
	if music_bus_index != -1:
		return "Music"
	else:
		return "Master"

# Автоматический запуск стартовой музыки
func _auto_start_music() -> void:
	# Ждем один кадр, чтобы все автозагружаемые синглтоны инициализировались
	await get_tree().process_frame
	
	# Проверяем, не играет ли уже музыка
	if not is_playing():
		play_bgm("res://assets/music/music.mp3", DEFAULT_VOLUME_DB, true)

# Настройка зацикливания для различных типов аудио потоков
func _set_stream_loop(stream: AudioStream, loop: bool) -> void:
	if stream is AudioStreamOggVorbis:
		stream.loop = loop
	elif stream is AudioStreamMP3:
		stream.loop = loop
	elif stream is AudioStreamWAV:
		# Для WAV файлов зацикливание настраивается через AudioStreamWAV
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD if loop else AudioStreamWAV.LOOP_DISABLED

# Загрузка настроек
func _load_settings() -> void:
	var file = FileAccess.open("user://music_settings.dat", FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		file.close()
		
		var json = JSON.new()
		var parse_result = json.parse(json_string)
		
		if parse_result == OK:
			var settings = json.data
			target_volume_db = settings.get("volume_db", DEFAULT_VOLUME_DB)
			is_muted = settings.get("is_muted", false)
			# Синхронизируем состояние шины с загруженным состоянием мьюта
			var bus_index = AudioServer.get_bus_index(_get_music_bus_name())
			AudioServer.set_bus_mute(bus_index, is_muted)
			# Не восстанавливаем current_track, чтобы музыка не начиналась автоматически
