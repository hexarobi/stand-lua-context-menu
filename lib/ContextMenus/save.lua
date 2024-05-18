-- ContextMenu Option
-- Place into `Stand/Lua Scripts/lib/ContextMenus`

local vehicle_utils = require("context_menu/vehicle_utils")

return {
    name="Save",
    help="Save entity to Constructs folder",
    applicable_to={"VEHICLE", "OBJECT", "PED", "WORLD_OBJECT"},
    hotkey="S",
    execute=function(target)
        local construct = vehicle_utils.create_construct_from_handle(target.handle)
        if vehicle_utils.save_construct(construct) then
            util.toast("Saved ".. construct.name .. " to " ..construct.filepath)
        end
    end
}