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

const SAVE_PATH := "user://save.cfg"
const SAVE_SECTION := "stats"
const SAVE_KEY_BEST := "best"

enum GameState { READY, PLAY, GAMEOVER }

@onready var cam: Camera2D = get_node("Camera2D")
@onready var ui_root: Control = get_node("UI/UIRoot")
@onready var score_label: Label = get_node("UI/UIRoot/ScoreLabel")
@onready var game_over_panel: Panel = get_node("UI/UIRoot/GameOverPanel")
@onready var restart_button: Button = get_node("UI/UIRoot/GameOverPanel/Buttons/RestartButton")
@onready var continue_button: Button = get_node("UI/UIRoot/GameOverPanel/Buttons/ContinueButton")
@onready var spawner: Spawner = get_node("Spawner")
@onready var yandex_sdk: Node = get_node("YandexSDK")
@onready var preview: PreviewDonut = spawner.get_node("PreviewDonut")

var donut_pool: Array[RigidBody2D] = []
var active_donuts: Array[RigidBody2D] = []

var _last_spawn_time: float = 0.0
var _score: int = 0
var _best: int = 0
var _can_continue: bool = true
var _state: int = GameState.READY

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

	# Камера
	if cam != null:
		cam.position = Vector2(VIRT_W * 0.5, VIRT_H * 0.5)
		_cam_start_y = cam.position.y
		_tower_top_y = cam.position.y + VIRT_H * 0.5
		_apply_camera_limits()

	# Применить сложность на старте
	_recalc_difficulty()

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
	print("Input event received: ", event)
	if event is InputEventScreenTouch and event.pressed:
		print("Screen touch detected")
		_on_tap(event.position)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		print("Mouse button detected")
		_on_tap(event.position)

func _unhandled_input(event: InputEvent) -> void:
	print("Unhandled input event received: ", event)
	if event is InputEventScreenTouch and event.pressed:
		print("Unhandled screen touch detected")
		_on_tap(event.position)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		print("Unhandled mouse button detected")
		_on_tap(event.position)

func _on_tap(_pos: Vector2) -> void:
	print("=== TAP EVENT ===")
	print("Tap detected at: ", _pos, " State: ", _state)
	print("Game over panel visible: ", game_over_panel.visible if game_over_panel != null else "null")
	print("Cooldown ready: ", _cooldown_ready())
	
	if _state == GameState.READY:
		print("Starting game...")
		_start_game()
		return
	if _state != GameState.PLAY:
		print("Game not in PLAY state: ", _state)
		return
	if game_over_panel.visible:
		print("Game over panel is visible, blocking spawn")
		return
	if not _cooldown_ready():
		print("Cooldown not ready")
		return
	var spawn_pos: Vector2
	if spawner != null:
		spawn_pos = spawner.get_spawn_position()
		print("Spawner position: ", spawn_pos)
	else:
		print("ERROR: spawner is null, using fallback position")
		spawn_pos = Vector2(VIRT_W * 0.5, 120.0)
	print("Spawning donut at: ", spawn_pos)
	if preview != null:
		print("Calling preview.flash_drop()...")
		preview.flash_drop()
	else:
		print("ERROR: preview is null, cannot call flash_drop()")
	_spawn_donut(spawn_pos)
	print("=== END TAP EVENT ===")

func _start_game() -> void:
	_state = GameState.PLAY
	
	# Дополнительная очистка перед началом игры
	_cleanup_fallen()
	
	# Спавним первый пончик
	var spawn_pos: Vector2
	if spawner != null:
		spawn_pos = spawner.get_spawn_position()
	else:
		print("ERROR: spawner is null, using fallback position")
		spawn_pos = Vector2(VIRT_W * 0.5, 120.0)
	_spawn_donut(spawn_pos)
	_last_spawn_time = float(Time.get_ticks_msec()) / 1000.0

