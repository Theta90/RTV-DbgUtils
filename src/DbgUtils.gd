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

var _configSettings = ModConfig.DEFAULT_CONFIG_SETTINGS.duplicate()

var _logs: Array[String] = []

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

		dbg = Dbg.new("DbgUtils", self , null)

		_modConfig = ModConfig.new()
		_modConfig.connect("ConfigValueChanged", _onConfigValueChanged)

		var root = get_node("/root")
		root.connect("child_entered_tree", _onRootChildrenChanged)
		root.connect("child_exiting_tree", _onRootChildrenChanged)

		add_child(_customLoggerUI)
		add_child(_modConfig)

		_customLoggerUI.CreateMenu(_configSettings)

		dbg.debug("DbgUtils initialized, [wave][rainbow]have a nice day![/rainbow][/wave]")
	else:
		dbg = _autoload.dbg
		_logger = _autoload._logger
		_modConfig = _autoload._modConfig
		_customLoggerUI = _autoload._customLoggerUI
		_configSettings = _autoload._configSettings

	get_tree().scene_changed.connect(_on_scene_changed)

	dbg.debug("%s is now attached to DbgUtils" % dbg._modId)

func _AddLog(msg: String, level: String = "DEBUG"):
	_logs.append(msg)
	_customLoggerUI.AddLog(msg, level)

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

## Called by the root from signals "child_entered_tree" and "child_exited_tree"
func _onRootChildrenChanged(_child: Node) -> void:
	var mainMenu = get_node_or_null("/root/Menu")
	_isInMainMenu = mainMenu != null

	if (!_isInMainMenu):
		return

	# if we just entered the menu
	if (!_isInMainMenu):
		_customLoggerUI.ToggleVisibility(_configSettings["openOnMenu"])

		if (_configSettings["openOnMenu"]):
			_customLoggerUI.ForEach(func(menu): menu._ApplyRectToWindow(menu.MENU_RECT))
	
	_isInMainMenu = true

func _onConfigValueChanged(configKey: String, newValue: Variant) -> void:
	#dbg.debug("Received ConfigValueChanged signal with key '%s' and value '%s'" % [configKey, newValue])
	_configSettings[configKey] = newValue
	
func _Tour():
	dbg.settings.includeTime = false
	dbg.settings.includeFileSource = false
	dbg.settings.includeLine = false
	_modConfig.SetLocalConfigValue("colorEntireLine", false)

	dbg.debug("This is a debug message!")
	dbg.info("This is an info message!")
	dbg.warning("This is a warning message!")
	dbg.error("This is an error message!")

	dbg.settings.includeTime = true
	dbg.settings.includeDate = true
	dbg.info("Include timestamps and dates")
	dbg.settings.includeTime = false
	dbg.settings.includeDate = false

	_modConfig.SetLocalConfigValue("colorEntireLine", true)
	dbg.info("Change an entire line's color based on it's level (customizable via MCM). This one is %s!" % _configSettings["defaultColorInfo"])
	_modConfig.SetLocalConfigValue("colorEntireLine", false)

	dbg.settings.includeFileSource = true
	dbg.settings.includeLine = true

	var nest1 = func someFunc():
		var nest2 = func nFunc():
			dbg.info("Add a minimal stack trace")
		nest2.call()
	nest1.call()
	
	dbg.settings.includeFileSource = false
	dbg.settings.includeLine = false

	dbg.error("Any BBCode is supported, go [rainbow sat=0.5 speed=0.1][tornado radius=10]🌪crazy🌪[/tornado][/rainbow]!!")

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

		if (_configSettings["openOnMenu"]):
			_customLoggerUI.ToggleVisibility(true)
	else:
		_isInMainMenu = false

func _notification(what: int) -> void:
	if (what == NOTIFICATION_PREDELETE):
		dbg.debug("DbgUtils is being deleted, goodbye 💔")

func _input(event: InputEvent) -> void:
	if (event is InputEventKey):
		if (event.keycode == _configSettings["toggleDebugUIKey"]):
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
	
		elif (event.keycode == _configSettings["toggleMouseKey"]):
			if (event.is_pressed()):
				_on_toggle_mouse_mode_key_pressed()

		#elif (event.keycode == Key.KEY_MINUS and event.is_pressed()):
		#	_Tour()

#region CustomLogger

