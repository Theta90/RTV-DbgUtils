extends Node
func _ready() -> void:
	print("Hello world!")
	overrideScript("res://mods/HelloWorld/Scripts/Character.gd")
	queue_free()

func overrideScript(overrideScriptPath: String):
	var script: Script = load(overrideScriptPath)
	script.reload()
	var parentScript = script.get_base_script();
	script.take_over_path(parentScript.resource_path)