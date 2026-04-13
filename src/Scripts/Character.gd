extends "res://Scripts/Character.gd"

func _ready() -> void:
	print("Hello World!")

func _process(delta: float) -> void:
	gameData.weaponPosition = 1 if gameData.isRunning else 2 # sprint lowers weapon