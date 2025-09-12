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
	
	# Заголовок уровня - используем только номер уровня, название берем из level_intro
	if level_title_label:
		var level_name = _get_level_name_from_intro(level_info.level_number)
		level_title_label.text = "✅ Уровень %d — «%s»" % [level_info.level_number, level_name]
		# Применяем цветовую схему к заголовку
		if level_info.color_scheme:
			level_title_label.add_theme_color_override("font_color", level_info.color_scheme.primary_color)
	
	# Описание уровня - используем только текст из level_intro
	if level_description_label:
		_display_gameplay_description(level_info)
	
	# Детальная информация об уровне (только для уровней 3+)
	if level_info_container and level_info.level_number > 2:
		_clear_level_info_container()
		# Добавляем атмосферное описание
		_add_info_item("", _get_atmosphere_from_intro(level_info.level_number))
		_add_info_item("", _get_cart_speed_from_intro(level_info.level_number))
		_add_info_item("", _get_objective_from_intro(level_info.level_number))
		_add_info_item("", "🎯 Цель: 50 очков")
		_add_info_item("", _get_hint_from_intro(level_info.level_number))
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
			lines.append("[center]Скидывай пончики один за другим — строй башню и лови ритм![/center]")
			lines.append("[center]4 одинаковых подряд? Лови сладкий бонус и взлетай в счёте![/center]")
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
		3:
			# Жёстко задаём уникальное описание для третьего уровня, как в инструкции
			lines.append("[center]🌬️ Добро пожаловать в шторм! Сегодня ветер не просто мешает —[/center]")
			lines.append("[center]он играет против тебя. Направление меняется внезапно,[/center]")
			lines.append("[center]и только мастер чувствует момент броска.[/center]")
			lines.append("")
			lines.append("[center]🎯 Задача: набери 50 очков, несмотря на ветер и спешку.[/center]")
			lines.append("[center]👆 Следи за стрелками — ветер может дуть в любую сторону![/center]")
			return  # Выходим, чтобы не выполнять код для остальных уровней
		4:
			# Специальное описание для четвертого уровня
			lines.append("[center]🏙️ Добро пожаловать на высоту![/center]")
			lines.append("[center]Башня растёт, а вместе с ней — и твои амбиции.[/center]")
			lines.append("[center]Теперь пончики летят дальше, дольше… и опаснее![/center]")
			lines.append("")
			lines.append("[center]🌬️ Ветер стал капризным — может ударить прямо во время броска.[/center]")
			lines.append("[center]🎯 Задача: всё та же — набери 50 очков и держи равновесие![/center]")
			lines.append("")
			lines.append("[center]👁 Следи за движением — башня слегка шатается,[/center]")
			lines.append("[center]🌪️ а порывы ветра могут сбить с толку даже мастера![/center]")
			return  # Выходим, чтобы не выполнять код для остальных уровней
		5:
			# Специальное описание для пятого уровня
			lines.append("[center]🏜️ Финальный вызов первой главы![/center]")
			lines.append("[center]Ты в Египте — пекло, песок и башня пончиков прямо у подножия пирамид.[/center]")
			lines.append("")
			lines.append("[center]⚠️ Песок скапливается, и твои пончики могут осесть в нём,[/center]")
			lines.append("[center]не соединяясь с башней![/center]")
			lines.append("")
			lines.append("[center]🌬 Ветер остаётся, но слабее, почти не влияет — чтобы игрок сконцентрировался на «поле»[/center]")
			lines.append("[center]🎯 Задача: набери 50 очков и докажи, что ты достоин вершины![/center]")
			lines.append("")
			lines.append("[center]👁 Следи за каждым броском — теперь всё решает точность.[/center]")
			return  # Выходим, чтобы не выполнять код для остальных уровней
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
	# Убираем фиксированную ширину, чтобы контейнер занимал всю доступную ширину
	info_item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
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
	# Убираем фиксированную ширину и позволяем лейблу расширяться
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
	
	# Устанавливаем уровень в GameState для использования в игре
	GameStateManager.reset_for_level(level_info.level_number)
	
	# Переходим к соответствующей сцене игры
	if level_info.level_number == 1:
		get_tree().change_scene_to_file("res://scenes/Game.tscn")
	elif level_info.level_number == 2:
		get_tree().change_scene_to_file("res://scenes/Game_level_2.tscn")
	elif level_info.level_number == 3:
		get_tree().change_scene_to_file("res://scenes/Game_level_3.tscn")
	elif level_info.level_number == 4:
		get_tree().change_scene_to_file("res://scenes/Game_level_4.tscn")
	elif level_info.level_number == 5:
		get_tree().change_scene_to_file("res://scenes/Game_level_5.tscn")
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

