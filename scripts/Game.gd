extends Node2D
## Шаг 8: баланс/сложность + всё с предыдущих шагов.
## - Скорость каретки растёт с очками.
## - Камера даёт больший запас над вершиной при высоком счёте.
## - Верхние пончики стабильнее: повышаем angular_damp и "мягчим" пороги settle.
## - Без тернарного ? : (используем a if cond else b).
## - Явные типы (treat warnings as errors).

const VIRT_W := 720.0
const VIRT_H := 1280.0

const POOL_SIZE := 24
const SPAWN_COOLDOWN := 0.08
const DONUT_SCENE := preload("res://scenes/Donut.tscn")

# Базовый уровень пола для пересчёта вершины башни
const _floor_y := 1200.0

const SAVE_PATH := "user://save.cfg"
const SAVE_SECTION := "stats"
const SAVE_KEY_BEST := "best"

enum GameState { READY, PLAY, GAMEOVER }

@onready var cam: Camera2D = get_node("Camera2D")
@onready var ui_root: Control = get_node("UI/UIRoot")
@onready var score_label: Label = get_node("UI/UIRoot/ScoreLabel")
@onready var game_over_panel: Control = get_node("UI/UIRoot/GameOverPanel")
@onready var game_over_score_label: Label = get_node("UI/UIRoot/GameOverPanel/MainContainer/ScoreLabel")
@onready var player_rank_label: Label = get_node("UI/UIRoot/GameOverPanel/MainContainer/PlayerRankLabel")
@onready var menu_button: Button = get_node("UI/UIRoot/GameOverPanel/MainContainer/MenuButton")
@onready var leaderboard_panel: Control = get_node("UI/UIRoot/GameOverPanel/MainContainer/LeaderboardPanel")
@onready var spawner: Spawner = get_node("Spawner")
# YandexSDK теперь доступен как автозагруженный синглтон
@onready var preview: PreviewDonut = spawner.get_node("PreviewDonut")

# Таймер для задержки показа рекламы
var _ad_delay_timer: Timer

# Переменные для кулдауна рекламы
var _last_ad_time: float = 0.0
const AD_COOLDOWN := 50.0

var donut_pool: Array[RigidBody2D] = []
var active_donuts: Array[RigidBody2D] = []
var donuts: Array[Donut] = []

var _last_spawn_time: float = 0.0
var score: int = 0
var combo_lock: bool = false
var _best: int = 0
var _state: int = GameState.READY
var _leaderboard_ready: bool = false
var next_style: String = "pink"

# Камера / башня
var _cam_start_y: float = 640.0
var _cam_margin: float = VIRT_H * 0.35
var _tower_top_y: float = 1280.0

# ===== Сложность =====
const SPAWNER_BASE_SPEED := 320.0      # px/s при Score=0 (увеличено с 250)
const SPAWNER_MAX_FACTOR := 2.2        # максимум множителя скорости (увеличено с 1.6)
const SPAWNER_SCORE_RATE := 0.035      # +3.5% скорости за очко (увеличено с 2%)

const CAM_MARGIN_MIN := 0.35           # 35% высоты экрана
const CAM_MARGIN_MAX := 0.45           # до 45% при большом счёте
const CAM_MARGIN_SCORE_CAP := 20       # к ~20 очкам достигаем CAM_MARGIN_MAX

const DAMP_BASE := 0.70                # angular_damp базовый
const DAMP_MAX := 1.00                 # верхняя граница
const DAMP_SCORE_RATE := 0.01          # +0.01 за очко (к ~30 очкам ≈1.0)

const SETTLE_LIN_BASE := 8.0           # базовый линейный порог
const SETTLE_LIN_MAX := 12.0           # предел "мягкости" линейного порога
const SETTLE_ANG_BASE := 0.6           # базовый угловой порог
const SETTLE_ANG_MAX := 1.0            # предел "мягкости" углового порога
const SETTLE_RATE := 0.10              # вклад в линейный порог на очко
const SETTLE_ANG_RATE := 0.02          # вклад в угловой порог на очко

func _ready() -> void:
	_load_best_from_disk()
	_init_donut_pool()
	_update_score_label()
	_hide_game_over()
	_setup_yandex_sdk()
	_setup_ad_delay_timer()
	_setup_language_manager()

	# Камера
	if cam != null:
		cam.position = Vector2(VIRT_W * 0.5, VIRT_H * 0.5)
		_cam_start_y = cam.position.y
		_tower_top_y = cam.position.y + VIRT_H * 0.5
		_apply_camera_limits()

	# Применить сложность на старте
	_recalc_difficulty()
	
	# Выбираем первый стиль и обновляем превью
	_select_next_style()
	_update_preview()

