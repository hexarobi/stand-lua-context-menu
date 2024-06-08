local vehicle_utils = require("context_menu/vehicle_utils")

local STAND_GARAGE_DIR = filesystem.stand_dir() .. 'Vehicles\\'

local items = {}

-- Avoid locking up GTA when reading files by running in os thread
util.execute_in_os_thread(function()
    return vehicle_utils.build_construct_menu_options(STAND_GARAGE_DIR, items)
end)
return {
    name="Garage",
    help="Spawn a vehicle from your Stand Garage",
    applicable_to={"COORDS"},
    items=items,
}
