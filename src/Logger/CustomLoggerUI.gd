extends Control

@export var DisplayTextBox: RichTextLabel
@export var WindowCanvas: CanvasLayer
@export var WindowFrame: PanelContainer
@export var WindowContent: PanelContainer
@export var HeaderBar: PanelContainer
@export var ResizeHandle: TextureRect

const DbgUtils := preload("res://mods/DbgUtils/DbgUtils.gd")

const MENU_RECT := Rect2(Vector2(1300, 600), Vector2(500, 300))
const DEFAULT_RECT := Rect2(Vector2(0, 0), Vector2(400, 200))
const MINIMIZED_RECT := Rect2(Vector2(0, 0), Vector2(128, 30))

var _preMinimizeRect := Rect2()
var _preMoveRect := Rect2()

var _isExpanded: bool = false
var _isVisible: bool = false

var _disengageMouseButtonIsPressed: bool = false
var _previousMouseMode: Variant = null # Input.MouseMode

var _mouseIsDraggingWindow: bool = false
var _mouseIsResizingWindow: bool = false

var _mouseDownPosition: Vector2 = Vector2.ZERO # Where the mouse was when it clicked the HeaderBar
var _mouseLeftButtonPressed: bool = false

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
	file.close()

	reset_window(true, true, MENU_RECT)

	DisplayTextBox.clear()
	_preMinimizeRect = WindowFrame.get_rect()

func _physics_process(_delta: float) -> void:
	if (_mouseIsDraggingWindow):
		_HandleMove()
	
	if (_mouseIsResizingWindow):
		_HandleResize()

func minimize_window():
	change_expanded_state(false)

func expand_window():
	change_expanded_state(true)

func change_expanded_state(isExpanded: bool):
	_isExpanded = isExpanded
	WindowContent.visible = isExpanded
	ResizeHandle.visible = isExpanded

	if (!isExpanded):
		_preMinimizeRect = WindowFrame.get_rect()
		_ApplyRectToWindow(MINIMIZED_RECT)
	else:
		_ApplyRectToWindow(_preMinimizeRect)

func hide_window():
	change_visibility(false)

func reveal_window():
	change_visibility(true)

func change_visibility(isVisible: bool):
	_isVisible = isVisible
	WindowCanvas.visible = isVisible
	WindowContent.visible = isVisible
	ResizeHandle.visible = isVisible
	
	WindowFrame.position = DEFAULT_RECT.position

	if (!isVisible):
		_on_mouse_btn_released()

func reset_window(isExpanded: bool, isVisible: bool, newRect: Variant = null):
	change_expanded_state(isExpanded)
	change_visibility(isVisible)
	if newRect is Rect2:
		_ApplyRectToWindow(newRect)

func clear_window():
	DisplayTextBox.clear()

func _on_mouse_btn_released():
	_mouseIsDraggingWindow = false
	_mouseIsResizingWindow = false
	_mouseLeftButtonPressed = false

func _HandleMove():
	if (!_isExpanded): # reveal if moved while minimized
		expand_window()

	var initialMousePos = _mouseDownPosition
	var currentMousePos = get_global_mouse_position()
	var newWindowPos = _preMoveRect.position + (currentMousePos - initialMousePos)

	WindowFrame.position = newWindowPos

func _HandleResize():
	if (!_isExpanded): # prevent resizing while minimized
		return

	var mousePos = get_global_mouse_position()
	var initialWindowRect = _preMoveRect
	var newSize = mousePos - initialWindowRect.position
	_ApplyToWindow(newSize, initialWindowRect.position)

func _ApplyToWindow(newSize: Vector2, newPosition: Vector2):
	WindowFrame.size = newSize
	WindowFrame.position = newPosition

func _ApplyRectToWindow(newRect: Rect2):
	_ApplyToWindow(newRect.size, newRect.position)

func _AppendText(newText: String):
	if (!DisplayTextBox):
		return

	DisplayTextBox.append_text(newText)