func _process(_delta: float) -> void:
	_cleanup_fallen()
	# _update_camera_follow()  # Отключено - камера больше не следует за башней

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_SIZE_CHANGED:
		_apply_camera_limits()
		if cam != null:
			cam.position.x = VIRT_W * 0.5

# ===== Ввод =====
func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		_on_tap(event.position)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_tap(event.position)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		_on_tap(event.position)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_tap(event.position)

func _on_tap(_pos: Vector2) -> void:
	
	if _state == GameState.READY:
		_start_game()
		return
	if _state != GameState.PLAY:
		return
	if game_over_panel.visible:
		return
	if not _cooldown_ready():
		return
	var spawn_pos: Vector2
	if spawner != null:
		spawn_pos = spawner.get_spawn_position()
	else:
		spawn_pos = Vector2(VIRT_W * 0.5, 120.0)
	if preview != null:
		preview.flash_drop()
	else:
		pass
	_spawn_donut(spawn_pos)

func _start_game() -> void:
	_state = GameState.PLAY
	
	# Дополнительная очистка перед началом игры
	_cleanup_fallen()
	
	# Запускаем аналитику
	YandexSdk.gameplay_started()
	
	# Спавним первый пончик
	var spawn_pos: Vector2
	if spawner != null:
		spawn_pos = spawner.get_spawn_position()
	else:
		spawn_pos = Vector2(VIRT_W * 0.5, 120.0)
	_spawn_donut(spawn_pos)
	_last_spawn_time = float(Time.get_ticks_msec()) / 1000.0

func _cooldown_ready() -> bool:
	var t: float = float(Time.get_ticks_msec()) / 1000.0
	return t - _last_spawn_time >= SPAWN_COOLDOWN

func _select_next_style() -> void:
	# Получаем все доступные стили из Donut.DONUT_TEXTURES
	var available_styles: Array[String] = []
	for key in Donut.DONUT_TEXTURES.keys():
		available_styles.append(key as String)
	
	if available_styles.is_empty():
		next_style = "pink"
		return
	
	# Выбираем случайный стиль
	var random_index: int = randi() % available_styles.size()
	next_style = available_styles[random_index]

func _update_preview() -> void:
	if preview != null and preview.has_method("set_texture"):
		# Получаем текстуру по стилю и передаем напрямую
		if Donut.DONUT_TEXTURES.has(next_style):
			var texture: Texture2D = Donut.DONUT_TEXTURES[next_style]
			preview.set_texture(texture)

# ===== Пул пончиков =====
func _init_donut_pool() -> void:
	donut_pool.clear()
	active_donuts.clear()
	for i in POOL_SIZE:
		var node: Node = DONUT_SCENE.instantiate()
		var d: RigidBody2D = node as RigidBody2D
		if d == null:
			push_error("Donut.tscn root не RigidBody2D — исправьте сцену Donut.")
			if node != null:
				node.free()
			continue
		add_child(d)
		_sleep_and_hide(d)
		donut_pool.append(d)

func _spawn_donut(world_pos: Vector2) -> void:
	var d: RigidBody2D = _take_from_pool()
	if d == null:
		var node: Node = DONUT_SCENE.instantiate()
		d = node as RigidBody2D
		if d == null:
			if node != null:
				node.free()
			return
		add_child(d)
	else:
		pass
	
	d.visible = true

	# Сначала сбрасываем внутреннее состояние пончика
	if d.has_method("reset_state"):
		d.reset_state()
	
	# Устанавливаем стиль пончика
	if d.has_method("set_style"):
		d.set_style(next_style)
	
	# Затем устанавливаем позицию и дополнительные свойства
	d.global_position = world_pos
	d.set("bottom_y_limit", get_world_bottom_limit() + 100.0)
	d.set_process(true)
	d.set_physics_process(true)

	# Стабильность верхних пончиков по мере роста счёта
	var damp: float = clamp(DAMP_BASE + float(score) * DAMP_SCORE_RATE, DAMP_BASE, DAMP_MAX)
	d.angular_damp = damp
	var lin_thr: float = clamp(SETTLE_LIN_BASE + float(score) * SETTLE_RATE, SETTLE_LIN_BASE, SETTLE_LIN_MAX)
	var ang_thr: float = clamp(SETTLE_ANG_BASE + float(score) * SETTLE_ANG_RATE, SETTLE_ANG_BASE, SETTLE_ANG_MAX)
	d.set("settle_linear_speed_threshold", lin_thr)
	d.set("settle_angular_speed_threshold", ang_thr)

	# Сигналы (сначала очищаем старые коннекты)
	_reset_donut_signals(d)
	var donut_obj: Object = d
	d.connect("settled", Callable(self, "_on_donut_settled").bind(donut_obj))
	d.connect("missed", Callable(self, "_on_donut_missed").bind(donut_obj))

	active_donuts.append(d)
	donuts.append(d as Donut)
	
	# Обновляем время последнего спавна
	_last_spawn_time = float(Time.get_ticks_msec()) / 1000.0
	
	# Выбираем следующий стиль и обновляем превью
	_select_next_style()
	_update_preview()

