extends Node

## Система динамической подкрутки спавна пончиков
## Реализует "липкую" Марковскую модель с ограничителем серий
## для создания более предсказуемых паттернов на ранних уровнях

var DONUT_TYPES := ["blue", "chocolate", "pink", "rainbow"]

var LEVEL_CONFIG := {
	1: { "stickiness": 0.85, "streak_cap": 5, "cooldown_factor": 0.4, "cooldown_spawns": 2, "group_size": 3, "double_chance": 0.8 },
	2: { "stickiness": 0.80, "streak_cap": 4, "cooldown_factor": 0.45, "cooldown_spawns": 2, "group_size": 3, "double_chance": 0.7 },
	3: { "stickiness": 0.75, "streak_cap": 4, "cooldown_factor": 0.5,  "cooldown_spawns": 2, "group_size": 2, "double_chance": 0.6 },
	4: { "stickiness": 0.70, "streak_cap": 3, "cooldown_factor": 0.55, "cooldown_spawns": 2, "group_size": 2, "double_chance": 0.5 },
	5: { "stickiness": 0.65, "streak_cap": 3, "cooldown_factor": 0.6,  "cooldown_spawns": 2, "group_size": 2, "double_chance": 0.4 },
	6: { "stickiness": 0.60, "streak_cap": 3, "cooldown_factor": 0.65, "cooldown_spawns": 2, "group_size": 2, "double_chance": 0.3 }
}

var _rng := RandomNumberGenerator.new()
var _last_type := ""
var _streak_len := 0
var _cooldown_left := 0
var _group_size := 0  # размер текущей группы одинаковых пончиков
var _target_group_size := 0  # целевой размер группы

var _telemetry := [] # массив словарей для телеметрии

func _ready() -> void:
	_rng.randomize()

## Инициализация seed для детерминированного поведения
func init_seed(seed_value: int = 0) -> void:
	if seed_value == 0:
		_rng.randomize()
	else:
		_rng.seed = seed_value

## Сброс состояния на старте уровня
func reset(level: int) -> void:
	_last_type = ""
	_streak_len = 0
	_cooldown_left = 0
	_group_size = 0
	_target_group_size = 0
	_telemetry.clear()
	_log("reset", level, "", 0.0, false)

## Установка кастомной конфигурации для уровня (для A/B тестирования)
func set_custom_config(level: int, cfg: Dictionary) -> void:
	LEVEL_CONFIG[level] = cfg

## Получение следующего типа пончика с учетом подкрутки
func get_next_donut_type(level: int) -> String:
	var cfg := _get_cfg(level)
	var s: float = cfg["stickiness"]
	var cap: int = cfg["streak_cap"]
	var cool_factor: float = cfg["cooldown_factor"]
	var cool_spawns: int = cfg["cooldown_spawns"]
	var group_size: int = cfg["group_size"]

	var s_eff: float = s
	var cooldown_active: bool = false
	if _cooldown_left > 0:
		s_eff = s * cool_factor
		cooldown_active = true

	var chosen := ""
	
	# Первый пончик - случайный выбор и инициализация группы
	if _last_type == "":
		chosen = _choose_any()
		_last_type = chosen
		_streak_len = 1
		_group_size = 1
		# Определяем размер группы с учетом вероятности двойных пончиков
		var double_chance: float = cfg.get("double_chance", 0.5)
		if _rng.randf() < double_chance:
			_target_group_size = 2  # Двойной пончик
		else:
			_target_group_size = 1  # Одиночный пончик
		_step_cooldown()
		_log("first", level, chosen, s_eff, cooldown_active)
		return chosen

	# Если группа не завершена - продолжаем тот же тип
	if _group_size < _target_group_size:
		chosen = _last_type
		_streak_len += 1
		_group_size += 1
		_step_cooldown()
		_log("group_continue", level, chosen, s_eff, cooldown_active)
		return chosen

	# Группа завершена - выбираем новый тип и новую группу
	chosen = _choose_other(_last_type)
	_last_type = chosen
	_streak_len = 1
	_group_size = 1
	# Определяем размер новой группы с учетом вероятности двойных пончиков
	var double_chance: float = cfg.get("double_chance", 0.5)
	if _rng.randf() < double_chance:
		_target_group_size = 2  # Двойной пончик
	else:
		_target_group_size = 1  # Одиночный пончик
	_cooldown_left = cool_spawns
	_log("group_switch", level, chosen, s_eff, true)
	return chosen

