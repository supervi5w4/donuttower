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
var game_over_panel: Control
@onready var game_over_score_label: Label = get_node("UI/UIRoot/GameOverPanel/MainContainer/ScoreLabel")
@onready var menu_button: Button = get_node("UI/UIRoot/GameOverPanel/MainContainer/MenuButton")
@onready var game_over_label: Label = get_node("UI/UIRoot/GameOverPanel/MainContainer/GameOverLabel")

# Кнопка следующего уровня (создадим программно)
var next_level_button: Button

# Кнопка дополнительной жизни
var extra_life_button: Button
var spawner: Spawner
# YandexSDK теперь доступен как автозагруженный синглтон
var preview: PreviewDonut

# Белая вспышка экрана
var white_flash_overlay: ColorRect

# Эффекты завершения уровня
var level_complete_overlay: ColorRect
var level_complete_label: Label
var celebration_particles: GPUParticles2D
var level_complete_timer: Timer

# Удалено: система рекламы по времени

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

# Модификаторы сложности по уровням
const LEVEL_SPEED_MODIFIERS := {
	1: 1.0,   # Уровень 1 - базовая скорость
	2: 1.1,   # Уровень 2 - +10% скорости
	3: 1.2,   # Уровень 3 - +20% скорости
	4: 1.3,   # Уровень 4 - +30% скорости
	5: 1.4,   # Уровень 5 - +40% скорости
	6: 1.5,   # Уровень 6 - +50% скорости
	7: 1.0    # Уровень 7 - базовая скорость (как первый уровень)
}

const LEVEL_COOLDOWN_MODIFIERS := {
	1: 1.0,   # Уровень 1 - базовый кулдаун
	2: 0.9,   # Уровень 2 - -10% кулдауна (быстрее спавн)
	3: 0.8,   # Уровень 3 - -20% кулдауна
	4: 0.7,   # Уровень 4 - -30% кулдауна
	5: 0.6,   # Уровень 5 - -40% кулдауна
	6: 0.5,   # Уровень 6 - -50% кулдауна
	7: 1.0    # Уровень 7 - базовый кулдаун (как первый уровень)
}

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
	print("Game: _ready() начал выполнение для уровня ", level_number)
	get_node("/root/GameStateManager").reset_for_level(level_number)
	
	# Музыка полностью отключена по запросу пользователя
	
	# Проверяем, есть ли GameOverPanel в сцене
	var panel := get_node_or_null("UI/UIRoot/GameOverPanel")
	if panel:
		pass
	
	# Получаем информацию об уровне из LevelData
	var level_info = LevelData.get_level_info(level_number)
	if level_info:
		score_to_unlock = level_info.target_score
	
	_level_ui = LevelUI.new()
	add_child(_level_ui)
	_level_ui.set_level_number(level_number)
	_level_ui.set_progress(0, score_to_unlock)
	
	# Устанавливаем цветовую схему для уровня
	if level_info and level_info.color_scheme:
		_level_ui.set_color_scheme(level_info.color_scheme)
	
	_apply_level_params()
	
	_load_best_from_disk()
	_init_donut_pool()
	_hide_game_over()
	_setup_game_over_panel()
	_setup_yandex_sdk()
	_setup_language_manager()
	_setup_white_flash()
	_setup_level_complete_effects()

	# Камера
	if cam != null:
		cam.position = Vector2(VIRT_W * 0.5, VIRT_H * 0.5)
		_cam_start_y = cam.position.y
		_tower_top_y = cam.position.y + VIRT_H * 0.5
		_apply_camera_limits()

	# Применить сложность на старте
	_recalc_difficulty()
	
	# Инициализируем SpawnDirector для уровня
	SpawnDirector.init_seed(int(Time.get_unix_time_from_system()))
	SpawnDirector.reset(level_number)
	
	# Инициализируем spawner
	spawner = get_node_or_null("Spawner")
	if not spawner:
		print("Ошибка: spawner не найден в сцене!")
		return
	
	# Инициализируем preview после spawner
	preview = spawner.get_node_or_null("PreviewDonut")
	if not preview:
		print("Ошибка: PreviewDonut не найден в spawner!")
		return
	
	# Инициализируем game_over_panel
	game_over_panel = get_node_or_null("UI/UIRoot/GameOverPanel")
	if not game_over_panel:
		print("Ошибка: game_over_panel не найден в сцене!")
		return
	
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
	
	# Подключаемся к событиям видимости страницы для обработки звуковых эффектов
	_setup_visibility_handlers()

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
	
	# Музыка отключена по запросу пользователя
	# 	print("Фоновая музыка запущена при начале игры")
	
	# Game Ready API уже был вызван в StartMenu при загрузке игры
	# Здесь мы только запускаем геймплей
	
	# Запускаем аналитику
	print("Game: вызываем YandexSDK.gameplay_started()...")
	YandexSDK.gameplay_started()
	print("Game: YandexSDK.gameplay_started() вызван")
	
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
	
	# Применяем модификатор уровня для кулдауна
	var level_cooldown_modifier: float = LEVEL_COOLDOWN_MODIFIERS.get(level_number, 1.0)
	if level_number > 6:
		# Для уровней выше 6 - прогрессивное уменьшение кулдауна
		level_cooldown_modifier = 0.5 - (level_number - 6) * 0.05
		level_cooldown_modifier = max(0.2, level_cooldown_modifier)  # Минимум 20% от базового кулдауна
	
	var effective_cooldown: float = SPAWN_COOLDOWN * level_cooldown_modifier
	return t - _last_spawn_time >= effective_cooldown

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

	# Победа на уровнях - используем данные из LevelData
	var level_info = LevelData.get_level_info(level_number)
	print("Game: Проверка победы - уровень: ", level_number, ", счет: ", score, ", цель: ", level_info.target_score if level_info else "НЕТ ДАННЫХ")
	if level_info and score >= level_info.target_score:
		print("Game: УСЛОВИЕ ПОБЕДЫ ВЫПОЛНЕНО! Уровень: ", level_number)
		if level_number < 5:
			get_node("/root/GameStateManager").unlock_level(level_number + 1)
			_level_completed_with_flash()
		elif level_number == 5:
			# Для уровня 5 переходим на уровень 6
			get_node("/root/GameStateManager").unlock_level(6)
			_level_completed_with_flash()
		elif level_number == 6:
			# Для уровня 6 (финального) показываем специальное поздравление
			_open_win_panel()

