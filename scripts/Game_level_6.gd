extends "res://scripts/Game.gd"

# Специальный скрипт для шестого уровня - ФИНАЛЬНЫЙ УРОВЕНЬ
# Камера наследуется от родительского класса как @onready var cam: Camera2D

# Система песка (как в 5-м уровне)
var sand_particles: Array[Node2D] = []
var sand_accumulation_height: float = 0.0
var sand_spawn_timer: Timer
var sand_spawn_rate: float = 12.0  # Немного быстрее чем в 5-м уровне
var sand_particle_scene: PackedScene
var sand_ground_height: float = 1214.0  # Высота ground из сцены
var max_sand_height: float = 400.0  # Увеличиваем максимальную высоту для финального уровня
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

# Финальные эффекты
var final_level_effects: Array[Node2D] = []
var victory_celebration: bool = false

# Система качки для 6-го уровня
var shake_timer: float = 0.0
var shake_period: float = 7.0  # Период ~7 секунд
var shake_amplitude: float = 8.0  # Амплитуда ~8 градусов
var shake_phase: float = 0.0
var calm_duration: float = 0.0  # Длительность "штиля"
var calm_timer: float = 0.0
var is_in_calm: bool = false

# Плавный переход наклона
var current_tilt: float = 0.0
var target_tilt: float = 0.0
var tilt_speed: float = 2.0  # Скорость плавного перехода

# Система бонусных очков за точную посадку
var precise_landings: int = 0  # Счетчик точных посадок подряд
var last_landing_angle: float = 0.0  # Угол последней посадки
var bonus_score: int = 0  # Дополнительные очки

# Модификаторы скорости каретки
var original_cart_speed: float = 0.0
var speed_modifier: float = 1.0

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
	
	# Создаем финальные эффекты
	_setup_final_level_effects()
	
	# Настраиваем камеру (она уже получена в родительском классе как cam)
	if cam:
		cam.position_smoothing_enabled = true
		cam.position_smoothing_speed = 5.0
	
	# Запоминаем время начала игры
	game_start_time = Time.get_unix_time_from_system()
	
	# Инициализируем систему качки
	_setup_shake_system()
	print("Система качки инициализирована для 6-го уровня!")
	
	# Сохраняем оригинальную скорость каретки
	original_cart_speed = spawner.cart_speed

func _setup_shake_system() -> void:
	"""Настраивает систему качки для 6-го уровня"""
	print("Настройка системы качки...")
	
	# Инициализируем случайную фазу качки
	shake_phase = randf() * 2.0 * PI
	
	# Случайная длительность "штиля" (0.7-1.0 секунды)
	calm_duration = randf_range(0.7, 1.0)
	
	# Устанавливаем пониженное трение для пончиков
	_setup_reduced_friction()
	
	print("Система качки настроена успешно!")

func _setup_reduced_friction() -> void:
	"""Устанавливает пониженное трение для пончиков"""
	# Это будет применяться при создании пончиков
	pass

func _setup_final_level_effects() -> void:
	"""Настраивает финальные эффекты для последнего уровня"""
	# Создаем дополнительные частицы для финального уровня
	var final_particles = GPUParticles2D.new()
	final_particles.name = "FinalParticles"
	final_particles.position = Vector2(360, 200)
	final_particles.z_index = -5
	
	# Настраиваем материал частиц для финального эффекта
	var final_material = ParticleProcessMaterial.new()
	final_material.direction = Vector3(0, 1, 0)
	final_material.initial_velocity_min = 20.0
	final_material.initial_velocity_max = 80.0
	final_material.gravity = Vector3(0, 50, 0)
	final_material.scale_min = 0.5
	final_material.scale_max = 1.5
	final_material.color = Color(1.0, 0.8, 0.2, 0.8)  # Золотой цвет
	final_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	final_material.emission_box_extents = Vector3(600, 100, 0)
	
	final_particles.process_material = final_material
	final_particles.amount = 100
	final_particles.lifetime = 6.0
	final_particles.emitting = true
	
	add_child(final_particles)
	final_level_effects.append(final_particles)

