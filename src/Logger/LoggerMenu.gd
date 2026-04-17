@tool
extends PanelContainer

signal VisibilityChanged(isVisible: bool)
signal ExpandedChanged(isExpanded: bool)
signal Moved(newPosition: Vector2)
signal Resized(newSize: Vector2)

@export var DisplayTextBox: RichTextLabel
@export var WindowContent: PanelContainer
@export var HeaderBar: PanelContainer
@export var ResizeHandle: TextureRect
@export var FilterEdit: LineEdit

## The scene holding this script
static var LoggerMenuPath: String = "res://mods/DbgUtils/Logger/LoggerMenu.tscn"

const DbgUtils := preload("res://mods/DbgUtils/DbgUtils.gd")
const ModConfig := preload("res://mods/DbgUtils/MCM/ModConfig.gd")

const MENU_RECT := Rect2(Vector2(1300, 600), Vector2(500, 300))
const DEFAULT_RECT := Rect2(Vector2(0, 0), Vector2(400, 200))
const MINIMIZED_RECT := Rect2(Vector2(0, 0), Vector2(128, 30))
const DEFAULT_TEXT_BACKGROUND_COLOR := Color("#00000099")

var _modConfig: ModConfig = null

var _maxLogs: int = 500 # todo: make configurable in this window
var _logLevel: int = 0 # todo: make configurable in this window

var _preMinimizeRect := Rect2()
var _preMoveRect := Rect2()

var _isExpanded: bool = false

var _mouseIsDraggingWindow: bool = false
var _mouseIsResizingWindow: bool = false
var _mouseDownPosition: Vector2 = Vector2.ZERO # Where the mouse was when it clicked the HeaderBar
var _mouseLeftButtonPressed: bool = false

var _resizeCooldownMsec: int = 50
var _lastResizeMsec = 999999

# Yes, this is ugly :(
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
	var fonts = {
		"normal_font": load("res://mods/DbgUtils/Assets/RobotoMono-Regular.ttf.fontdata"),
		"bold_font": load("res://mods/DbgUtils/Assets/RobotoMono-Bold.ttf.fontdata"),
		"bold_italic_font": load("res://mods/DbgUtils/Assets/RobotoMono-BoldItalic.ttf.fontdata"),
		"italic_font": load("res://mods/DbgUtils/Assets/RobotoMono-Italic.ttf.fontdata"),
	}
	
	fonts["mono_font"] = fonts["normal_font"]

	for font in fonts.keys():
		DisplayTextBox.add_theme_font_override(font, fonts[font])

	var path = "res://mods/DbgUtils/Assets/resize_handle.png"
	var file = FileAccess.open(path, FileAccess.READ)
	var imgBuffer = file.get_buffer(file.get_length())
	var img = Image.new()
	
	img.load_png_from_buffer(imgBuffer)
	ResizeHandle.texture = ImageTexture.create_from_image(img)

	DisplayTextBox.clear()

	ResetWindow(true, true, MENU_RECT)

	_preMinimizeRect = get_rect()
	
func _physics_process(_delta: float) -> void:
	if (_mouseIsDraggingWindow):
		_HandleMoveViaMouse()
	
	if (_mouseIsResizingWindow):
		_HandleResize()

func SetModConfig(config: ModConfig):
	if (_modConfig != null):
		if (_modConfig.is_connected("ConfigValueChanged", _on_mod_config_value_changed)):
			_modConfig.ConfigValueChanged.disconnect(_on_mod_config_value_changed)
	
	_modConfig = config
	config.ConfigValueChanged.connect(_on_mod_config_value_changed)
	_InvalidateFormattedMessages()

func MinimizeWindow():
	ChangeExpandedState(false)

func ExpandWindow():
	ChangeExpandedState(true)

func ChangeExpandedState(isExpanded: bool):
	if (_isExpanded == isExpanded):
		return

	_isExpanded = isExpanded
	WindowContent.visible = isExpanded
	ResizeHandle.visible = isExpanded

	if (!isExpanded):
		_preMinimizeRect = get_rect()
		UpdateWindowRect(MINIMIZED_RECT)
	else:
		UpdateWindowRect(_preMinimizeRect)
	
	emit_signal("ExpandedChanged", isExpanded)

func HideWindow():
	ChangeVisibility(false)

func RevealWindow():
	ChangeVisibility(true)

