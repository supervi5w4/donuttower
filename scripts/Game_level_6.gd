extends "res://scripts/Game.gd"

# Специальный скрипт для шестого уровня - ФИНАЛЬНЫЙ УРОВЕНЬ
# Камера наследуется от родительского класса как @onready var cam: Camera2D

# Система песка удалена для упрощения 6-го уровня
var game_start_time: float = 0.0

# Менеджер поздравления
var victory_manager: VictoryManager

# Система качки для 6-го уровня
var shake_timer: float = 0.0
var shake_period: float = 7.0  # Период ~7 секунд
var shake_amplitude: float = 8.0  # Амплитуда ~8 градусов
var shake_phase: float = 0.0
var calm_duration: float = 0.0  # Длительность "штиля"
var calm_timer: float = 0.0
var is_in_calm: bool = false

# Система визуальных эффектов качки
var sway_particles: Array[GPUParticles2D] = []
var last_sway_time: float = 0.0

# Плавный переход наклона
var current_tilt: float = 0.0
var target_tilt: float = 0.0
var tilt_speed: float = 2.0  # Скорость плавного перехода
var previous_tilt: float = 0.0  # Предыдущий угол для вычисления скорости изменения
var tilt_velocity: float = 0.0  # Скорость изменения угла наклона

# Система бонусных очков за точную посадку
var precise_landings: int = 0  # Счетчик точных посадок подряд
var last_landing_angle: float = 0.0  # Угол последней посадки
var bonus_score: int = 0  # Дополнительные очки

# Ссылка на каретку для синхронизации поворота
var cart: Node2D

# Модификаторы скорости каретки
var original_cart_speed: float = 0.0
var speed_modifier: float = 1.0

func _ready() -> void:
	# Вызываем родительский _ready() (включая запуск музыки)
	super._ready()
	
	# Система песка удалена для упрощения 6-го уровня
	
	# Создаем менеджер поздравления
	victory_manager = VictoryManager.new()
	add_child(victory_manager)
	victory_manager.setup_final_level_effects()
	
	# Настраиваем камеру (она уже получена в родительском классе как cam)
	if cam:
		cam.position_smoothing_enabled = true
		cam.position_smoothing_speed = 5.0
	
	# Получаем ссылку на каретку (spawner)
	cart = get_node("Spawner")
	if not cart:
		print("ОШИБКА: Каретка (Spawner) не найдена!")
	
	# Запоминаем время начала игры
	game_start_time = Time.get_unix_time_from_system()
	
	# Инициализируем систему качки
	_setup_shake_system()
	print("Система качки инициализирована для 6-го уровня!")
	
	# Сохраняем оригинальную скорость каретки
	original_cart_speed = spawner.speed

func add_score(points: int) -> void:
	"""Переопределяем добавление очков для 6-го уровня - стандартная логика"""
	# Вызываем родительский метод
	super.add_score(points)
	
	# Стандартная логика победы - 100 очков для 6-го уровня
	# Победа обрабатывается в родительском классе через _recalc_difficulty()

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

# Функция _setup_final_level_effects() перенесена в VictoryManager

# Функции песка удалены


# Все функции песка удалены для упрощения 6-го уровня

# Все функции песка удалены для упрощения 6-го уровня

func _spawn_donut(world_pos: Vector2) -> void:
	"""Переопределяем спавн пончика с пониженным трением"""
	# Вызываем родительский метод
	super._spawn_donut(world_pos)
	
	# Применяем пониженное трение к последнему созданному пончику
	if active_donuts.size() > 0:
		var last_donut = active_donuts[-1]
		if is_instance_valid(last_donut):
			# Устанавливаем пониженное трение и уменьшенный отскок
			last_donut.physics_material_override = PhysicsMaterial.new()
			last_donut.physics_material_override.friction = 0.7  # Увеличиваем трение
			last_donut.physics_material_override.bounce = 0.1    # Сильно уменьшаем отскок
			
			# Добавляем затухание для быстрого успокоения
			last_donut.linear_damp = 2.0  # Затухание линейной скорости
			last_donut.angular_damp = 3.0  # Затухание угловой скорости
	

