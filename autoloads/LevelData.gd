extends Node

# Структура данных для уровня
class LevelInfo:
	var level_number: int
	var level_name: String
	var description: String
	var cart_speed: String
	var objective: String
	var target_score: int
	var hint: String
	var color_scheme: LevelColorScheme
	
	func _init(num: int, name: String, desc: String, speed: String, obj: String, target: int, hint_text: String, colors: LevelColorScheme):
		level_number = num
		level_name = name
		description = desc
		cart_speed = speed
		objective = obj
		target_score = target
		hint = hint_text
		color_scheme = colors

# Цветовая схема уровня
class LevelColorScheme:
	var primary_color: Color      # Основной цвет (для заголовка и заполнителя прогресса)
	var secondary_color: Color    # Вторичный цвет (для рамки прогресса)
	var background_color: Color   # Цвет фона (для фона прогресса)
	var text_color: Color         # Цвет текста
	
	func _init(primary: Color, secondary: Color, background: Color, text: Color):
		primary_color = primary
		secondary_color = secondary
		background_color = background
		text_color = text

# Данные об уровнях
var levels_data: Array[LevelInfo] = []

# Текущий выбранный уровень
var current_level_info: LevelInfo

func _ready() -> void:
	_initialize_levels_data()

func _initialize_levels_data() -> void:
	"""Инициализация данных об уровнях"""
	levels_data.clear()
	
	# Цветовые схемы для уровней
	var level1_colors = LevelColorScheme.new(
		Color(0.4, 0.7, 0.9, 1.0),    # Голубой (как море в гавани)
		Color(0.2, 0.5, 0.8, 1.0),    # Темно-голубой
		Color(0.1, 0.2, 0.3, 0.8),    # Темно-синий фон
		Color(1.0, 1.0, 1.0, 1.0)     # Белый текст
	)
	
	var level2_colors = LevelColorScheme.new(
		Color(0.8, 0.4, 0.2, 1.0),    # Коричневый (шоколад)
		Color(0.6, 0.3, 0.1, 1.0),    # Темно-коричневый
		Color(0.2, 0.1, 0.05, 0.8),   # Очень темно-коричневый фон
		Color(1.0, 0.9, 0.7, 1.0)     # Кремовый текст
	)
	
	var level3_colors = LevelColorScheme.new(
		Color(0.2, 0.4, 0.8, 1.0),    # Темно-синий
		Color(0.1, 0.2, 0.6, 1.0),    # Очень темно-синий
		Color(0.05, 0.1, 0.3, 0.8),   # Темно-синий фон
		Color(1.0, 1.0, 1.0, 1.0)     # Белый текст
	)
	
	var level4_colors = LevelColorScheme.new(
		Color(0.6, 0.3, 0.8, 1.0),    # Фиолетовый (как небо на высоте)
		Color(0.4, 0.2, 0.6, 1.0),    # Темно-фиолетовый
		Color(0.2, 0.1, 0.3, 0.8),    # Очень темно-фиолетовый фон
		Color(1.0, 1.0, 1.0, 1.0)     # Белый текст
	)
	
	var level5_colors = LevelColorScheme.new(
		Color(0.9, 0.7, 0.3, 1.0),    # Золотисто-песочный (как песок пустыни)
		Color(0.7, 0.5, 0.2, 1.0),    # Темно-песочный
		Color(0.3, 0.2, 0.1, 0.8),    # Темно-коричневый фон (как тени пирамид)
		Color(1.0, 0.9, 0.7, 1.0)     # Кремовый текст
	)
	
	var level6_colors = LevelColorScheme.new(
		Color(0.8, 0.2, 0.2, 1.0),    # Красный (как закат в пустыне)
		Color(0.6, 0.1, 0.1, 1.0),    # Темно-красный
		Color(0.2, 0.05, 0.05, 0.9),  # Очень темно-красный фон (как тени заката)
		Color(1.0, 0.9, 0.8, 1.0)     # Светло-кремовый текст
	)
	
	
	# Уровень 1 - Гавань пончиков
	levels_data.append(LevelInfo.new(
		1,
		"Гавань пончиков",
		"Добро пожаловать в мир пончиков! 🌊\nСегодня ты на старте — мягкие пончики падают медленно.\nБашня ждёт твоих первых рекордов!\nПопробуй дотянуться до неба!",
		"🏃 Пончики летят медленно — успевай строить!",
		"🎯 Задача: набери 50 очков и построить башню из пончиков",
		50,
		"👆 Нажимай вовремя — и пусть башня растёт!",
		level1_colors
	))
	
	# Уровень 2 - Кафе "У Яниса"
	levels_data.append(LevelInfo.new(
		2,
		"Кафе \"У Яниса\"",
		"🏝️ Ветер с моря крепчает, а пончики катятся быстрее!\nТы в уютном греческом кафе на берегу, где башни из сладостей строят прямо под шум прибоя.",
		"🧱 Стенки стали ниже — теперь промахнуться проще.",
		"🎯 Задача: набери 55 очков и докажи, что ты мастер балансировки!",
		55,
		"👆 Жми вовремя и не дай пончику укатиться за горизонт!",
		level2_colors
	))
	
	# Уровень 3 - Штормовое утро
	levels_data.append(LevelInfo.new(
		3,
		"Штормовое утро",
		"🌬️ Добро пожаловать в шторм! Сегодня ветер не просто мешает —\nон играет против тебя. Направление меняется внезапно,\nи только мастер чувствует момент броска.",
		"🏃 Пончики летят с той же скоростью, что и во втором уровне!",
		"🎯 Задача: набери 60 очков, несмотря на ветер и спешку.",
		60,
		"👆 Планируй каждый тап! Один промах — и всё рухнет.",
		level3_colors
	))
	
	# Уровень 4 - Кафе на крыше
	levels_data.append(LevelInfo.new(
		4,
		"Кафе на крыше",
		"🏙️ Добро пожаловать на высоту!\nБашня растёт, а вместе с ней — и твои амбиции.\nТеперь пончики летят дальше, дольше… и опаснее!\n\n🌬️ Ветер стал капризным — может ударить прямо во время броска.\n🎯 Задача: всё та же — набери 65 очков и держи равновесие!\n\n👁 Следи за движением — башня слегка шатается,\n🌪️ а порывы ветра могут сбить с толку даже мастера!",
		"🌪️ Порывистый ветер и шатающаяся башня — настоящий вызов!",
		"🎯 Задача: набери 65 очков, несмотря на порывы ветра и шатание башни.",
		65,
		"👆 Чувствуй ритм порывов и не дай башне упасть!",
		level4_colors
	))
	
	# Уровень 5 - Тени пирамид
	levels_data.append(LevelInfo.new(
		5,
		"Тени пирамид",
		"🏜️ Финальный вызов первой главы!\nТы в Египте — пекло, песок и башня пончиков прямо у подножия пирамид.\n⚠️ Песок скапливается, и твои пончики могут осесть в нём,\nне соединяясь с башней!\n\n🌬 Ветер остаётся, но слабее, почти не влияет — чтобы игрок сконцентрировался на «поле»\n🎯 Задача: набери 70 очков и докажи, что ты достоин вершины!\n\n👁 Следи за каждым броском — теперь всё решает точность.",
		"🏜 Песок сверху падает песок который копится снизу экрана на ground",
		"🎯 Задача: набери 70 очков и докажи, что ты достоин вершины!",
		70,
		"👁 Следи за каждым броском — теперь всё решает точность.",
		level5_colors
	))
	
	# Уровень 6 - Закат в пустыне (ФИНАЛЬНЫЙ)
	levels_data.append(LevelInfo.new(
		6,
		"Закат в пустыне",
		"🌅 ФИНАЛЬНЫЙ ВЫЗОВ!\nТы достиг вершины мастерства — закат в пустыне освещает твой последний путь.\n🏜️ Песок падает ещё быстрее, башня шатается сильнее,\nа каждый промах может стать роковым!\n\n⚡ Ускоренная песчаная буря и более агрессивный песок —\nэто испытание для настоящих мастеров!\n🎯 Задача: набери 75 очков и стань легендой!\n\n👑 Это твой момент славы — покажи, на что ты способен!",
		"🌅 Ускоренная песчаная буря и более агрессивный песок",
		"🎯 Задача: набери 75 очков и стань легендой!",
		75,
		"👑 Это твой момент славы — покажи, на что ты способен!",
		level6_colors
	))

func get_level_info(level_number: int) -> LevelInfo:
	"""Получить информацию об уровне по номеру"""
	if level_number > 0 and level_number <= levels_data.size():
		return levels_data[level_number - 1]
	return levels_data[0]  # Возвращаем первый уровень по умолчанию

func set_current_level(level_number: int) -> void:
	"""Установить текущий уровень"""
	current_level_info = get_level_info(level_number)

func get_current_level_info() -> LevelInfo:
	"""Получить информацию о текущем уровне"""
	if current_level_info == null:
		current_level_info = get_level_info(1)
	return current_level_info

func get_total_levels() -> int:
	"""Получить общее количество уровней"""
	return levels_data.size()

func start_level(level_number: int) -> void:
	"""Запустить уровень с превью"""
	set_current_level(level_number)
	get_tree().change_scene_to_file("res://scenes/LevelIntro.tscn")