func _cooldown_ready() -> bool:
	var t: float = float(Time.get_ticks_msec()) / 1000.0
	return t - _last_spawn_time >= SPAWN_COOLDOWN

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
	print("_spawn_donut called with position: ", world_pos, " Game state: ", _state)
	var d: RigidBody2D = _take_from_pool()
	if d == null:
		print("No donut in pool, creating new one")
		var node: Node = DONUT_SCENE.instantiate()
		d = node as RigidBody2D
		if d == null:
			print("ERROR: Donut scene root is not RigidBody2D!")
			if node != null:
				node.free()
			return
		add_child(d)
		print("New donut created and added to scene")
	else:
		print("Reusing donut from pool")
	
	d.visible = true
	print("Donut visibility set to true")

	# Сброс состояний - явно устанавливаем режим физики перед снятием freeze
	d.freeze_mode = RigidBody2D.FREEZE_MODE_STATIC
	d.freeze = false
	d.linear_velocity = Vector2.ZERO
	d.angular_velocity = 0.0
	d.global_position = world_pos
	d.scale = Vector2.ONE  # Сброс масштаба к оригинальному размеру
	d.set("bottom_y_limit", get_world_bottom_limit() + 100.0)
	d.set_process(true)
	d.set_physics_process(true)
	d.sleeping = false
	
	# Сброс внутреннего состояния пончика
	if d.has_method("reset_state"):
		d.reset_state()

	# Стабильность верхних пончиков по мере роста счёта
	var damp: float = clamp(DAMP_BASE + float(_score) * DAMP_SCORE_RATE, DAMP_BASE, DAMP_MAX)
	d.angular_damp = damp
	var lin_thr: float = clamp(SETTLE_LIN_BASE + float(_score) * SETTLE_RATE, SETTLE_LIN_BASE, SETTLE_LIN_MAX)
	var ang_thr: float = clamp(SETTLE_ANG_BASE + float(_score) * SETTLE_ANG_RATE, SETTLE_ANG_BASE, SETTLE_ANG_MAX)
	d.set("settle_linear_speed_threshold", lin_thr)
	d.set("settle_angular_speed_threshold", ang_thr)

	# Сигналы (сначала очищаем старые коннекты)
	_reset_donut_signals(d)
	var donut_obj: Object = d
	d.connect("settled", Callable(self, "_on_donut_settled").bind(donut_obj))
	d.connect("missed", Callable(self, "_on_donut_missed").bind(donut_obj))

	active_donuts.append(d)
	
	# Обновляем время последнего спавна
	_last_spawn_time = float(Time.get_ticks_msec()) / 1000.0
	print("Donut spawned successfully! Active donuts: ", active_donuts.size())
	print("Donut physics state - freeze: ", d.freeze, " sleeping: ", d.sleeping, " freeze_mode: ", d.freeze_mode)

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
		print("Cannot recycle invalid donut")
		return
	if active_donuts.has(d):
		print("Recycling donut from active list")
		active_donuts.erase(d)
	else:
		print("Recycling donut not in active list")
	
	# Очистка сигналов перед переработкой
	_reset_donut_signals(d)
	
	# Сброс внутреннего состояния пончика
	if d.has_method("reset_state"):
		d.reset_state()
	
	_sleep_and_hide(d)
	donut_pool.append(d)
	print("Donut recycled. Active donuts: ", active_donuts.size())

func _sleep_and_hide(d: RigidBody2D) -> void:
	if d == null or not is_instance_valid(d):
		return
	# Устанавливаем правильный режим заморозки для хранения в пуле
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
	var threshold: float = cam.position.y + VIRT_H * 2.0 if cam != null else VIRT_H * 2.0
	print("Cleanup threshold: ", threshold, " Camera Y: ", cam.position.y if cam != null else "null")
	for d in active_donuts.duplicate():
		if d == null or not is_instance_valid(d):
			print("Removing invalid donut")
			active_donuts.erase(d)
			continue
		print("Donut at Y: ", d.global_position.y, " threshold: ", threshold)
		if d.global_position.y > threshold:
			print("Recycling fallen donut at Y: ", d.global_position.y)
			_recycle_donut(d)

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
# 	if cam == null:
# 		return
# 	# Цель — держать вершину башни с запасом _cam_margin
# 	var target_y: float = min(_cam_start_y, _tower_top_y - _cam_margin)
# 	if target_y < cam.position.y:
# 		cam.position.y = target_y

func _on_donut_settled(donut_obj: Object) -> void:
	var d: RigidBody2D = donut_obj as RigidBody2D
	if d == null or not is_instance_valid(d):
		print("Invalid donut in settled signal")
		return
	print("=== DONUT SETTLED ===")
	print("Donut settled at Y: ", d.global_position.y)
	print("Current score before: ", _score)
	# Счёт
	_score += 1
	print("Current score after: ", _score)
	_update_score_label()
	# Вершина башни — минимальное Y "замерших" тел
	_tower_top_y = min(_tower_top_y, d.global_position.y)
	# Пересчитать сложность
	_recalc_difficulty()
	print("=== END DONUT SETTLED ===")

func _on_donut_missed(donut_obj: Object) -> void:
	var d: RigidBody2D = donut_obj as RigidBody2D
	if d != null and is_instance_valid(d):
		print("Donut missed at Y: ", d.global_position.y, " bottom_limit: ", d.get("bottom_y_limit"))
	else:
		print("Invalid donut in missed signal")
	_set_game_over()

