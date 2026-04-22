# DbgUtils - Road to Vostok Debug Utilities

A debugging utility mod for modders that provides an in-game UI menu and logging tools to assist with mod development during runtime.

## Usage

Example usage of the logger in your mod's code (don't forget to check the MCM settings too!):

```gdscript
# preload & new() the script, optionally providing a DbgSettings .tres
var dbg := preload("res://mods/DbgUtils/Dbg.gd").new(MOD_ID, self , null)

func _ready() -> void:
	dbg.debug("This is a debug message!")
	dbg.info("This is an info message!")
	dbg.warning("This is a warning message!")
	dbg.error("This is an error message!")

	dbg.settings.includeTime = true
	dbg.settings.includeDate = true
	dbg.info("Include timestamps and dates")

	# if working within the editor
	dbg.settings.includeFileSource = true
	dbg.settings.includeLine = true
	var nest1 = func someFunc():
		var nest2 = func nFunc():
			dbg.info("Add a minimal stack trace")
		nest2.call()
	nest1.call()

	dbg.error("Any BBCode is supported, go [rainbow sat=0.5 speed=0.1][tornado radius=10]🌪crazy🌪[/tornado][/rainbow]!!")
```

There are two hotkeys:

- `~` to toggle the debug UI menu. This can be changed in the MCM settings if you want to use a different key.
- `.` to show/hide the mouse cursor (useful while in-game & mouse is hidden). This can also be changed in the MCM settings.

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

## Misc
For transparency, the repo for the build system that I created/use for this mod is located [here](https://github.com/Theta90/RTV-ModBuilder). It is a NodeJS-based script that will generate the mod.txt for me, bundle any assets, zip, and then rename to .vmz. It utilizes archiver (and it's dependencies).