func _take_from_pool() -> RigidBody2D:
	if donut_pool.is_empty():
		return null
	var d: RigidBody2D = null
	while not donut_pool.is_empty() and d == null:
		d = donut_pool.pop_back()
		if d == null or not is_instance_valid(d):
			d = null
	if d != null:
		d.visible = true
	return d

func _recycle_donut(d: RigidBody2D) -> void:
	if d == null or not is_instance_valid(d):
		return
	if active_donuts.has(d):
		active_donuts.erase(d)
	else:
		pass

	var donut_inst: Donut = d as Donut
	if donut_inst != null and donuts.has(donut_inst):
		donuts.erase(donut_inst)

	_reset_donut_signals(d)
	if d.has_method("reset_state"):
		d.reset_state()

	_sleep_and_hide(d)
	donut_pool.append(d)

func _sleep_and_hide(d: RigidBody2D) -> void:
	if d == null or not is_instance_valid(d):
		return
	# Устанавливаем статический режим для хранения в пуле
	d.freeze_mode = RigidBody2D.FREEZE_MODE_STATIC
	d.freeze = true
	d.sleeping = true
	d.set_process(false)
	d.set_physics_process(false)
	d.global_position = Vector2(-10000.0, -10000.0)
	d.scale = Vector2.ONE  # Сброс масштаба к оригинальному размеру
	d.visible = false
	# Дополнительный сброс физических свойств
	d.linear_velocity = Vector2.ZERO
	d.angular_velocity = 0.0

func _cleanup_fallen() -> void:
	if active_donuts.is_empty():
		return
	donuts = donuts.filter(func(x): return is_instance_valid(x))
	var threshold: float = cam.position.y + VIRT_H * 2.0 if cam != null else VIRT_H * 2.0
	var _cam_y: float = cam.position.y if cam != null else 0.0
	
	# Создаём новый массив только с валидными объектами
	var valid_donuts: Array[RigidBody2D] = []
	for d in active_donuts:
		if d != null and is_instance_valid(d):
			valid_donuts.append(d)
			if d.global_position.y > threshold:
				_recycle_donut(d)
	active_donuts = valid_donuts

func _reset_donut_signals(d: RigidBody2D) -> void:
	for c in d.get_signal_connection_list("settled"):
		d.disconnect("settled", c.callable)
	for c in d.get_signal_connection_list("missed"):
		d.disconnect("missed", c.callable)

# ===== Камера и башня =====
func _apply_camera_limits() -> void:
	if cam == null:
		return
	cam.limit_left = 0
	cam.limit_right = int(VIRT_W)
	cam.limit_top = -100000
	cam.limit_bottom = int(VIRT_H)

# func _update_camera_follow() -> void:
#     if cam == null:
#         return
#     # Цель — держать вершину башни с запасом _cam_margin
#     var target_y: float = min(_cam_start_y, _tower_top_y - _cam_margin)
#     if target_y < cam.position.y:
#         cam.position.y = target_y

func _on_donut_settled(donut_obj: Object) -> void:
	var d := donut_obj as RigidBody2D
	if d == null or not is_instance_valid(d):
		return

	score += 1
	_update_score_label()

	# сохраняем Y до await (после await d может быть удалён)
	var y_before := d.global_position.y

	# пусть check_touch_chain() вернёт true, если что‑то удалялось
	var removed_any := await check_touch_chain()

	# обновляем вершину башни
	if removed_any:
		_recompute_tower_top_y()
	else:
		# d всё ещё может пропасть по другим причинам — подстрахуемся
		_tower_top_y = min(_tower_top_y, y_before)

	_recalc_difficulty()

func _on_donut_missed(donut_obj: Object) -> void:
	var d: RigidBody2D = donut_obj as RigidBody2D
	if d != null and is_instance_valid(d):
		pass
	else:
		pass
	_set_game_over()

# ===== Сложность: скорость каретки и запас камеры =====
func _recalc_difficulty() -> void:
	# Скорость каретки: base * clamp(1 + score*rate, 1, MAX_FACTOR)
	var factor: float = 1.0 + float(score) * SPAWNER_SCORE_RATE
	if factor > SPAWNER_MAX_FACTOR:
		factor = SPAWNER_MAX_FACTOR
	if spawner != null:
		spawner.speed = SPAWNER_BASE_SPEED * factor

	# Запас камеры: линейная интерполяция от MIN к MAX к ~20 очкам
	var t: float = float(score)
	if t > float(CAM_MARGIN_SCORE_CAP):
		t = float(CAM_MARGIN_SCORE_CAP)
	var k: float = t / float(CAM_MARGIN_SCORE_CAP) # 0..1
	var margin_ratio: float = CAM_MARGIN_MIN + (CAM_MARGIN_MAX - CAM_MARGIN_MIN) * k
	_cam_margin = VIRT_H * margin_ratio

