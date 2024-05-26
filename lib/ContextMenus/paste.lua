
local vehicle_utils = require("context_menu/vehicle_utils")
local state = require("context_menu/shared_state")
local constructor_lib = require("constructor/constructor_lib")

return {
    name="Paste",
    help="Paste vehicle from clipboard to location, or attributes to another vehicle",
    applicable_to={"COORDS","VEHICLE"},
    hotkey="V",
    execute=function(target)
        local construct = state.clipboard_construct
        if construct == nil then
            util.toast("Nothing yet copied to clipboard. Try using the Copy command.")
        else
            if target.type == "COORDS" then
                util.toast("Spawning "..construct.name.." at "..target.pos.x..","..target.pos.y)
                construct.position = target.pos
                local camera_rotation = CAM.GET_FINAL_RENDERED_CAM_ROT(2)
                construct.world_rotation.z = camera_rotation.z
                vehicle_utils.spawn_construct(construct)
            elseif target.type == "VEHICLE" then
                local target_construct = constructor_lib.create_construct_from_handle(target.handle)
                target_construct.vehicle_attributes.paint = construct.vehicle_attributes.paint
                target_construct.vehicle_attributes.wheels = construct.vehicle_attributes.wheels
                target_construct.vehicle_attributes.neon = construct.vehicle_attributes.neon
                target_construct.vehicle_attributes.headlights = construct.vehicle_attributes.headlights
                constructor_lib.deserialize_vehicle_attributes(target_construct)
                util.toast("Pasting "..construct.name.." paint to "..target.name)
            end
        end
    end
}
