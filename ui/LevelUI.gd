extends Node
class_name LevelUI

var _level_label: Label
var _bar: ProgressBar
var _max: int = 50
var _color_scheme: LevelData.LevelColorScheme

func _ready() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	var root := MarginContainer.new()
	root.set_anchors_preset(Control.PRESET_TOP_WIDE)
	root.offset_left = 16
	root.offset_top = 60  # Опускаем ниже
	root.offset_right = -16
	root.offset_bottom = 120
	layer.add_child(root)

	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 8)
	root.add_child(vb)

	# Уровень
	_level_label = Label.new()
	_level_label.text = "Уровень: 1"
	_level_label.add_theme_font_size_override("font_size", 20)
	# Цвета будут установлены через set_color_scheme()
	_level_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	_level_label.add_theme_constant_override("shadow_offset_x", 1)
	_level_label.add_theme_constant_override("shadow_offset_y", 1)
	vb.add_child(_level_label)

	# Полоска прогресса
	_bar = ProgressBar.new()
	_bar.min_value = 0
	_bar.max_value = _max
	_bar.value = 0
	_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bar.custom_minimum_size.y = 20
	
	# Стилизация будет применена через set_color_scheme()
	vb.add_child(_bar)

func set_level_number(n: int) -> void:
	_level_label.text = "Уровень: %d" % n

func set_progress(score: int, max_score: int) -> void:
	_max = max_score
	_bar.max_value = max_score
	_bar.value = clamp(score, 0, max_score)

func set_color_scheme(color_scheme: LevelData.LevelColorScheme) -> void:
	"""Устанавливает цветовую схему для UI уровня"""
	_color_scheme = color_scheme
	_apply_color_scheme()

func _apply_color_scheme() -> void:
	"""Применяет текущую цветовую схему к элементам UI"""
	if not _color_scheme:
		return
	
	# Применяем цвета к заголовку уровня
	if _level_label:
		_level_label.add_theme_color_override("font_color", _color_scheme.primary_color)
	
	# Применяем стили к полоске прогресса
	if _bar:
		# Стиль фона полоски
		var style_box := StyleBoxFlat.new()
		style_box.bg_color = _color_scheme.background_color
		style_box.border_width_left = 2
		style_box.border_width_right = 2
		style_box.border_width_top = 2
		style_box.border_width_bottom = 2
		style_box.border_color = _color_scheme.secondary_color
		style_box.corner_radius_top_left = 10
		style_box.corner_radius_top_right = 10
		style_box.corner_radius_bottom_left = 10
		style_box.corner_radius_bottom_right = 10
		_bar.add_theme_stylebox_override("background", style_box)
		
		# Стиль заполнителя полоски
		var fill_style := StyleBoxFlat.new()
		fill_style.bg_color = _color_scheme.primary_color
		fill_style.corner_radius_top_left = 8
		fill_style.corner_radius_top_right = 8
		fill_style.corner_radius_bottom_left = 8
		fill_style.corner_radius_bottom_right = 8
		_bar.add_theme_stylebox_override("fill", fill_style)