func _setup_game_over_panel() -> void:
	# Проверяем, что game_over_panel инициализирован
	if not game_over_panel:
		print("Ошибка: game_over_panel не инициализирован!")
		return
	
	# Сначала проверяем, есть ли уже кнопка в сцене
	next_level_button = game_over_panel.get_node_or_null("MainContainer/NextLevelButton")
	
	if next_level_button:
		# Кнопка уже есть в сцене - подключаем сигнал только если он еще не подключен
		if not next_level_button.pressed.is_connected(_on_next_level_pressed):
			next_level_button.pressed.connect(_on_next_level_pressed)
		# Скрываем кнопку по умолчанию
		next_level_button.visible = false
	else:
		# Кнопки нет в сцене - создаем программно для уровней 1, 2, 3 и 4
		if level_number == 1 or level_number == 2 or level_number == 3 or level_number == 4:
			next_level_button = Button.new()
			next_level_button.name = "NextLevelButton"
			next_level_button.text = tr("ui.next_level.button")
			next_level_button.custom_minimum_size = Vector2(400, 80)
			next_level_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			next_level_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			
			# Стилизация кнопки в том же стиле, что и MenuButton
			next_level_button.add_theme_color_override("font_hover_color", Color(0.2, 0.1, 0.05, 1))
			next_level_button.add_theme_color_override("font_color", Color(0.2, 0.1, 0.05, 1))
			next_level_button.add_theme_color_override("font_pressed_color", Color(0.2, 0.1, 0.05, 1))
			next_level_button.add_theme_font_size_override("font_size", 24)
			
			# Применяем те же стили, что и у MenuButton
			var menu_btn := game_over_panel.get_node("MainContainer/MenuButton")
			if menu_btn:
				# Копируем стили от MenuButton
				next_level_button.add_theme_stylebox_override("hover", menu_btn.get_theme_stylebox("hover"))
				next_level_button.add_theme_stylebox_override("pressed", menu_btn.get_theme_stylebox("pressed"))
				next_level_button.add_theme_stylebox_override("normal", menu_btn.get_theme_stylebox("normal"))
			
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
			
			# Подключаем сигнал только если он еще не подключен
			if not next_level_button.pressed.is_connected(_on_next_level_pressed):
				next_level_button.pressed.connect(_on_next_level_pressed)
			
			# Скрываем кнопку по умолчанию
			next_level_button.visible = false
	
	# Создаем кнопку дополнительной жизни
	_setup_extra_life_button()