# ===== Функции для получения данных из level_intro =====

func _get_atmosphere_from_intro(level_number: int) -> String:
	"""Получить атмосферное описание из level_intro"""
	match level_number:
		1:
			return "Добро пожаловать! Сегодня ты в порту, где пахнет морем и свежей выпечкой."
		2:
			return "🏝️ Ветер с моря крепчает, а пончики катятся быстрее!\nТы в уютном греческом кафе на берегу, где башни из сладостей строят прямо под шум прибоя."
		3:
			return "🌬️ Добро пожаловать в шторм! Сегодня ветер не просто мешает —\nон играет против тебя. Направление меняется внезапно,\nи только мастер чувствует момент броска."
		4:
			return "🏙️ Добро пожаловать на высоту! Башня растёт, а вместе с ней — и твои амбиции. Теперь пончики летят дальше, дольше… и опаснее!"
		5:
			return "🏜️ Финальный вызов первой главы!\nТы в Египте — пекло, песок и башня пончиков прямо у подножия пирамид."
		_:
			return "Добро пожаловать в новый уровень!"

func _get_level_name_from_intro(level_number: int) -> String:
	"""Получить название уровня из level_intro"""
	match level_number:
		1:
			return "Гавань пончиков"
		2:
			return "Кафе \"У Яниса\""
		3:
			return "Штормовое утро"
		4:
			return "Кафе на крыше"
		5:
			return "Тени пирамид"
		_:
			return "Неизвестный уровень"

func _get_cart_speed_from_intro(level_number: int) -> String:
	"""Получить описание скорости пончиков из level_intro"""
	match level_number:
		1:
			return "🏃 Пончики летят медленно — успевай строить!"
		2:
			return "🧱 Внимание: стенки ниже — промахнуться проще!"
		3:
			return "🏃 Пончики летят с той же скоростью, что и во втором уровне!"
		4:
			return "🌪️ Порывистый ветер и шатающаяся башня — настоящий вызов!"
		5:
			return "🏜 Песок сверху падает песок который копится снизу экрана на ground"
		_:
			return "🏃 Пончики летят с обычной скоростью"

func _get_objective_from_intro(level_number: int) -> String:
	"""Получить цель уровня из level_intro"""
	match level_number:
		1:
			return "🎯 Задача: построить башню из пончиков"
		2:
			return "🎯 Задача: набери 50 очков и докажи, что ты мастер балансировки!"
		3:
			return "🎯 Задача: набери 50 очков, несмотря на ветер и спешку."
		4:
			return "🎯 Задача: всё та же — набери 50 очков и держи равновесие!"
		5:
			return "🎯 Задача: набери 50 очков и докажи, что ты достоин вершины!"
		_:
			return "🎯 Задача: набери 50 очков"

func _get_hint_from_intro(level_number: int) -> String:
	"""Получить подсказку из level_intro"""
	match level_number:
		1:
			return "👆 Жми вовремя — пусть башня растёт!"
		2:
			return "👆 Жми вовремя и не дай пончику укатиться за горизонт!"
		3:
			return "👆 Следи за стрелками — ветер может дуть в любую сторону!"
		4:
			return "👁 Следи за движением — башня слегка шатается, а порывы ветра могут сбить с толку даже мастера!"
		5:
			return "👁 Следи за каждым броском — теперь всё решает точность."
		_:
			return "👆 Жми вовремя!"