func _setup_sand_overflow_timer() -> void:
	"""Настраивает таймер переполнения песка через 2.5 минуты (быстрее чем в 5-м)"""
	sand_overflow_timer = Timer.new()
	sand_overflow_timer.wait_time = 150.0  # 2.5 минуты
	sand_overflow_timer.one_shot = true
	sand_overflow_timer.timeout.connect(_start_sand_overflow)
	add_child(sand_overflow_timer)
	sand_overflow_timer.start()
	

func _start_sand_overflow() -> void:
	"""Запускает переполнение песка"""
	sand_overflow_started = true
	max_sand_height = 1200.0  # Убираем ограничение по высоте для финального уровня
	sand_spawn_timer.wait_time = 0.3  # Ускоряем спавн песка сильнее чем в 5-м
	
	# Увеличиваем интенсивность финальных эффектов
	for effect in final_level_effects:
		if effect is GPUParticles2D:
			effect.amount = 200
			effect.lifetime = 8.0


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
	storm_material.initial_velocity_min = 60.0  # Быстрее чем в 5-м
	storm_material.initial_velocity_max = 180.0
	storm_material.gravity = Vector3(0, 250, 0)  # Сильнее гравитация
	storm_material.scale_min = 0.4
	storm_material.scale_max = 1.2
	storm_material.color = Color(0.9, 0.7, 0.3, 0.7)  # Песочный цвет с прозрачностью
	storm_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	storm_material.emission_box_extents = Vector3(500, 60, 0)  # Широкая область спавна
	
	sand_storm_particles.process_material = storm_material
	sand_storm_particles.amount = 250  # Больше частиц для финального уровня
	sand_storm_particles.lifetime = 10.0  # Долгая жизнь частиц
	sand_storm_particles.emitting = true
	
	add_child(sand_storm_particles)
	
	# Создаем таймер для изменения интенсивности бури
	sand_storm_timer = Timer.new()
	sand_storm_timer.wait_time = 1.5  # Чаще обновляем
	sand_storm_timer.timeout.connect(_update_sand_storm_intensity)
	sand_storm_timer.autostart = true
	add_child(sand_storm_timer)
	

func _update_sand_storm_intensity() -> void:
	"""Обновляет интенсивность песчаной бури"""
	if not sand_storm_particles:
		return
	
	var current_time = Time.get_unix_time_from_system()
	var elapsed_time = current_time - game_start_time
	
	# Постепенно увеличиваем интенсивность бури со временем (быстрее чем в 5-м)
	if elapsed_time > 45:  # После 45 секунд
		sand_storm_particles.amount = 350
		sand_storm_particles.lifetime = 12.0
	elif elapsed_time > 90:  # После 1.5 минут
		sand_storm_particles.amount = 450
		sand_storm_particles.lifetime = 14.0
	elif elapsed_time > 120:  # После 2 минут
		sand_storm_particles.amount = 550
		sand_storm_particles.lifetime = 16.0

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
	sand_body.gravity_scale = 3.5  # Песок падает быстрее чем в 5-м
	sand_body.mass = 0.04  # Еще легче
	sand_body.linear_damp = 0.05  # Меньше сопротивление воздуха
	
	# Создаем коллизию
	var collision = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(2.5, 2.5)  # Еще меньше частицы песка
	collision.shape = shape
	sand_body.add_child(collision)
	
	# Создаем спрайт с эффектом падения
	var sprite = Sprite2D.new()
	var texture = ImageTexture.new()
	var image = Image.create(2, 2, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.9, 0.7, 0.3, 0.9))  # Песочный цвет
	texture.set_image(image)
	sprite.texture = texture
	sand_body.add_child(sprite)
	
	# Добавляем эффект частиц для визуализации падения
	var particles = GPUParticles2D.new()
	var particle_material = ParticleProcessMaterial.new()
	particle_material.direction = Vector3(0, 1, 0)
	particle_material.initial_velocity_min = 15.0
	particle_material.initial_velocity_max = 25.0
	particle_material.gravity = Vector3(0, 120, 0)
	particle_material.scale_min = 0.4
	particle_material.scale_max = 1.0
	particles.process_material = particle_material
	particles.amount = 6
	particles.lifetime = 0.6
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
	var spawn_x = randf_range(-60, 780)  # Шире экрана для эффекта ветра
	var spawn_y = randf_range(-120, -30)  # Разная высота падения
	sand_particle.position = Vector2(spawn_x, spawn_y)
	
	# Добавляем случайный импульс для эффекта падения с ветром
	var wind_effect = randf_range(-40, 40)  # Сильнее эффект ветра
	var fall_force = randf_range(15, 60)  # Сильнее сила падения
	var random_force = Vector2(wind_effect, fall_force)
	sand_particle.apply_central_impulse(random_force)
	
	# Добавляем небольшое вращение для реалистичности
	sand_particle.angular_velocity = randf_range(-3, 3)
	
	# Добавляем в список для отслеживания
	sand_particles.append(sand_particle)
	
	# Добавляем таймер для проверки позиции
	var check_timer = Timer.new()
	check_timer.wait_time = 0.03  # Более частая проверка
	check_timer.timeout.connect(_check_sand_position.bind(sand_particle))
	check_timer.autostart = true
	sand_particle.add_child(check_timer)
	
	# Добавляем эффект исчезновения через время
	var cleanup_timer = Timer.new()
	cleanup_timer.wait_time = 12.0  # Удаляем через 12 секунд
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
		# Увеличиваем высоту накопления песка (быстрее чем в 5-м)
		sand_accumulation_height += 0.08  # Каждая частица добавляет 0.08 пикселя
		
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
		sand_visual_indicator.color = Color(0.6, 0.4, 0.1, 0.9)  # Еще темнее для финального уровня

