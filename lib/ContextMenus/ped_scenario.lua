local modes={
    normal={
        name="Ped Scenario",
        help="Trigger the nearest applicable ped scenario"
    },
    in_use={
        name="Cancel Scenario",
        help="Cancelw current ped scenario"
    }
}

local function get_handle(target)
    if target.type == "COORDS" then
        return players.user_ped()
    else
        return target.handle
    end
end

return {
    name=modes.normal.name,
    help=modes.normal.help,
    applicable_to={"COORDS", "PED"},
    execute=function(target)
        local handle = get_handle(target)
        if TASK.PED_HAS_USE_SCENARIO_TASK(handle) then
            TASK.CLEAR_PED_TASKS_IMMEDIATELY(handle)
        else
            TASK.CLEAR_PED_TASKS_IMMEDIATELY(handle)
            TASK.TASK_USE_NEAREST_SCENARIO_TO_COORD(
                handle, target.pos.x, target.pos.y, target.pos.z, 20.0, 0
            )
        end
    end,
    on_open=function(target, option)
        local handle = get_handle(target)
        if TASK.PED_HAS_USE_SCENARIO_TASK(handle) then
            option.name = modes.in_use.name
            option.help = modes.in_use.help
        else
            option.name = modes.normal.name
            option.help = modes.normal.help
        end
    end
}