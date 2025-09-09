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
const SPAWN_COOLDOWN := 0.05  # УВЕЛИЧЕННАЯ ПОДКРУТКА: уменьшен кулдаун с 0.08 до 0.05
const DONUT_SCENE := preload("res://scenes/Donut.tscn")

# Базовый уровень пола для пересчёта вершины башни
const _floor_y := 1200.0

const SAVE_PATH := "user://save.cfg"
const SAVE_SECTION := "stats"
const SAVE_KEY_BEST := "best"

# Параметризация уровня
@export var level_number: int = 1
@export var score_to_unlock: int = 50

@export var cart_path: NodePath
@export var wall_left_path: NodePath
@export var wall_right_path: NodePath

@export var initial_cart_speed_level1: float = 300.0
@export var initial_cart_speed_level2: float = 380.0
@export var initial_cart_speed_level3: float = 380.0
@export var initial_cart_speed_level4: float = 400.0

@export var wall_scale_x_level1: float = 1.0
@export var wall_scale_x_level2: float = 0.8
@export var wall_scale_x_level3: float = 0.6
@export var wall_scale_x_level4: float = 0.5

signal score_changed(new_score: int)
signal donut_missed

enum GameMode { READY, PLAY, GAMEOVER }

@onready var cam: Camera2D = get_node("Camera2D")
@onready var ui_root: Control = get_node("UI/UIRoot")
@onready var score_label: Label = get_node("UI/UIRoot/ScoreLabel")
@onready var game_over_panel: Control = get_node("UI/UIRoot/GameOverPanel")
@onready var game_over_score_label: Label = get_node("UI/UIRoot/GameOverPanel/MainContainer/ScoreLabel")
@onready var menu_button: Button = get_node("UI/UIRoot/GameOverPanel/MainContainer/MenuButton")
@onready var game_over_label: Label = get_node("UI/UIRoot/GameOverPanel/MainContainer/GameOverLabel")

# Кнопка следующего уровня (создадим программно)
var next_level_button: Button
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
var _state: int = GameMode.READY
var next_style: String = "pink"
var _level_ui: LevelUI

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

# УВЕЛИЧЕННАЯ ПОДКРУТКА: более сильное затухание вращения
const DAMP_BASE := 0.85                # angular_damp базовый (увеличено с 0.70)
const DAMP_MAX := 1.20                 # верхняя граница (увеличено с 1.00)
const DAMP_SCORE_RATE := 0.015         # +0.015 за очко (увеличено с 0.01)

# УВЕЛИЧЕННАЯ ПОДКРУТКА: более мягкие пороги успокоения
const SETTLE_LIN_BASE := 12.0          # базовый линейный порог (увеличено с 8.0)
const SETTLE_LIN_MAX := 18.0           # предел "мягкости" линейного порога (увеличено с 12.0)
const SETTLE_ANG_BASE := 1.0           # базовый угловой порог (увеличено с 0.6)
const SETTLE_ANG_MAX := 1.5            # предел "мягкости" углового порога (увеличено с 1.0)
const SETTLE_RATE := 0.15              # вклад в линейный порог на очко (увеличено с 0.10)
const SETTLE_ANG_RATE := 0.03          # вклад в угловой порог на очко (увеличено с 0.02)

func _ready() -> void:
	get_node("/root/GameStateManager").reset_for_level(level_number)
	
	# Проверяем, есть ли GameOverPanel в сцене
	var panel := get_node_or_null("UI/UIRoot/GameOverPanel")
	if panel:
		pass
	
	_level_ui = LevelUI.new()
	add_child(_level_ui)
	_level_ui.set_level_number(level_number)
	_level_ui.set_progress(0, score_to_unlock)
	
	# Устанавливаем цветовую схему для уровня
	var level_info = LevelData.get_level_info(level_number)
	if level_info and level_info.color_scheme:
		_level_ui.set_color_scheme(level_info.color_scheme)
	
	_apply_level_params()
	
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
	
	# Инициализируем SpawnDirector для уровня
	SpawnDirector.init_seed(Time.get_unix_time_from_system())
	SpawnDirector.reset(level_number)
	
	# Выбираем первый стиль и обновляем превью
	_select_next_style()
	_update_preview()
	
	# Настраиваем панель Game Over
	_setup_game_over_panel()
	
	# Подключаем сигнал donut_missed
	if has_signal("donut_missed"):
		connect("donut_missed", Callable(self, "_on_donut_missed_signal"))
	
	# Инициализируем состояние уровня
	_reset_level_state()

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
	elif event is InputEventKey and event.pressed:
		# Тестовая клавиша T для проверки SpawnDirector
		if event.keycode == KEY_T:
			_test_spawn_director()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		_on_tap(event.position)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_tap(event.position)

