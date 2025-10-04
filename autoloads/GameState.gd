extends Node
signal level_unlocked(level: int)

var highest_unlocked_level: int = 1
var current_level: int = 1
var score: int = 0

# Новые переменные для сохранения состояния игры
var game_in_progress: bool = false
var current_level_in_game: int = 1
var current_score_in_game: int = 0
var game_state: String = "ready"  # "ready", "playing", "gameover"

const SAVE_PATH := "user://save.json"

func _ready() -> void:
	_load()

func reset_for_level(level: int) -> void:
	current_level = level
	score = 0

func add_score(delta: int) -> void:
	score += delta

func unlock_level(level: int) -> void:
	if level > highest_unlocked_level:
		highest_unlocked_level = level
		_save()
		emit_signal("level_unlocked", level)

func is_unlocked(level: int) -> bool:
	return level <= highest_unlocked_level

# Новые функции для управления состоянием игры
func start_game(level: int) -> void:
	"""Начинает новую игру на указанном уровне"""
	print("GameStateManager: начинаем новую игру на уровне ", level)
	game_in_progress = true
	current_level_in_game = level
	current_score_in_game = 0
	game_state = "ready"
	_save()
	print("GameStateManager: новая игра сохранена")

func update_game_state(level: int, score: int, state: String) -> void:
	"""Обновляет состояние текущей игры"""
	print("GameStateManager: обновляем состояние - уровень: ", level, ", счет: ", score, ", состояние: ", state)
	current_level_in_game = level
	current_score_in_game = score
	game_state = state
	_save()
	print("GameStateManager: состояние обновлено и сохранено")

func end_game() -> void:
	"""Завершает текущую игру"""
	game_in_progress = false
	game_state = "ready"
	_save()

func has_game_in_progress() -> bool:
	"""Проверяет, есть ли незавершенная игра"""
	print("GameStateManager: проверяем наличие игры в процессе - ", game_in_progress)
	return game_in_progress

func get_game_level() -> int:
	"""Получает номер уровня текущей игры"""
	return current_level_in_game

func get_game_score() -> int:
	"""Получает счет текущей игры"""
	return current_score_in_game

func get_game_state() -> String:
	"""Получает состояние текущей игры"""
	return game_state

func _save() -> void:
	var data := {
		"highest_unlocked_level": highest_unlocked_level,
		"game_in_progress": game_in_progress,
		"current_level_in_game": current_level_in_game,
		"current_score_in_game": current_score_in_game,
		"game_state": game_state
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))

func _load() -> void:
	print("GameStateManager: загружаем сохраненные данные...")
	if not FileAccess.file_exists(SAVE_PATH):
		print("GameStateManager: файл сохранения не найден")
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f:
		var txt := f.get_as_text()
		print("GameStateManager: содержимое файла сохранения: ", txt)
		var res: Variant = JSON.parse_string(txt)
		if typeof(res) == TYPE_DICTIONARY:
			if res.has("highest_unlocked_level"):
				highest_unlocked_level = int(res["highest_unlocked_level"])
			if res.has("game_in_progress"):
				game_in_progress = bool(res["game_in_progress"])
			if res.has("current_level_in_game"):
				current_level_in_game = int(res["current_level_in_game"])
			if res.has("current_score_in_game"):
				current_score_in_game = int(res["current_score_in_game"])
			if res.has("game_state"):
				game_state = str(res["game_state"])
			print("GameStateManager: данные загружены - игра в процессе: ", game_in_progress, ", уровень: ", current_level_in_game, ", счет: ", current_score_in_game, ", состояние: ", game_state)
		else:
			print("GameStateManager: ошибка парсинга JSON")
	else:
		print("GameStateManager: не удалось открыть файл сохранения")
