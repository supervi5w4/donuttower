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
		# Убеждаемся, что масштаб установлен правильно
		sprite.scale = Vector2(0.16, 0.16)

func flash_drop() -> void:
	if sprite == null:
		return
	
	# Получаем оригинальный масштаб из сцены (0.16, 0.16)
	var original_scale: Vector2 = Vector2(0.16, 0.16)
	var pressed_scale: Vector2 = original_scale * press_scale
	
	var tw: Tween = create_tween()
	tw.tween_property(sprite, "scale", pressed_scale, press_in_time)
	tw.tween_property(sprite, "scale", original_scale, press_out_time)

func reset_scale() -> void:
	"""Сбрасывает масштаб превью пончика к оригинальному размеру"""
	if sprite != null:
		sprite.scale = Vector2(0.16, 0.16)

func set_texture(tex: Texture2D) -> void:
	"""Устанавливает текстуру превью пончика напрямую"""
	if sprite == null:
		return
	
	# Устанавливаем новую текстуру
	sprite.texture = tex

func set_texture_by_style(style: String) -> void:
	"""Устанавливает текстуру превью пончика по стилю"""
	if sprite == null:
		return
	
	# Проверяем, что стиль существует в словаре Donut.DONUT_TEXTURES
	if not Donut.DONUT_TEXTURES.has(style):
		push_error("PreviewDonut: style '" + style + "' not found in Donut.DONUT_TEXTURES")
		return
	
	# Устанавливаем новую текстуру
	sprite.texture = Donut.DONUT_TEXTURES[style]
