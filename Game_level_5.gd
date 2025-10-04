extends "res://scripts/Game.gd"

# Специальный скрипт для пятого уровня с механикой песка
@onready var camera: Camera2D

# Система песка
var sand_particles: Array[Node2D] = []
var sand_accumulation_height: float = 0.0
var sand_spawn_timer: Timer
var sand_spawn_rate: float = 15.0  # секунды между спавнами песка (очень медленно)
var sand_particle_scene: PackedScene
var sand_ground_height: float = 1214.0  # Высота ground из сцены
var max_sand_height: float = 300.0  # Увеличиваем максимальную высоту
var sand_visual_indicator: ColorRect  # Визуальный индикатор накопления песка

# Таймер для переполнения песка
var sand_overflow_timer: Timer
var sand_overflow_started: bool = false
var game_start_time: float = 0.0

# Система вязкости песка
var donuts_in_sand: Array[Dictionary] = []  # Список пончиков в песке с их данными

# Эффект падающего песка с неба
var sand_storm_particles: GPUParticles2D
var sand_storm_timer: Timer

func _ready() -> void:
	# Вызываем родительский _ready() (включая запуск музыки)
	super._ready()
	
	# Инициализируем систему песка
	_setup_sand_system()
	
	# Создаем визуальный индикатор песка
	_setup_sand_visual_indicator()
	
	# Настраиваем таймер переполнения песка
	_setup_sand_overflow_timer()
	
	# Создаем эффект песчаной бури
	_setup_sand_storm_effect()
	
	# Получаем камеру
	camera = get_node("Camera2D")
	if camera:
		camera.position_smoothing_enabled = true
		camera.position_smoothing_speed = 5.0
	
	# Запоминаем время начала игры
	game_start_time = Time.get_unix_time_from_system()

func _setup_sand_overflow_timer() -> void:
	"""Настраивает таймер переполнения песка через 3 минуты"""
	sand_overflow_timer = Timer.new()
	sand_overflow_timer.wait_time = 180.0  # 3 минуты
	sand_overflow_timer.one_shot = true
	sand_overflow_timer.timeout.connect(_start_sand_overflow)
	add_child(sand_overflow_timer)
	sand_overflow_timer.start()
	

func _start_sand_overflow() -> void:
	"""Запускает переполнение песка"""
	sand_overflow_started = true
	max_sand_height = 1000.0  # Убираем ограничение по высоте
	sand_spawn_timer.wait_time = 0.5  # Ускоряем спавн песка, но не слишком сильно
	

func _setup_sand_storm_effect() -> void:
	"""Создает эффект падающего песка с неба (песчаная буря)"""
	
	# Создаем систему частиц для песчаной бури
	sand_storm_particles = GPUParticles2D.new()
	sand_storm_particles.name = "SandStormParticles"
	sand_storm_particles.position = Vector2(360, -100)  # Сверху экрана
	sand_storm_particles.z_index = -10  # За UI, но перед фоном
	
	# Настраиваем материал частиц
	var storm_material = ParticleProcessMaterial.new()
	storm_material.direction = Vector3(0, 1, 0)  # Падение вниз
	storm_material.initial_velocity_min = 50.0
	storm_material.initial_velocity_max = 150.0
	storm_material.gravity = Vector3(0, 200, 0)  # Гравитация
	storm_material.scale_min = 0.3
	storm_material.scale_max = 1.0
	storm_material.color = Color(0.9, 0.7, 0.3, 0.6)  # Песочный цвет с прозрачностью
	storm_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	storm_material.emission_box_extents = Vector3(400, 50, 0)  # Широкая область спавна
	
	sand_storm_particles.process_material = storm_material
	sand_storm_particles.amount = 200  # Много частиц для эффекта бури
	sand_storm_particles.lifetime = 8.0  # Долгая жизнь частиц
	sand_storm_particles.emitting = true
	
	add_child(sand_storm_particles)
	
	# Создаем таймер для изменения интенсивности бури
	sand_storm_timer = Timer.new()
	sand_storm_timer.wait_time = 2.0
	sand_storm_timer.timeout.connect(_update_sand_storm_intensity)
	sand_storm_timer.autostart = true
	add_child(sand_storm_timer)
	

func _update_sand_storm_intensity() -> void:
	"""Обновляет интенсивность песчаной бури"""
	if not sand_storm_particles:
		return
	
	var current_time = Time.get_unix_time_from_system()
	var elapsed_time = current_time - game_start_time
	
	# Постепенно увеличиваем интенсивность бури со временем
	if elapsed_time > 60:  # После 1 минуты
		sand_storm_particles.amount = 300
		sand_storm_particles.lifetime = 10.0
	elif elapsed_time > 120:  # После 2 минут
		sand_storm_particles.amount = 400
		sand_storm_particles.lifetime = 12.0
	elif elapsed_time > 150:  # После 2.5 минут
		sand_storm_particles.amount = 500
		sand_storm_particles.lifetime = 15.0

