extends PanelContainer

signal VisibilityChanged(isVisible: bool)
signal ExpandedChanged(isExpanded: bool)
signal Moved(newPosition: Vector2)
signal Resized(newSize: Vector2)

@export var DisplayTextBox: RichTextLabel
@export var WindowContent: PanelContainer
@export var HeaderBar: PanelContainer
@export var ResizeHandle: TextureRect

## The scene holding this script
static var LoggerMenuPath: String = "res://mods/DbgUtils/Logger/LoggerMenu.tscn"

const MENU_RECT := Rect2(Vector2(1300, 600), Vector2(500, 300))
const DEFAULT_RECT := Rect2(Vector2(0, 0), Vector2(400, 200))
const MINIMIZED_RECT := Rect2(Vector2(0, 0), Vector2(128, 30))

var _maxLogs: int = 1000 # todo: make configurable in this window
var _logLevel: String = "DEBUG" # todo: make configurable in this window

var _preMinimizeRect := Rect2()
var _preMoveRect := Rect2()

var _isExpanded: bool = false

var _mouseIsDraggingWindow: bool = false
var _mouseIsResizingWindow: bool = false

var _mouseDownPosition: Vector2 = Vector2.ZERO # Where the mouse was when it clicked the HeaderBar
var _mouseLeftButtonPressed: bool = false

var _logs: Array[String] = []

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

func MoveWindow(newPos: Vector2):
	if (position.is_equal_approx(newPos)):
		return
	position = newPos
	emit_signal("Moved", position)

func ResizeWindow(newSize: Vector2):
	if (size.is_equal_approx(newSize)):
		return
	size = newSize
	emit_signal("Resized", size)

func UpdateWindow(newPos: Vector2, newSize: Vector2):
	MoveWindow(newPos)
	ResizeWindow(newSize)

func UpdateWindowRect(newRect: Rect2):
	UpdateWindow(newRect.position, newRect.size)

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

func AddLog(newText: String, level: String = "DEBUG"):
	if (!MeetsLogLevel(level)):
		return

	_logs.append(newText)
	DisplayTextBox.append_text(newText)

	_ManageLogCount()
	
func _ManageLogCount():
	var count = _logs.size()
	if (count > _maxLogs):
		var excess = count - _maxLogs
		_logs = _logs.slice(excess, count)
		DisplayTextBox.clear()

		for el in _logs:
			DisplayTextBox.append_text(el)

func MeetsLogLevel(level: String) -> bool:
	match _logLevel:
		"DEBUG":
			return true
		"INFO":
			return level != "DEBUG"
		"WARNING":
			return level != "DEBUG" and level != "INFO"
		"ERROR":
			return level == "ERROR"
		_:
			return false

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
			else:
				_on_mouse_btn_released()

func _unhandled_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton):
		if (event.button_index == MouseButton.MOUSE_BUTTON_LEFT):
			if (!event.is_pressed()): # only update on release
				_on_mouse_btn_released()
		return
