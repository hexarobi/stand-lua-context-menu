return {
    name="Destroy",
    help="Explode the vehicle",
    applicable_to={"VEHICLE"},
    hotkey="X",
    execute=function(target)
        local car = ENTITY.GET_ENTITY_COORDS(target.handle)
        FIRE.ADD_EXPLOSION(car.x, car.y, car.z, 7, 5000, false, true, 0.0, false)
    end
}