func _setup_sand_system() -> void:
	"""Настраивает систему падающего песка"""
	
	# Создаем таймер для спавна песка
	sand_spawn_timer = Timer.new()
	sand_spawn_timer.wait_time = sand_spawn_rate
	sand_spawn_timer.timeout.connect(_spawn_sand_particle)
	sand_spawn_timer.autostart = true
	add_child(sand_spawn_timer)
	
	# Создаем простую сцену для частицы песка
	_create_sand_particle_scene()
	

func _setup_sand_visual_indicator() -> void:
	"""Создает визуальный индикатор накопления песка"""
	sand_visual_indicator = ColorRect.new()
	sand_visual_indicator.color = Color(0.9, 0.7, 0.3, 0.6)  # Песочный цвет с прозрачностью
	sand_visual_indicator.position = Vector2(0, sand_ground_height - max_sand_height)
	sand_visual_indicator.size = Vector2(720, 0)  # Начинаем с нулевой высоты
	sand_visual_indicator.z_index = -50  # За стенками, но перед фоном
	add_child(sand_visual_indicator)
	

func _create_sand_particle_scene() -> void:
	"""Создает простую сцену для частицы песка"""
	# Создаем простую RigidBody2D для песка
	var sand_body = RigidBody2D.new()
	sand_body.name = "SandParticle"
	sand_body.gravity_scale = 3.0  # Песок падает быстрее
	sand_body.mass = 0.05  # Очень легкий песок
	sand_body.linear_damp = 0.1  # Небольшое сопротивление воздуха
	
	# Создаем коллизию
	var collision = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(3, 3)  # Еще меньше частицы песка
	collision.shape = shape
	sand_body.add_child(collision)
	
	# Создаем спрайт с эффектом падения
	var sprite = Sprite2D.new()
	var texture = ImageTexture.new()
	var image = Image.create(3, 3, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.9, 0.7, 0.3, 0.9))  # Песочный цвет
	texture.set_image(image)
	sprite.texture = texture
	sand_body.add_child(sprite)
	
	# Добавляем эффект частиц для визуализации падения
	var particles = GPUParticles2D.new()
	var particle_material = ParticleProcessMaterial.new()
	particle_material.direction = Vector3(0, 1, 0)
	particle_material.initial_velocity_min = 10.0
	particle_material.initial_velocity_max = 20.0
	particle_material.gravity = Vector3(0, 98, 0)
	particle_material.scale_min = 0.5
	particle_material.scale_max = 1.0
	particles.process_material = particle_material
	particles.amount = 5
	particles.lifetime = 0.5
	particles.emitting = true
	sand_body.add_child(particles)
	
	# Создаем PackedScene
	sand_particle_scene = PackedScene.new()
	sand_particle_scene.pack(sand_body)

func _spawn_sand_particle() -> void:
	"""Спавнит частицу песка"""
	if not sand_particle_scene:
		return
	
	# Создаем частицу песка
	var sand_particle = sand_particle_scene.instantiate()
	add_child(sand_particle)
	
	# Устанавливаем случайную позицию сверху экрана с эффектом "ветра"
	var spawn_x = randf_range(-50, 770)  # Шире экрана для эффекта ветра
	var spawn_y = randf_range(-100, -20)  # Разная высота падения
	sand_particle.position = Vector2(spawn_x, spawn_y)
	
	# Добавляем случайный импульс для эффекта падения с ветром
	var wind_effect = randf_range(-30, 30)  # Эффект ветра
	var fall_force = randf_range(10, 50)  # Сила падения
	var random_force = Vector2(wind_effect, fall_force)
	sand_particle.apply_central_impulse(random_force)
	
	# Добавляем небольшое вращение для реалистичности
	sand_particle.angular_velocity = randf_range(-2, 2)
	
	# Добавляем в список для отслеживания
	sand_particles.append(sand_particle)
	
	# Добавляем таймер для проверки позиции
	var check_timer = Timer.new()
	check_timer.wait_time = 0.05  # Более частая проверка
	check_timer.timeout.connect(_check_sand_position.bind(sand_particle))
	check_timer.autostart = true
	sand_particle.add_child(check_timer)
	
	# Добавляем эффект исчезновения через время
	var cleanup_timer = Timer.new()
	cleanup_timer.wait_time = 10.0  # Удаляем через 10 секунд
	cleanup_timer.one_shot = true
	cleanup_timer.timeout.connect(_cleanup_sand_particle.bind(sand_particle))
	cleanup_timer.start()
	sand_particle.add_child(cleanup_timer)

