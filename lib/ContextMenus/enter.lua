return {
    name="Enter",
    help="Attempt to drive or ride in any available seat of the selected vehicle",
    applicable_to={"VEHICLE"},
    hotkey="RETURN",
    execute=function(target)
        util.toast("Entering "..target.name)
        if VEHICLE.IS_VEHICLE_SEAT_FREE(target.handle, -1) then
            PED.SET_PED_INTO_VEHICLE(PLAYER.PLAYER_PED_ID(), target.handle, -1)
        else
            PED.SET_PED_INTO_VEHICLE(PLAYER.PLAYER_PED_ID(), target.handle, -2)
        end
    end
}