func ChangeVisibility(isVisible: bool):
	if (visible == isVisible):
		return

	visible = isVisible

	if (!isVisible):
		_on_mouse_btn_released()

	emit_signal("VisibilityChanged", isVisible)

func CloseWindow():
	ResetWindow(true, false, DEFAULT_RECT)

func OpenWindow():
	ResetWindow(true, true, DEFAULT_RECT)

func ResetWindow(isExpanded = null, isVisible = null, newRect = null):
	var tgtRect: Rect2 = newRect

	if (isExpanded == null):
		isExpanded = _isExpanded
	
	if (isVisible == null):
		isVisible = visible

	if (tgtRect == null):
		tgtRect = get_rect()

	ChangeExpandedState(isExpanded)
	ChangeVisibility(isVisible)
	UpdateWindowRect(tgtRect)

func ClearWindow():
	DisplayTextBox.clear()
	_logs.clear()

func MoveWindow(newPos: Vector2):
	if (position.is_equal_approx(newPos)):
		return

	set_position.call_deferred(newPos)
	emit_signal("Moved", position)

func ResizeWindow(newSize: Vector2):
	if (size.is_equal_approx(newSize)):
		return

	if (!_HasResizeCooldown()):
		_lastResizeMsec = Time.get_ticks_msec()
	else:
		return

	set_size.call_deferred(newSize)
	emit_signal("Resized", size)

func UpdateWindow(newPos: Vector2, newSize: Vector2):
	MoveWindow(newPos)
	ResizeWindow(newSize)

func UpdateWindowRect(newRect: Rect2):
	UpdateWindow(newRect.position, newRect.size)

# Known issue: If the log is below level, it isn't added to the list of logs.
#	If the log level is then changed to be above that log, the "missing" logs won't appear
func AddLog(msgData: Dictionary):
	if (msgData["level"] < _logLevel):
		return

	_logs.append(msgData)
	PostLog(msgData)

	#_ManageLogCount()

func PostLog(msgData: Dictionary, applyFilter = true):
	msgData["formattedMsg"] = _FormatMessage(msgData)
	if (applyFilter):
		var filteredMsg = _FilterMessage(msgData["formattedMsg"], FilterEdit.text)
		if (filteredMsg != null):
			DisplayTextBox.append_text(filteredMsg)
	else:
		DisplayTextBox.append_text(msgData["formattedMsg"])

func _HasResizeCooldown() -> bool:
	var tMsec = Time.get_ticks_msec()
	return tMsec - _lastResizeMsec < _resizeCooldownMsec
	#if (tMsec - _lastResizeMsec > _resizeCooldownMsec):
	#	_lastResizeMsec = tMsec
	#	return false
	#return true

func _FormatMessage(msgData: Dictionary) -> String:
	if (msgData["formattedMsg"] != null):
		return msgData["formattedMsg"]

	if (msgData["level"] < 2):
		msgData["formattedMsg"] = _FormatLogMessage(msgData)
	else:
		msgData["formattedMsg"] = _FormatErrorMessage(msgData)

	return msgData["formattedMsg"]

func _FormatLogMessage(msgData: Dictionary) -> String:
	var msg = msgData["raw"]
	var level = msgData["level"]
	var color = _GetColorForLevel(level).to_html()

	var shouldColorEntireMessage = _modConfig.GetConfigValueOrDefault("colorEntireMessage")
	if (shouldColorEntireMessage):
		msg = "[color=%s]%s[/color]" % [color, msg]
	else:
		msg = msg.replace("[%s]" % [msgData["levelName"]], "[color=%s][b][%s][/b][/color]" % [color, msgData["levelName"]])

	return msg

func _FormatErrorMessage(msgData: Dictionary) -> String:
	var errData = msgData["errData"]
	var msg = ""
	var color = (
			_modConfig.GetConfigValueOrDefault("defaultColorWarning") if errData["errorType"] == Logger.ERROR_TYPE_WARNING
			else _modConfig.GetConfigValueOrDefault("defaultColorError")
		).to_html()

	if (errData["existingPrefix"] != ""):
		msg = "[color=%s]%s %s[/color]\n[color=#999]%s[/color]\n[color=#999]%s[/color][code]" % [
			color,
			errData["existingPrefix"],
			errData["rationale"],
			errData["trace"],
			errData["scriptBacktracesText"]
		]
	else:
		msg = "[code][color=%s]%s %s %s[/color]\n[color=#999]%s[/color]\n[color=#999]%s[/color][code]" % [
			color,
			errData["generatedPrefix"],
			errData["code"],
			errData["rationale"],
			errData["trace"],
			errData["scriptBacktracesText"]
		]

	return msg