func _check_sand_position(sand_particle: RigidBody2D) -> void:
	"""Проверяет позицию частицы песка"""
	if not is_instance_valid(sand_particle):
		return
	
	# Проверяем, что песок достиг земли
	if sand_particle.position.y >= sand_ground_height - sand_accumulation_height:
		# Увеличиваем высоту накопления песка (очень медленно)
		sand_accumulation_height += 0.05  # Каждая частица добавляет только 0.05 пикселя
		
		# Ограничиваем максимальную высоту
		if sand_accumulation_height > max_sand_height:
			sand_accumulation_height = max_sand_height
		
		# Фиксируем частицу на месте
		sand_particle.freeze = true
		sand_particle.position.y = sand_ground_height - sand_accumulation_height
		
		# Обновляем визуальный индикатор
		_update_sand_visual_indicator()
		
		
		# Удаляем из списка активных частиц
		if sand_particles.has(sand_particle):
			sand_particles.erase(sand_particle)

func _cleanup_sand_particle(sand_particle: RigidBody2D) -> void:
	"""Очищает частицу песка"""
	if not is_instance_valid(sand_particle):
		return
	
	# Удаляем из списка
	if sand_particles.has(sand_particle):
		sand_particles.erase(sand_particle)
	
	# Удаляем объект
	sand_particle.queue_free()

func _update_sand_visual_indicator() -> void:
	"""Обновляет визуальный индикатор накопления песка"""
	if not sand_visual_indicator:
		return
	
	# Обновляем высоту индикатора
	var indicator_height = sand_accumulation_height
	sand_visual_indicator.size.y = indicator_height
	sand_visual_indicator.position.y = sand_ground_height - indicator_height
	
	# Если песок переполнился, меняем цвет на более темный
	if sand_overflow_started:
		sand_visual_indicator.color = Color(0.7, 0.5, 0.2, 0.8)  # Темнее

func _spawn_donut(world_pos: Vector2) -> void:
	"""Переопределяем спавн пончика"""
	# Вызываем родительский метод
	super._spawn_donut(world_pos)
	

func _process(_delta: float) -> void:
	"""Обновляем систему песка"""
	# Вызываем родительский метод
	super._process(_delta)
	
	# Проверяем, не тонут ли пончики в песке
	_check_donuts_in_sand()
	
	# Очищаем старые частицы песка
	_cleanup_sand_particles()
	
	# Обновляем скорость спавна песка в зависимости от времени
	_update_sand_spawn_rate()
	
	# Обновляем интенсивность песчаной бури
	_update_sand_storm_intensity()

func _update_sand_spawn_rate() -> void:
	"""Обновляет скорость спавна песка в зависимости от времени"""
	if not sand_spawn_timer:
		return
	
	var current_time = Time.get_unix_time_from_system()
	var elapsed_time = current_time - game_start_time
	
	# Постепенно ускоряем спавн песка (но все равно очень медленно)
	if elapsed_time > 60:  # После 1 минуты
		sand_spawn_timer.wait_time = 5.0
	elif elapsed_time > 120:  # После 2 минут
		sand_spawn_timer.wait_time = 4.0
	elif elapsed_time > 150:  # После 2.5 минут
		sand_spawn_timer.wait_time = 3.0

func _check_donuts_in_sand() -> void:
	"""Проверяет, не тонут ли пончики в накопленном песке"""
	if sand_accumulation_height <= 0:
		return
	
	var sand_level = sand_ground_height - sand_accumulation_height
	
	for donut in active_donuts:
		if not is_instance_valid(donut):
			continue
		
		# Проверяем, касается ли пончик уровня песка
		if donut.position.y >= sand_level:
			# Проверяем, есть ли уже этот пончик в списке "в песке"
			var donut_data = _find_donut_in_sand(donut)
			
			if donut_data.is_empty():
				# Пончик только что попал в песок - добавляем в список
				donut_data = {
					"donut": donut,
					"sink_speed": 0.5,  # Скорость проваливания (пикселей в секунду)
					"max_sink_depth": 30.0,  # Максимальная глубина проваливания
					"current_sink": 0.0  # Текущая глубина проваливания
				}
				donuts_in_sand.append(donut_data)
			
			# Применяем вязкость песка
			_apply_sand_viscosity(donut_data)
	
	# Обновляем проваливание пончиков в песке
	_update_donuts_sinking()