func _setup_extra_life_button() -> void:
	"""Создает кнопку дополнительной жизни"""
	# Проверяем, что game_over_panel инициализирован
	if not game_over_panel:
		print("Ошибка: game_over_panel не инициализирован!")
		return
	
	# Проверяем, есть ли уже кнопка в сцене
	extra_life_button = game_over_panel.get_node_or_null("MainContainer/ExtraLifeButton")
	
	if extra_life_button:
		# Кнопка уже есть в сцене - подключаем сигнал только если он еще не подключен
		if not extra_life_button.pressed.is_connected(_on_extra_life_pressed):
			extra_life_button.pressed.connect(_on_extra_life_pressed)
		# Скрываем кнопку по умолчанию
		extra_life_button.visible = false
	else:
		# Создаем кнопку программно
		extra_life_button = Button.new()
		extra_life_button.name = "ExtraLifeButton"
		extra_life_button.text = tr("ui.extra_life.button")
		extra_life_button.custom_minimum_size = Vector2(400, 80)
		extra_life_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		extra_life_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		
		# Стилизация кнопки в том же стиле, что и MenuButton
		extra_life_button.add_theme_color_override("font_hover_color", Color(0.2, 0.1, 0.05, 1))
		extra_life_button.add_theme_color_override("font_color", Color(0.2, 0.1, 0.05, 1))
		extra_life_button.add_theme_color_override("font_pressed_color", Color(0.2, 0.1, 0.05, 1))
		extra_life_button.add_theme_font_size_override("font_size", 24)
		
		# Применяем те же стили, что и у MenuButton
		var menu_btn := game_over_panel.get_node("MainContainer/MenuButton")
		if menu_btn:
			# Копируем стили от MenuButton
			extra_life_button.add_theme_stylebox_override("hover", menu_btn.get_theme_stylebox("hover"))
			extra_life_button.add_theme_stylebox_override("pressed", menu_btn.get_theme_stylebox("pressed"))
			extra_life_button.add_theme_stylebox_override("normal", menu_btn.get_theme_stylebox("normal"))
		
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
			main_container.add_child(extra_life_button)
			main_container.move_child(extra_life_button, menu_button_index)
		else:
			# Fallback: добавляем в конец
			main_container.add_child(extra_life_button)
		
		# Подключаем сигнал только если он еще не подключен
		if not extra_life_button.pressed.is_connected(_on_extra_life_pressed):
			extra_life_button.pressed.connect(_on_extra_life_pressed)
		
		# Скрываем кнопку по умолчанию
		extra_life_button.visible = false

func _setup_white_flash() -> void:
	"""Настраивает белую вспышку экрана"""
	white_flash_overlay = ColorRect.new()
	white_flash_overlay.name = "WhiteFlashOverlay"
	white_flash_overlay.color = Color.WHITE
	white_flash_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	white_flash_overlay.visible = false
	white_flash_overlay.z_index = 1000  # Поверх всего
	add_child(white_flash_overlay)

func _level_completed_with_flash() -> void:
	"""Завершение уровня с выразительными эффектами и паузой"""
	# Останавливаем игру
	_state = GameMode.GAMEOVER
	
	# Показываем выразительные эффекты завершения уровня
	_show_level_complete_effects()
	
	# Ждем завершения всех эффектов и паузы
	await _level_complete_animation()
	
	# Показываем белую вспышку перед переходом
	_show_white_flash()
	await _white_flash_animation()
	
	# Автоматически переходим к следующему уровню
	_go_to_next_level()

func _show_white_flash() -> void:
	"""Показывает белую вспышку экрана"""
	if white_flash_overlay:
		white_flash_overlay.visible = true
		white_flash_overlay.color = Color(1, 1, 1, 0)  # Начинаем с прозрачного
		
		# Анимация появления белой вспышки
		var tween = create_tween()
		tween.tween_property(white_flash_overlay, "color", Color.WHITE, 0.3)
		tween.tween_property(white_flash_overlay, "color", Color(1, 1, 1, 0), 0.3)

func _white_flash_animation() -> void:
	"""Ожидает завершения анимации белой вспышки"""
	if white_flash_overlay:
		var tween = create_tween()
		tween.tween_property(white_flash_overlay, "color", Color.WHITE, 0.3)
		await tween.finished
		
		tween = create_tween()
		tween.tween_property(white_flash_overlay, "color", Color(1, 1, 1, 0), 0.3)
		await tween.finished
		
		white_flash_overlay.visible = false

