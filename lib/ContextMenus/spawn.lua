
local function spawn_vehicle_at_position(model_name, pos, heading)
    if model_name == nil or type(model_name) ~= "string" then return nil end
    local model = util.joaat(model_name)
    if STREAMING.IS_MODEL_VALID(model) and STREAMING.IS_MODEL_A_VEHICLE(model) then
        util.request_model(model)
        local vehicle = entities.create_vehicle(model, pos, heading)
        STREAMING.SET_MODEL_AS_NO_LONGER_NEEDED(model)
        return vehicle
    end
end

return {
    name="Spawn",
    help="Spawn a vehicle at location",
    applicable_to={"COORDS"},
    execute=function(target)
        util.toast("Spawning at ")--..target.coords)
        spawn_vehicle_at_position("adder", target.pos, 0)
    end
}