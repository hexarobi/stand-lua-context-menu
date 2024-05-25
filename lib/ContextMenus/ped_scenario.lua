local config = {
    chain_scenario = false
}

local modes={
    normal={
        name="Ped Scenario",
        help="Trigger the nearest applicable ped scenario"
    },
    in_use={
        name="Cancel Scenario",
        help="Cancel current ped scenario"
    }
}

local function get_handle(target)
    if target.type == "COORDS" then
        return players.user_ped()
    else
        return target.handle
    end
end

local function is_scenario_active(handle)
    return TASK.PED_HAS_USE_SCENARIO_TASK(handle) or TASK.IS_PED_ACTIVE_IN_SCENARIO(handle)
end

return {
    name=modes.normal.name,
    help=modes.normal.help,
    applicable_to={"COORDS", "PED"},
    execute=function(target)
        local handle = get_handle(target)
        if is_scenario_active(handle) then
            TASK.CLEAR_PED_TASKS_IMMEDIATELY(handle)
        else
            TASK.CLEAR_PED_TASKS_IMMEDIATELY(handle)
            if config.chain_scenario then
                TASK.TASK_USE_NEAREST_SCENARIO_CHAIN_TO_COORD(
                        handle, target.pos.x, target.pos.y, target.pos.z, 20.0, 0
                )
            else
                TASK.TASK_USE_NEAREST_SCENARIO_TO_COORD(
                        handle, target.pos.x, target.pos.y, target.pos.z, 20.0, 0
                )
            end
        end
    end,
    on_open=function(target, option)
        local handle = get_handle(target)
        if is_scenario_active(handle) then
            option.name = modes.in_use.name
            option.help = modes.in_use.help
        else
            option.name = modes.normal.name
            option.help = modes.normal.help
        end
    end,
    config_menu=function(menu_root)
        menu_root:toggle("Chain Scenario", {}, "Attempt to chain scenarios together", function(value)
            config.chain_scenario = value
        end, config.chain_scenario)
    end
}