func _process(_delta: float) -> void:
	"""Обновляем систему качки"""
	# Вызываем родительский метод
	super._process(_delta)
	
	# Обновляем систему качки
	_update_shake_system(_delta)
	
	# Обновляем скорость каретки в зависимости от наклона
	_update_cart_speed()
	
	# Отладочная информация (можно убрать в релизе)
	_debug_donut_positions()
	
	# Проверяем ввод для возврата в меню после победы
	if victory_manager and victory_manager.check_victory_input():
		return

# Функция _check_victory_input() удалена - теперь используется victory_manager.check_victory_input()

# Функции песка удалены

func _update_shake_system(delta: float) -> void:
	"""Обновляет систему качки"""
	shake_timer += delta
	
	# Вычисляем синусоидальный целевой угол
	target_tilt = sin(shake_timer * 2.0 * PI / shake_period) * shake_amplitude
	
	# Отслеживаем знак предыдущего угла
	var previous_angle = current_tilt
	var current_angle = target_tilt
	
	# Проверяем пересечение нуля (смена знака)
	if (previous_angle > 0 and current_angle <= 0) or (previous_angle < 0 and current_angle >= 0):
		if not is_in_calm:  # Входим в состояние спокойствия только если не были в нем
			is_in_calm = true
			calm_timer = 0.0
			calm_duration = randf_range(0.7, 1.0)  # Случайная длительность 0.7-1.0 секунды
	
	# Если в состоянии спокойствия
	if is_in_calm:
		target_tilt = 0.0  # Устанавливаем целевой наклон в ноль
		calm_timer += delta
		
		# Выходим из состояния спокойствия
		if calm_timer >= calm_duration:
			is_in_calm = false
			calm_timer = 0.0
	
	# Вычисляем скорость изменения угла
	tilt_velocity = (target_tilt - previous_tilt) / delta if delta > 0 else 0.0
	
	# Интерполируем текущий наклон к целевому
	previous_tilt = current_tilt
	current_tilt = lerp(current_tilt, target_tilt, tilt_speed * delta)
	
	# Применяем наклон к камере и всей сцене
	_apply_camera_tilt(current_tilt)
	
	# Отладочная информация каждые 2 секунды
	if int(shake_timer) % 2 == 0 and shake_timer - int(shake_timer) < delta:
		var calm_status = " (СПОКОЙСТВИЕ)" if is_in_calm else ""
		var cam_angle = cam.rotation_degrees if cam else 0.0
		var cart_angle = cart.rotation_degrees if cart else 0.0
		print("Качка работает! Угол: ", current_tilt, " Камера: ", cam_angle, " Каретка: ", cart_angle, " Время: ", shake_timer, calm_status)

func _calculate_shake_angle() -> float:
	"""Вычисляет текущий угол наклона на основе синуса"""
	var time_factor = shake_timer / shake_period
	var sine_value = sin(time_factor * 2.0 * PI + shake_phase)
	return sine_value * shake_amplitude

func _apply_camera_tilt(angle: float) -> void:
	"""Применяет наклон к камере, каретке и всей сцене (палубе)"""
	if cam:
		cam.rotation_degrees = angle
	else:
		print("ОШИБКА: Камера не найдена!")
	
	# Поворачиваем каретку синхронно с камерой
	if cart:
		cart.rotation_degrees = angle
	else:
		print("ОШИБКА: Каретка не найдена!")
	
	# Наклоняем всю сцену, включая башню пончиков
	_apply_scene_tilt(angle)

func _apply_scene_tilt(angle: float) -> void:
	"""Наклоняет всю сцену, включая башню пончиков"""
	# НЕ наклоняем падающие пончики - только осевшие
	# Падающие пончики должны падать естественно под действием гравитации
	
	# Система песка удалена
	
	# Наклоняем фон (только визуально)
	var background = get_node("Background")
	if background:
		background.rotation_degrees = angle * 0.2  # Очень слабый наклон фона
	
	# НЕ наклоняем стены и землю - они должны оставаться физически стабильными
	# чтобы пончики могли правильно на них падать и стабилизироваться
	
	# Наклоняем UI элементы (очень слабо)
	var ui_container = get_node("UI/UIRoot")
	if ui_container:
		ui_container.rotation_degrees = angle * 0.1  # Очень слабый наклон UI
	
	# Применяем эффект качки к осевшим пончикам
	_apply_donut_sway(angle)
	
	# Добавляем визуальные эффекты качки
	_create_sway_visual_effects(angle)

