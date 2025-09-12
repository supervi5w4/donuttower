extends Control

@onready var next_level_btn: Button = get_node_or_null("%NextLevelButton")
@onready var restart_btn: Button = get_node_or_null("%RestartButton")
@onready var score_label: Label = get_node_or_null("%ScoreLabel")
@onready var game_over_label: Label = get_node_or_null("MainContainer/GameOverLabel")
@onready var game_over_score_label: Label = get_node_or_null("MainContainer/ScoreLabel")
@onready var menu_button: Button = get_node_or_null("MainContainer/MenuButton")
@onready var extra_life_button: Button = get_node_or_null("MainContainer/ExtraLifeButton")

var _next_scene_path: String = ""
var _is_win: bool = false
var _current_scene_path: String = ""  # Путь к текущей сцене для перезапуска

const ENABLE_ADS_RETRY := true  # Включаем рекламу

func _ready() -> void:
	add_to_group("GameOverPanel")
	
	# Подключаемся к сигналу смены языка
	if LanguageManager:
		LanguageManager.language_changed.connect(_on_language_changed)

	# Создаем кнопку "Следующий уровень" программно, если её нет в сцене
	if next_level_btn == null:
		next_level_btn = Button.new()
		next_level_btn.name = "NextLevelButton"
		next_level_btn.text = tr("ui.next_level.button")
		next_level_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		next_level_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		add_child(next_level_btn)

	next_level_btn.visible = false
	next_level_btn.pressed.connect(_on_next_level_pressed)

	# Создаем кнопку дополнительной жизни программно, если её нет в сцене
	if extra_life_button == null:
		extra_life_button = Button.new()
		extra_life_button.name = "ExtraLifeButton"
		extra_life_button.text = tr("ui.extra_life.button")
		extra_life_button.custom_minimum_size = Vector2(400, 80)  # Тот же размер, что и у других кнопок
		extra_life_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		extra_life_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		
		# Применяем точно те же стили, что и у других кнопок в меню
		extra_life_button.add_theme_color_override("font_hover_color", Color(0.2, 0.1, 0.05, 1))
		extra_life_button.add_theme_color_override("font_color", Color(0.2, 0.1, 0.05, 1))
		extra_life_button.add_theme_color_override("font_pressed_color", Color(0.2, 0.1, 0.05, 1))
		extra_life_button.add_theme_font_size_override("font_size", 24)
		
		# Создаем стили точно такие же, как у кнопок в сцене
		var normal_style = StyleBoxFlat.new()
		normal_style.bg_color = Color(1, 0.6, 0.2, 1)
		normal_style.corner_radius_top_left = 25
		normal_style.corner_radius_top_right = 25
		normal_style.corner_radius_bottom_right = 25
		normal_style.corner_radius_bottom_left = 25
		normal_style.shadow_color = Color(0, 0, 0, 0.3)
		normal_style.shadow_size = 8
		normal_style.shadow_offset = Vector2(0, 4)
		
		var hover_style = StyleBoxFlat.new()
		hover_style.bg_color = Color(1, 0.8, 0.4, 1)
		hover_style.corner_radius_top_left = 25
		hover_style.corner_radius_top_right = 25
		hover_style.corner_radius_bottom_right = 25
		hover_style.corner_radius_bottom_left = 25
		hover_style.shadow_color = Color(0, 0, 0, 0.4)
		hover_style.shadow_size = 10
		hover_style.shadow_offset = Vector2(0, 5)
		
		var pressed_style = StyleBoxFlat.new()
		pressed_style.bg_color = Color(1, 0.6, 0.2, 1)
		pressed_style.corner_radius_top_left = 25
		pressed_style.corner_radius_top_right = 25
		pressed_style.corner_radius_bottom_right = 25
		pressed_style.corner_radius_bottom_left = 25
		pressed_style.shadow_color = Color(0, 0, 0, 0.3)
		pressed_style.shadow_size = 8
		pressed_style.shadow_offset = Vector2(0, 4)
		
		# Применяем стили
		extra_life_button.add_theme_stylebox_override("normal", normal_style)
		extra_life_button.add_theme_stylebox_override("hover", hover_style)
		extra_life_button.add_theme_stylebox_override("pressed", pressed_style)
		
		# Добавляем кнопку в MainContainer в правильную позицию
		var main_container := get_node("MainContainer")
		
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
	
	# Подключаем сигнал
	extra_life_button.pressed.connect(_on_ads_pressed)
	extra_life_button.visible = false  # Скрываем по умолчанию
	
	# Подключаемся к сигналу рекламы YandexSDK
	if YandexSDK:
		YandexSDK.rewarded_ad.connect(_on_rewarded_ad_result)