func _spawn_donut(world_pos: Vector2) -> void:
	"""Переопределяем спавн пончика с пониженным трением"""
	# Вызываем родительский метод
	super._spawn_donut(world_pos)
	
	# Применяем пониженное трение к последнему созданному пончику
	if active_donuts.size() > 0:
		var last_donut = active_donuts[-1]
		if is_instance_valid(last_donut):
			# Устанавливаем пониженное трение (friction ≈ 0.5)
			last_donut.physics_material_override = PhysicsMaterial.new()
			last_donut.physics_material_override.friction = 0.5
			last_donut.physics_material_override.bounce = 0.3
	

func _process(_delta: float) -> void:
	"""Обновляем систему песка и качки"""
	# Вызываем родительский метод
	super._process(_delta)
	
	# Обновляем систему качки
	_update_shake_system(_delta)
	
	# Проверяем, не тонут ли пончики в песке
	_check_donuts_in_sand()
	
	# Очищаем старые частицы песка
	_cleanup_sand_particles()
	
	# Обновляем скорость спавна песка в зависимости от времени
	_update_sand_spawn_rate()
	
	# Обновляем интенсивность песчаной бури
	_update_sand_storm_intensity()
	
	# Обновляем скорость каретки в зависимости от наклона
	_update_cart_speed()
	
	# Отладочная информация (можно убрать в релизе)
	_debug_donut_positions()

func _update_sand_spawn_rate() -> void:
	"""Обновляет скорость спавна песка в зависимости от времени"""
	if not sand_spawn_timer:
		return
	
	var current_time = Time.get_unix_time_from_system()
	var elapsed_time = current_time - game_start_time
	
	# Постепенно ускоряем спавн песка (быстрее чем в 5-м)
	if elapsed_time > 45:  # После 45 секунд
		sand_spawn_timer.wait_time = 4.0
	elif elapsed_time > 90:  # После 1.5 минут
		sand_spawn_timer.wait_time = 3.0
	elif elapsed_time > 120:  # После 2 минут
		sand_spawn_timer.wait_time = 2.0

func _update_shake_system(delta: float) -> void:
	"""Обновляет систему качки"""
	try:
		shake_timer += delta
		
		# Упрощенная система качки - просто синусоидальный наклон
		var angle = sin(shake_timer * 2.0 * PI / shake_period) * shake_amplitude
		
		# Применяем наклон к камере и всей сцене
		_apply_camera_tilt(angle)
		
		# Отладочная информация каждые 2 секунды
		if int(shake_timer) % 2 == 0 and shake_timer - int(shake_timer) < delta:
			print("Качка работает! Угол: ", angle, " Время: ", shake_timer)
	except:
		print("Ошибка в системе качки, но продолжаем работу")

