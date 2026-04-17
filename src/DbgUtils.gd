extends Node

# Looking for help? See the _Tour() function near the middle for a demo of the mod's features

const CustomLoggerUI := preload("res://mods/DbgUtils/Logger/CustomLoggerUI.gd")
const LoggerMenu := preload("res://mods/DbgUtils/Logger/LoggerMenu.gd")
const DbgSettings := preload("res://mods/DbgUtils/DbgSettings.gd")
const Dbg := preload("res://mods/DbgUtils/Dbg.gd")
const ModConfig := preload("res://mods/DbgUtils/MCM/ModConfig.gd")

var dbg := Dbg.new("DbgUtils", self , null)

var _autoload = null
var _modConfig: ModConfig = null
var _customLoggerUI := load(CustomLoggerUI.ScenePath).instantiate() as CustomLoggerUI
var _logger: CustomLogger

var _isInMainMenu: bool = false
var _toggleDebugUIKeyPressed: bool = false

var _mouseIsForceConfined: bool = false # cannot be true while the below is true
var _mouseIsForceCaptured: bool = false # cannot be true while the above is true

## type MsgData = {
## 	raw: `String`,
## 	levelName: `String`,
## 	levelInt: `int`,
## 	levelPos: `Array[int, int]`,
##	formattedMsg: `String` | `null`,
##  errData?: {
##		function: `String`,
##		file: `String`,
##		line: `int`,
##		code: `String`,
##		rationale: `String`,
##		errorType: `int`,
##		errorName: `String`,
##		existingPrefix: `String`,
##		generatedPrefix: `String`,
##		trace: `String`,
##		backtrace: `String` # "[color=#999]%s[/color]" % [script_backtraces_text]
##	}
## }
var _logs: Array[Dictionary] = []

func _ready() -> void:
	var isFirstInstance: bool = false
	name = "DbgUtils"

	if (OS.is_debug_build()):
		_autoload = get_node_or_null("/root/DbgUtils") # testing in the editor
		if (_autoload == null):
			dbg.warning("DbgUtils autoload node not found in debug build. You can assign it manually in the editor under \"Globals\". " +
			"Proceeding without DebugUtils autoload, meaning the Dbg instance will be untethered.")
	else:
		_autoload = get_node_or_null("/root/!DbgUtils") # release build

	if (_autoload == null):
		isFirstInstance = true
		_autoload = self

	isFirstInstance = isFirstInstance or _autoload == self

	# If this is the first DbgUtils to initialize, set up the autoload and necessary nodes. 
	# Otherwise, get the existing instances from the autoload.
	if (isFirstInstance):
		_logger = CustomLogger.new(self )

		_modConfig = ModConfig.new()
		_modConfig.ConfigValueChanged.connect(_onConfigValueChanged)

		var root = get_node("/root")
		root.connect("child_entered_tree", _onRootChildrenChanged)
		root.connect("child_exiting_tree", _onRootChildrenChanged)

		add_child(_customLoggerUI)
		add_child(_modConfig)

		_customLoggerUI.CreateMenu(_modConfig)

		#var connectErr = _modConfig.connectionError
		#if (connectErr != Error.OK):
		#	dbg.error("DbgUtils failed to connect to MCM with the error: %s" % [error_string(connectErr)])
		#else:
		#	if (_modConfig.isFirstUse):
		#		var path = "%s/%s" % [_modConfig.FILE_PATH, _modConfig.FILE_NAME]
		#		dbg.info("Thanks for using DbgUtils! A config file has been created at %s. " % [path] +
		#			"These settings can be changed via MCM (if installed). Enjoy!!")

		dbg.info("DbgUtils initialized, [wave][rainbow]have a nice day![/rainbow][/wave]")
	else:
		dbg = _autoload.dbg
		_logger = _autoload._logger
		_modConfig = _autoload._modConfig
		_customLoggerUI = _autoload._customLoggerUI
		_modConfig = _autoload._modConfig

	get_tree().scene_changed.connect(_on_scene_changed)

	process_mode = Node.PROCESS_MODE_ALWAYS

	dbg.debug("%s is now attached to DbgUtils" % dbg._modId)

static func EscapeRegex(text: String) -> String:
	return (text
		.replace("\\", "\\\\")
		.replace(".", "\\.")
		.replace("+", "\\+")
		.replace("*", "\\*")
		.replace("?", "\\?")
		.replace("^", "\\^")
		.replace("$", "\\$")
		.replace("(", "\\(")
		.replace(")", "\\)")
		.replace("[", "\\[")
		.replace("]", "\\]")
		.replace("{", "\\{")
		.replace("}", "\\}")
		.replace("|", "\\|")
		.replace("-", "\\-")
		.replace("/", "\\/")
	)

