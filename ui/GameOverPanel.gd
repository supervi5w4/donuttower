extends Control

@onready var next_level_btn: Button = get_node_or_null("%NextLevelButton")
@onready var restart_btn: Button = get_node_or_null("%RestartButton")
@onready var score_label: Label = get_node_or_null("%ScoreLabel")

var _next_scene_path: String = ""
var _is_win: bool = false

const ENABLE_ADS_RETRY := false
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
		ads_btn.text = "Ещё одна жизнь (реклама)"
		ads_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		ads_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		add_child(ads_btn)

	if ads_btn:
		ads_btn.visible = ENABLE_ADS_RETRY
		ads_btn.pressed.connect(_on_ads_pressed)

func show_game_over(score: int, is_win: bool, next_scene_path: String = "") -> void:
	_is_win = is_win
	_next_scene_path = next_scene_path

	if score_label:
		score_label.text = "Очки: %d" % score

	# Показываем кнопку "Следующий уровень" только если:
	# 1. Игрок выиграл (is_win == true)
	# 2. Есть путь к следующей сцене
	# 3. Уровень 2 разблокирован
	var can_go_next := is_win and _next_scene_path != "" and GameStateManager.is_unlocked(2)
	if next_level_btn:
		next_level_btn.visible = can_go_next
	else:
	
	# Показываем панель
	visible = true

func _on_next_level_pressed() -> void:
	if _next_scene_path != "":
		get_tree().change_scene_to_file(_next_scene_path)

func _on_ads_pressed() -> void:
	if Engine.has_singleton("YandexSDK"):
		YandexSDK.show_rewarded_ad()
	else:
