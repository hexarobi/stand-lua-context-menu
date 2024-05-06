
local function get_control_of_vehicle(vehicle)
    if NETWORK.NETWORK_HAS_CONTROL_OF_ENTITY(vehicle) then
        return vehicle
    end
    -- Loop until we get control
    local netid = NETWORK.NETWORK_GET_NETWORK_ID_FROM_ENTITY(vehicle)
    local has_control_ent = false
    local loops = 15
    NETWORK.SET_NETWORK_ID_CAN_MIGRATE(netid, true)

    while not has_control_ent do
        has_control_ent = NETWORK.NETWORK_REQUEST_CONTROL_OF_ENTITY(vehicle)
        loops = loops - 1
        util.yield(15)
        if loops <= 0 then
            break
        end
    end
end

return {
    name="Repair",
    help="Removes all damage and restores the vehicle to a driveable state",
    author="Hexarobi",
    applicable_to={"VEHICLE"},
    execute=function(target)
        local vehicle = target.handle
        if get_control_of_vehicle(vehicle) then
            VEHICLE.SET_VEHICLE_FIXED(vehicle)
            FIRE.STOP_ENTITY_FIRE(vehicle)
            -- Also repair vehicle if its been destroyed by water
            VEHICLE.SET_VEHICLE_DIRT_LEVEL(vehicle, 0.0)
            VEHICLE.SET_VEHICLE_UNDRIVEABLE(vehicle, false)
            VEHICLE.SET_VEHICLE_ENGINE_HEALTH(vehicle, 1000.0)
            VEHICLE.SET_VEHICLE_PETROL_TANK_HEALTH(vehicle, 1000.0)
            VEHICLE.SET_VEHICLE_ENGINE_ON(vehicle, true, true, true)
        end
    end
}