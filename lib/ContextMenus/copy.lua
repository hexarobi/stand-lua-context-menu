

local vehicle_utils = require("context_menu/vehicle_utils")
local state = require("context_menu/shared_state")
local inspect = require("inspect")

return {
    name="Copy",
    help="Copy entity to clipboard, for later pasting",
    applicable_to={"VEHICLE", "OBJECT", "PED", "WORLD_OBJECT"},
    hotkey="C",
    execute=function(target)
        state.clipboard_construct = vehicle_utils.create_construct_from_handle(target.handle)
        util.log("Copied construct "..inspect(state.clipboard_construct))
        util.toast("Copied entity to clipboard "..target.name.." "..target.type)
    end
}