func _apply_donut_sway(angle: float) -> void:
	"""Применяет эффект качки к осевшим пончикам"""
	# Проходим по всем активным пончикам
	for donut in active_donuts:
		if not is_instance_valid(donut):
			continue
		
		# Проверяем, что пончик осел (settled)
		if donut.sleeping and donut.freeze:
			# Вычисляем силу качки в зависимости от угла наклона
			var sway_force = _calculate_sway_force(angle, donut)
			
			# Применяем силу к пончику
			if sway_force.length() > 0.1:  # Минимальный порог для применения силы
				# Временно размораживаем пончик для применения силы
				var was_frozen = donut.freeze
				donut.freeze = false
				
				# Применяем силу
				donut.apply_central_force(sway_force)
				
				# Добавляем небольшое затухание для стабилизации
				donut.linear_damp = 3.0
				donut.angular_damp = 4.0
				
				# Планируем повторную заморозку через небольшую задержку
				if was_frozen:
					_schedule_donut_refreeze(donut)

func _calculate_sway_force(angle: float, donut: RigidBody2D) -> Vector2:
	"""Вычисляет силу качки для конкретного пончика"""
	# Преобразуем угол в радианы
	var angle_rad = deg_to_rad(angle)
	
	# Базовая сила качки (горизонтальная составляющая)
	var base_force = 80.0  # Увеличена базовая сила для более заметного эффекта
	
	# Модификатор в зависимости от высоты пончика (выше = сильнее качает)
	var height_factor = 1.0
	if cam:
		var relative_height = (donut.global_position.y - cam.global_position.y) / VIRT_H
		height_factor = 1.0 + relative_height * 0.8  # До 80% увеличения силы для верхних пончиков
	
	# Учитываем скорость изменения угла для более реалистичного поведения
	var velocity_factor = 1.0 + abs(tilt_velocity) * 0.1  # Увеличиваем силу при быстрых изменениях
	
	# Вычисляем горизонтальную силу (основная составляющая качки)
	var horizontal_force = sin(angle_rad) * base_force * height_factor * velocity_factor
	
	# Добавляем силу от скорости изменения угла (инерция)
	var inertia_force = tilt_velocity * 20.0 * height_factor
	
	# Комбинируем силы
	var total_horizontal = horizontal_force + inertia_force
	
	# Добавляем небольшую вертикальную составляющую для реалистичности
	var vertical_force = cos(angle_rad) * base_force * 0.15 * height_factor * velocity_factor
	
	return Vector2(total_horizontal, vertical_force)

func _schedule_donut_refreeze(donut: RigidBody2D) -> void:
	"""Планирует повторную заморозку пончика через небольшую задержку"""
	if not is_instance_valid(donut):
		return
	
	# Создаем таймер для задержки
	var refreeze_timer = Timer.new()
	refreeze_timer.wait_time = 0.1  # 0.1 секунды задержки
	refreeze_timer.one_shot = true
	refreeze_timer.timeout.connect(_refreeze_donut.bind(donut))
	
	# Сначала добавляем таймер в дерево сцены, затем запускаем
	donut.add_child(refreeze_timer)
	refreeze_timer.start()

func _refreeze_donut(donut: RigidBody2D) -> void:
	"""Повторно замораживает пончик если он все еще спит"""
	if is_instance_valid(donut) and donut.sleeping:
		donut.freeze = true
		# Восстанавливаем оригинальные значения затухания
		donut.linear_damp = 2.0
		donut.angular_damp = 3.0

func _create_sway_visual_effects(angle: float) -> void:
	"""Создает визуальные эффекты для качки"""
	# Создаем эффекты только при сильной качке
	if abs(angle) < 2.0:
		return
	
	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time - last_sway_time < 0.1:  # Ограничиваем частоту создания эффектов
		return
	
	last_sway_time = current_time
	
	# Создаем частицы для каждого осевшего пончика
	for donut in active_donuts:
		if not is_instance_valid(donut):
			continue
		
		if donut.sleeping and donut.freeze:
			_create_donut_sway_particles(donut, angle)