func _calculate_shake_angle() -> float:
	"""Вычисляет текущий угол наклона на основе синуса"""
	var time_factor = shake_timer / shake_period
	var sine_value = sin(time_factor * 2.0 * PI + shake_phase)
	return sine_value * shake_amplitude

func _apply_camera_tilt(angle: float) -> void:
	"""Применяет наклон к камере и всей сцене (палубе)"""
	try:
		if cam:
			cam.rotation_degrees = angle
			# Наклоняем всю сцену, включая башню пончиков
			_apply_scene_tilt(angle)
		else:
			print("ОШИБКА: Камера не найдена!")
	except:
		print("Ошибка при наклоне камеры, но продолжаем работу")

func _apply_scene_tilt(angle: float) -> void:
	"""Наклоняет всю сцену, включая башню пончиков"""
	try:
		# Наклоняем все активные пончики
		for donut in active_donuts:
			if is_instance_valid(donut):
				# Применяем наклон к пончикам
				donut.rotation_degrees = angle * 0.8  # Слегка меньший наклон для пончиков
		
		# Наклоняем частицы песка
		for particle in sand_particles:
			if is_instance_valid(particle):
				particle.rotation_degrees = angle * 0.3  # Очень слабый наклон для частиц
		
		# Наклоняем визуальный индикатор песка
		if sand_visual_indicator:
			sand_visual_indicator.rotation_degrees = angle * 0.5
		
		# Наклоняем фон
		var background = get_node("Background")
		if background:
			background.rotation_degrees = angle * 0.2  # Очень слабый наклон фона
		
		# Наклоняем стены
		var left_wall = get_node("LeftWall")
		var right_wall = get_node("RightWall")
		if left_wall:
			left_wall.rotation_degrees = angle * 0.6
		if right_wall:
			right_wall.rotation_degrees = angle * 0.6
		
		# Наклоняем землю
		var ground = get_node("Ground")
		if ground:
			ground.rotation_degrees = angle * 0.4
		
		# Наклоняем UI элементы (очень слабо)
		var ui_root = get_node("UI/UIRoot")
		if ui_root:
			ui_root.rotation_degrees = angle * 0.1  # Очень слабый наклон UI
	except:
		print("Ошибка при наклоне сцены, но продолжаем работу")

func _update_cart_speed() -> void:
	"""Обновляет скорость каретки в зависимости от наклона"""
	if not spawner:
		return
	
	var current_angle = abs(current_tilt)
	
	# Если наклон больше 6 градусов, уменьшаем скорость на 10%
	if current_angle > 6.0:
		speed_modifier = 0.9
	else:
		speed_modifier = 1.0
	
	# Применяем модификатор скорости
	spawner.cart_speed = original_cart_speed * speed_modifier

func _debug_donut_positions() -> void:
	"""Отладочная функция для отслеживания позиций пончиков"""
	if not OS.is_debug_build():
		return  # Только в debug режиме
	
	var threshold: float = cam.position.y + VIRT_H * 2.0 if cam != null else VIRT_H * 2.0
	
	# Отладочная информация о качке (только каждые 3 секунды)
	if int(shake_timer) % 3 == 0 and shake_timer - int(shake_timer) < 0.1:
		print("Качка - Угол: ", cam.rotation_degrees if cam else "НЕТ КАМЕРЫ", " Время: ", shake_timer)
	
	for i in range(active_donuts.size()):
		var donut = active_donuts[i]
		if is_instance_valid(donut):
			# Проверяем критические позиции
			if donut.position.y > threshold:
				print("ПОНЧИК УПАЛ СЛИШКОМ НИЗКО! Y: ", donut.position.y, " Порог: ", threshold)
			elif donut.position.x < -100.0 or donut.position.x > VIRT_W + 100.0:
				print("ПОНЧИК УКАТИЛСЯ В СТОРОНУ! X: ", donut.position.x, " Y: ", donut.position.y)