func _go_to_next_level() -> void:
	"""Автоматически переходит к следующему уровню"""
	if level_number == 1:
		LevelData.set_current_level(2)
		GameStateManager.reset_for_level(2)
		get_tree().change_scene_to_file("res://scenes/Game_level_2.tscn")
	elif level_number == 2:
		LevelData.set_current_level(3)
		GameStateManager.reset_for_level(3)
		get_tree().change_scene_to_file("res://scenes/Game_level_3.tscn")
	elif level_number == 3:
		LevelData.set_current_level(4)
		GameStateManager.reset_for_level(4)
		get_tree().change_scene_to_file("res://scenes/Game_level_4.tscn")
	elif level_number == 4:
		LevelData.set_current_level(5)
		GameStateManager.reset_for_level(5)
		get_tree().change_scene_to_file("res://scenes/Game_level_5.tscn")
	elif level_number == 5:
		# Переходим на уровень 6 напрямую
		LevelData.set_current_level(6)
		GameStateManager.reset_for_level(6)
		get_tree().change_scene_to_file("res://scenes/Game_level_6.tscn")
	elif level_number == 6:
		# Для уровня 6 (финального) возвращаемся в главное меню
		get_tree().change_scene_to_file("res://scenes/StartMenu.tscn")
	else:
		# Для остальных уровней возвращаемся в главное меню
		get_tree().change_scene_to_file("res://scenes/StartMenu.tscn")

func _open_win_panel() -> void:
	_show_win_panel()

func _show_win_panel() -> void:
	# Определяем путь к следующему уровню
	var next_scene_path = ""
	if level_number == 1:
		next_scene_path = "res://scenes/Game_level_2.tscn"
	elif level_number == 2:
		next_scene_path = "res://scenes/Game_level_3.tscn"
	elif level_number == 3:
		next_scene_path = "res://scenes/Game_level_4.tscn"
	elif level_number == 4:
		next_scene_path = "res://scenes/Game_level_5.tscn"
	elif level_number == 5:
		next_scene_path = "res://scenes/Game_level_6.tscn"
	# Для уровня 6 (финального) next_scene_path остается пустым
	
	# Вызываем show_game_over с параметрами победы
	if game_over_panel:
		if game_over_panel.has_method("show_game_over"):
			game_over_panel.show_game_over(score, true, next_scene_path, scene_file_path)
		elif game_over_panel.has_method("show_game_over_fallback"):
			# Используем fallback функцию
			game_over_panel.show_game_over_fallback(score, true)
		else:
			# Последний fallback - показываем панель старым способом
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

	add_score(1)  # 1 donut = 100 point

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
	_set_game_over()
	if game_over_panel:
		# Проверяем, что у GameOverPanel есть функция show_game_over
		if game_over_panel.has_method("show_game_over"):
			# Получаем путь к текущей сцене для перезапуска
			var current_scene_path = scene_file_path
			# Вызываем show_game_over с параметрами проигрыша
			game_over_panel.show_game_over(score, false, "", current_scene_path)
		elif game_over_panel.has_method("show_game_over_fallback"):
			# Используем fallback функцию
			game_over_panel.show_game_over_fallback(score, false)
		else:
			# Последний fallback - показываем панель старым способом
			game_over_panel.visible = true

# ===== Сложность: скорость каретки и запас камеры =====
func _recalc_difficulty() -> void:
	# Скорость каретки: base * level_modifier * clamp(1 + score*rate, 1, MAX_FACTOR)
	var factor: float = 1.0 + float(score) * SPAWNER_SCORE_RATE
	if factor > SPAWNER_MAX_FACTOR:
		factor = SPAWNER_MAX_FACTOR
	
	# Применяем модификатор уровня для скорости
	var level_speed_modifier: float = LEVEL_SPEED_MODIFIERS.get(level_number, 1.0)
	if level_number > 6:
		# Для уровней выше 6 - прогрессивное увеличение
		level_speed_modifier = 1.5 + (level_number - 6) * 0.1
	
	if spawner != null:
		spawner.speed = SPAWNER_BASE_SPEED * level_speed_modifier * factor

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
	
	# Показываем панель поражения
	_show_lose_panel()

func _show_lose_panel() -> void:
	# Вызываем show_game_over с параметрами проигрыша
	if game_over_panel:
		if game_over_panel.has_method("show_game_over"):
			game_over_panel.show_game_over(score, false, "", scene_file_path)
		elif game_over_panel.has_method("show_game_over_fallback"):
			# Используем fallback функцию
			game_over_panel.show_game_over_fallback(score, false)
		else:
			# Последний fallback - показываем панель старым способом
			game_over_panel.visible = true

