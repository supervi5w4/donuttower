extends Node2D
## Шаг 7: счёт, рекорд (ConfigFile), рестарт/продолжение, Game Over.
## - +1 очко за каждый "успокоившийся" пончик (signal settled)
## - Промах (signal missed) -> Game Over
## - Рекорд сохраняется в user://save.cfg (section "stats", key "best")
## - Restart: чистка, сброс камеры/счёта/состояний
## - Continue: заглушка rewarded, одна попытка на игру

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

# Камера/башня
var _cam_start_y: float = 640.0
var _cam_margin: float = VIRT_H * 0.35
var _tower_top_y: float = 1280.0

func _ready() -> void:
	print("Game _ready() called")
	_load_best_from_disk()
	_init_donut_pool()
	_update_score_label()
	_hide_game_over()
	
	print("Spawner reference: ", spawner)
	if spawner != null:
		var initial_spawn_pos = spawner.get_spawn_position()
		print("Initial spawn position: ", initial_spawn_pos)
		_spawn_donut(initial_spawn_pos)
	else:
		print("Spawner is null!")
		_spawn_donut(Vector2(VIRT_W * 0.5, 120.0))
	
	print("Game initialized, state: ", _state)

	# Подключение сигналов кнопок
	restart_button.pressed.connect(_on_restart_pressed)
	continue_button.pressed.connect(_on_continue_pressed)

	# Позиция/лимиты камеры
	if cam != null:
		cam.position = Vector2(VIRT_W * 0.5, VIRT_H * 0.5)
		_cam_start_y = cam.position.y
		_tower_top_y = cam.position.y + VIRT_H * 0.5
		_apply_camera_limits()

func _process(_delta: float) -> void:
	_cleanup_fallen()
	_update_camera_follow()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_SIZE_CHANGED:
		_apply_camera_limits()
		if cam != null:
			cam.position.x = VIRT_W * 0.5

# ===== Ввод =====
func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		print("Touch input detected at: ", event.position)
		_on_tap(event.position)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		print("Mouse click detected at: ", event.position, " calling _on_tap")
		_on_tap(event.position)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		print("UNHANDLED Touch input detected at: ", event.position)
		_on_tap(event.position)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		print("UNHANDLED Mouse click detected at: ", event.position, " calling _on_tap")
		_on_tap(event.position)

func _on_tap(_pos: Vector2) -> void:
	print("_on_tap called with position: ", _pos)
	print("Current game state: ", _state, " (PLAY = ", GameState.PLAY, ")")
	print("Game over panel visible: ", game_over_panel.visible)
	
	if _state != GameState.PLAY:
		print("Game not in PLAY state, ignoring tap")
		return
	if game_over_panel.visible:
		print("Game over panel is visible, ignoring tap")
		return
	if not _cooldown_ready():
		print("Cooldown not ready, ignoring tap")
		return
	
	print("All checks passed, spawning donut...")
	var spawn_pos: Vector2 = spawner.get_spawn_position() if spawner != null else Vector2(VIRT_W * 0.5, 120.0)
	print("Spawn position: ", spawn_pos)
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
	print("_spawn_donut called with world_pos: ", world_pos)
	var d: RigidBody2D = _take_from_pool()
	print("Donut from pool: ", d)
	if d == null:
		print("No donut in pool, creating new one")
		var node: Node = DONUT_SCENE.instantiate()
		d = node as RigidBody2D
		if d == null:
			print("Failed to create donut from scene")
			if node != null:
				node.free()
			return
		add_child(d)
		print("New donut created and added to scene")

	# Сброс состояний
	d.freeze = false
	d.linear_velocity = Vector2.ZERO
	d.angular_velocity = 0.0
	d.global_position = world_pos
	d.set("bottom_y_limit", get_world_bottom_limit() + 100.0)
	d.set_process(true)
	d.set_physics_process(true)
	d.sleeping = false

	# Сигналы (очистим/переподключим, чтобы не накапливать)
	_reset_donut_signals(d)
	var donut_obj: Object = d
	d.connect("settled", Callable(self, "_on_donut_settled").bind(donut_obj))
	d.connect("missed", Callable(self, "_on_donut_missed").bind(donut_obj))

	active_donuts.append(d)
	print("Donut spawned successfully at position: ", d.global_position)
	print("Donut freeze: ", d.freeze, " sleeping: ", d.sleeping)

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
	# Вершина башни
	_tower_top_y = min(_tower_top_y, d.global_position.y)

func _on_donut_missed(_donut_obj: Object) -> void:
	_set_game_over()

# ===== Game Over / Restart / Continue =====
func _set_game_over() -> void:
	if _state == GameState.GAMEOVER:
		return
	_state = GameState.GAMEOVER
	_show_game_over()
	# Обновим и сохраним рекорд
	if _score > _best:
		_best = _score
		_save_best_to_disk()
	_update_score_label() # чтобы сразу показать best в лейбле

func _on_restart_pressed() -> void:
	_reset_game()

func _on_continue_pressed() -> void:
	# Заглушка rewarded: разрешим 1 раз за попытку
	if _state != GameState.GAMEOVER:
		return
	if not _can_continue:
		return
	_can_continue = false
	_grant_continue()

func _grant_continue() -> void:
	# Скрываем панель и возвращаемся к PLAY
	_hide_game_over()
	_state = GameState.PLAY
	# Дополнительно можно слегка поднять нижний лимит, но пока не требуется.

func _reset_game() -> void:
	# Очистка всех активных пончиков
	for d in active_donuts.duplicate():
		_recycle_donut(d)
	# Сброс счёта и флагов
	_score = 0
	_can_continue = true
	_state = GameState.PLAY
	_update_score_label()
	_hide_game_over()
	# Камера: вернём внутренние ориентиры (вниз не опускаем)
	if cam != null:
		_tower_top_y = cam.position.y + VIRT_H * 0.5
		# Можно принудительно вернуть позицию камеры к стартовой:
		cam.position.y = _cam_start_y

# ===== Сохранение =====
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