class CustomLogger extends Logger:
		var _dbgUtils

		func _init(dbgUtils) -> void:
			OS.add_logger(self )
			_dbgUtils = dbgUtils
		
		func _log_message(message: String, _error: bool) -> void:
			if (!_dbgUtils or !_dbgUtils.is_node_ready()):
				return

			#var regEx = RegEx.create_from_string("(?i)\\[(debug|info|warning|error)\\]")
			#message = regEx.sub(message, "[$1]".to_upper(), false) # replace first instace of the [level] w/<level>.to_upper()

			# Replace all instances of [level] with [LEVEL] (case-insensitive)
			var levels = ["DEBUG", "INFO", "WARNING", "ERROR"]
			for level in levels:
				var regEx = RegEx.create_from_string("(?i)\\[%s\\]" % level)
				message = regEx.sub(message, "[%s]" % level, false)

			var level: String = (
				"DEBUG" if message.find("[DEBUG]") != -1
				else "INFO" if message.find("[INFO]") != -1
				else "WARNING" if message.find("[WARNING]") != -1
				else "ERROR" if message.find("[ERROR]") != -1
				else "DEBUG"
			)

			match level:
				"DEBUG":
					if (_dbgUtils._configSettings["colorEntireLine"]):
						message = "[color=%s]%s[/color]" % [_dbgUtils._configSettings["defaultColorDebug"].to_html(), message]
					else:
						message = message.replace("[DEBUG]", "[color=%s][b][DEBUG][/b][/color]" % _dbgUtils._configSettings["defaultColorDebug"].to_html())
				"INFO":
					if (_dbgUtils._configSettings["colorEntireLine"]):
						message = "[color=%s]%s[/color]" % [_dbgUtils._configSettings["defaultColorInfo"].to_html(), message]
					else:
						message = message.replace("[INFO]", "[color=%s][b][INFO][/b][/color]" % _dbgUtils._configSettings["defaultColorInfo"].to_html())
				"WARNING":
					if (_dbgUtils._configSettings["colorEntireLine"]):
						message = "[color=%s]%s[/color]" % [_dbgUtils._configSettings["defaultColorWarning"].to_html(), message]
					else:
						message = message.replace("[WARNING]", "[color=%s][b][WARNING][/b][/color]" % _dbgUtils._configSettings["defaultColorWarning"].to_html())
				"ERROR":
					if (_dbgUtils._configSettings["colorEntireLine"]):
						message = "[color=%s]%s[/color]" % [_dbgUtils._configSettings["defaultColorError"].to_html(), message]
					else:
						message = message.replace("[ERROR]", "[color=%s][b][ERROR][/b][/color]" % _dbgUtils._configSettings["defaultColorError"].to_html())
				
			_dbgUtils._AddLog.call_deferred(message, level)
			
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
			var hasPrefix: bool = false

			# The column at which to print the trace. Should match the length of the
			# unformatted text above it.
			var trace_indent := 0

			var levels = ["WARNING", "ERROR"]
			var tgtLevel = "ERROR" if error_type == ERROR_TYPE_ERROR else "WARNING"

			for level in levels:
				var regEx = RegEx.create_from_string("(?i)\\[%s\\]" % level)

				if (level == "ERROR"):
					var hasMatch = regEx.search(code) != null
					if (hasMatch):
						var realError = (
							"ERROR" if error_type == ERROR_TYPE_ERROR
							else "SCRIPT ERROR" if error_type == ERROR_TYPE_SCRIPT
							else "SHADER ERROR" if error_type == ERROR_TYPE_SHADER
							else "ERROR"
						)
						hasPrefix = true
						prefix = regEx.sub(code, "[b][%s][/b]" % [realError], false)
						break # meh
				else:
					if (regEx.search(code) != null):
						hasPrefix = true
						prefix = regEx.sub(code, "[b][%s][/b]" % [level], false)
						break
			
			match error_type:
				ERROR_TYPE_ERROR:
					trace_indent = 6
					if (!hasPrefix):
						prefix = "[color=%s][b]ERROR:[/b]" % [_dbgUtils._configSettings["defaultColorError"].to_html()]
				ERROR_TYPE_WARNING:
					trace_indent = 8
					if (!hasPrefix):
						prefix = "[color=%s][b]WARNING:[/b]" % [_dbgUtils._configSettings["defaultColorWarning"].to_html()]
				ERROR_TYPE_SCRIPT:
					trace_indent = 13
					if (!hasPrefix):
						prefix = "[color=%s][b]SCRIPT ERROR:[/b]" % [_dbgUtils._configSettings["defaultColorError"].to_html()]
				ERROR_TYPE_SHADER:
					trace_indent = 13
					if (!hasPrefix):
						prefix = "[color=%s][b]SHADER ERROR:[/b]" % [_dbgUtils._configSettings["defaultColorError"].to_html()]
				
			var trace: String = "%*s %s (%s:%s)" % [trace_indent, "at:", function, file, line]
			var script_backtraces_text: String = ""

			for backtrace in script_backtraces:
				script_backtraces_text += backtrace.format(trace_indent - 3) + "\n"
			
			var msg = ""

			if (hasPrefix):
				var color = (
					_dbgUtils._configSettings["defaultColorWarning"] if error_type == ERROR_TYPE_WARNING
					else _dbgUtils._configSettings["defaultColorError"]
				).to_html()
				msg = "[color=%s]%s %s[/color]\n[color=#999]%s[/color]\n[color=#999]%s[/color][code]" % [
					color,
					prefix,
					rationale,
					trace,
					script_backtraces_text
				]
			else:
				msg = "[code]%s %s %s[/color]\n[color=#999]%s[/color]\n[color=#999]%s[/color][code]" % [
					prefix,
					code,
					rationale,
					trace,
					script_backtraces_text,
				]
			
			#_dbgUtils._AddLog.call_deferred("Prefix:%s\nCode: %s" % [prefix, code], "WARNING" if error_type == ERROR_TYPE_WARNING else "ERROR")
			_dbgUtils._AddLog.call_deferred(msg, tgtLevel)

		func _notification(what: int) -> void:
			if (what == NOTIFICATION_PREDELETE):
				OS.remove_logger(self )

#endregion CustomLogger
