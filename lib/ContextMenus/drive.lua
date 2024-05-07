return {
    name="Drive",
    help="Attempt to drive the selected vehicle",
    applicable_to={"VEHICLE"},
    execute=function(target)
        util.toast("Driving "..target.name)
        PED.SET_PED_INTO_VEHICLE(PLAYER.PLAYER_PED_ID(), target.handle, -1)
    end
}