func _AddLog(msgData: Dictionary):
	_logs.append(msgData)
	_customLoggerUI.AddLog(msgData)

	if (_logs.size() > 1000):
		const numLogsToRemove = 500
		_logs = _logs.slice(numLogsToRemove, _logs.size())
		dbg.warning("DbgUtils log count exceeded 1000. %s old logs have been cleared to prevent memory issues." % numLogsToRemove)

func _CaptureMouse():
	if (Input.mouse_mode == Input.MouseMode.MOUSE_MODE_CAPTURED):
		return
	
	Input.mouse_mode = Input.MouseMode.MOUSE_MODE_CAPTURED
	_mouseIsForceCaptured = true
	_mouseIsForceConfined = false

func _ConfineMouse():
	if (Input.mouse_mode == Input.MouseMode.MOUSE_MODE_CONFINED):
		return

	Input.mouse_mode = Input.MouseMode.MOUSE_MODE_CONFINED
	_mouseIsForceConfined = true
	_mouseIsForceCaptured = false

func _Tour():
	dbg.settings.includeTime = false
	dbg.settings.includeFileSource = false
	dbg.settings.includeLine = false

	dbg.debug("This is a debug message!")
	dbg.info("This is an info message!")
	dbg.warning("This is a warning message!")
	dbg.error("This is an error message!")

	dbg.settings.includeTime = true
	dbg.settings.includeDate = true
	dbg.info("Include timestamps and dates")
	dbg.settings.includeTime = false
	dbg.settings.includeDate = false

	dbg.settings.includeFileSource = true
	dbg.settings.includeLine = true

	var nest1 = func someFunc():
		var nest2 = func nFunc():
			dbg.info("Add a minimal stack trace")
		nest2.call()
	nest1.call()
	
	dbg.settings.includeFileSource = false
	dbg.settings.includeLine = false

	dbg.debug("Any BBCode is supported, go [rainbow sat=0.5 speed=0.1][tornado radius=10]🌪crazy🌪[/tornado][/rainbow]!!")

## Called by the root from signals "child_entered_tree" and "child_exited_tree"
func _onRootChildrenChanged(_child: Node) -> void:
	var mainMenu = get_node_or_null("/root/Menu")
	_isInMainMenu = mainMenu != null

	if (!_isInMainMenu):
		return

	# if we just entered the menu
	if (!_isInMainMenu):
		var openOnMenu = _modConfig.GetConfigValue("openOnMenu")
		_customLoggerUI.ToggleVisibility(openOnMenu)

		if (openOnMenu):
			_customLoggerUI.ForEach(func(menu): menu._ApplyRectToWindow(menu.MENU_RECT))
	
	_isInMainMenu = true

func _onConfigValueChanged(_configKey: String, _newValue: Variant) -> void:
	#dbg.debug("Received ConfigValueChanged signal with key '%s' and value '%s'" % [configKey, newValue])
	#_configSettings[configKey] = newValue
	pass
	
func _on_toggle_mouse_mode_key_pressed():
	if (_isInMainMenu):
		_ConfineMouse()
	else:
		if (_mouseIsForceCaptured):
			_ConfineMouse()
		elif (_mouseIsForceConfined):
			_CaptureMouse()
		else:
			var curMode = Input.mouse_mode
			if (curMode == Input.MouseMode.MOUSE_MODE_CAPTURED):
				_ConfineMouse()
			elif (curMode == Input.MouseMode.MOUSE_MODE_CONFINED):
				_CaptureMouse()

func _on_scene_changed() -> void:
	# if we just entered the menu
	var mainMenu = get_node_or_null("/root/Menu")
	if (mainMenu != null):
		_isInMainMenu = true

		if (_modConfig.GetConfigValue("openOnMenu")):
			_customLoggerUI.ToggleVisibility(true)
	else:
		_isInMainMenu = false

func _notification(what: int) -> void:
	if (what == NOTIFICATION_PREDELETE):
		dbg.debug("DbgUtils is being deleted, goodbye 💔")

func _input(event: InputEvent) -> void:
	if (event is InputEventKey):
		if (event.keycode == _modConfig.GetConfigValue("toggleDebugUIKey")):
			if (_toggleDebugUIKeyPressed and event.is_pressed()):
				return # prevent holding
			elif (not event.is_pressed()):
				_toggleDebugUIKeyPressed = false
				return
			
			_toggleDebugUIKeyPressed = true
	
			var hasVisibleMenus = _customLoggerUI.HasAnyVisibleMenus()

			_customLoggerUI.ToggleVisibility(!hasVisibleMenus)
			hasVisibleMenus = !hasVisibleMenus

			if (_isInMainMenu):
				_ConfineMouse()
			elif (_mouseIsForceCaptured):
				_CaptureMouse()
			elif (_mouseIsForceConfined):
				_ConfineMouse()
			else: # Not captured or confined
				var curMode = Input.mouse_mode
				if (curMode == Input.MouseMode.MOUSE_MODE_CAPTURED):
					_ConfineMouse()
				elif (curMode == Input.MouseMode.MOUSE_MODE_CONFINED):
					_CaptureMouse()
	
		elif (event.keycode == _modConfig.GetConfigValue("toggleMouseKey")):
			if (event.is_pressed()):
				_on_toggle_mouse_mode_key_pressed()

		elif (event.keycode == Key.KEY_MINUS and event.is_pressed()):
			_Tour()