func _on_next_level_pressed() -> void:
	if level_number == 1:
		# Переходим на уровень 2 напрямую
		LevelData.set_current_level(2)
		GameStateManager.reset_for_level(2)
		get_tree().change_scene_to_file("res://scenes/Game_level_2.tscn")
	elif level_number == 2:
		# Переходим на уровень 3 напрямую
		LevelData.set_current_level(3)
		GameStateManager.reset_for_level(3)
		get_tree().change_scene_to_file("res://scenes/Game_level_3.tscn")
	elif level_number == 3:
		# Переходим на уровень 4 напрямую
		LevelData.set_current_level(4)
		GameStateManager.reset_for_level(4)
		get_tree().change_scene_to_file("res://scenes/Game_level_4.tscn")
	elif level_number == 4:
		# Переходим на уровень 5 напрямую
		LevelData.set_current_level(5)
		GameStateManager.reset_for_level(5)
		get_tree().change_scene_to_file("res://scenes/Game_level_5.tscn")
	elif level_number == 5:
		# Переходим на уровень 6 напрямую
		LevelData.set_current_level(6)
		GameStateManager.reset_for_level(6)
		get_tree().change_scene_to_file("res://scenes/Game_level_6.tscn")
	elif level_number == 6:
		# Для уровня 6 (финального) возвращаемся в главное меню
		get_tree().change_scene_to_file("res://scenes/StartMenu.tscn")
	else:
		# Для остальных уровней возвращаемся в главное меню
		get_tree().change_scene_to_file("res://scenes/StartMenu.tscn")

func _on_restart_pressed() -> void:
	# Запускаем аудио контекст при первом взаимодействии
	# Загружаем главное меню вместо сброса игры
	get_tree().change_scene_to_file("res://scenes/StartMenu.tscn")

func _on_extra_life_pressed() -> void:
	"""Обработчик нажатия кнопки дополнительной жизни"""
	# Запускаем аудио контекст при первом взаимодействии
	# Показываем рекламу за вознаграждение
	if OS.has_feature("yandex"):
		YandexSDK.show_rewarded_ad()
	else:
		# Для тестирования вне Yandex Games
		# Симулируем успешный просмотр рекламы
		_on_rewarded_ad("rewarded")


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
	# Подключаем сигналы от официального YandexSDK только если они еще не подключены
	if not YandexSDK.interstitial_ad.is_connected(_on_interstitial_ad):
		YandexSDK.interstitial_ad.connect(_on_interstitial_ad)
	if not YandexSDK.rewarded_ad.is_connected(_on_rewarded_ad):
		YandexSDK.rewarded_ad.connect(_on_rewarded_ad)
	if not YandexSDK.stats_loaded.is_connected(_on_stats_loaded):
		YandexSDK.stats_loaded.connect(_on_stats_loaded)
	
	# Запускаем асинхронную инициализацию
	_initialize_yandex_sdk_async()

func _initialize_yandex_sdk_async() -> void:
	# Асинхронная инициализация YandexSDK
	# Проверяем, что игра еще не инициализируется
	if not YandexSDK.is_game_initialization_started and not YandexSDK.is_game_initialized:
		print("YandexSDK: начинаем инициализацию игры...")
		YandexSDK.init_game()
		await YandexSDK.game_initialized
		print("YandexSDK: игра инициализирована")
	elif YandexSDK.is_game_initialized:
		print("YandexSDK: игра уже инициализирована")
	else:
		print("YandexSDK: ожидаем завершения инициализации...")
		await YandexSDK.game_initialized
		print("YandexSDK: инициализация завершена")
	
	# Настраиваем обработчики паузы и возобновления
	YandexSDK.setup_pause_resume_handlers()
	
	# НЕ вызываем Game Ready API здесь - он будет вызван когда игра действительно готова
	print("YandexSDK: инициализация завершена, Game Ready API будет вызван при начале игры")

# Удалено: функция показа рекламы по времени


func _on_interstitial_ad(result: String) -> void:
	# Обработчик результата Interstitial рекламы
	match result:
		"opened":
			pass
		"closed":
			# После закрытия interstitial рекламы тоже восстанавливаем музыку
			print("Game: interstitial реклама закрыта, восстанавливаем музыку")
		"error":
			# После ошибки interstitial рекламы тоже восстанавливаем музыку
			print("Game: ошибка interstitial рекламы, восстанавливаем музыку")

