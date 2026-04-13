extends Object
class_name DbgUtils

enum LogLevel {
	DEBUG = 0,
	INFO = 1,
	WARNING = 2,
	ERROR = 3,
}

var _modId: String
var _scriptPath: String

var _settings = {
	# Minimum log level to output. Messages with a lower level will be ignored.
	"level" = LogLevel.DEBUG,

	# Include the log level in the message (e.g. [DEBUG], [INFO], etc.)
	"includeLevel" = true,

	# Convert the timestamp to UTC before formatting it. If false, local time will be used.
	"useUTC" = false,

	# Include the time for when the log message was generated (e.g. [12:34:56])
	"includeTime" = true,

	# Include the date for when the log message was generated (e.g. [2024-01-01])
	"includeDate" = false,

	# Include the mod ID in the log message (e.g. [MyMod])
	"includeModId" = true,

	# Include the file source for the current stack frame
	"includeFileSource" = true,

	# Include the line number for the current stack frame.
	# Note that only debug builds will have line number information available, 
	#	so this will be ignored in release builds.
	"includeLine" = true,

	# The maximum stack depth to include in the log message. 0 for unlimited.
	"maxDepth" = 0,

	# Colors for each log level
	"colors" = {
		LogLevel.DEBUG: Color.WHITE,
		LogLevel.INFO: Color.AQUA,
		LogLevel.WARNING: Color.YELLOW,
		LogLevel.ERROR: Color.RED,
	},
}

var _printMethods = {
	LogLevel.DEBUG: print,
	LogLevel.INFO: print,
	LogLevel.WARNING: push_warning,
	LogLevel.ERROR: push_error,
}

func _init(modId: String = "", modEntry: Object = null, settings: Dictionary = {}) -> void:
	if (modId == "" and modEntry == null):
		return

	_modId = modId

	if (modEntry != null):
		var script: Script = modEntry.get_script()
		if (script != null):
			_scriptPath = script.resource_path

	if (modEntry == null or _scriptPath == null or _scriptPath == ""):
		_scriptPath = modId

	apply_settings(settings)

func apply_settings(newSettings: Dictionary) -> void:
	for key in newSettings.keys():
		if (key in _settings):
			_settings[key] = newSettings[key]

func log(
	msg: String,
	stack = get_stack(),
	level: LogLevel = LogLevel.DEBUG
) -> void:
	_send_message(msg, stack, level)

func debug(msg: String, stack = get_stack()) -> void:
	_send_message(msg, stack, LogLevel.DEBUG)

func info(msg: String, stack = get_stack()) -> void:
	_send_message(msg, stack, LogLevel.INFO)

func warning(msg: String, stack = get_stack()) -> void:
	_send_message(msg, stack, LogLevel.WARNING)

func error(msg: String, stack = get_stack()) -> void:
	_send_message(msg, stack, LogLevel.ERROR)

func _send_message(
	msg: String,
	stack: Array[Dictionary],
	level: LogLevel
) -> void:
	if (!_is_at_least_level(level)):
		return

	print("_send_message called with msg: %s, level: %s" % [msg, _get_level_name(level)])
	
	var timeStr = "%s" % [Time.get_date_string_from_system(_settings.useUTC)] if (_settings.includeDate) else ""
	var dateStr = "%s" % [Time.get_time_string_from_system(_settings.useUTC)] if (_settings.includeTime) else ""
	var whenStr = "%s" % [dateStr] if (dateStr != "") else timeStr
	whenStr += "-%s" % [timeStr] if (timeStr != "" and whenStr != "") else timeStr if (timeStr != "") else ""

	var levelName = _get_level_name(level) if (_settings.includeLevel) else ""
	var modIdStr = _modId if (_settings.includeModId) else ""
	var stackStr: String = ""
	
	if (_settings.includeFileSource or _settings.includeLine):
		if (stack.size() > 0):
			stackStr = _format_stack(stack)

	var formattedmsg = "[color=%s]%s%s%s%s:[/color] %s" % [
		_get_color_for_level(level),
		"[%s]" % levelName if (levelName != "") else "",
		"[%s]" % whenStr if (whenStr != "") else "",
		"[%s]" % modIdStr if (modIdStr != "") else "",
		"[%s]" % stackStr if (stackStr != "") else "",
		msg
	]
	
	_printMethods[level].call(formattedmsg)
	
func _format_stack(stack: Array[Dictionary]) -> String:
	print("Original stack: %s" % stack)

	var prevLine := ""
	var curDepth := 0
	var maxDepth: int = _settings.maxDepth
	var workingStack = stack.slice(1) if (stack[0]["function"] == "_send_message") else stack

	if (_settings.maxDepth > 0):
		if (workingStack.size() > _settings.maxDepth):
			workingStack = stack.slice(_settings.maxDepth)

	for frame in workingStack: # remove last frame (log fn)
		var fileName: String = frame["source"].get_file()
		var fnName: String = frame["function"]
		var newStr := "%s(%s)" % [fileName, fnName] if (_settings.includeFileSource) else fnName

		if ("line" in frame and _settings.includeLine):
			newStr += ":%d" % [frame["line"]]

		if (prevLine != ""):
			newStr = "%s <- %s" % [prevLine, newStr]

		prevLine = newStr
		curDepth += 1

		if (maxDepth != 0 and curDepth >= maxDepth):
			break
	
	return prevLine

func _is_at_least_level(level: LogLevel) -> bool:
	return level >= _settings.level

func _get_color_for_level(level: LogLevel) -> Color:
	return _settings.colors[level]

func _get_level_name(level: LogLevel) -> String:
	return LogLevel.keys()[level]