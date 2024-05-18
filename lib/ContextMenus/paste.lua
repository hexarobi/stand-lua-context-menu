
local vehicle_utils = require("context_menu/vehicle_utils")
local state = require("context_menu/shared_state")

return {
    name="Paste",
    help="Paste vehicle from clipboard to location",
    applicable_to={"COORDS"},
    hotkey="V",
    execute=function(target)
        local construct = state.clipboard_construct
        if construct == nil then
            util.toast("Nothing yet copied to clipboard. Try using the Copy command.")
        else
            util.toast("Spawning "..construct.name.." at "..target.pos.x..","..target.pos.y)
            construct.position = target.pos
            local camera_rotation = CAM.GET_FINAL_RENDERED_CAM_ROT(2)
            construct.world_rotation.z = camera_rotation.z
            vehicle_utils.spawn_construct(construct)
        end
    end
}