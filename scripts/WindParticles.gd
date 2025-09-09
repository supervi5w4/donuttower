extends Node2D

# Система частиц для визуализации ветра
@onready var wind_particles: CPUParticles2D

# Настройки частиц
const PARTICLE_COUNT := 450
const PARTICLE_SPEED := 900.0
const PARTICLE_LIFETIME := 4.0

# Цвета частиц в зависимости от силы ветра (более яркие и заметные)
const WEAK_WIND_COLOR := Color(0.9, 0.95, 1.0, 0.9)     # Яркий светло-голубой
const MODERATE_WIND_COLOR := Color(0.7, 0.9, 1.0, 0.95)  # Яркий голубой
const STRONG_WIND_COLOR := Color(0.5, 0.7, 1.0, 1.0)     # Яркий синий
const STORM_WIND_COLOR := Color(0.3, 0.5, 0.9, 1.0)      # Яркий темно-синий

func _ready() -> void:
	_setup_particles()

func _setup_particles() -> void:
	"""Настраивает систему частиц"""
	wind_particles = CPUParticles2D.new()
	add_child(wind_particles)
	
	# Основные настройки
	wind_particles.emitting = false
	wind_particles.amount = PARTICLE_COUNT
	wind_particles.lifetime = PARTICLE_LIFETIME
	
	# Настройки эмиссии
	wind_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	wind_particles.emission_rect_extents = Vector2(360, 50)  # Ширина экрана, высота 50px
	
	# Настройки частиц
	wind_particles.direction = Vector2(1, 0)  # По умолчанию вправо
	wind_particles.spread = 15.0
	wind_particles.initial_velocity_min = PARTICLE_SPEED * 0.5
	wind_particles.initial_velocity_max = PARTICLE_SPEED * 1.5
	
	# Размер частиц (больше и заметнее)
	wind_particles.scale_amount_min = 1.0
	wind_particles.scale_amount_max = 2.5
	
	# Цвет
	wind_particles.color = WEAK_WIND_COLOR
	
	# Позиция - верх экрана
	wind_particles.position = Vector2(360, 100)  # Центр экрана по X, 100px от верха

func update_wind(wind_force: float) -> void:
	"""Обновляет визуализацию ветра"""
	if not wind_particles:
		return
	
	# Определяем направление и силу
	var direction = 1.0 if wind_force >= 0 else -1.0
	var abs_force = abs(wind_force)
	
	# Обновляем направление частиц
	wind_particles.direction = Vector2(direction, 0)
	
	# Обновляем скорость частиц в зависимости от силы ветра
	var speed_multiplier = abs_force / 200.0  # Нормализуем от 0 до 1 (теперь максимум 200)
	wind_particles.initial_velocity_min = PARTICLE_SPEED * 0.3 * speed_multiplier
	wind_particles.initial_velocity_max = PARTICLE_SPEED * 1.0 * speed_multiplier
	
	# Обновляем цвет в зависимости от силы ветра (возвращаем к нормальным порогам)
	var wind_color: Color
	if abs_force < 40:
		wind_color = WEAK_WIND_COLOR
	elif abs_force < 100:
		wind_color = MODERATE_WIND_COLOR
	elif abs_force < 160:
		wind_color = STRONG_WIND_COLOR
	else:
		wind_color = STORM_WIND_COLOR
	
	wind_particles.color = wind_color
	
	# Обновляем количество частиц в зависимости от силы ветра (увеличиваем базовое количество)
	wind_particles.amount = int(PARTICLE_COUNT * (0.5 + 0.5 * speed_multiplier))
	
	# Обновляем время жизни частиц
	wind_particles.lifetime = PARTICLE_LIFETIME * (0.5 + 0.5 * speed_multiplier)
	
	# Запускаем или останавливаем эмиссию
	if abs_force > 5:  # Минимальная сила для показа частиц
		wind_particles.emitting = true
	else:
		wind_particles.emitting = false
	

func stop_wind() -> void:
	"""Останавливает визуализацию ветра"""
	if wind_particles:
		wind_particles.emitting = false