# ===== Game Over / Restart / Continue / Save =====
func _set_game_over() -> void:
	if _state == GameState.GAMEOVER:
		return
	_state = GameState.GAMEOVER
	
	# Останавливаем аналитику
	YandexSdk.gameplay_stopped()
	
	# Проверяем, побит ли рекорд
	if score > _best:
		_best = score
		_save_best_to_disk()
	
	# Сохраняем статистику игры
	_save_game_stats()
	
	# Обновляем отображение очков
	_update_game_over_score()
	_update_score_label()
	_show_game_over()
	
	# Отправляем результат в лидерборд
	_submit_score_to_leaderboard()
	
	# Загружаем и показываем лидерборд
	_load_and_show_leaderboard()
	
	# Загружаем запись игрока в лидерборде
	_load_player_leaderboard_entry()
	
	# Запускаем таймер для показа рекламы через 3 секунды
	_start_ad_delay_timer()

func _on_restart_pressed() -> void:
	# Останавливаем таймер рекламы, если он активен
	_stop_ad_delay_timer()
	# Загружаем главное меню вместо сброса игры
	get_tree().change_scene_to_file("res://scenes/StartMenu.tscn")


func _reset_game() -> void:
	
	# Полная очистка всех активных пончиков
	for d in active_donuts.duplicate():
		_recycle_donut(d)
	
	# Очистка всех пончиков в пуле - сброс состояния и сигналов
	for d in donut_pool:
		if d != null and is_instance_valid(d):
			_reset_donut_signals(d)
			_sleep_and_hide(d)
			# Сброс внутреннего состояния пончика
			if d.has_method("reset_state"):
				d.reset_state()
	
	# Сброс игровых переменных
	score = 0
	_last_spawn_time = 0.0
	_state = GameState.READY
	_update_score_label()
	_hide_game_over()
	
	# Камера: вернуть ориентиры; позицию — к стартовой
	if cam != null:
		_tower_top_y = cam.position.y + VIRT_H * 0.5
		cam.position.y = _cam_start_y
	
	# Пересчитать сложность под нулевой счёт
	_recalc_difficulty()
	
	# Сброс масштаба превью пончика
	if preview != null:
		preview.reset_scale()
	
	# Выбираем новый стиль и обновляем превью
	_select_next_style()
	_update_preview()
	

func _load_best_from_disk() -> void:
	# Используем YandexSdk для загрузки данных
	if OS.has_feature("yandex"):
		YandexSdk.load_data(["best_score"])
		# Подключаемся к сигналу загрузки данных
		if not YandexSdk.data_loaded.is_connected(_on_data_loaded):
			YandexSdk.data_loaded.connect(_on_data_loaded)
		
		# Загружаем статистику
		YandexSdk.load_stats(["games_played", "total_score", "best_score"])
		# Подключаемся к сигналу загрузки статистики
		if not YandexSdk.stats_loaded.is_connected(_on_stats_loaded):
			YandexSdk.stats_loaded.connect(_on_stats_loaded)
		
		# Загружаем все данные
		YandexSdk.load_all_data()
		
		# Загружаем всю статистику
		YandexSdk.load_all_stats()
	else:
		# Fallback на локальное сохранение для не-веб платформ
		var cfg := ConfigFile.new()
		var err: int = cfg.load(SAVE_PATH)
		if err != OK:
			_best = 0
			return
		_best = int(cfg.get_value(SAVE_SECTION, SAVE_KEY_BEST, 0))

func _save_best_to_disk() -> void:
	# Используем YandexSdk для сохранения данных
	if OS.has_feature("yandex"):
		YandexSdk.save_data({"best_score": _best}, true)
	else:
		# Fallback на локальное сохранение для не-веб платформ
		var cfg := ConfigFile.new()
		cfg.set_value(SAVE_SECTION, SAVE_KEY_BEST, _best)
		var err: int = cfg.save(SAVE_PATH)
		if err != OK:
			push_warning(tr("ui.error.save_record") + " " + SAVE_PATH)

# ===== Вспомогательные =====
func get_world_bottom_limit() -> float:
	return cam.position.y + VIRT_H if cam != null else VIRT_H

func _update_score_label() -> void:
	if score_label:
		score_label.text = tr("ui.hud.score") + ": " + str(score)

