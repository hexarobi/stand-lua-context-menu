return {
    name="Teleport",
    help="Teleport to location",
    priority=1,
    hotkey="T",
    --applicable_to={"COORDS"},
    execute=function(target)
        if (target.pos.x == 0 and target.pos.y == 0) or target.pos.z < 0 then
            util.toast("Invalid target position")
        else
            util.log("Teleporting to "..target.pos.x..", "..target.pos.y..", "..target.pos.z)
            ENTITY.SET_ENTITY_COORDS(players.user_ped(), target.pos.x, target.pos.y, target.pos.z)
        end
    end
}