#region CustomLogger

class CustomLogger extends Logger:
		var _dbgUtils

		func _init(dbgUtils) -> void:
			OS.add_logger(self )
			_dbgUtils = dbgUtils
		
		func _log_message(message: String, _error: bool) -> void:
			if (!_dbgUtils or !_dbgUtils.is_node_ready()):
				return

			var msgData = {
				"raw": "",
				"level": 0,
				"levelName": "DEBUG",
				"formattedMsg": null
			}
			
			# Get the log level from the very start of the msg, choosing the closest to the beginning
			var dbgIndex = message.findn("[debug]")
			var infoIndex = message.findn("[info]")

			if (dbgIndex != -1 and (dbgIndex < infoIndex or infoIndex == -1)):
				message = RegEx.create_from_string("(?i)\\[debug\\]").sub(message, "[DEBUG]", false)
				msgData["levelPos"] = [dbgIndex, dbgIndex + 7] # 7 = length of "[debug]"
			elif (infoIndex != -1 and (infoIndex < dbgIndex or dbgIndex == -1)):
				message = RegEx.create_from_string("(?i)\\[info\\]").sub(message, "[INFO]", false)
				msgData["level"] = 1
				msgData["levelName"] = "INFO"
				msgData["levelPos"] = [infoIndex, infoIndex + 6] # 6 = length of "[info]"

			msgData["raw"] = message

			_dbgUtils._AddLog.call_deferred(msgData)
			
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

			var errData = {
				"function": function,
				"file": file,
				"line": line,
				"code": code,
				"rationale": rationale,
				"errorType": error_type,
				"errorName": "",
				"existingPrefix": "",
				"generatedPrefix": "",
				"trace": "",
				"scriptBacktracesText": "" # "[color=#999]%s[/color]" % [script_backtraces_text]
			}

			var msgData = {
				"raw": "",
				"level": - 1,
				"levelName": "",
				"formattedMsg": null,
				"errData": errData
			}

			for level in ["WARNING", "ERROR"]:
				var regEx = RegEx.create_from_string("(?i)\\[%s\\]" % level)

				if (level == "ERROR"):
					var hasMatch = regEx.search(code) != null
					if (hasMatch):
						errData["errorName"] = (
							"ERROR" if error_type == ERROR_TYPE_ERROR
							else "SCRIPT ERROR" if error_type == ERROR_TYPE_SCRIPT
							else "SHADER ERROR" if error_type == ERROR_TYPE_SHADER
							else "ERROR"
						)
						msgData["level"] = 3
						msgData["levelName"] = "ERROR"
						errData["existingPrefix"] = regEx.sub(code, "[%s]" % [errData["errorName"]], false)
						break # meh
				else:
					if (regEx.search(code) != null):
						msgData["level"] = 2
						msgData["levelName"] = "WARNING"
						errData["errorName"] = "WARNING"
						errData["existingPrefix"] = regEx.sub(code, "[%s]" % [errData["errorName"]], false)
						break
						
			# The column at which to print the trace. Should match the length of the
			# unformatted text above it.
			var trace_indent := 0
			
			match error_type:
				ERROR_TYPE_ERROR:
					trace_indent = 6
					if (errData["existingPrefix"] == ""):
						msgData["level"] = 3
						msgData["levelName"] = "ERROR"
						errData["generatedPrefix"] = "ERROR:"
				ERROR_TYPE_WARNING:
					trace_indent = 8
					if (errData["existingPrefix"] == ""):
						msgData["level"] = 2
						msgData["levelName"] = "WARNING"
						errData["generatedPrefix"] = "WARNING:"
				ERROR_TYPE_SCRIPT:
					trace_indent = 13
					if (errData["existingPrefix"] == ""):
						msgData["level"] = 3
						msgData["levelName"] = "ERROR"
						errData["generatedPrefix"] = "SCRIPT ERROR:"
				ERROR_TYPE_SHADER:
					trace_indent = 13
					if (errData["existingPrefix"] == ""):
						msgData["level"] = 3
						msgData["levelName"] = "ERROR"
						errData["generatedPrefix"] = "SHADER ERROR:"
				
			errData["trace"] = "%*s %s (%s:%s)" % [trace_indent, "at:", function, file, line]

			for backtrace in script_backtraces:
				errData["scriptBacktracesText"] += backtrace.format(trace_indent - 3) + "\n"

			_dbgUtils._AddLog.call_deferred(msgData) # todo

		func _notification(what: int) -> void:
			if (what == NOTIFICATION_PREDELETE):
				OS.remove_logger(self )

#endregion CustomLogger