## Просмотр следующего типа без влияния на состояние (для превью)
func peek_next(level: int) -> String:
	# Снятие снепшота RNG, чтобы просмотр не влиял на реальный спавн
	var backup_state := _rng.state
	var backup_last := _last_type
	var backup_streak := _streak_len
	var backup_cd := _cooldown_left
	var backup_group_size := _group_size
	var backup_target_group_size := _target_group_size

	var t := get_next_donut_type(level)

	# Восстановление состояния
	_rng.state = backup_state
	_last_type = backup_last
	_streak_len = backup_streak
	_cooldown_left = backup_cd
	_group_size = backup_group_size
	_target_group_size = backup_target_group_size
	return t

## Получение текстуры пончика по типу
func get_next_donut_texture(t: String) -> Texture2D:
	match t:
		"blue":
			return load("res://assets/donuts/donut_blue.png")
		"chocolate":
			return load("res://assets/donuts/donut_chocolate.png")
		"pink":
			return load("res://assets/donuts/donut_pink.png")
		"rainbow":
			return load("res://assets/donuts/donut_rainbow.png")
		_:
			return load("res://assets/donuts/donut_blue.png")

## Экспорт телеметрии в CSV файл
func export_csv(path: String) -> void:
	var text := "idx,event,level,type,s_eff,cooldown,streak\n"
	for i in _telemetry.size():
		var r: Dictionary = _telemetry[i]
		text += str(i) + "," + str(r.event) + "," + str(r.level) + "," + str(r.type) + "," + str(r.s_eff) + "," + str(r.cooldown) + "," + str(r.streak) + "\n"
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(text)
		f.flush()
		f.close()

## Получение конфигурации уровня (с fallback для неизвестных уровней)
func _get_cfg(level: int) -> Dictionary:
	if LEVEL_CONFIG.has(level):
		return LEVEL_CONFIG[level]
	
	# Динамическое вычисление для уровней выше 6
	var dynamic_stickiness: float = clamp(0.60 - 0.05 * (level - 6), 0.25, 0.60)
	var dynamic_streak_cap: int = 3  # Всегда максимум 3 пончика подряд
	var dynamic_cooldown_factor: float = clamp(0.65 + (level - 6) * 0.02, 0.65, 0.8)
	var dynamic_cooldown_spawns: int = 2
	var dynamic_group_size: int = 2
	var dynamic_double_chance: float = clamp(0.3 - 0.05 * (level - 6), 0.1, 0.3)
	
	return {
		"stickiness": dynamic_stickiness,
		"streak_cap": dynamic_streak_cap,
		"cooldown_factor": dynamic_cooldown_factor,
		"cooldown_spawns": dynamic_cooldown_spawns,
		"group_size": dynamic_group_size,
		"double_chance": dynamic_double_chance
	}

## Случайный выбор любого типа пончика
func _choose_any() -> String:
	var i := _rng.randi_range(0, DONUT_TYPES.size() - 1)
	return DONUT_TYPES[i]

## Выбор любого типа кроме указанного
func _choose_other(except_type: String) -> String:
	var candidates := []
	for t in DONUT_TYPES:
		if t != except_type:
			candidates.append(t)
	var i := _rng.randi_range(0, candidates.size() - 1)
	return candidates[i]

## Уменьшение счетчика кулдауна
func _step_cooldown() -> void:
	if _cooldown_left > 0:
		_cooldown_left -= 1

## Логирование события в телеметрию
func _log(event: String, level: int, t: String, s_eff: float, cooldown_active: bool) -> void:
	var row := {
		"event": event,
		"level": level,
		"type": t,
		"s_eff": s_eff,
		"cooldown": cooldown_active,
		"streak": _streak_len
	}
	_telemetry.append(row)
