extends Control

@export var DisplayTextBox: RichTextLabel
@export var WindowCanvas: CanvasLayer
@export var WindowFrame: PanelContainer
@export var WindowContent: PanelContainer
@export var HeaderBar: PanelContainer
@export var ResizeHandle: TextureRect

enum WindowSide {
	NONE = 0,
	TOP = 1 << 1,
	RIGHT = 1 << 2,
	BOTTOM = 1 << 3,
	LEFT = 1 << 4,
}

const DEFAULT_WINDOW_SIZE := Vector2(256, 128)
const HIDDEN_WINDOW_SIZE := Vector2(128, 30)

var disengageMouseButtonIsPressed: bool = false
var previousMouseMode: Variant = null # Input.MouseMode

var preMinimizeRect: Rect2 = Rect2()
var preMoveRect: Rect2 = Rect2()

var mouseIsDraggingWindow: bool = false
var mouseIsResizingWindow: bool = false
var mouseIsInsideFrame: bool = false

var mouseDownPosition: Vector2 = Vector2.ZERO # Where the mouse was when it clicked the HeaderBar
var mouseLeftButtonPressed: bool = false

var logger # CustomLogger

func _init() -> void:
	logger = load("res://mods/DbgUtils/Logger/CustomLogger.gd").new().GetNewLogger(self )

func _ready() -> void:
	preMinimizeRect = WindowFrame.get_rect()

	#var fonts = {
	#	"regular": load("res://mods/DbgUtils/Assets/RobotoMono-Regular.ttf"),
	#	"bold": load("res://mods/DbgUtils/Assets/RobotoMono-Bold.ttf"),
	#	"italic": load("res://mods/DbgUtils/Assets/RobotoMono-Italic.ttf"),
	#	"bold_italic": load("res://mods/DbgUtils/Assets/RobotoMono-BoldItalic.ttf"),
	#}

	#DisplayTextBox.add_theme_font_override("normal_font", fonts["regular"])
	#DisplayTextBox.add_theme_font_override("bold_font", fonts["bold"])
	#DisplayTextBox.add_theme_font_override("italic_font", fonts["italic"])
	#DisplayTextBox.add_theme_font_override("bold_italic_font", fonts["bold_italic"])
	#var texture = FileAccess.open("res://mods/DbgUtils/Assets/resize_handle.png", FileAccess.READ)
	#print(texture)

func _physics_process(_delta: float) -> void:
	if (mouseIsDraggingWindow):
		_HandleMove()
	
	if (mouseIsResizingWindow):
		_HandleResize()

func _HandleMove():
	if (WindowContent.visible == false): # reveal if moved while minimized
		WindowContent.visible = true
		WindowFrame.size = preMinimizeRect.size

	var initialMousePos = mouseDownPosition
	var currentMousePos = get_global_mouse_position()
	var newWindowPos = preMoveRect.position + (currentMousePos - initialMousePos)

	WindowFrame.position = newWindowPos

func _HandleResize():
	if (WindowContent.visible == false):
		return

	var mousePos = get_global_mouse_position()
	var initialWindowRect = preMoveRect
	var newSize = mousePos - initialWindowRect.position
	_ApplyToWindow(newSize, initialWindowRect.position)

func _ResetWindow(isVisible: bool = true):
	WindowFrame.size = DEFAULT_WINDOW_SIZE
	WindowFrame.position = Vector2.ZERO
	WindowCanvas.visible = isVisible
	if (!isVisible):
		if (mouseIsDraggingWindow or mouseIsResizingWindow):
			mouseIsDraggingWindow = false
			mouseIsResizingWindow = false
		if (disengageMouseButtonIsPressed):
			disengageMouseButtonIsPressed = false
			previousMouseMode = null

func _ApplyToWindow(newSize: Vector2, newPosition: Vector2):
	WindowFrame.size = newSize
	WindowFrame.position = newPosition

func _ApplyRectToWindow(newRect: Rect2):
	_ApplyToWindow(newRect.size, newRect.position)

