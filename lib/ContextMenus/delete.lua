return {
    name="Delete",
    help="Removes the selected object",
    applicable_to={"PED", "VEHICLE", "OBJECT"},
    hotkey="BACKSPACE",
    execute=function(target)
        util.toast("Deleting object "..target.name)
        entities.delete(target.handle)
    end
}