extends Control

@onready var level_title_label: Label = $MainContainer/LevelTitleLabel
@onready var level_description_label: RichTextLabel = $MainContainer/LevelDescriptionLabel
@onready var level_info_container: VBoxContainer = $MainContainer/LevelInfoContainer
@onready var skip_button: Button = $MainContainer/SkipButton
@onready var countdown_label: Label = $MainContainer/CountdownLabel

var countdown_timer: float = 10.0
var is_skipping: bool = false

func _ready() -> void:
	# Получаем информацию о текущем уровне
	var level_info = LevelData.get_current_level_info()
	
	# Заполняем интерфейс данными об уровне
	_display_level_info(level_info)
	
	# Запускаем таймер автоперехода
	_start_auto_transition()
	
	# Подключаем кнопку пропуска
	if skip_button:
		skip_button.pressed.connect(_on_skip_button_pressed)

func _display_level_info(level_info: LevelData.LevelInfo) -> void:
	"""Отображает информацию об уровне в интерфейсе"""
	
	# Заголовок уровня
	if level_title_label:
		level_title_label.text = "✅ Уровень %d — «%s»" % [level_info.level_number, level_info.level_name]
		# Применяем цветовую схему к заголовку
		if level_info.color_scheme:
			level_title_label.add_theme_color_override("font_color", level_info.color_scheme.primary_color)
	
	# Описание уровня - используем BBCode для более игрового стиля
	if level_description_label:
		_display_gameplay_description(level_info)
	
	# Детальная информация об уровне (только для уровней 3+)
	if level_info_container and level_info.level_number > 2:
		_clear_level_info_container()
		_add_info_item("", level_info.cart_speed)
		_add_info_item("", level_info.objective)
		_add_info_item("", tr("ui.level.info.target_score") % level_info.target_score)
		_add_info_item("", level_info.hint)
	elif level_info_container:
		# Для уровней 1 и 2 скрываем дополнительную информацию, так как она уже есть в описании
		_clear_level_info_container()

func _display_gameplay_description(level_info: LevelData.LevelInfo) -> void:
	"""Отображает игровое описание уровня с BBCode"""
	if not level_description_label:
		return
	
	# Включаем BBCode
	level_description_label.bbcode_enabled = true
	
	var lines: Array = []
	
	# Специальные описания для каждого уровня
	match level_info.level_number:
		1:
			lines.append("[center]Добро пожаловать! Сегодня ты в порту, где пахнет морем и свежей выпечкой.[/center]")
			lines.append("")
			lines.append("🎯 Задача: [b]построить башню из пончиков[/b]")
			lines.append("🏃 Пончики летят медленно — успевай строить!")
			lines.append("")
			lines.append("👆 Жми вовремя — пусть башня растёт!")
			lines.append("🧁 Если всё получится — заработаешь 50 очков!")
		2:
			lines.append("[center]🏝️ Ветер с моря крепчает, а пончики катятся быстрее![/center]")
			lines.append("[center]Ты в уютном греческом кафе на берегу, где башни из сладостей строят прямо под шум прибоя.[/center]")
			lines.append("")
			lines.append("🎯 Задача: [b]набери 50 очков и докажи, что ты мастер балансировки![/b]")
			lines.append("🧱 Внимание: [b]стенки ниже[/b] — промахнуться проще!")
			lines.append("")
			lines.append("👆 Жми вовремя и не дай пончику укатиться за горизонт!")
		_:
			# Для остальных уровней используем стандартное описание
			lines.append("[center]%s[/center]" % level_info.description)
			lines.append("")
			lines.append("🎯 Задача: [b]%s[/b]" % level_info.objective)
			lines.append("🏃 %s" % level_info.cart_speed)
			lines.append("")
			lines.append("👆 %s" % level_info.hint)
	
	level_description_label.text = "\n".join(lines)
	
	# Применяем цветовую схему к RichTextLabel
	if level_info.color_scheme:
		level_description_label.add_theme_color_override("default_color", level_info.color_scheme.text_color)

func _clear_level_info_container() -> void:
	"""Очищает контейнер с информацией об уровне"""
	if level_info_container:
		for child in level_info_container.get_children():
			child.queue_free()

func _add_info_item(label_key: String, value_text: String) -> void:
	"""Добавляет элемент информации об уровне"""
	if not level_info_container:
		return
	
	var info_item = HBoxContainer.new()
	info_item.add_theme_constant_override("separation", 10)
	info_item.custom_minimum_size = Vector2(700, 35)
	
	# Получаем цветовую схему текущего уровня
	var level_info = LevelData.get_current_level_info()
	var color_scheme = level_info.color_scheme if level_info else null
	
	# Если есть лейбл, создаем его
	if label_key != "":
		var label = Label.new()
		label.text = tr(label_key)
		# Используем цветовую схему или цвет по умолчанию
		var label_color = color_scheme.primary_color if color_scheme else Color(1.0, 0.8, 0.4, 1.0)
		label.add_theme_color_override("font_color", label_color)
		label.add_theme_font_size_override("font_size", 20)
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		label.custom_minimum_size = Vector2(200, 35)
		label.autowrap_mode = TextServer.AUTOWRAP_OFF
		info_item.add_child(label)
	
	# Лейбл со значением (всегда создаем)
	var value = Label.new()
	value.text = value_text
	# Используем цветовую схему или цвет по умолчанию
	var value_color = color_scheme.text_color if color_scheme else Color(1.0, 1.0, 1.0, 1.0)
	value.add_theme_color_override("font_color", value_color)
	value.add_theme_font_size_override("font_size", 20)
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	value.custom_minimum_size = Vector2(500, 35)
	value.autowrap_mode = TextServer.AUTOWRAP_WORD
	
	info_item.add_child(value)
	level_info_container.add_child(info_item)

func _start_auto_transition() -> void:
	"""Запускает автоматический переход через 10 секунд"""
	# Запускаем таймер обратного отсчета
	await get_tree().create_timer(10.0).timeout
	
	if not is_skipping:
		_transition_to_game()

func _on_skip_button_pressed() -> void:
	"""Обработчик нажатия кнопки пропуска"""
	is_skipping = true
	_transition_to_game()

func _transition_to_game() -> void:
	"""Переход к игровой сцене"""
	var level_info = LevelData.get_current_level_info()
	print("LevelIntro: Переход к игровой сцене - Уровень %d: %s" % [level_info.level_number, level_info.level_name])
	
	# Устанавливаем уровень в GameState для использования в игре
	GameStateManager.reset_for_level(level_info.level_number)
	
	# Переходим к соответствующей сцене игры
	if level_info.level_number == 1:
		get_tree().change_scene_to_file("res://scenes/Game.tscn")
	elif level_info.level_number == 2:
		get_tree().change_scene_to_file("res://scenes/Game_level_2.tscn")
	else:
		# Для остальных уровней используем основную сцену
		get_tree().change_scene_to_file("res://scenes/Game.tscn")

func _process(delta: float) -> void:
	"""Обновление обратного отсчета"""
	if is_skipping:
		return
	
	countdown_timer -= delta
	
	if countdown_label:
		var remaining_seconds = int(ceil(countdown_timer))
		if remaining_seconds > 0:
			countdown_label.text = "⌛ Автоматический переход через %d сек..." % remaining_seconds
		else:
			countdown_label.text = "🚀 Запускаем игру..."

func _input(event: InputEvent) -> void:
	"""Обработка ввода для быстрого пропуска"""
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER:
			_on_skip_button_pressed()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_on_skip_button_pressed()
