return {
    name="Player Menu",
    help="Opens the Stand menu for this Player",
    applicable_to={"PLAYER"},
    hotkey="M",
    execute=function(target)
        if target.player_id then
            menu.trigger_commands("p "..PLAYER.GET_PLAYER_NAME(target.player_id))
        else
            util.toast("Invalid player id: "..tostring(target.player_id))
        end
    end
}