func show_game_over(score: int, is_win: bool, next_scene_path: String = "", current_scene_path: String = "") -> void:
	
	_is_win = is_win
	_next_scene_path = next_scene_path
	_current_scene_path = current_scene_path

	# Обновляем заголовок
	if game_over_label:
		game_over_label.text = tr("ui.gameover.title") if not is_win else tr("ui.level.completed")

	# Скрываем счет (убираем отображение очков)
	if game_over_score_label:
		game_over_score_label.visible = false

	# Показываем кнопку "Следующий уровень" только если:
	# 1. Игрок выиграл (is_win == true)
	# 2. Есть путь к следующей сцене
	# 3. Уровень 2 разблокирован
	var can_go_next := is_win and _next_scene_path != "" and GameStateManager.is_unlocked(2)
	if next_level_btn:
		next_level_btn.visible = can_go_next
	
	# Показываем кнопку "Дополнительная жизнь" только если игрок проиграл
	if extra_life_button:
		extra_life_button.visible = ENABLE_ADS_RETRY and not is_win
	
	# Обновляем все тексты с учетом текущего языка
	_update_all_texts()
	
	# Показываем панель
	visible = true

func _on_language_changed(_language_code: String) -> void:
	"""Обработчик смены языка - обновляем все тексты"""
	_update_all_texts()

func _update_all_texts() -> void:
	"""Обновляет все тексты с учетом текущего языка"""
	# Обновляем кнопку следующего уровня
	if next_level_btn:
		next_level_btn.text = tr("ui.next_level.button")
	
	# Обновляем кнопку дополнительной жизни
	if extra_life_button:
		extra_life_button.text = tr("ui.extra_life.button")
	
	# Обновляем кнопку меню
	if menu_button:
		menu_button.text = tr("ui.menu.button")
	
	# Обновляем заголовок если панель видна
	if visible and game_over_label:
		game_over_label.text = tr("ui.gameover.title") if not _is_win else tr("ui.level.completed")

func _on_next_level_pressed() -> void:
	if _next_scene_path != "":
		get_tree().change_scene_to_file(_next_scene_path)

func _on_ads_pressed() -> void:
	"""Обработчик нажатия кнопки дополнительной жизни"""
	if YandexSDK:
		YandexSDK.show_rewarded_ad()
	else:
		# В случае отсутствия SDK, просто перезапускаем уровень
		_restart_current_level()

func _on_rewarded_ad_result(result: String) -> void:
	"""Обработчик результата просмотра рекламы за вознаграждение"""
	
	match result:
		"rewarded":
			_restart_current_level()
		"closed":
			pass
		"opened":
			pass
		"error":
			# В случае ошибки тоже перезапускаем уровень
			_restart_current_level()

func _restart_current_level() -> void:
	"""Перезапускает текущий уровень"""
	if _current_scene_path != "":
		get_tree().change_scene_to_file(_current_scene_path)
	else:
		pass

# Fallback функция для совместимости со старым кодом
func show_game_over_fallback(score: int, is_win: bool) -> void:
	"""Fallback функция для показа панели проигрыша"""
	
	# Обновляем заголовок
	if game_over_label:
		game_over_label.text = tr("ui.gameover.title_win") if not is_win else tr("ui.level.completed")
	
	# Скрываем счет (убираем отображение очков)
	if game_over_score_label:
		game_over_score_label.visible = false
	
	# Скрываем кнопку следующего уровня в fallback режиме
	if next_level_btn:
		next_level_btn.visible = false
	
	# Показываем кнопку дополнительной жизни только при проигрыше
	if extra_life_button:
		extra_life_button.visible = ENABLE_ADS_RETRY and not is_win
	
	# Убеждаемся, что кнопка меню видна
	if menu_button:
		menu_button.visible = true
	
	# Показываем панель
	visible = true