func _on_donut_settled(donut_obj: Object) -> void:
	"""Переопределяем обработку посадки пончика для системы бонусных очков"""
	var d := donut_obj as RigidBody2D
	if d == null or not is_instance_valid(d):
		return

	# Получаем текущий угол наклона
	var current_angle = abs(current_tilt)
	last_landing_angle = current_angle
	
	# Проверяем точную посадку (наклон > 6°)
	if current_angle > 6.0:
		# Точная посадка - добавляем бонусные очки
		precise_landings += 1
		bonus_score += 2
		
		# Проверяем серию из 3 точных посадок
		if precise_landings >= 3:
			bonus_score += 5
			precise_landings = 0  # Сбрасываем счетчик
			# Можно добавить визуальный эффект для серии
			_show_combo_effect()
	else:
		# Обычная посадка - сбрасываем счетчик точных посадок
		precise_landings = 0
	
	# Добавляем обычные очки
	add_score(1)
	
	# Добавляем бонусные очки
	if bonus_score > 0:
		add_score(bonus_score)
		bonus_score = 0  # Сбрасываем бонусные очки

	# сохраняем Y до await (после await d может быть удалён)
	var y_before := d.global_position.y

	# пусть check_touch_chain() вернёт true, если что‑то удалялось
	var removed_any := await check_touch_chain()

	# обновляем вершину башни
	if removed_any:
		_recompute_tower_top_y()
	else:
		# d всё ещё может пропасть по другим причинам — подстрахуемся
		_tower_top_y = min(_tower_top_y, y_before)

	_recalc_difficulty()

func _show_combo_effect() -> void:
	"""Показывает эффект комбо из 3 точных посадок"""
	# Создаем эффект частиц для комбо
	var combo_particles = GPUParticles2D.new()
	combo_particles.name = "ComboEffect"
	combo_particles.position = Vector2(360, 200)
	combo_particles.z_index = 10
	
	var combo_material = ParticleProcessMaterial.new()
	combo_material.direction = Vector3(0, 1, 0)
	combo_material.initial_velocity_min = 100.0
	combo_material.initial_velocity_max = 200.0
	combo_material.gravity = Vector3(0, 50, 0)
	combo_material.scale_min = 1.0
	combo_material.scale_max = 2.0
	combo_material.color = Color(1.0, 0.8, 0.2, 1.0)  # Золотой цвет
	combo_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	combo_material.emission_box_extents = Vector3(100, 50, 0)
	
	combo_particles.process_material = combo_material
	combo_particles.amount = 50
	combo_particles.lifetime = 2.0
	combo_particles.emitting = true
	
	add_child(combo_particles)
	
	# Удаляем эффект через время
	var cleanup_timer = Timer.new()
	cleanup_timer.wait_time = 3.0
	cleanup_timer.one_shot = true
	cleanup_timer.timeout.connect(_cleanup_combo_effect.bind(combo_particles))
	cleanup_timer.start()
	combo_particles.add_child(cleanup_timer)

func _cleanup_combo_effect(effect: GPUParticles2D) -> void:
	"""Очищает эффект комбо"""
	if is_instance_valid(effect):
		effect.queue_free()

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
					"sink_speed": 0.7,  # Быстрее проваливание для финального уровня
					"max_sink_depth": 40.0,  # Больше глубина проваливания
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
	
	# Сильно замедляем пончик (эффект вязкости) - сильнее чем в 5-м
	donut.linear_velocity *= 0.4  # Замедляем на 60% каждый кадр
	donut.angular_velocity *= 0.5  # Замедляем вращение
	
	# Добавляем сильное сопротивление песка
	var sand_resistance = Vector2(-donut.linear_velocity.x * 0.7, -donut.linear_velocity.y * 0.5)
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
				if sand_accumulation_height > 200 and _state == GameMode.PLAY:  # Если песок поднялся слишком высоко
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
		if not is_instance_valid(particle) or particle.position.y > 1500:
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
	
	# Дополнительная проверка для уровня 6 - если пончик упал слишком низко
	# Используем тот же порог, что и в родительской функции
	var threshold: float = cam.position.y + VIRT_H * 2.0 if cam != null else VIRT_H * 2.0
	
	for donut in active_donuts:
		if is_instance_valid(donut):
			# Проверяем, упал ли пончик слишком низко
			if donut.position.y > threshold:
				# Проверяем, что игра еще не завершена
				if _state == GameMode.PLAY:
					_set_game_over()
					return
			# Проверяем, укатился ли пончик в стороны (за пределы экрана)
			elif donut.position.x < -100.0 or donut.position.x > VIRT_W + 100.0:
				# Проверяем, что игра еще не завершена
				if _state == GameMode.PLAY:
					_set_game_over()
					return
	
	# Вызываем родительский метод
	super._cleanup_fallen()

