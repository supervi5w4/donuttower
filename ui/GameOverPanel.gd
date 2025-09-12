extends Control

@onready var next_level_btn: Button = get_node_or_null("%NextLevelButton")
@onready var restart_btn: Button = get_node_or_null("%RestartButton")
@onready var score_label: Label = get_node_or_null("%ScoreLabel")
@onready var game_over_label: Label = get_node_or_null("MainContainer/GameOverLabel")
@onready var game_over_score_label: Label = get_node_or_null("MainContainer/ScoreLabel")
@onready var menu_button: Button = get_node_or_null("MainContainer/MenuButton")

var _next_scene_path: String = ""
var _is_win: bool = false
var _current_scene_path: String = ""  # Путь к текущей сцене для перезапуска

const ENABLE_ADS_RETRY := true  # Включаем рекламу
@onready var ads_btn: Button = get_node_or_null("%ExtraLifeButton")

func _ready() -> void:
	add_to_group("GameOverPanel")

	# Создаем кнопку "Следующий уровень" программно, если её нет в сцене
	if next_level_btn == null:
		next_level_btn = Button.new()
		next_level_btn.name = "NextLevelButton"
		next_level_btn.text = "Следующий уровень"
		next_level_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		next_level_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		add_child(next_level_btn)

	next_level_btn.visible = false
	next_level_btn.pressed.connect(_on_next_level_pressed)

	# Создаем кнопку рекламы программно, если её нет в сцене и включена
	if ads_btn == null and ENABLE_ADS_RETRY:
		ads_btn = Button.new()
		ads_btn.name = "ExtraLifeButton"
		ads_btn.text = tr("ui.extra_life.button")
		ads_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		ads_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		add_child(ads_btn)

	if ads_btn:
		ads_btn.visible = ENABLE_ADS_RETRY
		ads_btn.pressed.connect(_on_ads_pressed)
		
	# Подключаемся к сигналу рекламы YandexSDK
	if YandexSDK:
		YandexSDK.rewarded_ad.connect(_on_rewarded_ad_result)

func show_game_over(score: int, is_win: bool, next_scene_path: String = "", current_scene_path: String = "") -> void:
	_is_win = is_win
	_next_scene_path = next_scene_path
	_current_scene_path = current_scene_path

	# Обновляем заголовок
	if game_over_label:
		game_over_label.text = "Игра окончена!" if not is_win else "Уровень пройден!"

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
	if ads_btn:
		ads_btn.visible = ENABLE_ADS_RETRY and not is_win and _current_scene_path != ""
	
	# Показываем панель
	visible = true

func _on_next_level_pressed() -> void:
	if _next_scene_path != "":
		get_tree().change_scene_to_file(_next_scene_path)

func _on_ads_pressed() -> void:
	"""Обработчик нажатия кнопки дополнительной жизни"""
	if YandexSDK:
		print("Показываем рекламу за вознаграждение...")
		YandexSDK.show_rewarded_ad()
	else:
		print("YandexSDK недоступен")
		# В случае отсутствия SDK, просто перезапускаем уровень
		_restart_current_level()

func _on_rewarded_ad_result(result: String) -> void:
	"""Обработчик результата просмотра рекламы за вознаграждение"""
	print("Результат рекламы: ", result)
	
	match result:
		"rewarded":
			print("Игрок получил награду! Перезапускаем уровень...")
			_restart_current_level()
		"closed":
			print("Реклама закрыта без награды")
		"opened":
			print("Реклама открыта")
		"error":
			print("Ошибка при показе рекламы")
			# В случае ошибки тоже перезапускаем уровень
			_restart_current_level()

func _restart_current_level() -> void:
	"""Перезапускает текущий уровень"""
	if _current_scene_path != "":
		print("Перезапускаем уровень: ", _current_scene_path)
		get_tree().change_scene_to_file(_current_scene_path)
	else:
		print("Ошибка: путь к текущей сцене не задан")

# Fallback функция для совместимости со старым кодом
func show_game_over_fallback(score: int, is_win: bool) -> void:
	"""Fallback функция для показа панели проигрыша"""
	print("Используем fallback функцию show_game_over_fallback")
	
	# Обновляем заголовок
	if game_over_label:
		game_over_label.text = "Игра окончена!" if not is_win else "Уровень пройден!"
	
	# Скрываем счет (убираем отображение очков)
	if game_over_score_label:
		game_over_score_label.visible = false
	
	# Скрываем кнопку следующего уровня в fallback режиме
	if next_level_btn:
		next_level_btn.visible = false
	
	# Показываем кнопку дополнительной жизни только при проигрыше
	if ads_btn:
		ads_btn.visible = ENABLE_ADS_RETRY and not is_win
	
	# Убеждаемся, что кнопка меню видна
	if menu_button:
		menu_button.visible = true
	
	# Показываем панель
	visible = true
