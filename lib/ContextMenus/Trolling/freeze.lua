local modes={
    freeze={
        name="Freeze",
        help="Lock entity in current position"
    },
    unfreeze={
        name="Unfreeze",
        help="Unlock entity position to allow movement"
    }
}

local frozen_handles = {}

local function is_handle_frozen(handle)
    for frozen_handle_index, frozen_handle in frozen_handles do
        if handle == frozen_handle then
            return frozen_handle_index
        end
    end
    return false
end

local function add_handle_to_frozen_list(handle)
    table.insert(frozen_handles, handle)
end

local function remove_handle_from_frozen_list(handle)
    table.remove(frozen_handles, is_handle_frozen(handle))
end

return {
    name="Freeze",
    help="Freeze entity in position",
    applicable_to={"VEHICLE", "OBJECT", "PED", "WORLD_OBJECT"},
    execute=function(target)
        if is_handle_frozen(target.handle) then
            if entities.request_control(target.handle) then
                ENTITY.FREEZE_ENTITY_POSITION(target.handle, false)
                remove_handle_from_frozen_list(target.handle)
            end
        else
            if entities.request_control(target.handle) then
                ENTITY.FREEZE_ENTITY_POSITION(target.handle, true)
                add_handle_to_frozen_list(target.handle)
            end
        end
    end,
    on_open=function(target, option)
        if is_handle_frozen(target.handle) then
            option.name = modes.unfreeze.name
            option.help = modes.unfreeze.help
        else
            option.name = modes.freeze.name
            option.help = modes.freeze.help
        end
    end,
}