func _on_tap(_pos: Vector2) -> void:
	
	if _state == GameMode.READY:
		_start_game()
		return
	if _state != GameMode.PLAY:
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
	_state = GameMode.PLAY
	
	# Дополнительная очистка перед началом игры
	_cleanup_fallen()
	
	# Запускаем аналитику
	YandexSDK.gameplay_started()
	
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
	# Используем SpawnDirector для выбора следующего типа пончика
	next_style = SpawnDirector.get_next_donut_type(level_number)

func _update_preview() -> void:
	if preview != null and preview.has_method("set_texture"):
		# Получаем текстуру через SpawnDirector
		var texture: Texture2D = SpawnDirector.get_next_donut_texture(next_style)
		preview.set_texture(texture)

func _apply_level_params() -> void:
	var cart := get_node_or_null(cart_path) if cart_path != NodePath("") else null
	if cart and "set_speed" in cart:
		var sp: float
		if level_number == 1:
			sp = initial_cart_speed_level1
		elif level_number == 2:
			sp = initial_cart_speed_level2
		elif level_number == 3:
			sp = initial_cart_speed_level3
		elif level_number == 4:
			sp = initial_cart_speed_level4
		else:
			sp = initial_cart_speed_level1
		cart.set_speed(sp)

	var wl := get_node_or_null(wall_left_path) if wall_left_path != NodePath("") else null
	var wr := get_node_or_null(wall_right_path) if wall_right_path != NodePath("") else null
	var sx: float
	if level_number == 1:
		sx = wall_scale_x_level1
	elif level_number == 2:
		sx = wall_scale_x_level2
	elif level_number == 3:
		sx = wall_scale_x_level3
	elif level_number == 4:
		sx = wall_scale_x_level4
	else:
		sx = wall_scale_x_level1
	if wl:
		wl.scale.x = sx
	if wr:
		wr.scale.x = sx

func add_score(delta: int) -> void:
	score += delta
	get_node("/root/GameStateManager").score = score
	emit_signal("score_changed", score)

	if _level_ui:
		_level_ui.set_progress(score, score_to_unlock)

	# Победа на уровнях
	if level_number == 1 and score >= score_to_unlock:
		get_node("/root/GameStateManager").unlock_level(2)
		_open_win_panel()
	elif level_number == 2 and score >= score_to_unlock:
		get_node("/root/GameStateManager").unlock_level(3)
		_open_win_panel()
	elif level_number == 3 and score >= score_to_unlock:
		get_node("/root/GameStateManager").unlock_level(4)
		_open_win_panel()
	elif level_number == 4 and score >= score_to_unlock:
		# Для уровня 4 пока что просто показываем панель победы
		_open_win_panel()
	elif level_number == 5 and score >= score_to_unlock:
		# Для уровня 5 показываем специальную панель победы
		_open_win_panel()

func _setup_game_over_panel() -> void:
	# Создаем кнопку "Следующий уровень" программно для уровней 1, 2 и 3
	if level_number == 1 or level_number == 2 or level_number == 3:
		next_level_button = Button.new()
		next_level_button.name = "NextLevelButton"
		next_level_button.text = "Следующий уровень"
		next_level_button.custom_minimum_size = Vector2(400, 80)
		next_level_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		next_level_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		
		# Стилизация кнопки в том же стиле, что и MenuButton
		next_level_button.add_theme_color_override("font_hover_color", Color(0.2, 0.1, 0.05, 1))
		next_level_button.add_theme_color_override("font_color", Color(0.2, 0.1, 0.05, 1))
		next_level_button.add_theme_color_override("font_pressed_color", Color(0.2, 0.1, 0.05, 1))
		next_level_button.add_theme_font_size_override("font_size", 24)
		
		# Применяем те же стили, что и у MenuButton
		var menu_button := game_over_panel.get_node("MainContainer/MenuButton")
		if menu_button:
			# Копируем стили от MenuButton
			next_level_button.add_theme_stylebox_override("hover", menu_button.get_theme_stylebox("hover"))
			next_level_button.add_theme_stylebox_override("pressed", menu_button.get_theme_stylebox("pressed"))
		next_level_button.add_theme_stylebox_override("normal", menu_button.get_theme_stylebox("normal"))
		
		# Добавляем кнопку в MainContainer в правильную позицию
		var main_container := game_over_panel.get_node("MainContainer")
		
		# Находим индекс кнопки MenuButton
		var menu_button_index := -1
		for i in range(main_container.get_child_count()):
			if main_container.get_child(i).name == "MenuButton":
				menu_button_index = i
				break
		
		if menu_button_index >= 0:
			# Добавляем кнопку перед MenuButton
			main_container.add_child(next_level_button)
			main_container.move_child(next_level_button, menu_button_index)
		else:
			# Fallback: добавляем в конец
			main_container.add_child(next_level_button)
		
		# Подключаем сигнал
		next_level_button.pressed.connect(_on_next_level_pressed)
		
		# Скрываем кнопку по умолчанию
		next_level_button.visible = false
	else:
		# Для уровня 2 и выше используем кнопку из сцены
		next_level_button = game_over_panel.get_node_or_null("MainContainer/NextLevelButton")
		if next_level_button:
			next_level_button.pressed.connect(_on_next_level_pressed)

func _open_win_panel() -> void:
	_show_win_panel()

func _show_win_panel() -> void:
	# Обновляем заголовок
	if game_over_label:
		game_over_label.text = "Уровень пройден!"
	
	# Обновляем счет
	if game_over_score_label:
		game_over_score_label.text = "Очки: " + str(score)
	
	# Показываем кнопку следующего уровня для уровней 1, 2 и 3
	if next_level_button:
		if level_number == 1 or level_number == 2 or level_number == 3:
			next_level_button.visible = true
		else:
			next_level_button.visible = false
	
	# Показываем панель
	game_over_panel.visible = true

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

	add_score(1)
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
	on_donut_fell()

func on_donut_fell() -> void:
	# Вызываем эту функцию там, где раньше был немедленный Game Over.
	emit_signal("donut_missed")

func _reset_level_state() -> void:
	_hide_game_over()

func _on_donut_missed_signal() -> void:
	_handle_game_over()

func _handle_game_over() -> void:
	# Останови спавн/инпут/таймеры по проектной логике
	if game_over_panel:
		game_over_panel.visible = true
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
	if _state == GameMode.GAMEOVER:
		return
	_state = GameMode.GAMEOVER
	
	# Останавливаем аналитику
	YandexSDK.gameplay_stopped()
	
	# Проверяем, побит ли рекорд
	if score > _best:
		_best = score
		_save_best_to_disk()
	
	# Сохраняем статистику игры
	_save_game_stats()
	
	# Обновляем отображение очков
	_update_game_over_score()
	_update_score_label()
	
	# Показываем панель поражения
	_show_lose_panel()
	
	# Запускаем таймер для показа рекламы через 3 секунды
	_start_ad_delay_timer()

func _show_lose_panel() -> void:
	# Обновляем заголовок
	if game_over_label:
		game_over_label.text = "Игра окончена!"
	
	# Обновляем счет
	if game_over_score_label:
		game_over_score_label.text = "Очки: " + str(score)
	
	# Скрываем кнопку следующего уровня
	if next_level_button:
		next_level_button.visible = false
	
	# Показываем панель
	game_over_panel.visible = true

func _on_next_level_pressed() -> void:
	if level_number == 1:
		# Переходим на уровень 2 через интро
		LevelData.start_level(2)
	elif level_number == 2:
		# Переходим на уровень 3 через интро
		LevelData.start_level(3)
	elif level_number == 3:
		# Переходим на уровень 4 через интро
		LevelData.start_level(4)
	elif level_number == 4:
		# Переходим на уровень 5 через интро
		LevelData.start_level(5)
	elif level_number == 5:
		# Для уровня 5 возвращаемся в главное меню
		get_tree().change_scene_to_file("res://scenes/StartMenu.tscn")
	else:
		# Для остальных уровней возвращаемся в главное меню
		get_tree().change_scene_to_file("res://scenes/StartMenu.tscn")

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
	_state = GameMode.READY
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
	# Используем YandexSDK для загрузки данных
	if OS.has_feature("yandex"):
		YandexSDK.load_data(["best_score"])
		# Подключаемся к сигналу загрузки данных
		if not YandexSDK.data_loaded.is_connected(_on_data_loaded):
			YandexSDK.data_loaded.connect(_on_data_loaded)
		
		# Загружаем статистику
		YandexSDK.load_stats(["games_played", "total_score", "best_score"])
		# Подключаемся к сигналу загрузки статистики
		if not YandexSDK.stats_loaded.is_connected(_on_stats_loaded):
			YandexSDK.stats_loaded.connect(_on_stats_loaded)
		
		# Загружаем все данные
		YandexSDK.load_all_data()
		
		# Загружаем всю статистику
		YandexSDK.load_all_stats()
	else:
		# Fallback на локальное сохранение для не-веб платформ
		var cfg := ConfigFile.new()
		var err: int = cfg.load(SAVE_PATH)
		if err != OK:
			_best = 0
			return
		_best = int(cfg.get_value(SAVE_SECTION, SAVE_KEY_BEST, 0))

