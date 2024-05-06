
local function request_control_once(entity)
    if not NETWORK.NETWORK_IS_IN_SESSION() then
        return true
    end
    local netId = NETWORK.NETWORK_GET_NETWORK_ID_FROM_ENTITY(entity)
    NETWORK.SET_NETWORK_ID_CAN_MIGRATE(netId, true)
    return NETWORK.NETWORK_REQUEST_CONTROL_OF_ENTITY(entity)
end

local function request_control(entity, timeout)
    if not ENTITY.DOES_ENTITY_EXIST(entity) then
        return false
    end
    local end_time = util.current_time_millis() + (timeout or 500)
    repeat util.yield_once() until request_control_once(entity) or util.current_time_millis() >= end_time
    return request_control_once(entity)
end

return {
    name="Flip Over",
    help="Roll vehicle over",
    author="Hexarobi",
    applicable_to={"VEHICLE"},
    execute=function(target)
        util.toast("Flipping "..target.name)
        --ENTITY.FREEZE_ENTITY_POSITION(target.handle, true)
        local rotation = ENTITY.GET_ENTITY_ROTATION(target.handle, 2)

        if request_control(target.handle, 1000) then

            local new_y = 0
            util.log("rotation "..rotation.y)
            if math.abs(rotation.y) < 90 then
                new_y = 180.0
            end
            util.log("new y = "..new_y)
            --ENTITY.SET_ENTITY_ROTATION(target.handle, rotation.x, new_y, rotation.z, 2, true)
            ENTITY.APPLY_FORCE_TO_ENTITY(target.handle, 1, 0.0, 0.0, 10.71, 5.0, 0.0, 0.0, 1, false, true, true, true, true)

            --ENTITY.APPLY_FORCE_TO_ENTITY(target.handle, 1, 0.0, 0.0, 10.71, 5.0, 0.0, 0.0, 1, false, true, true, true, true)
            --OBJECT.PLACE_OBJECT_ON_GROUND_PROPERLY(target.handle)
        end

        --ENTITY.FREEZE_ENTITY_POSITION(target.handle, false)
    end
}