func _update_game_over_score() -> void:
	"""Обновляет отображение счета в GameOverPanel"""
	if game_over_score_label:
		game_over_score_label.text = tr("ui.gameover.your_score") + ": " + str(score)

func _update_player_rank_display(rank_text: String) -> void:
	"""Обновляет отображение рейтинга игрока в GameOverPanel"""
	if player_rank_label:
		player_rank_label.text = rank_text
		# Скрываем label, если текст пустой
		player_rank_label.visible = not rank_text.is_empty()

func _show_game_over() -> void:
	game_over_panel.visible = true

func _hide_game_over() -> void:
	game_over_panel.visible = false

# ===== Яндекс SDK и реклама =====
func _setup_yandex_sdk() -> void:
	# Подключаем сигналы от официального YandexSdk
	YandexSdk.interstitial_ad.connect(_on_interstitial_ad)
	YandexSdk.rewarded_ad.connect(_on_rewarded_ad)
	YandexSdk.leaderboard_initialized.connect(_on_leaderboard_initialized)
	YandexSdk.leaderboard_entries_loaded.connect(_on_leaderboard_entries_loaded)
	YandexSdk.leaderboard_player_entry_loaded.connect(_on_leaderboard_player_entry_loaded)
	YandexSdk.stats_loaded.connect(_on_stats_loaded)
	
	# Запускаем асинхронную инициализацию
	_initialize_yandex_sdk_async()

func _initialize_yandex_sdk_async() -> void:
	"""Асинхронная инициализация YandexSdk"""
	# Проверяем, что игра еще не инициализируется
	if not YandexSdk.is_game_initialization_started and not YandexSdk.is_game_initialized:
		print("Game: Инициализируем YandexSdk игру...")
		YandexSdk.init_game()
		await YandexSdk.game_initialized
		print("Game: YandexSdk игра инициализирована")
	elif YandexSdk.is_game_initialized:
		print("Game: YandexSdk игра уже инициализирована")
	else:
		print("Game: YandexSdk игра уже инициализируется, ждем...")
		await YandexSdk.game_initialized
		print("Game: YandexSdk игра инициализирована")
	
	# Инициализируем лидерборд (хотя метод помечен как устаревший, он все еще нужен)
	print("Game: Инициализируем лидерборд...")
	YandexSdk.init_leaderboard()
	
	# Вызываем Game Ready API
	print("Game: Вызываем Game Ready API...")
	YandexSdk.game_ready()
	
	# Game Ready API вызывается без дополнительных сигналов

func _show_interstitial_ad() -> void:
	"""Показывает Interstitial рекламу при Game Over"""
	YandexSdk.show_interstitial_ad()


func _on_interstitial_ad(result: String) -> void:
	"""Обработчик результата Interstitial рекламы"""
	match result:
		"opened":
			print("Interstitial реклама открыта")
		"closed":
			print("Interstitial реклама закрыта")
		"error":
			print("Ошибка показа Interstitial рекламы")

func _on_rewarded_ad(result: String) -> void:
	"""Обработчик результата Rewarded рекламы"""
	match result:
		"opened":
			print("Rewarded реклама открыта")
		"rewarded":
			print("Награда получена!")
		"closed":
			print("Rewarded реклама закрыта")
		"error":
			print("Ошибка показа Rewarded рекламы")

func _on_leaderboard_initialized() -> void:
	"""Обработчик инициализации лидерборда"""
	print("Game: Лидерборд инициализирован")
	print("Game: YandexSdk.is_leaderboard_initialized = ", YandexSdk.is_leaderboard_initialized)
	_leaderboard_ready = true

func _on_data_loaded(data: Dictionary) -> void:
	"""Обработчик загрузки данных от YandexSdk"""
	print("Game: Данные загружены: ", data)
	if data.has("best_score"):
		_best = int(data["best_score"])
		print("Game: Лучший результат загружен: ", _best)

func _on_stats_loaded(stats: Dictionary) -> void:
	"""Обработчик загрузки статистики от YandexSdk"""
	print("Game: Статистика загружена: ", stats)
	if stats.has("best_score"):
		_best = int(stats["best_score"])
		print("Game: Лучший результат из статистики: ", _best)

func _on_leaderboard_entries_loaded(data: Dictionary) -> void:
	"""Обработчик загрузки записей лидерборда"""
	print("Game: Записи лидерборда загружены: ", data)
	# Здесь можно обновить UI лидерборда с полученными данными

