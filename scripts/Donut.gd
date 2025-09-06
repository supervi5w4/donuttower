extends RigidBody2D
class_name Donut
## GDScript 2.0 (Godot 4.4.1)
## Логика «пончика»:
## - Следит за "успокоением": низкая линейная и угловая скорость в течение N секунд
## - После успокоения замораживает тело (freeze_mode = STATIC) и шлёт сигнал settled
## - Если уходит ниже порога bottom_y_limit — шлёт сигнал missed (единожды)

signal settled
signal missed

# Словарь с текстурами пончиков
const DONUT_TEXTURES = {
	"pink": preload("res://assets/donuts/donut_pink.png"),
	"chocolate": preload("res://assets/donuts/donut_chocolate.png"),
	"blue": preload("res://assets/donuts/donut_blue.png"),
	"rainbow": preload("res://assets/donuts/donut_rainbow.png")
}

@export var bottom_y_limit: float = 10000.0

# Порог "успокоения"
@export var settle_linear_speed_threshold: float = 8.0     # пикс/с
@export var settle_angular_speed_threshold: float = 0.6    # рад/с
@export var settle_time_required: float = 0.80             # сек (сколько держаться ниже порогов)

var _settle_timer: float = 0.0
var _settled_emitted: bool = false
var _missed_emitted: bool = false

func reset_state() -> void:
	_settle_timer = 0.0
	_settled_emitted = false
	_missed_emitted = false
	# Сначала замораживаем тело для сброса состояния
	freeze = true
	freeze_mode = RigidBody2D.FREEZE_MODE_STATIC
	# Сбрасываем физические свойства
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	scale = Vector2.ONE  # Сброс масштаба к оригинальному размеру
	sleeping = false
	# Теперь размораживаем тело, чтобы оно стало динамическим
	freeze = false
	# Устанавливаем стиль по умолчанию
	set_style("pink")

func set_style(style: String) -> void:
	# Проверяем, что стиль существует в словаре
	if not DONUT_TEXTURES.has(style):
		push_error("Donut style '" + style + "' not found in DONUT_TEXTURES")
		return
	
	# Получаем спрайт и устанавливаем новую текстуру
	var sprite = $Sprite2D
	sprite.texture = DONUT_TEXTURES[style]
	
	# Устанавливаем фиксированный радиус коллизии для всех пончиков
	# Это предотвращает пробелы между пончиками разных размеров
	var collision_shape = $CollisionShape2D
	if collision_shape.shape is CircleShape2D:
		var circle_shape = collision_shape.shape as CircleShape2D
		circle_shape.radius = 35.0  # Фиксированный радиус для всех пончиков

func get_radius() -> float:
	var cs := $CollisionShape2D
	if cs and cs.shape is CircleShape2D:
		return (cs.shape as CircleShape2D).radius
	return 0.0

func get_style() -> String:
	var sprite = $Sprite2D
	if sprite and sprite.texture:
		# Ищем стиль по текстуре
		for style in DONUT_TEXTURES.keys():
			if DONUT_TEXTURES[style] == sprite.texture:
				return style
	return "pink"  # стиль по умолчанию

func _ready() -> void:
	# На старте убеждаемся, что тело активно
	freeze_mode = RigidBody2D.FREEZE_MODE_STATIC
	freeze = false
	sleeping = false
	_settle_reset()

func _physics_process(delta: float) -> void:
	# Отладочная информация каждые 60 кадров (примерно раз в секунду)
	if Engine.get_process_frames() % 60 == 0:
		pass
	_check_missed()
	_check_settle(delta)

func _check_missed() -> void:
	if _missed_emitted:
		return
	if global_position.y > bottom_y_limit:
		_missed_emitted = true
		emit_signal("missed")

func _check_settle(delta: float) -> void:
	if _settled_emitted:
		return
	var lin_spd: float = linear_velocity.length()
	var ang_spd: float = absf(angular_velocity)

	var below_linear: bool = lin_spd <= settle_linear_speed_threshold
	var below_angular: bool = ang_spd <= settle_angular_speed_threshold

	if below_linear and below_angular:
		_settle_timer += delta
		if _settle_timer >= settle_time_required:
			# Заморозим как статик, чтобы башня не "ползла"
			freeze_mode = RigidBody2D.FREEZE_MODE_STATIC
			freeze = true
			sleeping = true
			_settled_emitted = true
			emit_signal("settled")
	else:
		_settle_reset()

func _settle_reset() -> void:
	_settle_timer = 0.0
