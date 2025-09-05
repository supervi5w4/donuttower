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

var donut_pool: Array[RigidBody2D] = []
var active_donuts: Array[RigidBody2D] = []

var _last_spawn_time: float = 0.0
var _score: int = 0
var _best: int = 0
var _can_continue: bool = true
var _state: int = GameState.PLAY

# Камера / башня
var _cam_start_y: float = 640.0
var _cam_margin: float = VIRT_H * 0.35
var _tower_top_y: float = 1280.0

# ===== Сложность =====
const SPAWNER_BASE_SPEED := 180.0      # px/s при Score=0
const SPAWNER_MAX_FACTOR := 1.6        # максимум множителя скорости
const SPAWNER_SCORE_RATE := 0.02       # +2% скорости за очко (до MAX_FACTOR)

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
	_update_camera_follow()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_SIZE_CHANGED:
		_apply_camera_limits()
		if cam != null:
			cam.position.x = VIRT_W * 0.5

# ===== Ввод =====
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		_on_tap(event.position)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_tap(event.position)

func _on_tap(_pos: Vector2) -> void:
	if _state != GameState.PLAY:
		return
	if game_over_panel.visible:
		return
	if not _cooldown_ready():
		return
	var spawn_pos: Vector2 = spawner.get_spawn_position() if spawner != null else Vector2(VIRT_W * 0.5, 120.0)
	_spawn_donut(spawn_pos)

func _cooldown_ready() -> bool:
	var t: float = float(Time.get_ticks_msec()) / 1000.0
	if t - _last_spawn_time < SPAWN_COOLDOWN:
		return false
	_last_spawn_time = t
	return true

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

	# Сброс состояний
	d.reset_state()
	d.freeze = false
	d.linear_velocity = Vector2.ZERO
	d.angular_velocity = 0.0
	d.global_position = world_pos
	d.set("bottom_y_limit", get_world_bottom_limit() + 100.0)
	d.set_process(true)
	d.set_physics_process(true)
	d.sleeping = false

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
	_sleep_and_hide(d)
	donut_pool.append(d)

func _sleep_and_hide(d: RigidBody2D) -> void:
	if d == null or not is_instance_valid(d):
		return
	d.freeze = true
	d.sleeping = true
	d.set_process(false)
	d.set_physics_process(false)
	d.global_position = Vector2(-10000.0, -10000.0)

func _cleanup_fallen() -> void:
	if active_donuts.is_empty():
		return
	var threshold: float = cam.position.y + VIRT_H * 2.0 if cam != null else VIRT_H * 2.0
	for d in active_donuts.duplicate():
		if d == null or not is_instance_valid(d):
			active_donuts.erase(d)
			continue
		if d.global_position.y > threshold:
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

func _update_camera_follow() -> void:
	if cam == null:
		return
	# Цель — держать вершину башни с запасом _cam_margin
	var target_y: float = min(_cam_start_y, _tower_top_y - _cam_margin)
	if target_y < cam.position.y:
		cam.position.y = target_y

func _on_donut_settled(donut_obj: Object) -> void:
	var d: RigidBody2D = donut_obj as RigidBody2D
	if d == null or not is_instance_valid(d):
		return
	# Счёт
	_score += 1
	_update_score_label()
	# Вершина башни — минимальное Y "замерших" тел
	_tower_top_y = min(_tower_top_y, d.global_position.y)
	# Пересчитать сложность
	_recalc_difficulty()

func _on_donut_missed(_donut_obj: Object) -> void:
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

func _on_restart_pressed() -> void:
	_reset_game()

func _on_continue_pressed() -> void:
	if _state != GameState.GAMEOVER:
		return
	if not _can_continue:
		return
	_can_continue = false
	_grant_continue()

func _grant_continue() -> void:
	_hide_game_over()
	_state = GameState.PLAY

func _reset_game() -> void:
	for d in active_donuts.duplicate():
		_recycle_donut(d)
	_score = 0
	_can_continue = true
	_state = GameState.PLAY
	_update_score_label()
	_hide_game_over()
	# Камера: вернуть ориентиры; позицию — к стартовой
	if cam != null:
		_tower_top_y = cam.position.y + VIRT_H * 0.5
		cam.position.y = _cam_start_y
	# Пересчитать сложность под нулевой счёт
	_recalc_difficulty()

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