# ===== Сложность: скорость каретки и запас камеры =====
func _recalc_difficulty() -> void:
	# Скорость каретки: base * clamp(1 + score*rate, 1, MAX_FACTOR)
	var factor: float = 1.0 + float(_score) * SPAWNER_SCORE_RATE
	if factor > SPAWNER_MAX_FACTOR:
		factor = SPAWNER_MAX_FACTOR
	if spawner != null:
		spawner.speed = SPAWNER_BASE_SPEED * factor

	# Запас камеры: линейная интерполяция от MIN к MAX к ~20 очкам
	var t: float = float(_score)
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
	_show_game_over()
	if _score > _best:
		_best = _score
		_save_best_to_disk()
	_update_score_label()
	
	# Показываем Interstitial рекламу при Game Over
	_show_interstitial_ad()

func _on_restart_pressed() -> void:
	_reset_game()

func _on_continue_pressed() -> void:
	if _state != GameState.GAMEOVER:
		return
	if not _can_continue:
		return
	
	# Показываем Rewarded рекламу для продолжения игры
	_show_rewarded_ad()

func _grant_continue() -> void:
	_hide_game_over()
	_state = GameState.PLAY

func _reset_game() -> void:
	print("=== RESETTING GAME ===")
	print("Before reset - Active donuts: ", active_donuts.size(), " Pool size: ", donut_pool.size())
	
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
	_score = 0
	_last_spawn_time = 0.0
	_can_continue = true
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
	
	print("After reset - Active donuts: ", active_donuts.size(), " Pool size: ", donut_pool.size())
	print("Game state set to: ", _state)
	print("=== GAME RESET COMPLETE ===")

func _load_best_from_disk() -> void:
	var cfg := ConfigFile.new()
	var err: int = cfg.load(SAVE_PATH)
	if err != OK:
		_best = 0
		return
	_best = int(cfg.get_value(SAVE_SECTION, SAVE_KEY_BEST, 0))

func _save_best_to_disk() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value(SAVE_SECTION, SAVE_KEY_BEST, _best)
	var err: int = cfg.save(SAVE_PATH)
	if err != OK:
		push_warning("Не удалось сохранить рекорд в " + SAVE_PATH)

# ===== Вспомогательные =====
func get_world_bottom_limit() -> float:
	return cam.position.y + VIRT_H if cam != null else VIRT_H

func _update_score_label() -> void:
	if score_label:
		score_label.text = "Score: " + str(_score) + "\nBest: " + str(_best)

func _show_game_over() -> void:
	game_over_panel.visible = true

func _hide_game_over() -> void:
	game_over_panel.visible = false

# ===== Яндекс SDK и реклама =====
func _setup_yandex_sdk() -> void:
	if yandex_sdk == null:
		print("YandexSDK node not found")
		return
	
	# Подключаем сигналы от YandexSDK
	yandex_sdk.interstitial_closed.connect(_on_interstitial_closed)
	yandex_sdk.rewarded_completed.connect(_on_rewarded_completed)
	yandex_sdk.rewarded_closed.connect(_on_rewarded_closed)
	yandex_sdk.ad_error.connect(_on_ad_error)

func _show_interstitial_ad() -> void:
	"""Показывает Interstitial рекламу при Game Over"""
	if yandex_sdk != null:
		print("Показываем Interstitial рекламу")
		yandex_sdk.show_interstitial()
	else:
		print("YandexSDK недоступен, пропускаем Interstitial")

func _show_rewarded_ad() -> void:
	"""Показывает Rewarded рекламу для продолжения игры"""
	if yandex_sdk != null:
		print("Показываем Rewarded рекламу")
		yandex_sdk.show_rewarded()
	else:
		print("YandexSDK недоступен, даем продолжение бесплатно")
		_grant_continue()

func _on_interstitial_closed(was_shown: bool) -> void:
	"""Обработчик закрытия Interstitial рекламы"""
	print("Interstitial реклама закрыта, показана: ", was_shown)
	# Никаких дополнительных действий не требуется

func _on_rewarded_completed() -> void:
	"""Обработчик завершения Rewarded рекламы - игрок получил награду"""
	print("Rewarded реклама завершена, даем продолжение")
	_can_continue = false
	_grant_continue()

func _on_rewarded_closed() -> void:
	"""Обработчик закрытия Rewarded рекламы"""
	print("Rewarded реклама закрыта")

func _on_ad_error(error_message: String) -> void:
	"""Обработчик ошибок рекламы"""
	print("Ошибка рекламы: ", error_message)
	# При ошибке рекламы даем продолжение бесплатно (для Rewarded)
	if _state == GameState.GAMEOVER and _can_continue:
		print("Даем продолжение бесплатно из-за ошибки рекламы")
		_can_continue = false
		_grant_continue()
