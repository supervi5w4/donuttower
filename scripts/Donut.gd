extends RigidBody2D
class_name Donut
## GDScript 2.0 (Godot 4.4.1)
## Логика «пончика»:
## - Следит за "успокоением": низкая линейная и угловая скорость в течение N секунд
## - После успокоения замораживает тело (freeze_mode = STATIC) и шлёт сигнал settled
## - Если уходит ниже порога bottom_y_limit — шлёт сигнал missed (единожды)

signal settled
signal missed

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
	freeze = false
	sleeping = false

func _ready() -> void:
	# На старте убеждаемся, что тело активно
	freeze = false
	sleeping = false
	_settle_reset()

func _physics_process(delta: float) -> void:
	_check_missed()
	_check_settle(delta)

func _check_missed() -> void:
	if _missed_emitted:
		return
	if global_position.y > bottom_y_limit:
		print("Donut missed! Y: ", global_position.y, " limit: ", bottom_y_limit)
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
			print("Donut settled! Y: ", global_position.y, " timer: ", _settle_timer)
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
