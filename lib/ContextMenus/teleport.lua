return {
    name="Teleport",
    help="Teleport to location",
    priority=1,
    hotkey="T",
    --applicable_to={"COORDS"},
    execute=function(target)
        ENTITY.SET_ENTITY_COORDS(players.user_ped(), target.pos.x, target.pos.y, target.pos.z)
    end
}