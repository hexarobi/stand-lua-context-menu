
local vehicle_utils = require("context_menu/vehicle_utils")

local function sort_items_by_name(items)
    table.sort(items, function(a, b)
        if a.name:lower() ~= b.name:lower() then
            return a.name:lower() < b.name:lower()
        end
        if a.model~= nil and b.model ~= nil and a.model:lower() ~= b.model:lower() then
            return a.model:lower() < b.model:lower()
        end
    end)
    for _, item in items do
        if item.items ~= nil then
            sort_items_by_name(item.items)
        end
    end
end

local function spawn_item(target)
    local item = target.selected_option
    util.toast("Spawning "..item.name)
    local camera_rotation = CAM.GET_FINAL_RENDERED_CAM_ROT(2)
    vehicle_utils.spawn_vehicle_at_position(item.model, target.pos, camera_rotation.z)
end

local function build_vehicles_items()
    local vehicles_items_by_class = {}
    for _, vehicle in pairs(util.get_vehicles()) do
        local item = {
            name = util.get_label_text(VEHICLE.GET_DISPLAY_NAME_FROM_VEHICLE_MODEL(util.joaat(vehicle.name))),
            model = vehicle.name,
            class = lang.get_localised(vehicle.class) or "Unknown",
            execute = spawn_item,
            applicable_to = {"COORDS"},
        }
        if util.get_label_text(vehicle.manufacturer) ~= "NULL" then
            item.manufacturer = util.get_label_text(vehicle.manufacturer)
        else
            item.manufacturer = ""
        end
        item.help = "Spawn a "..item.manufacturer.." "..item.name
        if vehicles_items_by_class[item.class] == nil then
            vehicles_items_by_class[item.class] = {
                name=item.class,
                help="Browse "..item.class,
                items={},
            }
        end
        table.insert(vehicles_items_by_class[item.class].items, item)
    end

    local vehicles_items = {}
    for _, class_item in vehicles_items_by_class do
        table.insert(vehicles_items, class_item)
    end
    sort_items_by_name(vehicles_items)
    return vehicles_items
end

return {
    name="Vehicle Class",
    help="Spawn a vehicle by class",
    applicable_to={"COORDS"},
    items=build_vehicles_items()
}