func _OnDisengageMouseKeyPressed(isPressed: bool):
	if (isPressed):
		if (disengageMouseButtonIsPressed):
			return # prevent holding
		disengageMouseButtonIsPressed = true
	else:
		if (disengageMouseButtonIsPressed):
			disengageMouseButtonIsPressed = false
			return # prevent holding
			
	var oldMode = Input.get_mouse_mode()
	var newMode: Input.MouseMode

	if (previousMouseMode != null):
		newMode = previousMouseMode
		previousMouseMode = null
	else:
		if (oldMode != Input.MOUSE_MODE_CONFINED and oldMode != Input.MOUSE_MODE_VISIBLE):
			previousMouseMode = oldMode
			newMode = Input.MOUSE_MODE_CONFINED
			
	Input.set_mouse_mode(newMode)

	if (newMode != Input.MOUSE_MODE_VISIBLE and newMode != Input.MOUSE_MODE_CONFINED): # if no longer visible
		if (mouseIsDraggingWindow or mouseIsResizingWindow):
			mouseIsDraggingWindow = false
			mouseIsResizingWindow = false

func _on_window_frame_resized():
	size = WindowFrame.size

func _on_minimize_window_pressed() -> void:
	var isVisible = WindowContent.visible
	if (isVisible):
		preMinimizeRect = WindowFrame.get_rect()
		WindowContent.visible = false;
		_ApplyToWindow(HIDDEN_WINDOW_SIZE, Vector2.ZERO)
	else:
		WindowContent.visible = true
		_ApplyToWindow(preMinimizeRect.size, preMinimizeRect.position)

func _on_close_window_pressed() -> void:
	_ResetWindow(false) # TODO: make a way to "reset & reappear"

func _on_clear_text_pressed() -> void:
	DisplayTextBox.clear()

func _on_open_logs_pressed() -> void:
	OS.shell_open(ProjectSettings.globalize_path(String(ProjectSettings.get_setting_with_override(&"debug/file_logging/log_path")).get_base_dir()))

func _on_tree_exiting() -> void:
	var curParent = get_parent()

	if (curParent != null and curParent.name == "HUD"):
		curParent.remove_child.call_deferred(self )
		get_node_or_null("/root").add_child.call_deferred(self )

	disengageMouseButtonIsPressed = false
	previousMouseMode = null

func _on_tree_entered() -> void:
	move_to_front.call_deferred()
	disengageMouseButtonIsPressed = false
	previousMouseMode = null

func _on_header_bar_gui_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton):
		if (event.button_index == MouseButton.MOUSE_BUTTON_LEFT):
			if (event.is_pressed() and !mouseLeftButtonPressed):
				mouseDownPosition = get_global_mouse_position()
				preMoveRect = WindowFrame.get_rect()
				mouseIsDraggingWindow = true
				mouseLeftButtonPressed = true
			else:
				mouseIsDraggingWindow = false
				mouseLeftButtonPressed = false

func _on_resize_handle_gui_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton):
		if (event.button_index == MouseButton.MOUSE_BUTTON_LEFT):
			if (event.is_pressed()):
				mouseDownPosition = get_global_mouse_position()
				preMoveRect = WindowFrame.get_rect()
				mouseIsResizingWindow = true
			else:
				mouseIsResizingWindow = false
				mouseLeftButtonPressed = false

func _unhandled_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton):
		if (event.button_index == MouseButton.MOUSE_BUTTON_LEFT):
			if (!event.is_pressed()): # only update on release
				mouseLeftButtonPressed = false
				mouseIsDraggingWindow = false
				mouseIsResizingWindow = false
		return

	if (event is InputEventKey):
		if (event.keycode == KEY_QUOTELEFT):
			if (event.is_pressed()):
				_ResetWindow(!WindowCanvas.visible)
		
		if (event.keycode == KEY_PERIOD):
			if (event.is_pressed()):
				if (disengageMouseButtonIsPressed):
					return # prevent holding
				disengageMouseButtonIsPressed = true
			else:
				if (disengageMouseButtonIsPressed):
					disengageMouseButtonIsPressed = false
					return # prevent holding

			var oldMode = Input.get_mouse_mode()
			var newMode: Input.MouseMode

			if (previousMouseMode != null):
				newMode = previousMouseMode
				previousMouseMode = null
			else:
				if (oldMode != Input.MOUSE_MODE_CONFINED and oldMode != Input.MOUSE_MODE_VISIBLE):
					previousMouseMode = oldMode
					newMode = Input.MOUSE_MODE_CONFINED

			Input.set_mouse_mode(newMode)
