extends "res://scripts/Game.gd"

# Специальный скрипт для третьего уровня с системой ветра
@onready var wind_manager: Node
@onready var wind_particles: Node2D

# Переменная для отслеживания активных пончиков
var falling_donuts: Array[RigidBody2D] = []

func _ready() -> void:
	# Вызываем родительский _ready()
	super._ready()
	
	# Инициализируем систему ветра
	_setup_wind_system()

func _setup_wind_system() -> void:
	"""Настраивает систему ветра для третьего уровня"""
	
	# Создаем менеджер ветра
	var wind_manager_script = preload("res://scripts/WindManager.gd")
	wind_manager = Node.new()
	wind_manager.set_script(wind_manager_script)
	wind_manager.name = "WindManager"
	add_child(wind_manager)
	
	# Создаем систему частиц
	var wind_particles_script = preload("res://scripts/WindParticles.gd")
	wind_particles = Node2D.new()
	wind_particles.set_script(wind_particles_script)
	wind_particles.name = "WindParticles"
	add_child(wind_particles)
	
	# Подключаем сигналы
	wind_manager.wind_changed.connect(_on_wind_changed)
	

func _on_wind_changed(new_force: float) -> void:
	"""Обработчик изменения ветра"""
	
	# Обновляем визуализацию
	if wind_particles:
		wind_particles.update_wind(new_force)

func _spawn_donut(world_pos: Vector2) -> void:
	"""Переопределяем спавн пончика для добавления в список падающих"""
	# Вызываем родительский метод
	super._spawn_donut(world_pos)
	
	# Добавляем пончик в список падающих
	var last_donut = active_donuts[-1] if not active_donuts.is_empty() else null
	if last_donut and not falling_donuts.has(last_donut):
		falling_donuts.append(last_donut)

func _process(_delta: float) -> void:
	"""Обновляем физику ветра для падающих пончиков"""
	# Вызываем родительский метод
	super._process(_delta)
	
	# Применяем силу ветра к падающим пончикам
	_apply_wind_to_falling_donuts()

func _apply_wind_to_falling_donuts() -> void:
	"""Применяет силу ветра к падающим пончикам"""
	if not wind_manager:
		return
	
	var wind_force = wind_manager.get_wind_force()
	
	# Применяем ветер ко всем активным пончикам
	for donut in active_donuts:
		if not is_instance_valid(donut):
			continue
		
		# Проверяем, что пончик падает (имеет положительную скорость по Y или не спит)
		if donut.linear_velocity.y > 0 or not donut.sleeping:
			# Применяем силу ветра (умеренная сила)
			var wind_vector = Vector2(wind_force * 0.3, 0)  # Уменьшаем силу до 30%
			donut.apply_central_force(wind_vector)

func _recycle_donut(d: RigidBody2D) -> void:
	"""Переопределяем переработку пончика для удаления из списка падающих"""
	# Удаляем из списка падающих пончиков
	if falling_donuts.has(d):
		falling_donuts.erase(d)
	
	# Вызываем родительский метод
	super._recycle_donut(d)

func _cleanup_fallen() -> void:
	"""Переопределяем очистку упавших пончиков"""
	# Очищаем список падающих пончиков от недействительных
	falling_donuts = falling_donuts.filter(func(donut): return is_instance_valid(donut))
	
	# Вызываем родительский метод
	super._cleanup_fallen()

func get_wind_info() -> Dictionary:
	"""Возвращает информацию о текущем ветре"""
	if not wind_manager:
		return {"force": 0, "direction": "штиль", "strength": "отсутствует"}
	
	return {
		"force": wind_manager.get_wind_force(),
		"direction": wind_manager.get_wind_direction(),
		"strength": wind_manager.get_wind_strength()
	}