func _on_leaderboard_player_entry_loaded(data: Dictionary) -> void:
	"""Обработчик загрузки записи игрока в лидерборде"""
	print("Game: Запись игрока в лидерборде загружена: ", data)
	
	# Проверяем, что данные содержат необходимую информацию
	if data.is_empty():
		print("Game: Запись игрока в лидерборде отсутствует - игрок еще не участвовал в рейтинге")
		_update_player_rank_display("")
		return
	
	# Извлекаем рейтинг и лучший результат
	var rank: int = data.get("rank", 0)
	var score: int = data.get("score", 0)
	
	# Проверяем наличие ключей в данных
	if not data.has("rank") or not data.has("score"):
		print("Game: Неполные данные записи игрока в лидерборде")
		_update_player_rank_display("")
		return
	
	if rank > 0 and score > 0:
		# Отображаем рейтинг и лучший результат
		var rank_text: String = "Ваш рейтинг: #" + str(rank) + " (лучший результат: " + str(score) + ")"
		_update_player_rank_display(rank_text)
		print("Game: Рейтинг игрока: #", rank, ", лучший результат: ", score)
	else:
		# Если нет валидных данных, скрываем отображение
		print("Game: Нет валидных данных о рейтинге игрока (rank: ", rank, ", score: ", score, ")")
		_update_player_rank_display("")


func _save_game_stats() -> void:
	"""Сохраняет статистику игры"""
	if OS.has_feature("yandex"):
		var stats = {
			"games_played": 1,
			"total_score": score,
			"best_score": _best
		}
		YandexSdk.save_stats(stats)
		print("Game: Статистика сохранена: ", stats)
		
		# Инкрементируем счетчик игр
		var increments = {
			"games_played": 1
		}
		YandexSdk.increment_stats(increments)
		print("Game: Статистика инкрементирована: ", increments)

# ===== Лидерборд =====
func _submit_score_to_leaderboard() -> void:
	"""Отправляет результат игрока в лидерборд"""
	print("Game: Отправка результата в лидерборд: ", score, " очков")
	
	# Проверяем, что мы на веб-платформе
	if not OS.has_feature("yandex"):
		print("Game: Не веб-платформа, лидерборд недоступен")
		return
	
	# Ждем инициализации лидерборда
	if not _leaderboard_ready and not YandexSdk.is_leaderboard_initialized:
		print("Game: Лидерборд еще не готов, ждем инициализации...")
		await YandexSdk.leaderboard_initialized
		_leaderboard_ready = true
	elif YandexSdk.is_leaderboard_initialized:
		_leaderboard_ready = true
	
	# Проверяем авторизацию перед отправкой
	YandexSdk.check_is_authorized()
	# Подключаемся к сигналу проверки авторизации (отключаем предыдущие подключения)
	if YandexSdk.check_auth.is_connected(_on_auth_checked):
		YandexSdk.check_auth.disconnect(_on_auth_checked)
	YandexSdk.check_auth.connect(_on_auth_checked)

func _on_auth_checked(is_authorized: bool) -> void:
	"""Обработчик проверки авторизации"""
	print("Game: Авторизация проверена: ", is_authorized)
	
	# Отключаем сигнал после получения результата
	if YandexSdk.check_auth.is_connected(_on_auth_checked):
		YandexSdk.check_auth.disconnect(_on_auth_checked)
	
	if is_authorized:
		# Отправляем результат в лидерборд
		YandexSdk.save_leaderboard_score("donuttowerleaderboard", score)
	else:
		print("Game: Пользователь не авторизован, результат не отправлен в лидерборд")
		# Можно предложить авторизацию
		YandexSdk.open_auth_dialog()

func _load_and_show_leaderboard() -> void:
	"""Загружает и показывает лидерборд"""
	# Загружаем лидерборд через LeaderboardPanel
	if leaderboard_panel != null and leaderboard_panel.has_method("load_leaderboard"):
		leaderboard_panel.load_leaderboard()
	else:
		print("Game: LeaderboardPanel не найден или не имеет метода load_leaderboard")

func _load_player_leaderboard_entry() -> void:
	"""Загружает запись игрока в лидерборде"""
	# Проверяем, что мы на веб-платформе
	if not OS.has_feature("yandex"):
		print("Game: Не веб-платформа, лидерборд недоступен")
		_update_player_rank_display("")
		return
	
	# Ждем инициализации лидерборда
	if not _leaderboard_ready and not YandexSdk.is_leaderboard_initialized:
		print("Game: Лидерборд еще не готов для загрузки записи игрока, ждем инициализации...")
		await YandexSdk.leaderboard_initialized
		_leaderboard_ready = true
	elif YandexSdk.is_leaderboard_initialized:
		_leaderboard_ready = true
	
	# Проверяем авторизацию перед загрузкой записи игрока
	YandexSdk.check_is_authorized()
	# Подключаемся к сигналу проверки авторизации (отключаем предыдущие подключения)
	if YandexSdk.check_auth.is_connected(_on_auth_checked_for_player_entry):
		YandexSdk.check_auth.disconnect(_on_auth_checked_for_player_entry)
	YandexSdk.check_auth.connect(_on_auth_checked_for_player_entry)

