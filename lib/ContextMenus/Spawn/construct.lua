local vehicle_utils = require("context_menu/vehicle_utils")

local CONSTRUCTS_DIR = filesystem.stand_dir() .. 'Constructs\\'

local items = {}

-- Avoid locking up GTA when reading files by running in os thread
util.execute_in_os_thread(function()
    return vehicle_utils.build_construct_menu_options(CONSTRUCTS_DIR, items)
end)

return {
    name="Constructs",
    help="Spawn a vehicle from your Constructs folder",
    applicable_to={"COORDS"},
    items=items
}
