extends Control
## Панель таблицы результатов для GameOverPanel
## Отображает топ-10 игроков в стиле игры

@onready var leaderboard_container: VBoxContainer = $LeaderboardContainer
@onready var loading_label: Label = $LoadingLabel
@onready var error_label: Label = $ErrorLabel
@onready var title_label: Label = $TitleLabel

var yandex_sdk: Node
var leaderboard_entries: Array = []

func _ready() -> void:
	# Находим YandexSDK в сцене
	yandex_sdk = get_node("/root/Game/YandexSDK")
	if yandex_sdk == null:
		return
	
	# Подключаем сигналы
	yandex_sdk.leaderboard_loaded.connect(_on_leaderboard_loaded)
	yandex_sdk.leaderboard_error.connect(_on_leaderboard_error)
	
	# Настраиваем начальное состояние
	_show_loading()

func load_leaderboard() -> void:
	"""Загружает данные лидерборда"""
	if yandex_sdk != null:
		yandex_sdk.load_leaderboard()
	else:
		_show_error(tr("ui.leaderboard.sdk_unavailable"))

func _on_leaderboard_loaded(entries: Array) -> void:
	"""Обработчик успешной загрузки лидерборда"""
	leaderboard_entries = entries
	_display_leaderboard()

func _on_leaderboard_error(error_message: String) -> void:
	"""Обработчик ошибки загрузки лидерборда"""
	_show_error(tr("ui.leaderboard.load_error"))

func _display_leaderboard() -> void:
	"""Отображает загруженные данные лидерборда"""
	_hide_all_states()
	
	if leaderboard_entries.is_empty():
		_show_empty_leaderboard()
		return
	
	# Создаем элементы таблицы
	for i in range(leaderboard_entries.size()):
		var entry = leaderboard_entries[i]
		var rank = i + 1
		var player_name = _get_player_name(entry)
		var score = _get_player_score(entry)
		
		var row = _create_leaderboard_row(rank, player_name, score)
		leaderboard_container.add_child(row)
	
	# Показываем контейнер с результатами
	_show_leaderboard()

func _create_leaderboard_row(rank: int, player_name: String, score: int) -> Control:
	"""Создает строку таблицы результатов"""
	var row = HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 35)
	
	# Добавляем отступы
	row.add_theme_constant_override("separation", 10)
	
	# Ранг
	var rank_label = Label.new()
	rank_label.custom_minimum_size = Vector2(50, 0)
	rank_label.text = str(rank) + "."
	rank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rank_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rank_label.theme_override_font_sizes.font_size = 18
	
	# Специальные цвета для топ-3
	if rank == 1:
		rank_label.theme_override_colors.font_color = Color(1, 0.9, 0.2, 1)  # Золото
	elif rank == 2:
		rank_label.theme_override_colors.font_color = Color(0.8, 0.8, 0.9, 1)  # Серебро
	elif rank == 3:
		rank_label.theme_override_colors.font_color = Color(1, 0.6, 0.3, 1)  # Бронза
	else:
		rank_label.theme_override_colors.font_color = Color(1, 0.8, 0.2, 1)
	
	rank_label.theme_override_colors.font_shadow_color = Color(0, 0, 0, 0.8)
	row.add_child(rank_label)
	
	# Имя игрока
	var name_label = Label.new()
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.text = player_name
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.theme_override_font_sizes.font_size = 16
	name_label.theme_override_colors.font_color = Color(1, 1, 1, 1)
	name_label.theme_override_colors.font_shadow_color = Color(0, 0, 0, 0.8)
	row.add_child(name_label)
	
	# Очки
	var score_label = Label.new()
	score_label.custom_minimum_size = Vector2(70, 0)
	score_label.text = str(score)
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	score_label.theme_override_font_sizes.font_size = 18
	score_label.theme_override_colors.font_color = Color(1, 0.6, 0.2, 1)
	score_label.theme_override_colors.font_shadow_color = Color(0, 0, 0, 0.8)
	row.add_child(score_label)
	
	return row

func _get_player_name(entry: Dictionary) -> String:
	"""Извлекает имя игрока из записи лидерборда"""
	if entry.has("player") and entry.player.has("publicName"):
		return entry.player.publicName
	elif entry.has("player") and entry.player.has("name"):
		return entry.player.name
	else:
		return tr("ui.leaderboard.default_player")

func _get_player_score(entry: Dictionary) -> int:
	"""Извлекает очки игрока из записи лидерборда"""
	if entry.has("score"):
		return int(entry.score)
	else:
		return 0

func _show_loading() -> void:
	"""Показывает состояние загрузки"""
	_hide_all_states()
	loading_label.visible = true

func _show_error(message: String) -> void:
	"""Показывает сообщение об ошибке"""
	_hide_all_states()
	error_label.text = message
	error_label.visible = true

func _show_empty_leaderboard() -> void:
	"""Показывает сообщение о пустом лидерборде"""
	_hide_all_states()
	error_label.text = tr("ui.leaderboard.empty")
	error_label.visible = true

func _hide_all_states() -> void:
	"""Скрывает все состояния панели"""
	loading_label.visible = false
	error_label.visible = false
	leaderboard_container.visible = false
	
	# Очищаем контейнер от старых элементов
	for child in leaderboard_container.get_children():
		child.queue_free()

func _show_leaderboard() -> void:
	"""Показывает таблицу результатов"""
	leaderboard_container.visible = true