func _save_best_to_disk() -> void:
	# Используем YandexSDK для сохранения данных
	if OS.has_feature("yandex"):
		YandexSDK.save_data({"best_score": _best}, true)
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
	# Обновляет отображение счета в GameOverPanel
	if game_over_score_label:
		game_over_score_label.text = tr("ui.gameover.your_score") + ": " + str(score)


func _show_game_over() -> void:
	game_over_panel.visible = true

func _hide_game_over() -> void:
	if game_over_panel:
		game_over_panel.visible = false

# ===== Яндекс SDK и реклама =====
func _setup_yandex_sdk() -> void:
	# Подключаем сигналы от официального YandexSDK
	YandexSDK.interstitial_ad.connect(_on_interstitial_ad)
	YandexSDK.rewarded_ad.connect(_on_rewarded_ad)
	if not YandexSDK.stats_loaded.is_connected(_on_stats_loaded):
		YandexSDK.stats_loaded.connect(_on_stats_loaded)
	
	# Запускаем асинхронную инициализацию
	_initialize_yandex_sdk_async()

func _initialize_yandex_sdk_async() -> void:
	# Асинхронная инициализация YandexSDK
	# Проверяем, что игра еще не инициализируется
	if not YandexSDK.is_game_initialization_started and not YandexSDK.is_game_initialized:
		YandexSDK.init_game()
		await YandexSDK.game_initialized
	elif YandexSDK.is_game_initialized:
		pass
	else:
		await YandexSDK.game_initialized
	
	
	# Вызываем Game Ready API
	YandexSDK.game_ready()
	
	# Game Ready API вызывается без дополнительных сигналов

func _show_interstitial_ad() -> void:
	# Показывает Interstitial рекламу при Game Over
	YandexSDK.show_interstitial_ad()


func _on_interstitial_ad(result: String) -> void:
	# Обработчик результата Interstitial рекламы
	match result:
		"opened":
			pass
		"closed":
			pass
		"error":
			pass

func _on_rewarded_ad(result: String) -> void:
	# Обработчик результата Rewarded рекламы
	match result:
		"opened":
			pass
		"rewarded":
			pass
		"closed":
			pass
		"error":
			pass


func _on_data_loaded(data: Dictionary) -> void:
	# Обработчик загрузки данных от YandexSDK
	if data.has("best_score"):
		_best = int(data["best_score"])

func _on_stats_loaded(stats: Dictionary) -> void:
	# Обработчик загрузки статистики от YandexSDK
	if stats.has("best_score"):
		_best = int(stats["best_score"])




func _save_game_stats() -> void:
	"""Сохраняет статистику игры"""
	if OS.has_feature("yandex"):
		var stats = {
			"games_played": 1,
			"total_score": score,
			"best_score": _best
		}
		YandexSDK.save_stats(stats)
		
		# Инкрементируем счетчик игр
		var increments = {
			"games_played": 1
		}
		YandexSDK.increment_stats(increments)


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
		pass

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
	# Обновляет все тексты в игровом интерфейсе
	# Обновляем кнопку меню
	if menu_button:
		menu_button.text = tr("ui.menu.button")
	
	# Обновляем заголовок Game Over
	var game_over_label = get_node("UI/UIRoot/GameOverPanel/MainContainer/GameOverLabel")
	if game_over_label:
		game_over_label.text = tr("ui.gameover.title")
	
	


func check_touch_chain() -> bool:
	if combo_lock:
		return false
	donuts = donuts.filter(func(x): return is_instance_valid(x))
	var n: int = donuts.size()
	if n < 4:  # УВЕЛИЧЕННАЯ ПОДКРУТКА: уменьшено с 5 до 4 пончиков для цепочки
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
		if color_indices.size() < 4:  # УВЕЛИЧЕННАЯ ПОДКРУТКА: уменьшено с 5 до 4 пончиков для цепочки
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
				var touch: bool = dist <= (di.get_radius() + dj.get_radius()) * 1.15  # УВЕЛИЧЕННАЯ ПОДКРУТКА: увеличено с 1.02 до 1.15
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
			if comp.size() >= 4:  # УВЕЛИЧЕННАЯ ПОДКРУТКА: уменьшено с 5 до 4 пончиков для цепочки
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
	add_score(bonus_points)
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

# ===== Тестирование SpawnDirector =====
func _test_spawn_director() -> void:
	"""Тестовая функция для проверки работы SpawnDirector"""
	print("=== Тест SpawnDirector ===")
	print("Уровень: ", level_number)
	
	# Генерируем 20 пончиков и выводим результаты
	for i in range(20):
		var donut_type := SpawnDirector.get_next_donut_type(level_number)
		print("Спавн ", i + 1, ": ", donut_type)
	
	print("=== Конец теста ===")
