extends PanelContainer

@export var DisplayTextBox: RichTextLabel
@export var WindowContent: PanelContainer
@export var HeaderBar: PanelContainer
@export var HeaderButtonPanel: PanelContainer
@export var ResizeHandle: TextureRect
@export var FilterEdit: LineEdit
@export var FilterMatchCount: Label

## Will need to change this to support multiple LoggerMenus (currently clears global logs)
signal ClearPressed

## The scene holding this script
static var LoggerMenuPath: String = "res://mods/DbgUtils/Logger/LoggerMenu.tscn"

const DbgUtils := preload("res://mods/DbgUtils/DbgUtils.gd")
const ModConfig := preload("res://mods/DbgUtils/MCM/ModConfig.gd")

const MENU_RECT := Rect2(Vector2(1300, 600), Vector2(500, 300))
const DEFAULT_RECT := Rect2(Vector2(0, 0), Vector2(400, 200))
const MINIMIZED_RECT := Rect2(Vector2(0, 0), Vector2(128, 30))
const DEFAULT_TEXT_BACKGROUND_COLOR := Color("#00000099")

var _modConfig: ModConfig = null

var _logLevel: int = 0 # todo: make configurable in this window
var _maxLogCount: int = 300

var _preMinimizeRect := Rect2()
var _preMoveRect := Rect2()

var _isExpanded: bool = false

var _mouseIsDraggingWindow: bool = false
var _mouseIsResizingWindow: bool = false
var _mouseDownPosition: Vector2 = Vector2.ZERO # Where the mouse was when it clicked the HeaderBar
var _mouseLeftButtonPressed: bool = false

var _resizeCooldownMsec: int = 10
var _lastResizeMsec = 0

# Try to batch process updates
var _refreshCooldownMsec: int = 10
var _lastRefreshMsec = 0
var _refreshQueued: bool = false

# Yes, this is ugly :(
## type MsgData = {
## 	raw: `String`,
## 	level: `int`,
## 	levelName: `String`,
## 	formattedText: `String`, # the text after being formatted with color tags and such, but before filtering
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
var _logsMatchingFilter: Array[Dictionary] = []

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

	DisplayTextBox.text = ""
	
	_lastResizeMsec = Time.get_ticks_msec() - _lastResizeMsec
	_lastRefreshMsec = Time.get_ticks_msec() - _lastRefreshMsec

	ResetWindow(true, true, MENU_RECT)

	_preMinimizeRect = get_rect()

	var inputEvent = InputEventKey.new()
	inputEvent.keycode = KEY_EQUAL
	inputEvent.key_label = KEY_EQUAL
	inputEvent.physical_keycode = KEY_EQUAL
	InputMap.add_action("print_multiline_text")
	InputMap.action_add_event("print_multiline_text", inputEvent)
	
func _physics_process(_delta: float) -> void:
	if (_mouseIsDraggingWindow):
		_HandleMoveViaMouse()
	
	if (_mouseIsResizingWindow):
		_HandleResize()

	if (_refreshQueued):
		if (_refreshCooldownMsec - (Time.get_ticks_msec() - _lastRefreshMsec) <= 0): # if remaining cooldown
			_UpdateTextBox()
			_refreshQueued = false
			_lastRefreshMsec = Time.get_ticks_msec()
		
func SetModConfig(config: ModConfig):
	if (_modConfig != null):
		if (_modConfig.is_connected("ConfigValueChanged", _on_mod_config_value_changed)):
			_modConfig.ConfigValueChanged.disconnect(_on_mod_config_value_changed)
	
	_modConfig = config
	config.ConfigValueChanged.connect(_on_mod_config_value_changed)

func MinimizeWindow():
	ChangeExpandedState(false)

func ExpandWindow():
	ChangeExpandedState(true)

func ChangeExpandedState(isExpanded: bool):
	if (_isExpanded == isExpanded):
		return

	_isExpanded = isExpanded
	DisplayTextBox.visible = isExpanded
	ResizeHandle.visible = isExpanded
	WindowContent.visible = isExpanded

	if (!isExpanded):
		_preMinimizeRect = get_rect()
		UpdateWindowRect(MINIMIZED_RECT)
	else:
		UpdateWindowRect(_preMinimizeRect)

func HideWindow():
	ChangeVisibility(false)

func RevealWindow():
	ChangeVisibility(true)

func ChangeVisibility(isVisible: bool):
	if (visible == isVisible):
		return

	visible = isVisible
	WindowContent.visible = isVisible

	if (!isVisible):
		_on_mouse_btn_released()

	_UpdateTextBox()

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
	#_refreshQueued = true

func Clear():
	DisplayTextBox.text = ""
	_logs.clear()
	_UpdateTextBox()

func MoveWindow(newPos: Vector2):
	if (position.is_equal_approx(newPos)):
		return

	set_position(newPos)

	#DisplayTextBox.size = DisplayTextBox.get_parent().size + Vector2(0, 200)
	#DisplayTextBox.position = DisplayTextBox.get_parent().position - Vector2(0, 200)
	#_refreshQueued = true
	#emit_signal("Moved", position)