func _find_donut_in_sand(donut: RigidBody2D) -> Dictionary:
	"""Находит данные пончика в списке 'в песке'"""
	for data in donuts_in_sand:
		if data["donut"] == donut:
			return data
	return {}  # Возвращаем пустой словарь вместо null

func _apply_sand_viscosity(donut_data: Dictionary) -> void:
	"""Применяет вязкость песка к пончику"""
	var donut = donut_data["donut"]
	
	# Сильно замедляем пончик (эффект вязкости)
	donut.linear_velocity *= 0.5  # Замедляем на 50% каждый кадр
	donut.angular_velocity *= 0.6  # Замедляем вращение
	
	# Добавляем сильное сопротивление песка
	var sand_resistance = Vector2(-donut.linear_velocity.x * 0.5, -donut.linear_velocity.y * 0.3)
	donut.apply_central_force(sand_resistance)

func _update_donuts_sinking() -> void:
	"""Обновляет проваливание пончиков в песке"""
	var sand_level = sand_ground_height - sand_accumulation_height
	
	for i in range(donuts_in_sand.size() - 1, -1, -1):
		var donut_data = donuts_in_sand[i]
		var donut = donut_data["donut"]
		
		if not is_instance_valid(donut):
			donuts_in_sand.remove_at(i)
			continue
		
		# Проверяем, что пончик все еще в песке
		if donut.position.y >= sand_level:
			# Пончик медленно проваливается в песок
			donut_data["current_sink"] += donut_data["sink_speed"] * get_process_delta_time()
			
			# Ограничиваем глубину проваливания
			if donut_data["current_sink"] > donut_data["max_sink_depth"]:
				donut_data["current_sink"] = donut_data["max_sink_depth"]
			
			# Устанавливаем новую позицию пончика (проваливается вниз)
			donut.position.y = sand_level - donut_data["current_sink"]
			
			# Если пончик провалился достаточно глубоко, фиксируем его
			if donut_data["current_sink"] >= donut_data["max_sink_depth"]:
				donut.freeze = true
				
				# Если песок накопился слишком высоко, это может означать поражение
				# НО только если игра еще не завершена
				if sand_accumulation_height > 150 and _state == GameMode.PLAY:  # Если песок поднялся слишком высоко
					_set_game_over()
					return
		else:
			# Пончик больше не в песке - удаляем из списка
			donuts_in_sand.remove_at(i)

func _cleanup_sand_particles() -> void:
	"""Очищает старые частицы песка"""
	# Удаляем частицы, которые упали слишком низко
	for i in range(sand_particles.size() - 1, -1, -1):
		var particle = sand_particles[i]
		if not is_instance_valid(particle) or particle.position.y > 1400:
			if is_instance_valid(particle):
				particle.queue_free()
			sand_particles.remove_at(i)

func get_sand_info() -> Dictionary:
	"""Возвращает информацию о системе песка"""
	var storm_intensity = 0
	if sand_storm_particles:
		storm_intensity = sand_storm_particles.amount
	
	return {
		"accumulation_height": sand_accumulation_height,
		"max_height": max_sand_height,
		"particles_count": sand_particles.size(),
		"spawn_rate": sand_spawn_rate,
		"overflow_started": sand_overflow_started,
		"storm_intensity": storm_intensity
	}

func _recycle_donut(d: RigidBody2D) -> void:
	"""Переопределяем переработку пончика"""
	# Вызываем родительский метод
	super._recycle_donut(d)

func _cleanup_fallen() -> void:
	"""Переопределяем очистку упавших пончиков"""
	# Очищаем пончики в песке от недействительных
	donuts_in_sand = donuts_in_sand.filter(func(data): return is_instance_valid(data["donut"]))
	
	# Дополнительная проверка для уровня 5 - если пончик упал слишком низко
	# Используем тот же bottom_y_limit, что и у пончиков
	var bottom_limit = get_world_bottom_limit() + 100.0  # Тот же лимит, что у поnчиков
	
	for donut in active_donuts:
		if is_instance_valid(donut) and donut.position.y > bottom_limit:
			# Проверяем, что игра еще не завершена
			if _state == GameMode.PLAY:
				_set_game_over()
				return
	
	# Вызываем родительский метод
	super._cleanup_fallen()

func _show_win_panel() -> void:
	"""Переопределяем панель победы для уровня 5 - прямой переход на 6 уровень без интро"""
	# Устанавливаем 6 уровень как текущий в LevelData
	LevelData.set_current_level(6)
	
	# Прямой переход на 6 уровень без интро
	get_tree().change_scene_to_file("res://scenes/Game_level_6.tscn")
