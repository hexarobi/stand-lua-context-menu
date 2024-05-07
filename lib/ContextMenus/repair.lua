
--local function request_control_once(entity)
--    if not NETWORK.NETWORK_IS_IN_SESSION() then
--        return true
--    end
--    local netId = NETWORK.NETWORK_GET_NETWORK_ID_FROM_ENTITY(entity)
--    NETWORK.SET_NETWORK_ID_CAN_MIGRATE(netId, true)
--    return NETWORK.NETWORK_REQUEST_CONTROL_OF_ENTITY(entity)
--end
--
--local function request_control(entity, timeout)
--    if not ENTITY.DOES_ENTITY_EXIST(entity) then
--        return false
--    end
--    local end_time = util.current_time_millis() + (timeout or 500)
--    repeat util.yield_once() until request_control_once(entity) or util.current_time_millis() >= end_time
--    return request_control_once(entity)
--end

return {
    name="Repair",
    help="Removes all damage and restores the vehicle to a driveable state",
    applicable_to={"VEHICLE"},
    execute=function(target)
        local vehicle = target.handle
        if entities.request_control(vehicle) then
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