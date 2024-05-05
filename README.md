# ContextMenuManager

A script for Stand mod menu to add context menu items when right-clicking objects in game.

# How to add new Context Menu scripts

1. Browse to `Stand/Lua Scripts/lib/ContextMenus` and create a new `.lua` or `.pluto` file
2. Within that file return a table with the appropriate keys set

## Keys

* name - The name of the option as it will be displayed in the context menu
* help - Optional help text to be displayed with the option
* author - Optional name of the author of this menu option script
* applicable_to - Optional list of entity types this option applies to. Default: `{"VEHICLE", "PED", "OBJECT"}`
* execute - Function that will be executed when the menu option is selected
