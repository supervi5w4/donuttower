extends Control

func _on_start_button_pressed():
	# Переход к игровой сцене
	get_tree().change_scene_to_file("res://scenes/Game.tscn")
