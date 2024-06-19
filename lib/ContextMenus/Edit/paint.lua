local constants = require("context_menu/constants")
local vehicle_utils = require("context_menu/vehicle_utils")

local config = {
    included_colors={
        'MatteWhite',
        'UtilBlue',
        'UtilGreen',
        'MetallicBlack',
        'MetallicTaxiYellow',
        'UtilLightBrown',
        'MatteOliveDrab',
        'UtilOrange',
        'HotPink',
        'MattePurple',
    }
}

local function build_color_vector(color)
    local vector = vehicle_utils.color_hex_to_vector(color.hex)
    vector.a = 0.9
    return vector
end

local function build_color_items()
    local items = {}
    for _, color in constants.VEHICLE_COLORS do
        if table.contains(config.included_colors, color.name) then
            local item = {
                name=color.friendly_name or color.name,
                help="Paint "..color.name,
                applicable_to={"VEHICLE"},
                color=build_color_vector(color),
                execute=function(target)
                    local vehicle = target.handle
                    if entities.request_control(vehicle) then
                        vehicle_utils.set_vehicle_colors(vehicle, color, color)
                        util.toast("Painting vehicle "..color.name)
                    end
                end
            }
            table.insert(items, item)
        end
    end
    return items
end

return {
    name="Paint",
    help="Paint the vehicle",
    applicable_to={"VEHICLE"},
    items={
        {
            name="Random Paint",
            help="Paint the vehicle a random color",
            applicable_to={"VEHICLE"},
            execute=function(target)
                local vehicle = target.handle
                if entities.request_control(vehicle) then
                    local color = vehicle_utils.get_random_vehicle_color()
                    vehicle_utils.set_vehicle_colors(vehicle, color, color)
                    util.toast("Painting vehicle "..color.name)
                end
            end
        },
        {
            name="Colors",
            help="Select a specific color",
            applicable_to={"VEHICLE"},
            items=build_color_items()
        }
    }
}