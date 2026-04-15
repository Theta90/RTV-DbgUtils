extends Node

const CustomLoggerUI := preload("res://mods/DbgUtils/Logger/CustomLoggerUI.tscn")
const DbgSettings := preload("res://mods/DbgUtils/DbgSettings.gd")
const Dbg := preload("res://mods/DbgUtils/Dbg.gd")

var dbg := Dbg.new("DbgUtils", self , null)

var _customLoggerUI := CustomLoggerUI.instantiate()
var _logger: CustomLogger
var _dbgInstances: Dictionary[String, Dbg] = {}

func _ready() -> void:
	_logger = CustomLogger.new(self )
	dbg = Dbg.new("DbgUtils", self , null)
	_dbgInstances["DbgUtils"] = dbg

	add_child(_customLoggerUI)
	
	dbg.debug("DbgUtils initialized, [wave][rainbow]have a nice day![/rainbow][/wave]")

## Attach a new Dbg instance for the given modId and modEntry.
## Returns the new Dbg instance, or null if an instance with the modId already exists.
func attach(modId: String, modEntry: Object, dbgSettings: DbgSettings = null) -> Variant:
	if (modId in _dbgInstances):
		dbg.error("A DbgInstance with the modId '%s' is already attached -- attach() failed." % modId)
		return null

	var newDbg = Dbg.new(modId, modEntry, dbgSettings)
	newDbg._dbgUtils = self
	_dbgInstances[modId] = newDbg

	dbg.debug("Attached new DbgInstance with modId '%s'" % modId)

	return newDbg

## Detach the Dbg instance with the given modId. 
## Returns true if successful, false if no instance with the modId was found.
func detach(modId: String) -> bool:
	if (modId not in _dbgInstances):
		dbg.error("No DbgInstance with the modId '%s' -- detach() failed." % modId)
		return false

	_dbgInstances.erase(modId)

	dbg.debug("Detached DbgInstance with modId '%s'" % modId)

	return true

## Get the current text in the custom logger's display box.
func get_current_log() -> String:
	return _customLoggerUI.DisplayTextBox.text

func _notification(what: int) -> void:
	if (what == NOTIFICATION_PREDELETE):
		for dbgInstance in _dbgInstances.values():
			dbgInstance.settings = null
		_dbgInstances.clear()

func _input(event: InputEvent) -> void:
	if (event is InputEventKey and event.is_pressed() and event.keycode == Key.KEY_F5):
		dbg.debug("This is a debug message")
		dbg.info("This is an info message")
		dbg.warning("This is a warning message")
		dbg.error("This is an error message")
		dbg.debug("DbgUtils also supports [wave][rainbow]rich text![/rainbow][/wave]")

#region CustomLogger

class CustomLogger extends Logger:
		var _dbgUtils: Node = null

		func _init(dbgUtils: Node) -> void:
			OS.add_logger(self )
			_dbgUtils = dbgUtils
		
		func _log_message(message: String, _error: bool) -> void:
			if (!_dbgUtils or !_dbgUtils.is_node_ready()):
				return

			message = message.replace("[DEBUG]", "[color=medium_purple][b][DEBUG][/b][/color]")
			message = message.replace("[INFO]", "[color=deep_sky_blue][b][INFO][/b][/color]")
			message = message.replace("[WARNING]", "[color=yellow][b][WARNING][/b][/color]")
			message = message.replace("[ERROR]", "[color=red][b][ERROR][/b][/color]")

			_dbgUtils._customLoggerUI._AppendText.call_deferred("%s" % message)

		func _log_error(
				function: String,
				file: String,
				line: int,
				code: String,
				rationale: String,
				_editor_notify: bool,
				error_type: int,
				script_backtraces: Array[ScriptBacktrace]
		) -> void:
			if (!_dbgUtils or !_dbgUtils.is_node_ready()):
				return

			var prefix: String = ""

			# The column at which to print the trace. Should match the length of the
			# unformatted text above it.
			var trace_indent := 0

			match error_type:
				ERROR_TYPE_ERROR:
					prefix = "[color=#f54][b]ERROR:[/b]"
					trace_indent = 6
				ERROR_TYPE_WARNING:
					prefix = "[color=#fd4][b]WARNING:[/b]"
					trace_indent = 8
				ERROR_TYPE_SCRIPT:
					prefix = "[color=#f4f][b]SCRIPT ERROR:[/b]"
					trace_indent = 13
				ERROR_TYPE_SHADER:
					prefix = "[color=#4bf][b]SHADER ERROR:[/b]"
					trace_indent = 13
				
			var trace: String = "%*s %s (%s:%s)" % [trace_indent, "at:", function, file, line]
			var script_backtraces_text: String = ""

			for backtrace in script_backtraces:
				script_backtraces_text += backtrace.format(trace_indent - 3) + "\n"

			_dbgUtils._customLoggerUI._AppendText.call_deferred(
				"[code]%s %s %s[/color]\n[color=#999]%s[/color]\n[color=#999]%s[/color][code]" % [
					prefix,
					code,
					rationale,
					trace,
					script_backtraces_text,
				]
			)

		func _notification(what: int) -> void:
			if (what == NOTIFICATION_PREDELETE):
				OS.remove_logger(self )

#endregion CustomLogger
