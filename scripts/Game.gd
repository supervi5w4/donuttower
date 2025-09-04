extends Node2D
## Подключена каретка Spawner: спавн пончиков теперь берёт координату из неё.

const VIRT_W := 720.0
const VIRT_H := 1280.0

const POOL_SIZE := 24
const SPAWN_COOLDOWN := 0.08 # сек, анти-дребезг
const DONUT_SCENE := preload("res://scenes/Donut.tscn")

var cam: Camera2D = null

@onready var ui_root: Control = get_node("UI/UIRoot")
@onready var score_label: Label = get_node("UI/UIRoot/ScoreLabel")
@onready var game_over_panel: Panel = get_node("UI/UIRoot/GameOverPanel")
@onready var restart_button: Button = get_node("UI/UIRoot/GameOverPanel/Buttons/RestartButton")
@onready var continue_button: Button = get_node("UI/UIRoot/GameOverPanel/Buttons/ContinueButton")
@onready var spawner: Spawner = get_node("Spawner") # каретка

var donut_pool: Array[RigidBody2D] = []
var active_donuts: Array[RigidBody2D] = []

var _last_spawn_time: float = 0.0
var _score: int = 0
var _can_continue: bool = true

func _ready() -> void:
	_init_donut_pool()
	_update_score_label()
	_hide_game_over()

func _process(_delta: float) -> void:
	_cleanup_fallen()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		_on_tap(event.position)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_tap(event.position)

func _on_tap(_pos: Vector2) -> void:
	# Игнорим ввод, если открыт GameOver
	if game_over_panel.visible:
		return
	if not _cooldown_ready():
		return

	var spawn_pos: Vector2 = spawner.get_spawn_position() if spawner != null else Vector2(VIRT_W * 0.5, 80.0)
	_spawn_donut(spawn_pos)

func _cooldown_ready() -> bool:
	var t: float = float(Time.get_ticks_msec()) / 1000.0
	if t - _last_spawn_time < SPAWN_COOLDOWN:
		return false
	_last_spawn_time = t
	return true

func _init_donut_pool() -> void:
	donut_pool.clear()
	active_donuts.clear()
	for i in POOL_SIZE:
		var d: RigidBody2D = DONUT_SCENE.instantiate() as RigidBody2D
		add_child(d)
		_sleep_and_hide(d)
		donut_pool.append(d)

func _spawn_donut(world_pos: Vector2) -> void:
	var d: RigidBody2D = _take_from_pool()
	if d == null:
		d = DONUT_SCENE.instantiate() as RigidBody2D
		add_child(d)

	d.freeze = false
	d.linear_velocity = Vector2.ZERO
	d.angular_velocity = 0.0
	d.global_position = world_pos
	d.set("bottom_y_limit", get_world_bottom_limit() + 100.0)
	d.set_process(true)
	d.set_physics_process(true)
	d.sleeping = false

	active_donuts.append(d)

func _take_from_pool() -> RigidBody2D:
	if donut_pool.is_empty():
		return null
	var d: RigidBody2D = donut_pool.pop_back()
	d.visible = true
	d.collision_layer = d.collision_layer
	return d

func _recycle_donut(d: RigidBody2D) -> void:
	if active_donuts.has(d):
		active_donuts.erase(d)
	_sleep_and_hide(d)
	donut_pool.append(d)

func _sleep_and_hide(d: RigidBody2D) -> void:
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
		if d.global_position.y > threshold:
			_recycle_donut(d)

func get_world_bottom_limit() -> float:
	return cam.position.y + VIRT_H if cam != null else VIRT_H

# ===== UI =====
func _update_score_label() -> void:
	if score_label:
		score_label.text = str(_score)

func _show_game_over() -> void:
	game_over_panel.visible = true

func _hide_game_over() -> void:
	game_over_panel.visible = false

# ===== Buttons =====
func _on_restart_pressed() -> void:
	_reset_game()

func _on_continue_pressed() -> void:
	if not _can_continue:
		return
	_can_continue = false
	_hide_game_over()

func _reset_game() -> void:
	for d in active_donuts.duplicate():
		_recycle_donut(d)
	_score = 0
	_update_score_label()
	_can_continue = true
	_hide_game_over()
