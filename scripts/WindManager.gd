extends Node

# Менеджер ветра для третьего уровня
signal wind_changed(new_force: float)

# Сила ветра (от -100 до +100)
var wind_force: float = 0.0

# Таймер для изменения ветра
var wind_timer: Timer

# Минимальная и максимальная сила ветра
const MIN_WIND_FORCE := -200.0
const MAX_WIND_FORCE := 200.0

# Интервал изменения ветра (3-5 секунд)
const MIN_WIND_INTERVAL := 3.0
const MAX_WIND_INTERVAL := 5.0

func _ready() -> void:
	_setup_wind_timer()
	_start_wind_cycle()

func _setup_wind_timer() -> void:
	"""Настраивает таймер для изменения ветра"""
	wind_timer = Timer.new()
	wind_timer.one_shot = true
	wind_timer.timeout.connect(_change_wind)
	add_child(wind_timer)

func _start_wind_cycle() -> void:
	"""Запускает цикл изменения ветра"""
	_change_wind()

func _change_wind() -> void:
	"""Изменяет силу ветра"""
	# Генерируем случайную силу ветра
	wind_force = randf_range(MIN_WIND_FORCE, MAX_WIND_FORCE)
	
	# Округляем до целого числа для более четких значений
	wind_force = round(wind_force)
	
	# Отправляем сигнал об изменении ветра
	emit_signal("wind_changed", wind_force)
	
	
	# Устанавливаем следующий таймер
	var next_interval = randf_range(MIN_WIND_INTERVAL, MAX_WIND_INTERVAL)
	wind_timer.wait_time = next_interval
	wind_timer.start()

func get_wind_force() -> float:
	"""Получить текущую силу ветра"""
	return wind_force

func get_wind_direction() -> String:
	"""Получить направление ветра в виде строки"""
	if wind_force > 0:
		return "вправо"
	elif wind_force < 0:
		return "влево"
	else:
		return "штиль"

func get_wind_strength() -> String:
	"""Получить силу ветра в виде строки"""
	var abs_force = abs(wind_force)
	if abs_force < 40:
		return "слабый"
	elif abs_force < 100:
		return "умеренный"
	elif abs_force < 160:
		return "сильный"
	else:
		return "штормовой"
