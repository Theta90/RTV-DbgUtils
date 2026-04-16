extends Object

var _modId: String = ""
var _scriptPath: String = ""

const DbgSettings = preload("res://mods/DbgUtils/DbgSettings.gd")

const _print_methods = {
	"DEBUG": print,
	"INFO": print,
	"WARNING": push_warning,
	"ERROR": push_error,
}

var settings := DbgSettings.new()

func _init(modId: String = "no modId", modEntry: Object = null, dbgSettings: DbgSettings = null) -> void:
	_modId = modId

	if (dbgSettings != null):
		apply_settings(dbgSettings)

	if (_modId == "no modId" and modEntry == null):
		push_warning("Dbg initialized without a modId or modEntry.")
		return

	if (modEntry != null):
		var script: Script = modEntry.get_script()
		if (script != null):
			_scriptPath = script.resource_path

	if (modEntry == null and (_scriptPath == null or _scriptPath == "")):
		_scriptPath = modId

func apply_settings(newSettings: DbgSettings) -> void:
	settings = newSettings

func clear_settings() -> void:
	apply_settings(load("res://mods/DbgUtils/DbgSettings.gd").new())

func log(
	msg: String,
	level: String = "DEBUG",
	stack = get_stack()
) -> void:
	level = level.to_upper()

	if (level not in ["DEBUG", "INFO", "WARNING", "ERROR"]):
		push_error("DbgUtils: Dbg.log() for %s tried to use an invalid log level '%s'. Defaulting to 'DEBUG'." % [_modId, level])
		level = "DEBUG"
	
	_send_message(msg, stack, level)

func debug(msg: String, stack = get_stack()) -> void:
	_send_message(msg, stack, "DEBUG")

func info(msg: String, stack = get_stack()) -> void:
	_send_message(msg, stack, "INFO")

func warning(msg: String, stack = get_stack()) -> void:
	_send_message(msg, stack, "WARNING")

func error(msg: String, stack = get_stack()) -> void:
	_send_message(msg, stack, "ERROR")

## Do not use this method directly!
## Instead, use log() with the appropriate log level, or one of the helper methods debug(), info(), warning(), or error().
func _send_message(
	msg: String,
	stack: Array[Dictionary],
	level: String
) -> void:
	if (!_is_at_least_level(level)):
		return

	var timeStr = "%s" % [Time.get_date_string_from_system(settings.useUTC)] if (settings.includeDate) else ""
	var dateStr = "%s" % [Time.get_time_string_from_system(settings.useUTC)] if (settings.includeTime) else ""
	var whenStr = "%s" % [dateStr] if (dateStr != "") else timeStr
	whenStr += "-%s" % [timeStr] if (timeStr != "" and whenStr != "") else timeStr if (timeStr != "") else ""

	var stackStr: String = ""

	if (stack.size() > 0):
		stackStr = _format_stack(stack)

	var formattedMsg = "%s%s%s%s: %s" % [
		"[%s]" % whenStr if (whenStr != "") else "",
		"[%s]" % _modId,
		"[%s]" % level,
		"[%s]" % stackStr if (stackStr != "") else "",
		msg
	]

	_print_methods[level].call(formattedMsg)
	
func _format_stack(stack: Array[Dictionary]) -> String:
	var prevLine := ""
	var curDepth := 0
	var maxDepth: int = settings.maxDepth

	for frame in stack:
		if (frame["source"] == get_script().resource_path):
			continue # skip frames from Dbg itself

		var fileName: String = frame["source"].get_file()
		var fnName: String = frame["function"]
		var newStr := "%s(%s)" % [fileName, fnName] if (settings.includeFileSource) else fnName

		if ("line" in frame and settings.includeLine):
			newStr += ":%d" % [frame["line"]]

		if (prevLine != ""):
			newStr = "%s <- %s" % [prevLine, newStr]

		prevLine = newStr
		curDepth += 1

		if (maxDepth != 0 and curDepth >= maxDepth):
			break
	
	return prevLine

func _is_at_least_level(level: String) -> bool:
	match level:
		"DEBUG":
			return settings.level == "DEBUG"
		"INFO":
			return settings.level != "WARNING" and settings.level != "ERROR"
		"WARNING":
			return settings.level != "ERROR"
		"ERROR":
			return true
	return false