func _create_donut_sway_particles(donut: RigidBody2D, angle: float) -> void:
	"""Создает частицы качки для конкретного пончика"""
	# Создаем систему частиц
	var particles = GPUParticles2D.new()
	particles.name = "SwayParticles"
	particles.position = donut.global_position
	particles.z_index = 1
	
	# Настраиваем материал частиц
	var particle_material = ParticleProcessMaterial.new()
	particle_material.direction = Vector3(sin(deg_to_rad(angle)), 0, 0)  # Направление по углу качки
	particle_material.initial_velocity_min = 20.0
	particle_material.initial_velocity_max = 40.0
	particle_material.gravity = Vector3(0, 50, 0)
	particle_material.scale_min = 0.3
	particle_material.scale_max = 0.8
	particle_material.color = Color(1.0, 0.8, 0.2, 0.6)  # Золотистый цвет
	particle_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	particle_material.emission_sphere_radius = 10.0
	
	particles.process_material = particle_material
	particles.amount = 5
	particles.lifetime = 0.5
	particles.emitting = true
	
	add_child(particles)
	sway_particles.append(particles)
	
	# Удаляем частицы через время
	var cleanup_timer = Timer.new()
	cleanup_timer.wait_time = 1.0
	cleanup_timer.one_shot = true
	cleanup_timer.timeout.connect(_cleanup_sway_particles.bind(particles))
	
	# Сначала добавляем таймер в дерево сцены, затем запускаем
	particles.add_child(cleanup_timer)
	cleanup_timer.start()

func _cleanup_sway_particles(particles: GPUParticles2D) -> void:
	"""Очищает частицы качки"""
	if is_instance_valid(particles):
		sway_particles.erase(particles)
		particles.queue_free()

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
	spawner.speed = original_cart_speed * speed_modifier

func _debug_donut_positions() -> void:
	"""Отладочная функция для отслеживания позиций пончиков"""
	if not OS.is_debug_build():
		return  # Только в debug режиме
	
	var threshold: float = cam.position.y + VIRT_H * 2.0 if cam != null else VIRT_H * 2.0
	
	# Отладочная информация о качке (только каждые 3 секунды)
	if int(shake_timer) % 3 == 0 and shake_timer - int(shake_timer) < 0.1:
		var cam_angle = cam.rotation_degrees if cam else 0.0
		print("Качка - Угол: ", cam_angle, " Время: ", shake_timer)
	
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
	
	# Сначала добавляем таймер в дерево сцены, затем запускаем
	combo_particles.add_child(cleanup_timer)
	cleanup_timer.start()

func _cleanup_combo_effect(effect: GPUParticles2D) -> void:
	"""Очищает эффект комбо"""
	if is_instance_valid(effect):
		effect.queue_free()

# Функции песка удалены

# Все функции песка удалены для упрощения 6-го уровня

func _recycle_donut(d: RigidBody2D) -> void:
	"""Переопределяем переработку пончика"""
	# Вызываем родительский метод
	super._recycle_donut(d)

func _cleanup_fallen() -> void:
	"""Переопределяем очистку упавших пончиков"""
	# Система песка удалена
	
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
	
	# Очищаем частицы качки
	_cleanup_all_sway_particles()
	
	# Вызываем родительский метод
	super._cleanup_fallen()

func _cleanup_all_sway_particles() -> void:
	"""Очищает все частицы качки"""
	for particles in sway_particles:
		if is_instance_valid(particles):
			particles.queue_free()
	sway_particles.clear()

func _show_win_panel() -> void:
	"""Переопределяем панель победы для ФИНАЛЬНОГО уровня 6"""
	print("Game_level_6: _show_win_panel() вызвана, счет: ", score)
	# Показываем специальное поздравление с прохождением игры
	if victory_manager:
		print("Game_level_6: VictoryManager найден, показываем поздравление")
		victory_manager.show_victory_message(score)
	else:
		print("Game_level_6: ОШИБКА - VictoryManager не найден!")

func _open_win_panel() -> void:
	"""Переопределяем открытие панели победы для 6-го уровня"""
	print("Game_level_6: _open_win_panel() вызвана, счет: ", score)
	# Показываем специальное поздравление с прохождением игры
	if victory_manager:
		print("Game_level_6: VictoryManager найден, показываем поздравление")
		victory_manager.show_victory_message(score)
	else:
		print("Game_level_6: ОШИБКА - VictoryManager не найден!")

# Все функции поздравления перенесены в VictoryManager

func _restart_current_level() -> void:
	"""Переопределяем перезапуск уровня для 6-го уровня"""
	# Скрываем панель Game Over
	_hide_game_over()
	
	# Сбрасываем состояние игры
	_reset_game()
	
	# Перезапускаем уровень 6
	get_tree().change_scene_to_file("res://scenes/Game_level_6.tscn")