func _on_rewarded_ad(result: String) -> void:
	# Обработчик результата Rewarded рекламы
	match result:
		"opened":
			pass
		"rewarded":
			_restart_current_level()
		"closed":
			# После закрытия рекламы восстанавливаем музыку
			print("Game: реклама закрыта, восстанавливаем музыку")
		"error":
			# После ошибки рекламы тоже восстанавливаем музыку
			print("Game: ошибка рекламы, восстанавливаем музыку")

func _restart_current_level() -> void:
	"""Перезапускает текущий уровень после просмотра рекламы"""
	# Скрываем панель Game Over
	_hide_game_over()
	
	# Сбрасываем состояние игры
	_reset_game()
	
	# Перезапускаем уровень
	match level_number:
		1:
			get_tree().change_scene_to_file("res://scenes/Game.tscn")
		2:
			get_tree().change_scene_to_file("res://scenes/Game_level_2.tscn")
		3:
			get_tree().change_scene_to_file("res://scenes/Game_level_3.tscn")
		4:
			get_tree().change_scene_to_file("res://scenes/Game_level_4.tscn")
		5:
			get_tree().change_scene_to_file("res://scenes/Game_level_5.tscn")
		6:
			get_tree().change_scene_to_file("res://scenes/Game_level_6.tscn")
		_:
			get_tree().change_scene_to_file("res://scenes/Game.tscn")

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


# ===== Удалено: система рекламы по времени =====

# ===== Управление языками =====
func _setup_language_manager() -> void:
	"""Настраивает обработчик смены языка"""
	if LanguageManager:
		LanguageManager.language_changed.connect(_on_language_changed)
		# Обновляем UI тексты сразу после подключения к сигналу
		_update_all_ui_texts()
		_update_game_over_score()

func _on_language_changed(_language_code: String) -> void:
	"""Обработчик смены языка - обновляем все тексты"""
	_update_game_over_score()
	_update_all_ui_texts()

func _update_all_ui_texts() -> void:
	# Обновляет все тексты в игровом интерфейсе
	# Обновляем кнопку меню
	if menu_button:
		menu_button.text = tr("ui.menu.button")
	
	# Обновляем заголовок Game Over
	var game_over_lbl = get_node("UI/UIRoot/GameOverPanel/MainContainer/GameOverLabel")
	if game_over_lbl:
		game_over_lbl.text = tr("ui.gameover.title")
	
	


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
	pass

# Настройка обработчиков видимости страницы
func _setup_visibility_handlers() -> void:
	"""Настраивает обработчики видимости страницы для звуковых эффектов"""
	# Подключаемся к событиям видимости окна
	get_window().visibility_changed.connect(_on_visibility_changed)
	
	# Для веб-платформы дополнительно подключаемся к Page Visibility API
	if OS.has_feature("web"):
		_setup_page_visibility_api()

# Обработка изменения видимости страницы
func _on_visibility_changed() -> void:
	"""Обработчик изменения видимости страницы для звуковых эффектов"""
	if not get_window().visible:
		print("Game: страница стала невидимой, приостанавливаем звуковые эффекты")
		_pause_all_sound_effects()
	else:
		print("Game: страница стала видимой, возобновляем звуковые эффекты")
		_resume_all_sound_effects()

# Настройка Page Visibility API для веб-платформы
func _setup_page_visibility_api() -> void:
	"""Настраивает обработчики Page Visibility API для веб-платформы"""
	if not OS.has_feature("web"):
		return
	
	JavaScriptBridge.eval("""
		(() => {
			// Функция для отправки события в Godot
			function notifyGameVisibilityChange(isVisible) {
				if (window.godot && window.godot.call) {
					window.godot.call('Game', '_on_page_visibility_change', [isVisible]);
				}
			}
			
			// Обработчики для Page Visibility API
			document.addEventListener('visibilitychange', function() {
				const isVisible = !document.hidden;
				console.log('Game Page Visibility API: страница', isVisible ? 'видима' : 'скрыта');
				notifyGameVisibilityChange(isVisible);
			});
			
			// Дополнительные обработчики для различных событий
			window.addEventListener('blur', function() {
				console.log('Game Page Visibility API: окно потеряло фокус');
				notifyGameVisibilityChange(false);
			});
			
			window.addEventListener('focus', function() {
				console.log('Game Page Visibility API: окно получило фокус');
				notifyGameVisibilityChange(true);
			});
			
			console.log('Game: Page Visibility API настроен');
		})();
	""")

