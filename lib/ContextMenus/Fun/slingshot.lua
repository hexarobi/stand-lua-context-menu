local force = {
    vector={x=0, y=150, z=35},
    offset={x=0, y=0, z=0},
    force_type=1,
    bone_index=0,
    is_local=true,
    ignore_up_vec=true,
    is_mass_relative=true,
}

return {
    name="Slingshot",
    help="Send the vehicle flying",
    applicable_to={"VEHICLE"},
    execute=function(target)
        if entities.request_control(target.handle) then
            ENTITY.APPLY_FORCE_TO_ENTITY(
                target.handle, force.force_type,
                force.vector.x, force.vector.y, force.vector.z,
                force.offset.x, force.offset.y, force.offset.z,
                force.bone_index, force.is_local,
                force.ignore_up_vec, force.is_mass_relative,
                true, true
            )
            util.toast("Sending vehicle flying!")
        end
    end,
    config_menu=function(menu_root)
        menu_root:slider_float("X", {"cmslingx"}, "", -25000, 25000, math.floor(force.vector.x * 100), 1, function(value)
            force.vector.x = value / 100
        end)
        menu_root:slider_float("Y", {"cmslingy"}, "", -25000, 25000, math.floor(force.vector.y * 100), 1, function(value)
            force.vector.y = value / 100
        end)
        menu_root:slider_float("Z", {"cmslingz"}, "", -25000, 25000, math.floor(force.vector.z * 100), 1, function(value)
            force.vector.z = value / 100
        end)
    end
}