func _GetColorForLevel(level: int) -> Color:
	match level:
		0:
			return _modConfig.GetConfigValueOrDefault("defaultColorDebug")
		1:
			return _modConfig.GetConfigValueOrDefault("defaultColorInfo")
		2:
			return _modConfig.GetConfigValueOrDefault("defaultColorWarning")
		3:
			return _modConfig.GetConfigValueOrDefault("defaultColorError")
	
	return Color("white")

func _InvalidateFormattedMessages():
	for msg in _logs:
		msg["formattedMsg"] = null

func _RepostAllMessages():
	var messages: Array[Dictionary] = []
	for msg in _logs:
		msg["formattedMsg"] = _FormatMessage(msg)
		messages.append(msg)
	_ApplyFilterToLogs(FilterEdit.text, messages)

	#for el in _logs:
	#	PostLog(el, false) # we want to batch apply filtering
	#_ApplyFilterToLogs(FilterEdit.text, messages)

func _HandleMoveViaMouse():
	if (!_isExpanded): # reveal if moved while minimized
		ExpandWindow()

	var initialMousePos = _mouseDownPosition
	var currentMousePos = get_global_mouse_position()
	var newWindowPos = _preMoveRect.position + (currentMousePos - initialMousePos)

	MoveWindow(newWindowPos)

func _HandleResize():
	if (!_isExpanded): # prevent resizing while minimized
		return

	var mousePos = get_global_mouse_position()
	var initialWindowRect = _preMoveRect
	var newSize = mousePos - initialWindowRect.position

	ResizeWindow(newSize)

# Need to revisit this, currently destroys the performance
func _ManageLogCount():
	var count = _logs.size()
	if (count > _maxLogs):
		var excess: int = max(0, count - int(_maxLogs * 1.25)) # add buffer
		_logs = _logs.slice(excess, count)
		#print.call_deferred("Removed %d excess logs, count is now %d" % [excess, _logs.size()])

		DisplayTextBox.clear()
		_RepostAllMessages()

	# Toggle threading if huge amounts of logs are being posted, to prevent freezing the game
	#@warning_ignore("integer_division")
	#if (count > _maxLogs / 2):
	#	if (DisplayTextBox.threaded == false):
	#		DisplayTextBox.threaded = true
	#else:
	#	if (DisplayTextBox.threaded == true):
	#		DisplayTextBox.threaded = false

func _ApplyFilterToLogs(filterText: String, logs = null):
	var matches: Array[String] = []
	var regex = RegEx.create_from_string(r"(?i)(%s)" % DbgUtils.EscapeRegex(filterText))
	var highlightColor = _modConfig.GetConfigValueOrDefault("filterHighlightColor").to_html()
	var textColor = _modConfig.GetConfigValueOrDefault("filterTextColor").to_html()

	var shouldHighlight = _modConfig.GetConfigValueOrDefault("filterHighlightEnabled")
	var shouldRemoveNonMatches = _modConfig.GetConfigValueOrDefault("filterRemoveNonMatches")

	if (logs == null):
		logs = _logs

	if (filterText.length() < 2):
		for i in range(logs.size()): # Select the text of each log
			matches.append(logs[i]["formattedMsg"])
	else:
		if (!shouldHighlight and !shouldRemoveNonMatches):
			return # no need to filter if we're not highlighting or removing non-matches

		var matchedStr = "[color=%s][bgcolor=%s]$0[/bgcolor][/color]" % [textColor, highlightColor]
		for el in logs:
			var elMatches = regex.search_all(el["formattedMsg"])

			if (!shouldHighlight && elMatches.size() > 0): # match, not highlighting
				matches.append(el["formattedMsg"])
			elif (!shouldRemoveNonMatches and elMatches.size() == 0): # unknown match, not removing non-matches
				matches.append(el["formattedMsg"])
			elif (elMatches.size() > 0): # match, highlighting and removing non-matches
				matches.append(regex.sub(el["formattedMsg"], matchedStr, true))
	
	DisplayTextBox.clear()

	if (matches.size() == 0):
		DisplayTextBox.append_text("[color=#999]\"%s\" was not found in any log messages[/color]" % filterText)
	else:
		var batchSize = 50
		for i in range(0, matches.size(), batchSize):
			var batch = matches.slice(i, i + batchSize)
			DisplayTextBox.append_text(batch.reduce(func(a, b): return a + "\n" + b))
		#for el in matches:
		#	DisplayTextBox.append_text(el)