func _on_auth_checked_for_player_entry(is_authorized: bool) -> void:
	"""Обработчик проверки авторизации для загрузки записи игрока"""
	print("Game: Авторизация для загрузки записи игрока проверена: ", is_authorized)
	
	# Отключаем сигнал после получения результата
	if YandexSdk.check_auth.is_connected(_on_auth_checked_for_player_entry):
		YandexSdk.check_auth.disconnect(_on_auth_checked_for_player_entry)
	
	if is_authorized:
		# Загружаем запись игрока в лидерборде
		print("Game: Загружаем запись игрока в лидерборде...")
		YandexSdk.load_leaderboard_player_entry("donuttowerleaderboard")
	else:
		print("Game: Пользователь не авторизован, запись игрока не загружена")
		_update_player_rank_display("")

# Обработчики для лидерборда больше не нужны, так как официальный SDK не возвращает сигналы для save_leaderboard_score

# ===== Таймер задержки рекламы =====
func _setup_ad_delay_timer() -> void:
	"""Настраивает таймер для задержки показа рекламы"""
	_ad_delay_timer = Timer.new()
	_ad_delay_timer.wait_time = 3.0  # 3 секунды задержки
	_ad_delay_timer.one_shot = true
	_ad_delay_timer.timeout.connect(_on_ad_delay_timeout)
	add_child(_ad_delay_timer)

func _start_ad_delay_timer() -> void:
	"""Запускает таймер для показа рекламы"""
	if _ad_delay_timer != null:
		_ad_delay_timer.start()

func _on_ad_delay_timeout() -> void:
	"""Обработчик срабатывания таймера - показываем рекламу с проверкой кулдауна"""
	var current_time: float = Time.get_ticks_msec() / 1000.0
	var time_since_last_ad: float = current_time - _last_ad_time
	
	if time_since_last_ad >= AD_COOLDOWN:
		# Обновляем время последнего показа рекламы
		_last_ad_time = current_time
		# Показываем рекламу
		_show_interstitial_ad()
	else:
		# Кулдаун еще не прошел, просто сбрасываем таймер
		print("Реклама не показана: кулдаун еще не прошел. Осталось: ", AD_COOLDOWN - time_since_last_ad, " секунд")

func _stop_ad_delay_timer() -> void:
	"""Останавливает таймер показа рекламы"""
	if _ad_delay_timer != null and _ad_delay_timer.time_left > 0:
		_ad_delay_timer.stop()

# ===== Управление языками =====
func _setup_language_manager() -> void:
	"""Настраивает обработчик смены языка"""
	if LanguageManager:
		LanguageManager.language_changed.connect(_on_language_changed)
		# Обновляем UI тексты сразу после подключения к сигналу
		_update_all_ui_texts()
		_update_score_label()
		_update_game_over_score()

func _on_language_changed(_language_code: String) -> void:
	"""Обработчик смены языка - обновляем все тексты"""
	_update_score_label()
	_update_game_over_score()
	_update_all_ui_texts()

func _update_all_ui_texts() -> void:
	"""Обновляет все тексты в игровом интерфейсе"""
	# Обновляем кнопку меню
	if menu_button:
		menu_button.text = tr("ui.menu.button")
	
	# Обновляем заголовок Game Over
	var game_over_label = get_node("UI/UIRoot/GameOverPanel/MainContainer/GameOverLabel")
	if game_over_label:
		game_over_label.text = tr("ui.gameover.title")
	
	# Обновляем тексты лидерборда
	_update_leaderboard_texts()
	
	# Обновляем отображение рейтинга игрока (если есть данные)
	if player_rank_label and player_rank_label.visible:
		# Текст рейтинга уже содержит переводы, поэтому просто обновляем видимость
		pass

func _update_leaderboard_texts() -> void:
	"""Обновляет тексты лидерборда при смене языка"""
	if leaderboard_panel:
		# Обновляем заголовок лидерборда
		var title_label = leaderboard_panel.get_node("TitleLabel")
		if title_label:
			title_label.text = tr("ui.leaderboard.title")
		
		# Обновляем текст загрузки
		var loading_label = leaderboard_panel.get_node("LoadingLabel")
		if loading_label:
			loading_label.text = tr("ui.leaderboard.loading")
		
		# Обновляем текст ошибки
		var error_label = leaderboard_panel.get_node("ErrorLabel")
		if error_label:
			error_label.text = tr("ui.leaderboard.error")