func _show_win_panel() -> void:
	"""Переопределяем панель победы для ФИНАЛЬНОГО уровня 6"""
	# Скрываем кнопку "Next Level" для финального уровня
	if game_over_panel:
		var next_level_button = game_over_panel.get_node("MainContainer/NextLevelButton")
		if next_level_button:
			next_level_button.visible = false
		
		# Меняем текст на "Поздравляем!"
		var game_over_label = game_over_panel.get_node("MainContainer/GameOverLabel")
		if game_over_label:
			game_over_label.text = "Поздравляем!"
		
		# Показываем панель с победой (без следующего уровня)
		if game_over_panel.has_method("show_game_over"):
			game_over_panel.show_game_over(score, true, "", scene_file_path)
		elif game_over_panel.has_method("show_game_over_fallback"):
			# Используем fallback функцию
			game_over_panel.show_game_over_fallback(score, true)
		else:
			# Последний fallback - показываем панель старым способом
			game_over_panel.visible = true
		
		# Запускаем финальное празднование
		_start_final_celebration()

func _start_final_celebration() -> void:
	"""Запускает финальное празднование для завершения игры"""
	if victory_celebration:
		return
	
	victory_celebration = true
	
	# Увеличиваем интенсивность всех эффектов
	for effect in final_level_effects:
		if effect is GPUParticles2D:
			effect.amount = 500
			effect.lifetime = 10.0
	
	# Увеличиваем интенсивность песчаной бури
	if sand_storm_particles:
		sand_storm_particles.amount = 800
		sand_storm_particles.lifetime = 20.0
	
	# Создаем дополнительные эффекты празднования
	_create_victory_effects()

func _create_victory_effects() -> void:
	"""Создает дополнительные эффекты для празднования победы"""
	# Создаем взрывы частиц в разных местах экрана
	for i in range(5):
		var explosion = GPUParticles2D.new()
		explosion.name = "VictoryExplosion" + str(i)
		explosion.position = Vector2(randf_range(100, 620), randf_range(200, 1000))
		explosion.z_index = -5
		
		var explosion_material = ParticleProcessMaterial.new()
		explosion_material.direction = Vector3(0, 1, 0)
		explosion_material.initial_velocity_min = 50.0
		explosion_material.initial_velocity_max = 150.0
		explosion_material.gravity = Vector3(0, 100, 0)
		explosion_material.scale_min = 0.5
		explosion_material.scale_max = 2.0
		explosion_material.color = Color(1.0, 0.8, 0.2, 0.9)
		explosion_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		explosion_material.emission_box_extents = Vector3(50, 50, 0)
		
		explosion.process_material = explosion_material
		explosion.amount = 100
		explosion.lifetime = 3.0
		explosion.emitting = true
		
		add_child(explosion)
		
		# Удаляем эффект через время
		var cleanup_timer = Timer.new()
		cleanup_timer.wait_time = 5.0
		cleanup_timer.one_shot = true
		cleanup_timer.timeout.connect(_cleanup_victory_effect.bind(explosion))
		cleanup_timer.start()
		explosion.add_child(cleanup_timer)

func _cleanup_victory_effect(effect: GPUParticles2D) -> void:
	"""Очищает эффект празднования"""
	if is_instance_valid(effect):
		effect.queue_free()