func ResizeWindow(newSize: Vector2):
	if (size.is_equal_approx(newSize)):
		return

	if (!_HasResizeCooldown()):
		_lastResizeMsec = Time.get_ticks_msec()
	else:
		return

	newSize = newSize.max(WindowContent.get_combined_minimum_size() + get_theme_stylebox("panel").get_minimum_size())

	DisplayTextBox.process_mode = Node.PROCESS_MODE_DISABLED

	set_size(newSize)

	await get_tree().process_frame

	DisplayTextBox.process_mode = Node.PROCESS_MODE_INHERIT

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

	if (!("formattedText" in msgData)):
			msgData["formattedText"] = null
	
	if (msgData["formattedText"] == null):
		msgData["formattedText"] = _FilterMessage(_FormatMessage(msgData), FilterEdit.text)

	if (_modConfig.GetConfigValueOrDefault("enableMaxLogCount") and _logs.size() >= _maxLogCount):
		_logs.remove_at(0)
	
	_logs.append(msgData)

	_refreshQueued = true

func _HasResizeCooldown() -> bool:
	return _resizeCooldownMsec - (Time.get_ticks_msec() - _lastResizeMsec) > 0

func _FormatMessage(msgData: Dictionary) -> String:
	if (msgData["level"] < 2):
		return _FormatLogMessage(msgData)
	else:
		return _FormatErrorMessage(msgData)

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

func _HandleMoveViaMouse():
	if (!_isExpanded): # reveal if moved while minimized
		ExpandWindow()

	var initialMousePos = _mouseDownPosition
	var currentMousePos = get_global_mouse_position()
	var minWindowPos = - HeaderBar.size + Vector2(5, 5) + HeaderButtonPanel.size
	var maxWindowPos = get_viewport_rect().size - Vector2(5, 5) - HeaderButtonPanel.size
	var newWindowPos = minWindowPos.max(_preMoveRect.position + (currentMousePos - initialMousePos)).min(maxWindowPos)

	MoveWindow(newWindowPos)

func _HandleResize():
	if (!_isExpanded): # prevent resizing while minimized
		return

	var mousePos = get_global_mouse_position()
	var initialWindowRect = _preMoveRect
	var newSize = get_viewport_rect().size.min(mousePos - initialWindowRect.position)
	
	ResizeWindow(newSize)

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

func _GetRecentLogs(count: int) -> Array[Dictionary]:
	return _logs.slice(max(0, _logs.size() - count), _logs.size())

func _ResizeLogs(count: int):
	if (_logs.size() <= count):
		return

	_logs = _GetRecentLogs(count)
	_UpdateTextBox()

func _UpdateTextBox():
	var mostRecentLogs = _GetRecentLogs(_maxLogCount)
	var text = ""

	_logsMatchingFilter.clear()

	for msgData in mostRecentLogs:
		if (msgData["formattedText"] == null or msgData["formattedText"] == ""):
			msgData["formattedText"] = _FilterMessage(_FormatMessage(msgData), FilterEdit.text)
		
		if (msgData["formattedText"] != null):
			text += msgData["formattedText"]
			_logsMatchingFilter.append(msgData)

	DisplayTextBox.text = text

	if (_logsMatchingFilter.size() == _logs.size()):
		FilterMatchCount.visible = false
	else:
		FilterMatchCount.text = "%d/%d matching logs" % [_logsMatchingFilter.size(), _logs.size()]
		FilterMatchCount.visible = true
	
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
		for msg in _logs:
			msg["formattedText"] = null
		
		_refreshQueued = true

func _on_mouse_btn_released():
	_mouseIsDraggingWindow = false
	_mouseIsResizingWindow = false
	_mouseLeftButtonPressed = false

func _on_minimize_window_pressed() -> void:
	ChangeExpandedState(!_isExpanded)

func _on_close_window_pressed() -> void:
	CloseWindow()

func _on_clear_text_pressed() -> void:
	Clear()
	ClearPressed.emit(self )

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
		
			accept_event()

func _on_resize_handle_gui_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton):
		if (event.button_index == MouseButton.MOUSE_BUTTON_LEFT):
			if (event.is_pressed()):
				_mouseDownPosition = get_global_mouse_position()
				_preMoveRect = get_rect()
				_mouseIsResizingWindow = true
			else:
				_on_mouse_btn_released()
			
			accept_event()

func _on_filter_edit_text_changed(_text: String) -> void:
	for msg in _logs:
		msg["formattedText"] = null
	_refreshQueued = true

func _on_scroll_follow_toggle_toggled(toggled_on: bool) -> void:
	DisplayTextBox.scroll_following = toggled_on
	DisplayTextBox.scroll_following_visible_characters = toggled_on

func _unhandled_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton):
		if (event.button_index == MouseButton.MOUSE_BUTTON_LEFT):
			if (event.is_pressed()):
				_mouseDownPosition = get_global_mouse_position()
				if ((_mouseIsDraggingWindow or _mouseIsResizingWindow) and (!get_global_rect().has_point(_mouseDownPosition))):
					_on_mouse_btn_released() # stop dragging if we click outside the window
			else: # only update on release
				_on_mouse_btn_released()
	elif (event is InputEventMouseMotion and (_mouseIsDraggingWindow or _mouseIsResizingWindow)):
		if (!Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)):
			_on_mouse_btn_released() # catch case where mouse button release is missed
