extends "res://scripts/Game.gd"

# Специальный скрипт для четвертого уровня с порывистым ветром и шатающейся башней
@onready var wind_manager: Node
@onready var wind_particles: Node2D
@onready var camera: Camera2D

# Переменная для отслеживания активных пончиков
var falling_donuts: Array[RigidBody2D] = []

# Система шатания башни
var tower_shake_timer: Timer
var is_tower_shaking: bool = false
var shake_intensity: float = 0.0
var shake_duration: float = 0.0
var original_camera_position: Vector2

# Порывистый ветер
var gust_wind_active: bool = false
var gust_wind_force: float = 0.0
var gust_wind_timer: Timer
var gust_wind_duration: float = 0.0

func _ready() -> void:
	# Вызываем родительский _ready() (включая запуск музыки)
	super._ready()
	
	# Инициализируем систему ветра
	_setup_wind_system()
	
	# Инициализируем систему шатания башни
	_setup_tower_shaking()
	
	# Получаем камеру
	camera = get_node("Camera2D")
	if camera:
		original_camera_position = camera.position

func _setup_wind_system() -> void:
	"""Настраивает систему порывистого ветра для четвертого уровня"""
	
	# Создаем менеджер ветра с порывами
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
	
	# Настраиваем порывистый ветер
	_setup_gust_wind()
	

func _setup_gust_wind() -> void:
	"""Настраивает систему порывистого ветра"""
	gust_wind_timer = Timer.new()
	gust_wind_timer.one_shot = true
	gust_wind_timer.timeout.connect(_trigger_gust_wind)
	add_child(gust_wind_timer)
	
	# Запускаем первый порыв через 2-4 секунды
	var initial_delay = randf_range(2.0, 4.0)
	gust_wind_timer.wait_time = initial_delay
	gust_wind_timer.start()

func _trigger_gust_wind() -> void:
	"""Запускает порыв ветра"""
	if gust_wind_active:
		return
	
	# Определяем силу и длительность порыва
	gust_wind_force = randf_range(-300.0, 300.0)
	gust_wind_duration = randf_range(2.0, 3.0)
	
	gust_wind_active = true
	
	
	# Запускаем таймер окончания порыва
	var gust_end_timer = Timer.new()
	gust_end_timer.one_shot = true
	gust_end_timer.wait_time = gust_wind_duration
	gust_end_timer.timeout.connect(_end_gust_wind)
	add_child(gust_end_timer)
	gust_end_timer.start()
	
	# Запускаем шатание башни
	_start_tower_shake()

func _end_gust_wind() -> void:
	"""Заканчивает порыв ветра"""
	gust_wind_active = false
	gust_wind_force = 0.0
	
	
	# Планируем следующий порыв через 3-6 секунд
	var next_gust_delay = randf_range(3.0, 6.0)
	gust_wind_timer.wait_time = next_gust_delay
	gust_wind_timer.start()

func _setup_tower_shaking() -> void:
	"""Настраивает систему шатания башни"""
	tower_shake_timer = Timer.new()
	tower_shake_timer.wait_time = 0.05  # Обновляем каждые 50мс
	tower_shake_timer.timeout.connect(_update_tower_shake)
	add_child(tower_shake_timer)
	tower_shake_timer.start()

func _start_tower_shake() -> void:
	"""Запускает шатание башни"""
	if is_tower_shaking:
		return
	
	is_tower_shaking = true
	shake_intensity = randf_range(2.0, 5.0)
	shake_duration = randf_range(1.5, 2.5)
	

func _update_tower_shake() -> void:
	"""Обновляет эффект шатания башни"""
	if not is_tower_shaking or not camera:
		return
	
	# Уменьшаем интенсивность со временем
	shake_duration -= 0.05
	if shake_duration <= 0:
		_stop_tower_shake()
		return
	
	# Создаем случайное смещение камеры
	var shake_offset = Vector2(
		randf_range(-shake_intensity, shake_intensity),
		randf_range(-shake_intensity * 0.5, shake_intensity * 0.5)
	)
	
	camera.position = original_camera_position + shake_offset

func _stop_tower_shake() -> void:
	"""Останавливает шатание башни"""
	is_tower_shaking = false
	shake_intensity = 0.0
	
	if camera:
		camera.position = original_camera_position
	

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
	
	# Добавляем порывистый ветер если активен
	if gust_wind_active:
		wind_force += gust_wind_force
	
	# Определяем границы карты (используем константы из родительского класса)
	var map_left = 0.0
	var map_right = 720.0  # VIRT_W
	var edge_zone_width = 300.0  # Зона ослабления ветра у краев карты
	
	# Применяем ветер ко всем активным пончикам
	for donut in active_donuts:
		if not is_instance_valid(donut):
			continue
		
		# Проверяем, что пончик падает (имеет положительную скорость по Y или не спит)
		if donut.linear_velocity.y > 0 or not donut.sleeping:
			# Получаем позицию пончика
			var donut_x = donut.global_position.x
			
			# Вычисляем коэффициент ослабления ветра в зависимости от расстояния до края
			var wind_reduction_factor = 1.0
			
			# Проверяем близость к левому краю
			if donut_x < map_left + edge_zone_width:
				var distance_to_left = donut_x - map_left
				if distance_to_left < edge_zone_width:
					# Ослабляем ветер при приближении к левому краю
					wind_reduction_factor = distance_to_left / edge_zone_width
					# Дополнительно ограничиваем силу ветра, направленную влево
					if wind_force < 0:
						wind_reduction_factor *= 0.3  # Сильно ослабляем ветер влево у левого края
			
			# Проверяем близость к правому краю
			elif donut_x > map_right - edge_zone_width:
				var distance_to_right = map_right - donut_x
				if distance_to_right < edge_zone_width:
					# Ослабляем ветер при приближении к правому краю
					wind_reduction_factor = distance_to_right / edge_zone_width
					# Дополнительно ограничиваем силу ветра, направленную вправо
					if wind_force > 0:
						wind_reduction_factor *= 0.3  # Сильно ослабляем ветер вправо у правого края
			
			# Применяем силу ветра с учетом ослабления
			var final_wind_force = wind_force * wind_reduction_factor * 0.4  # Базовый коэффициент 40%
			var wind_vector = Vector2(final_wind_force, 0)
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
		return {"force": 0, "direction": "штиль", "strength": "отсутствует", "gust_active": false}
	
	var base_wind = wind_manager.get_wind_force()
	var total_wind = base_wind + (gust_wind_force if gust_wind_active else 0)
	
	return {
		"force": total_wind,
		"direction": wind_manager.get_wind_direction(),
		"strength": wind_manager.get_wind_strength(),
		"gust_active": gust_wind_active,
		"gust_force": gust_wind_force if gust_wind_active else 0
	}

func get_tower_shake_info() -> Dictionary:
	"""Возвращает информацию о шатании башни"""
	return {
		"is_shaking": is_tower_shaking,
		"intensity": shake_intensity,
		"duration": shake_duration
	}