# Обработчик изменения видимости страницы через Page Visibility API
func _on_page_visibility_change(page_visible: bool) -> void:
	"""Обработчик изменения видимости страницы через Page Visibility API"""
	print("Game: Page Visibility API - страница ", "видима" if page_visible else "скрыта")
	
	if not page_visible:
		# Страница стала невидимой - приостанавливаем звуковые эффекты
		print("Game: страница стала невидимой (Page Visibility API), приостанавливаем звуковые эффекты")
		_pause_all_sound_effects()
	else:
		# Страница стала видимой - возобновляем звуковые эффекты
		print("Game: страница стала видимой (Page Visibility API), возобновляем звуковые эффекты")
		_resume_all_sound_effects()

# Приостановка всех звуковых эффектов
func _pause_all_sound_effects() -> void:
	"""Приостанавливает все звуковые эффекты в игре"""
	# Приостанавливаем все AudioStreamPlayer узлы в сцене
	_pause_audio_nodes_recursive(self)
	
	# Приостанавливаем звуки пончиков
	for donut in active_donuts:
		if is_instance_valid(donut):
			_pause_audio_nodes_recursive(donut)

# Возобновление всех звуковых эффектов
func _resume_all_sound_effects() -> void:
	"""Возобновляет все звуковые эффекты в игре"""
	# Возобновляем все AudioStreamPlayer узлы в сцене
	_resume_audio_nodes_recursive(self)
	
	# Возобновляем звуки пончиков
	for donut in active_donuts:
		if is_instance_valid(donut):
			_resume_audio_nodes_recursive(donut)

# Рекурсивная приостановка аудио узлов
func _pause_audio_nodes_recursive(node: Node) -> void:
	"""Рекурсивно приостанавливает все AudioStreamPlayer узлы"""
	if node is AudioStreamPlayer:
		if node.playing:
			node.stream_paused = true
	
	for child in node.get_children():
		_pause_audio_nodes_recursive(child)

# Рекурсивное возобновление аудио узлов
func _resume_audio_nodes_recursive(node: Node) -> void:
	"""Рекурсивно возобновляет все AudioStreamPlayer узлы"""
	if node is AudioStreamPlayer:
		if node.stream_paused:
			node.stream_paused = false
	
	for child in node.get_children():
		_resume_audio_nodes_recursive(child)


# ===== Эффекты завершения уровня =====
func _setup_level_complete_effects() -> void:
	"""Настраивает эффекты для завершения уровня"""
	
	# Создаем оверлей для эффектов завершения уровня
	level_complete_overlay = ColorRect.new()
	level_complete_overlay.name = "LevelCompleteOverlay"
	level_complete_overlay.color = Color(0, 0, 0, 0)  # Прозрачный
	level_complete_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	level_complete_overlay.visible = false
	level_complete_overlay.z_index = 500  # Поверх игры, но под UI
	add_child(level_complete_overlay)
	
	# Создаем лейбл "Уровень пройден!"
	level_complete_label = Label.new()
	level_complete_label.name = "LevelCompleteLabel"
	# Показываем "Игра пройдена!" на 6-м уровне, иначе "Уровень пройден!"
	if level_number == 6:
		level_complete_label.text = tr("ui.game.completed")
	else:
		level_complete_label.text = tr("ui.level_complete.title")
	level_complete_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_complete_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	level_complete_label.add_theme_font_size_override("font_size", 64)
	level_complete_label.add_theme_color_override("font_color", Color.GOLD)
	level_complete_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	level_complete_label.add_theme_constant_override("shadow_offset_x", 4)
	level_complete_label.add_theme_constant_override("shadow_offset_y", 4)
	
	# Простое центрирование через размер и позицию
	level_complete_label.size = Vector2(VIRT_W, 100)  # На всю ширину экрана
	level_complete_label.position = Vector2(0, VIRT_H * 0.5 - 50)  # По центру по вертикали
	
	level_complete_label.visible = false
	level_complete_label.z_index = 600
	add_child(level_complete_label)
	
	# Создаем систему частиц для празднования
	celebration_particles = GPUParticles2D.new()
	celebration_particles.name = "CelebrationParticles"
	celebration_particles.position = Vector2(VIRT_W * 0.5, VIRT_H * 0.5)  # Центр экрана
	celebration_particles.z_index = 550
	
	# Настраиваем материал частиц
	var particle_material = ParticleProcessMaterial.new()
	particle_material.direction = Vector3(0, -1, 0)  # Взрыв вверх
	particle_material.initial_velocity_min = 200.0
	particle_material.initial_velocity_max = 400.0
	particle_material.gravity = Vector3(0, 98, 0)  # Гравитация
	particle_material.scale_min = 0.5
	particle_material.scale_max = 1.5
	particle_material.color = Color.GOLD
	particle_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	particle_material.emission_sphere_radius = 50.0
	
	celebration_particles.process_material = particle_material
	celebration_particles.amount = 100
	celebration_particles.lifetime = 3.0
	celebration_particles.emitting = false
	celebration_particles.visible = false
	add_child(celebration_particles)
	
	# Создаем таймер для паузы
	level_complete_timer = Timer.new()
	level_complete_timer.name = "LevelCompleteTimer"
	level_complete_timer.wait_time = 2.5  # 2.5 секунды паузы
	level_complete_timer.one_shot = true
	add_child(level_complete_timer)