func check_touch_chain() -> bool:
	if combo_lock:
		return false
	donuts = donuts.filter(func(x): return is_instance_valid(x))
	var n: int = donuts.size()
	if n < 5:
		return false
	
	# Группируем пончики по цветам
	var donuts_by_color: Dictionary = {}
	for i in range(n):
		var di: Donut = donuts[i]
		if not is_instance_valid(di):
			continue
		var color: String = di.get_style()
		if not donuts_by_color.has(color):
			donuts_by_color[color] = []
		donuts_by_color[color].append(i)
	
	# Проверяем каждый цвет отдельно
	for color in donuts_by_color.keys():
		var color_indices: Array = donuts_by_color[color]
		if color_indices.size() < 5:
			continue
		
		# Строим граф только для пончиков этого цвета
		var adj: Array = []
		adj.resize(n)
		for i in range(n):
			adj[i] = []
		
		for i in color_indices:
			var di: Donut = donuts[i]
			if not is_instance_valid(di):
				continue
			for j in color_indices:
				if i >= j:  # избегаем дублирования
					continue
				var dj: Donut = donuts[j]
				if not is_instance_valid(dj):
					continue
				# Дополнительная проверка валидности перед обращением к свойствам
				if not is_instance_valid(di) or not is_instance_valid(dj):
					continue
				var dist: float = (di.global_position - dj.global_position).length()
				var touch: bool = dist <= (di.get_radius() + dj.get_radius()) * 1.02
				if touch:
					adj[i].append(j)
					adj[j].append(i)
		
		# Ищем компоненты связности только среди пончиков этого цвета
		var visited := {}
		for i in color_indices:
			if visited.has(i):
				continue
			var comp: Array = []
			var q: Array = [i]
			visited[i] = true
			while not q.is_empty():
				var v: int = q.pop_front()
				if v < 0 or v >= n:
					continue
				comp.append(v)
				for w in adj[v]:
					if not visited.has(w):
						visited[w] = true
						q.append(w)
			if comp.size() >= 5:
				await _apply_chain_bonus_and_remove(comp)
				return true
	
	return false

func _update_score_ui() -> void:
	_update_score_label()
	_update_game_over_score()

func _apply_chain_bonus_and_remove(indices: Array) -> void:
	combo_lock = true
	
	# Сначала собираем все валидные объекты для анимации
	var donuts_to_animate: Array[Donut] = []
	for idx in indices:
		if idx >= 0 and idx < donuts.size():
			var d: Donut = donuts[idx]
			if is_instance_valid(d):
				donuts_to_animate.append(d)
	
	# Количество очков равно количеству удаляемых пончиков
	var bonus_points: int = donuts_to_animate.size()
	score += bonus_points
	_update_score_ui()
	
	# Анимируем все собранные объекты
	for d in donuts_to_animate:
		if is_instance_valid(d):
			var tw: Tween = create_tween()
			tw.tween_property(d, "scale", d.scale * 0.0, 0.18)
			await tw.finished
			if is_instance_valid(d):
				d.queue_free()
	
	# Очищаем массивы от недействительных объектов
	donuts = donuts.filter(func(x): return is_instance_valid(x))
	active_donuts = active_donuts.filter(func(x): return is_instance_valid(x))
	
	# Размораживаем пончики, которые могли потерять опору
	_unfreeze_donuts_after_removal()
	
	await get_tree().process_frame
	combo_lock = false

func _recompute_tower_top_y() -> void:
	var top := INF
	for dn in donuts:
		if is_instance_valid(dn) and dn.is_inside_tree() and dn.sleeping:
			top = min(top, dn.global_position.y)
	if top == INF:
		top = _floor_y            # задай базовый уровень пола
	_tower_top_y = top

func _are_all_same_color(indices: Array) -> bool:
	if indices.is_empty():
		return false
	
	# Получаем цвет первого пончика
	var first_donut: Donut = donuts[indices[0]]
	if not is_instance_valid(first_donut):
		return false
	
	var first_color: String = first_donut.get_style()
	
	# Проверяем, что все остальные пончики имеют тот же цвет
	for i in range(1, indices.size()):
		var donut: Donut = donuts[indices[i]]
		if not is_instance_valid(donut):
			return false
		var donut_color: String = donut.get_style()
		if donut_color != first_color:
			return false
	
	return true

func _unfreeze_donuts_after_removal() -> void:
	# Размораживаем все "замершие" пончики, чтобы они могли упасть
	# если потеряли опору после удаления цепочки
	for d in donuts:
		if is_instance_valid(d) and d.sleeping:
			# Размораживаем пончик
			d.freeze = false
			d.sleeping = false
			# Сбрасываем таймер успокоения, чтобы пончик снова начал "успокаиваться"
			if d.has_method("_settle_reset"):
				d._settle_reset()
