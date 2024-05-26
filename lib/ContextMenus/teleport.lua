
local config = {
    include_vehicle=true,
    teleport_to_ground_z=false,
}

local function find_ground_z(position, timeout)
    if timeout == nil then timeout = 100 end
    local success = false
    local max_ground_z = 1000
    local ground_z = max_ground_z
    local counter = 0
    while success == false and counter < timeout do
        success, ground_z = util.get_ground_z(position.x, position.y, max_ground_z)
        counter = counter + 1
        util.yield()
    end
    if ground_z < max_ground_z then
        return ground_z
    end
end

return {
    name="Teleport",
    help="Teleport to location",
    priority=1,
    hotkey="T",
    --applicable_to={"COORDS"},
    execute=function(target)
        if target.type == "PLAYER" then
            menu.trigger_commands("tp"..target.name)
            return
        end
        local teleport_position = {x=target.pos.x, y=target.pos.y, z=target.pos.z}
        if config.teleport_to_ground_z then
            local ground_z = find_ground_z(target.pos, 100)
            if ground_z then
                target.pos.z = ground_z
            else
                util.toast("Invalid teleport position")
                return
            end
        end
        util.log("Teleporting to "..teleport_position.x..", "..teleport_position.y..", "..teleport_position.z)
        local handle = players.user_ped()
        if config.include_vehicle and PED.IS_PED_IN_ANY_VEHICLE(players.user_ped()) then
            handle = PED.GET_VEHICLE_PED_IS_IN(players.user_ped(), false)
        end
        ENTITY.SET_ENTITY_COORDS(handle, teleport_position.x, teleport_position.y, teleport_position.z)
    end,
    config_menu=function(menu_root)
        menu_root:toggle("Include Vehicle", {}, "If inside a vehicle, then teleport the vehicle as well", function(value)
            config.include_vehicle = value
        end, config.include_vehicle)
        menu_root:toggle("Teleport to Roof", {}, "Teleport to highest safe ground position", function(value)
            config.teleport_to_ground_z = value
        end, config.teleport_to_ground_z)
    end
}
