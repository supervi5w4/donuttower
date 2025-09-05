extends Node2D
class_name PreviewDonut
## Превью-пончик, который ездит вместе со Spawner (родителем).
## Это НЕ физическое тело. Только визуальная мишень для прицеливания.

@onready var sprite: Sprite2D = get_node("Sprite2D")

@export var idle_alpha: float = 0.85       # лёгкая прозрачность превью
@export var press_scale: float = 0.94      # масштаб при "щелчке"
@export var press_in_time: float = 0.08    # сек сжатия
@export var press_out_time: float = 0.10   # сек разжатия

func _ready() -> void:
	if sprite != null:
		sprite.modulate = Color(1.0, 1.0, 1.0, idle_alpha)
		sprite.z_index = 10  # поверх линии указателя/фона

func flash_drop() -> void:
	if sprite == null:
		return
	var tw: Tween = create_tween()
	tw.tween_property(sprite, "scale", Vector2(press_scale, press_scale), press_in_time)
	tw.tween_property(sprite, "scale", Vector2(1.0, 1.0), press_out_time)
