

local vehicle_utils = require("context_menu/vehicle_utils")
local state = require("context_menu/shared_state")

return {
    name="Copy",
    help="Copy vehicle to clipboard, for pasting",
    applicable_to={"VEHICLE"},
    hotkey="C",
    execute=function(target)
        state.clipboard_construct = vehicle_utils.create_construct_from_vehicle(target.handle)
        util.toast("Copied vehicle to clipboard "..target.name)
    end
}