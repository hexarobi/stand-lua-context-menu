return {
    name="Enter",
    help="Attempt to ride in any available seat of the selected vehicle",
    author="Hexarobi",
    applicable_to={"VEHICLE"},
    execute=function(target)
        util.toast("Entering "..target.name)
        PED.SET_PED_INTO_VEHICLE(PLAYER.PLAYER_PED_ID(), target.handle, -2)
    end
}