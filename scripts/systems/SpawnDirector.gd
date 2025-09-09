extends Node

## Система динамической подкрутки спавна пончиков
## Реализует "липкую" Марковскую модель с ограничителем серий
## для создания более предсказуемых паттернов на ранних уровнях

var DONUT_TYPES := ["blue", "chocolate", "pink", "rainbow"]

var LEVEL_CONFIG := {
	1: { "stickiness": 0.65, "streak_cap": 3, "cooldown_factor": 0.6, "cooldown_spawns": 3 },
	2: { "stickiness": 0.58, "streak_cap": 3, "cooldown_factor": 0.65, "cooldown_spawns": 3 },
	3: { "stickiness": 0.48, "streak_cap": 3, "cooldown_factor": 0.7,  "cooldown_spawns": 3 },
	4: { "stickiness": 0.35, "streak_cap": 3, "cooldown_factor": 0.75, "cooldown_spawns": 2 },
	5: { "stickiness": 0.25, "streak_cap": 3, "cooldown_factor": 0.8,  "cooldown_spawns": 2 }
}

var _rng := RandomNumberGenerator.new()
var _last_type := ""
var _streak_len := 0
var _cooldown_left := 0

var _telemetry := [] # массив словарей для телеметрии

func _ready() -> void:
	_rng.randomize()

## Инициализация seed для детерминированного поведения
func init_seed(seed: int = 0) -> void:
	if seed == 0:
		_rng.randomize()
	else:
		_rng.seed = seed

## Сброс состояния на старте уровня
func reset(level: int) -> void:
	_last_type = ""
	_streak_len = 0
	_cooldown_left = 0
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

	var s_eff: float = s
	var cooldown_active: bool = false
	if _cooldown_left > 0:
		s_eff = s * cool_factor
		cooldown_active = true

	var chosen := ""
	
	# Первый пончик - случайный выбор
	if _last_type == "":
		chosen = _choose_any()
		_last_type = chosen
		_streak_len = 1
		_step_cooldown()
		_log("first", level, chosen, s_eff, cooldown_active)
		return chosen

	# Принудительный сброс серии при достижении лимита
	if _streak_len >= cap:
		chosen = _choose_other(_last_type)
		_last_type = chosen
		_streak_len = 1
		_cooldown_left = cool_spawns
		_log("force_switch", level, chosen, s_eff, true)
		return chosen

	# Обычное решение: повторить или сменить тип
	var repeat: bool = _rng.randf() < s_eff
	if repeat:
		chosen = _last_type
		_streak_len += 1
	else:
		chosen = _choose_other(_last_type)
		_last_type = chosen
		_streak_len = 1

	_step_cooldown()
	_log("normal", level, chosen, s_eff, cooldown_active)
	return chosen

## Просмотр следующего типа без влияния на состояние (для превью)
func peek_next(level: int) -> String:
	# Снятие снепшота RNG, чтобы просмотр не влиял на реальный спавн
	var backup_state := _rng.state
	var backup_last := _last_type
	var backup_streak := _streak_len
	var backup_cd := _cooldown_left

	var t := get_next_donut_type(level)

	# Восстановление состояния
	_rng.state = backup_state
	_last_type = backup_last
	_streak_len = backup_streak
	_cooldown_left = backup_cd
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
	
	# Динамическое вычисление для уровней выше 5
	var dynamic_stickiness: float = clamp(0.65 - 0.10 * (level - 1), 0.25, 0.65)
	var dynamic_streak_cap: int = 3  # Всегда максимум 3 пончика подряд
	var dynamic_cooldown_factor: float = clamp(0.6 + (level - 1) * 0.05, 0.6, 0.8)
	var dynamic_cooldown_spawns: int = 2 if level > 3 else 3
	
	return {
		"stickiness": dynamic_stickiness,
		"streak_cap": dynamic_streak_cap,
		"cooldown_factor": dynamic_cooldown_factor,
		"cooldown_spawns": dynamic_cooldown_spawns
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
	print("SpawnDirector:", row)
