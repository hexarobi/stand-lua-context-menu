return {
    name="Cat",
    help="Spawn a cat at location",
    applicable_to={"COORDS"},
    execute=function(target)
        local model_hash = util.joaat("a_c_cat_01")
        util.request_model(model_hash)
        local cat = entities.create_ped(28, model_hash, target.pos, 0)
        util.toast("Spawning a cat at "..target.pos.x..","..target.pos.y.." handle: "..cat)
        TASK.TASK_WANDER_STANDARD(cat, 10.0, 10)
    end
}