## Returns String | null (if the msg didn't match the filter and should be removed)
func _FilterMessage(msg: String, filterText: String) -> Variant:
	if (filterText.length() < 2):
		return msg

	var regex = RegEx.create_from_string(r"(?i)(%s)" % DbgUtils.EscapeRegex(filterText))
	var matches = regex.search_all(msg)

	if (matches.size() == 0):
		return null

	var highlightColor = _modConfig.GetConfigValueOrDefault("filterHighlightColor").to_html()
	var textColor = _modConfig.GetConfigValueOrDefault("filterTextColor").to_html()

	if (_modConfig.GetConfigValueOrDefault("filterHighlightEnabled")):
		msg = regex.sub(msg, "[color=%s][bgcolor=%s]$0[/bgcolor][/color]" % [textColor, highlightColor], true)

	if (msg == ""):
		return null

	return msg

func _on_mod_config_value_changed(key: String, _value: Variant):
	const COLOR_SETTING_KEYS = [
		"colorEntireMessage",
		"defaultColorDebug",
		"defaultColorInfo",
		"defaultColorWarning",
		"defaultColorError",
		"filterHighlightEnabled",
		"filterRemoveNonMatches",
		"filterHighlightColor",
		"filterTextColor"
	]

	if (key in COLOR_SETTING_KEYS):
		_InvalidateFormattedMessages()
		DisplayTextBox.clear()
		_RepostAllMessages()
		_ApplyFilterToLogs(FilterEdit.text) # re-apply filter

func _on_mouse_btn_released():
	_mouseIsDraggingWindow = false
	_mouseIsResizingWindow = false
	_mouseLeftButtonPressed = false

func _on_resized():
	size = size

func _on_minimize_window_pressed() -> void:
	ChangeExpandedState(!_isExpanded)

func _on_close_window_pressed() -> void:
	CloseWindow()

func _on_clear_text_pressed() -> void:
	ClearWindow()

func _on_open_logs_pressed() -> void:
	OS.shell_open(ProjectSettings.globalize_path(String(ProjectSettings.get_setting_with_override(&"debug/file_logging/log_path")).get_base_dir()))

func _on_tree_exiting() -> void:
	var curParent = get_parent()
	var root = get_node_or_null("/root")

	# prevent self from being removed from the tree
	if (curParent != null and curParent != root):
		curParent.remove_child.call_deferred(self )
		root.add_child.call_deferred(self )

	_on_mouse_btn_released()

func _on_tree_entered() -> void:
	move_to_front.call_deferred()

func _on_header_bar_gui_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton):
		if (event.button_index == MouseButton.MOUSE_BUTTON_LEFT):
			if (event.is_pressed() and !_mouseLeftButtonPressed):
				_mouseDownPosition = get_global_mouse_position()
				_preMoveRect = get_rect()
				_mouseIsDraggingWindow = true
				_mouseLeftButtonPressed = true

			elif (not event.is_pressed()):
				_on_mouse_btn_released()

func _on_resize_handle_gui_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton):
		if (event.button_index == MouseButton.MOUSE_BUTTON_LEFT):
			if (event.is_pressed()):
				_mouseDownPosition = get_global_mouse_position()
				_preMoveRect = get_rect()
				_mouseIsResizingWindow = true
				DisplayTextBox.self_modulate = DisplayTextBox.self_modulate.darkened(0.3)
				DisplayTextBox.process_mode = Node.PROCESS_MODE_DISABLED
				DisplayTextBox.autowrap_mode = TextServer.AUTOWRAP_OFF
			else:
				_on_mouse_btn_released()
				DisplayTextBox.process_mode = Node.PROCESS_MODE_INHERIT
				DisplayTextBox.self_modulate = Color.WHITE
				DisplayTextBox.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func _on_filter_edit_text_changed(filterText: String) -> void:
	if (!DisplayTextBox.threaded):
		_ApplyFilterToLogs(filterText)
	else:
		call_deferred_thread_group("_ApplyFilterToLogs", filterText)

func _unhandled_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton):
		if (event.button_index == MouseButton.MOUSE_BUTTON_LEFT):
			if (!event.is_pressed()): # only update on release
				_on_mouse_btn_released()
