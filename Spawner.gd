extends Node2D
class_name Spawner
## Каретка, движущаяся между move_left_x и move_right_x на высоте move_y.
## Возвращает позицию спавна через get_spawn_position().

@export var move_left_x: float = 60.0
@export var move_right_x: float = 660.0
@export var move_y: float = 200.0
@export var speed: float = 180.0 # пикселей/сек

var _dir: int = 1 # 1 вправо, -1 влево

func _ready() -> void:
	# Стартуем слева
	position = Vector2(move_left_x, move_y)
	_dir = 1

func _process(delta: float) -> void:
	# Равномерное пинг‑понг‑движение
	var next_x: float = position.x + float(_dir) * speed * delta

	if next_x > move_right_x:
		next_x = move_right_x
		_dir = -1
	elif next_x < move_left_x:
		next_x = move_left_x
		_dir = 1

	position.x = next_x
	position.y = move_y

func get_spawn_position() -> Vector2:
	# Позиция дропа пончика
	return global_position