func _show_level_complete_effects() -> void:
	"""Показывает эффекты завершения уровня"""
	if not level_complete_overlay or not level_complete_label or not celebration_particles:
		return
	
	# Показываем оверлей с анимацией
	level_complete_overlay.visible = true
	var tween = create_tween()
	tween.tween_property(level_complete_overlay, "color", Color(0, 0, 0, 0.3), 0.5)
	
	# Показываем лейбл с анимацией
	level_complete_label.visible = true
	level_complete_label.scale = Vector2.ZERO
	level_complete_label.modulate = Color.WHITE
	
	# Анимация появления лейбла
	var label_tween = create_tween()
	label_tween.tween_property(level_complete_label, "scale", Vector2.ONE, 0.8)
	label_tween.tween_property(level_complete_label, "modulate", Color.GOLD, 0.3)
	
	# Добавляем пульсацию
	var pulse_tween = create_tween()
	pulse_tween.set_loops()
	pulse_tween.tween_property(level_complete_label, "scale", Vector2(1.1, 1.1), 0.5)
	pulse_tween.tween_property(level_complete_label, "scale", Vector2.ONE, 0.5)
	
	# Запускаем частицы празднования
	celebration_particles.visible = true
	celebration_particles.restart()
	celebration_particles.emitting = true
	
	# Добавляем эффект "звездного взрыва" для всех пончиков на экране
	_create_star_explosion_effect()

func _create_star_explosion_effect() -> void:
	"""Создает эффект звездного взрыва для всех пончиков"""
	for donut in active_donuts:
		if is_instance_valid(donut):
			# Создаем маленькие частицы вокруг каждого пончика
			var star_particles = GPUParticles2D.new()
			star_particles.position = donut.global_position
			star_particles.z_index = 400
			
			var star_material = ParticleProcessMaterial.new()
			star_material.direction = Vector3(0, 0, 0)  # Взрыв во все стороны
			star_material.initial_velocity_min = 50.0
			star_material.initial_velocity_max = 150.0
			star_material.gravity = Vector3(0, 50, 0)  # Слабая гравитация
			star_material.scale_min = 0.2
			star_material.scale_max = 0.8
			star_material.color = Color.YELLOW
			star_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
			star_material.emission_sphere_radius = 20.0
			
			star_particles.process_material = star_material
			star_particles.amount = 20
			star_particles.lifetime = 1.5
			star_particles.emitting = true
			
			add_child(star_particles)
			
			# Удаляем частицы через время
			var cleanup_timer = Timer.new()
			cleanup_timer.wait_time = 2.0
			cleanup_timer.one_shot = true
			cleanup_timer.timeout.connect(star_particles.queue_free)
			star_particles.add_child(cleanup_timer)
			cleanup_timer.start()

func _level_complete_animation() -> void:
	"""Ожидает завершения анимации завершения уровня"""
	# Запускаем таймер паузы
	level_complete_timer.start()
	await level_complete_timer.timeout
	
	# Скрываем эффекты
	if level_complete_overlay:
		var tween = create_tween()
		tween.tween_property(level_complete_overlay, "color", Color(0, 0, 0, 0), 0.5)
		await tween.finished
		level_complete_overlay.visible = false
	
	if level_complete_label:
		var label_tween = create_tween()
		label_tween.tween_property(level_complete_label, "modulate", Color(1, 1, 1, 0), 0.5)
		await label_tween.finished
		level_complete_label.visible = false
	
	if celebration_particles:
		celebration_particles.emitting = false
		celebration_particles.visible = false
