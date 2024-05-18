return {
    name="Player Menu",
    help="Opens the Stand menu for this Player",
    applicable_to={"PLAYER"},
    hotkey="M",
    execute=function(target)
        menu.trigger_commands("p "..target.name)
    end
}