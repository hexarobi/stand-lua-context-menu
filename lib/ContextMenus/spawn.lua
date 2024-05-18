
local vehicle_utils = require("context_menu/vehicle_utils")

return {
    name="Random Car",
    help="Spawn a random vehicle at location",
    applicable_to={"COORDS"},
    hotkey="R",
    execute=function(target)
        local camera_rotation = CAM.GET_FINAL_RENDERED_CAM_ROT(2)
        local vehicle = vehicle_utils.spawn_shuffled_vehicle_at_position("", target.pos, camera_rotation.z)
        util.toast("Spawning "..vehicle_utils.get_vehicle_name(vehicle).." at "..target.pos.x..","..target.pos.y)
    end
}