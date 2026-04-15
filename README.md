# DbgUtils - Road to Vostok Debug Utilities

A debugging utility mod for modders that provides an in-game UI menu and logging tools to assist with mod development during runtime.

## Usage

Example usage of the logger in your mod's code:

```gdscript
# preload & new() the script, optionally providing a DbgSettings .tres
var dbg := preload("res://mods/DbgUtils/Dbg.gd").new(MOD_ID, self , null)

func _ready() -> void:
	# Change settings directly if desired (or use apply_settings(...))
	dbg.settings.includeTime = true
	dbg.settings.maxDepth = 3

	# Will print to both the console & to the log file
	dbg.debug("Initializing...")
	dbg.info("This is an info message!")
	dbg.warning("This is a warning message!")
	dbg.error("This is an error message!")
```

There are two hotkeys:

- `~` to toggle the debug UI menu
- `.` to show/hide the mouse cursor (useful while in-game & mouse is hidden)

## Overview

DbgUtils is designed to enhance the modding experience by offering a convenient way to view logs and debug information directly within the game. It includes a custom logger that integrates with the UI, allowing mod developers to easily track events, errors, and other relevant data without needing to rely solely on external log files.

If you are not a modder, this can still be useful for locating broken mods or just keeping an eye on what's going on in the game. Anything that uses standard logging functions (like `print()`, `push_error()`, etc.) will have their output displayed in the DbgUtils UI.

I made this due to the issue of Godot not always flushing the console to file until the game exits, which makes it difficult to see logs in real-time while testing mods. It's possible already to just run the game with a terminal open, but with DbgUtils, you can see your logs immediately in the in-game UI, making the development process smoother and more efficient.

## Features

- In-game debug UI menu overlay
- Custom runtime logger with UI integration
- Resizable debug panel
- Monospaced font rendering for clean log output

## Installation

1. Download the latest release of DbgUtils from the [Releases](https://github.com/Theta90/RTV-DbgUtils/releases) page.

2. Place the ".vmz" file in your "mods" folder within the Road to Vostok game directory.

On Steam, this is typically located at:

```
C:\Program Files (x86)\Steam\steamapps\common\Road to Vostok\mods
```

3. Enjoy :)!
