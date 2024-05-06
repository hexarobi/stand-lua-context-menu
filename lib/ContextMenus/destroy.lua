
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
    name="Destroy",
    help="Explode the vehicle",
    author="Hexarobi",
    applicable_to={"VEHICLE"},
    execute=function(target)
        local car = ENTITY.GET_ENTITY_COORDS(target.handle)
        FIRE.ADD_EXPLOSION(car.x, car.y, car.z, 81, 5000, false, true, 0.0, false)
    end
}