func _OnDisengageMouseKeyPressed(isPressed: bool):
	if (isPressed):
		if (_disengageMouseButtonIsPressed):
			return # prevent holding
		_disengageMouseButtonIsPressed = true
	else:
		if (_disengageMouseButtonIsPressed):
			_disengageMouseButtonIsPressed = false
			return # prevent holding
			
	var oldMode = Input.get_mouse_mode()
	var newMode: Input.MouseMode

	if (_previousMouseMode != null):
		newMode = _previousMouseMode
		_previousMouseMode = null
	else:
		if (oldMode != Input.MOUSE_MODE_CONFINED and oldMode != Input.MOUSE_MODE_VISIBLE):
			_previousMouseMode = oldMode
			newMode = Input.MOUSE_MODE_CONFINED
			
	Input.set_mouse_mode(newMode)

	if (newMode != Input.MOUSE_MODE_VISIBLE and newMode != Input.MOUSE_MODE_CONFINED): # if no longer visible
		if (_mouseIsDraggingWindow or _mouseIsResizingWindow):
			_on_mouse_btn_released()

func _on_window_frame_resized():
	size = WindowFrame.size

func _on_minimize_window_pressed() -> void:
	change_expanded_state(!_isExpanded)

func _on_close_window_pressed() -> void:
	reset_window(true, false, DEFAULT_RECT)

func _on_clear_text_pressed() -> void:
	clear_window()

func _on_open_logs_pressed() -> void:
	OS.shell_open(ProjectSettings.globalize_path(String(ProjectSettings.get_setting_with_override(&"debug/file_logging/log_path")).get_base_dir()))

func _on_tree_exiting() -> void:
	var curParent = get_parent()

	if (curParent != null and curParent.name == "HUD"):
		curParent.remove_child.call_deferred(self )
		get_node_or_null("/root").add_child.call_deferred(self )

	_disengageMouseButtonIsPressed = false
	_previousMouseMode = null

	_on_mouse_btn_released()

func _on_tree_entered() -> void:
	move_to_front.call_deferred()
	_disengageMouseButtonIsPressed = false
	_previousMouseMode = null

func _on_header_bar_gui_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton):
		if (event.button_index == MouseButton.MOUSE_BUTTON_LEFT):
			if (event.is_pressed() and !_mouseLeftButtonPressed):
				_mouseDownPosition = get_global_mouse_position()
				_preMoveRect = WindowFrame.get_rect()
				_mouseIsDraggingWindow = true
				_mouseLeftButtonPressed = true
			elif (not event.is_pressed()):
				_on_mouse_btn_released()

func _on_resize_handle_gui_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton):
		if (event.button_index == MouseButton.MOUSE_BUTTON_LEFT):
			if (event.is_pressed()):
				_mouseDownPosition = get_global_mouse_position()
				_preMoveRect = WindowFrame.get_rect()
				_mouseIsResizingWindow = true
			else:
				_on_mouse_btn_released()

func _unhandled_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton):
		if (event.button_index == MouseButton.MOUSE_BUTTON_LEFT):
			if (!event.is_pressed()): # only update on release
				_on_mouse_btn_released()
		return

	if (event is InputEventKey):
		if (event.keycode == KEY_QUOTELEFT):
			if (event.is_pressed()):
				reset_window(_isExpanded, !_isVisible, DEFAULT_RECT)
			return
		
		if (event.keycode == KEY_PERIOD):
			if (event.is_pressed()):
				if (_disengageMouseButtonIsPressed):
					return # prevent holding
				_disengageMouseButtonIsPressed = true
			else:
				if (_disengageMouseButtonIsPressed):
					_disengageMouseButtonIsPressed = false
					return # prevent holding

			var oldMode = Input.get_mouse_mode()
			var newMode: Input.MouseMode

			if (_previousMouseMode != null):
				newMode = _previousMouseMode
				_previousMouseMode = null
			else:
				if (oldMode != Input.MOUSE_MODE_VISIBLE and oldMode != Input.MOUSE_MODE_CONFINED):
					_previousMouseMode = oldMode
					newMode = Input.MOUSE_MODE_CONFINED

			Input.set_mouse_mode(newMode)

			if (newMode != Input.MOUSE_MODE_VISIBLE and newMode != Input.MOUSE_MODE_CONFINED): # if no longer visible
				_on_mouse_btn_released()