-- Vehicle Utils

local constants = require("context_menu/constants")
local vehicle_utils = {}
local CONSTRUCTS_DIR = filesystem.stand_dir() .. 'Constructs\\ContextMenu Saves\\'

vehicle_utils.spawn_vehicle_at_position = function(model_name, position, heading)
    if model_name == nil or type(model_name) ~= "string" then return nil end
    local model = util.joaat(model_name)
    if STREAMING.IS_MODEL_VALID(model) and STREAMING.IS_MODEL_A_VEHICLE(model) then
        util.request_model(model)
        local vehicle = entities.create_vehicle(model, position, heading)
        STREAMING.SET_MODEL_AS_NO_LONGER_NEEDED(model)
        return vehicle
    end
end

vehicle_utils.spawn_vehicle_for_player = function(pid, model_name, offset)
    local target_ped = PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(pid)
    if offset == nil then offset = {x=0, y=5.5, z=0.5} end
    local pos = ENTITY.GET_OFFSET_FROM_ENTITY_IN_WORLD_COORDS(target_ped, offset.x, offset.y, offset.z)
    local heading = ENTITY.GET_ENTITY_HEADING(target_ped)
    return vehicle_utils.spawn_vehicle_at_position(model_name, pos, heading)
end


vehicle_utils.table_copy = function(obj)
    if type(obj) ~= 'table' then
        return obj
    end
    local res = setmetatable({}, getmetatable(obj))
    for k, v in pairs(obj) do
        res[vehicle_utils.table_copy(k)] = vehicle_utils.table_copy(v)
    end
    return res
end

vehicle_utils.str_starts_with = function(String,Start)
    return string.sub(String,1,string.len(Start))==Start
end

vehicle_utils.get_vehicle_name = function(handle)
    local model = vehicle_utils.get_model_hash(handle)
    return util.get_label_text(VEHICLE.GET_DISPLAY_NAME_FROM_VEHICLE_MODEL(model))
end

-- credit to the amazing aarroonn
vehicle_utils.get_model_hash = function(handle_or_ptr)
    if handle_or_ptr < 0xFFFFFF then
        handle_or_ptr = entities.handle_to_pointer(handle_or_ptr)
    end
    local model_info = memory.read_long(handle_or_ptr + 0x20)
    if model_info ~= 0 then
        return memory.read_int(model_info + 0x18)
    end
end

---
--- Spawn Vehicle
---

vehicle_utils.spawn_shuffled_vehicle_at_position = function(vehicle_model_name, position, heading)
    --cc_utils.debug_log("Spawning vehicle "..vehicle_model_name)
    -- If vehicle model is nil or empty, or is a group name, then get a random vehicle model
    local new_vehicle_model_name = vehicle_utils.get_random_vehicle_model(vehicle_model_name)
    if new_vehicle_model_name then
        vehicle_model_name = new_vehicle_model_name
    end
    local vehicle = vehicle_utils.spawn_vehicle_at_position(vehicle_model_name, position, heading)
    if vehicle then
        vehicle_utils.set_all_mods_to_random(vehicle)
        vehicle_utils.randomize_livery(vehicle)
        vehicle_utils.set_performance_tuning_max(vehicle)
        vehicle_utils.set_plate_for_player(vehicle, players.user())
        return vehicle
    end

end


---
--- Constructor Lib
---

vehicle_utils.require_dependency = function(dependency_path)
    local dep_status, required_dep = pcall(require, dependency_path)
    if not dep_status then
        util.log("Could not load "..dependency_path..": "..required_dep)
    else
        return required_dep
    end
end

vehicle_utils.require_constructor_lib = function()
    local constructor_lib = vehicle_utils.require_dependency("constructor/constructor_lib")
    if not constructor_lib then
        util.toast("This command relies on constructor_lib. Please install Constructor to use this command.", TOAST_ALL)
        return
    end
    return constructor_lib
end

vehicle_utils.create_construct_from_handle = function(handle)
    local constructor_lib = vehicle_utils.require_constructor_lib()
    if not constructor_lib then return end
    return constructor_lib.create_construct_from_handle(handle)
end

vehicle_utils.save_construct = function(construct)
    local constructor_lib = vehicle_utils.require_constructor_lib()
    if not constructor_lib then return end
    constructor_lib.default_attachment_attributes(construct)
    return constructor_lib.save_construct(construct, CONSTRUCTS_DIR)
end

vehicle_utils.spawn_construct = function(construct)
    local constructor_lib = vehicle_utils.require_constructor_lib()
    if not constructor_lib then return end
    constructor_lib.spawn_construct(construct)
end

vehicle_utils.spawn_construct_for_player = function(pid, construct)
    local constructor_lib = vehicle_utils.require_constructor_lib()
    if not constructor_lib then return end
    if type(construct) ~= "table" then error("Construct must be a table") end
    if construct.model == nil then error("Construct must have a model") end
    construct.handle = vehicle_utils.spawn_vehicle_for_player(pid, construct.model)
    constructor_lib.deserialize_vehicle_attributes(construct)
end

vehicle_utils.apply_favorite_to_current_vehicle = function(pid, vehicle_handle)
    local constructor_lib = vehicle_utils.require_constructor_lib()
    if not constructor_lib then return end
    local fav_vehicle = user_db.get_user_vehicle(pid)
    if fav_vehicle then
        local construct = vehicle_utils.create_construct_from_handle(vehicle_handle)
        construct.vehicle_attributes = fav_vehicle.vehicle_attributes
        constructor_lib.deserialize_vehicle_attributes(construct)
        return true
    end
end


---
--- Random Vehicles
---

local class_keys = {
    "off_road", "sport_classic", "military", "compacts", "sport", "muscle", "motorcycle", "open_wheel",
    "super", "van", "suv", "commercial", "plane", "sedan", "service", "industrial", "helicopter", "boat",
    "utility", "emergency", "cycle", "coupe", "rail"
}
local class_aliases = {
    offroad="off_road",
    classic="sport_classic",
    sportclassic="sport_classic",
    bike="cycle",
    openwheel="open_wheel",
}
local non_car_classes = {
    "plane", "helicopter", "boat", "motorcycle", "cycle", "rail", "industrial", "commercial", "emergency", "service",
}

local find_class_name = function(key)
    --return lang.get_string(vehicle.class):lower():gsub(" ", ""):gsub("-", "")
    for _, class_key in class_keys do
        if key == util.joaat(class_key) then
            return class_key
        end
    end
end

local function build_random_vehicles()
    local blocked_random_vehicles = {
        "kosatka", "cargoplane", "cargoplane2", "blimp", "blimp2", "blimp3", "alkonost", "armytanker",
        "armytrailer", "armytrailer2", "baletrailer", "boattrailer", "boattrailer2", "boattrailer3", "docktrailer",
        "freighttrailer", "graintrailer", "proptrailer", "raketrailer", "trailerlarge", "trailerlogs",
        "trailers", "trailers2", "trailers3", "trailers4", "trailers5", "trailersmall", "trailersmall2", "tvtrailer", "tvtrailer2",
        "coach", "tr2", "tr3", "tr4", "trflat",
    }
    vehicle_utils.random_vehicles = {
        all={},
        car={},
    }
    for _, vehicle in util.get_vehicles() do
        if not table.contains(blocked_random_vehicles, vehicle.name) then
            table.insert(vehicle_utils.random_vehicles.all, vehicle.name)
            local class_name = find_class_name(vehicle.class)
            if vehicle_utils.random_vehicles[class_name] == nil then vehicle_utils.random_vehicles[class_name] = {} end
            table.insert(vehicle_utils.random_vehicles[class_name], vehicle.name)
            if not table.contains(non_car_classes, class_name) then
                table.insert(vehicle_utils.random_vehicles.car, vehicle.name)
            end
        end
    end
end
build_random_vehicles()
--cc_utils.debug_log("Random vehicles: "..inspect(vehicle_utils.random_vehicles))

vehicle_utils.get_random_vehicle_model = function(category)
    if category == nil or category == "" then category = "car" end
    if class_aliases[category] ~= nil then category = class_aliases[category] end
    local vehicle_list = vehicle_utils.random_vehicles[category]
    if vehicle_list ~= nil then
        local vehicle = vehicle_list[math.random(#vehicle_list)]
        return vehicle
    end
end

vehicle_utils.apply_vehicle_model_name_shortcuts = function(vehicle_model_name)
    if constants.spawn_aliases[vehicle_model_name] then
        return constants.spawn_aliases[vehicle_model_name]
    end
    return vehicle_model_name
end

---
--- Vehicle Paint
---

vehicle_utils.get_vehicle_color_from_command = function(command)
    for _, vehicle_color in pairs(constants.VEHICLE_COLORS) do
        if vehicle_color.index == tonumber(command) or vehicle_color.name:lower() == command then
            return vehicle_color
        end
    end
end

vehicle_utils.set_extra_color = function(vehicle, pearl_color, wheel_color)
    local current_pearl_color = memory.alloc(8)
    local current_wheel_color = memory.alloc(8)
    VEHICLE.GET_VEHICLE_EXTRA_COLOURS(vehicle, current_pearl_color, current_wheel_color)
    pearl_color = vehicle_utils.get_vehicle_color_from_command(pearl_color)
    wheel_color = vehicle_utils.get_vehicle_color_from_command(wheel_color)
    if pearl_color == nil then pearl_color = {index=current_pearl_color} end
    if wheel_color == nil then wheel_color = {index=current_wheel_color} end
    VEHICLE.SET_VEHICLE_EXTRA_COLOURS(vehicle, pearl_color.index, wheel_color.index)
end

vehicle_utils.apply_random_paint = function(vehicle_handle)
    -- Dont apply custom paint to emergency vehicles
    if VEHICLE.GET_VEHICLE_CLASS(vehicle_handle) == constants.VEHICLE_CLASSES.EMERGENCY then
        return
    end
    local main_color = vehicle_utils.get_random_vehicle_color()
    vehicle_utils.set_vehicle_colors(vehicle_handle, main_color, main_color)
end

local function dec_to_hex(input)
    return ('%X'):format(input)
end

vehicle_utils.color_rgb_to_hex = function(rgb_color)
    return dec_to_hex(rgb_color.r) .. dec_to_hex(rgb_color.g) .. dec_to_hex(rgb_color.b)
end

vehicle_utils.color_hex_to_rgb = function(hexcode)
    return {
        name="#"..hexcode,
        hex="#"..hexcode,
        r=tonumber(string.sub(hexcode, 1, 2),16),
        g=tonumber(string.sub(hexcode, 3, 4),16),
        b=tonumber(string.sub(hexcode, 5, 6),16)
    }
end

vehicle_utils.find_vehicle_color_by_name = function(color_name)
    if constants.VEHICLE_COLOR_ALIASES[color_name] ~= nil then
        color_name = constants.VEHICLE_COLOR_ALIASES[color_name]
    end
    for _, vehicle_color in constants.VEHICLE_COLORS do
        if vehicle_color.name:lower() == color_name:lower() or vehicle_color.index == tonumber(color_name) then
            return vehicle_utils.table_copy(vehicle_color)
        end
    end
end

vehicle_utils.get_command_color = function(command)
    if vehicle_utils.str_starts_with(command, "#") then
        return vehicle_utils.color_hex_to_rgb(command:sub(2))
    end
    return vehicle_utils.find_vehicle_color_by_name(command)
end

vehicle_utils.get_random_vehicle_color = function ()
    return vehicle_utils.table_copy(constants.VEHICLE_COLORS[math.random(1, #constants.VEHICLE_COLORS)])
end

vehicle_utils.set_vehicle_colors = function(vehicle, main_color, secondary_color)
    if main_color.index ~= nil and secondary_color and secondary_color.index ~= nil then
        vehicle_utils.debug_log("Painting vehicle stock color "..main_color.name)
        VEHICLE.CLEAR_VEHICLE_CUSTOM_PRIMARY_COLOUR(vehicle)
        VEHICLE.CLEAR_VEHICLE_CUSTOM_SECONDARY_COLOUR(vehicle)
        VEHICLE.SET_VEHICLE_COLOURS(vehicle, main_color.index, secondary_color.index)
    else
        if main_color.index ~= nil then
            vehicle_utils.debug_log("Painting vehicle color "..main_color.name)
            VEHICLE.SET_VEHICLE_MOD_COLOR_1(vehicle, main_color.paint_type, main_color.index, 0)
            VEHICLE.SET_VEHICLE_COLOURS(vehicle, main_color.index, main_color.index)
            VEHICLE.CLEAR_VEHICLE_CUSTOM_PRIMARY_COLOUR(vehicle)
            VEHICLE.CLEAR_VEHICLE_CUSTOM_SECONDARY_COLOUR(vehicle)
        elseif main_color.r ~= nil then
            vehicle_utils.debug_log("Painting vehicle custom color "..main_color.hex)
            VEHICLE.SET_VEHICLE_CUSTOM_PRIMARY_COLOUR(vehicle, main_color.r, main_color.g, main_color.b)
            VEHICLE.SET_VEHICLE_MOD_COLOR_1(vehicle, main_color.paint_type or 0, 0, 0)
        end
        if secondary_color and secondary_color.index ~= nil then
            vehicle_utils.debug_log("Painting vehicle secondary color "..secondary_color.name)
            VEHICLE.SET_VEHICLE_MOD_COLOR_2(vehicle, secondary_color.paint_type or 0, secondary_color.index, 0)
            VEHICLE.CLEAR_VEHICLE_CUSTOM_SECONDARY_COLOUR(vehicle)
        elseif secondary_color and secondary_color.r ~= nil then
            vehicle_utils.debug_log("Painting vehicle secondary custom color "..secondary_color.hex)
            VEHICLE.SET_VEHICLE_CUSTOM_SECONDARY_COLOUR(vehicle, secondary_color.r, secondary_color.g, secondary_color.b)
            VEHICLE.SET_VEHICLE_MOD_COLOR_2(vehicle, secondary_color.paint_type or 0, 0, 0)
        end
    end
end

local function get_color_command_message(color_command)
    if color_command.name then
        return color_command.name
    else
        return color_command.hex:lower()
    end
end

local function build_color_messages(main_color, secondary_color)
    if main_color == secondary_color then
        return get_color_command_message(main_color)
    else
        return get_color_command_message(main_color) .. " and " .. get_color_command_message(secondary_color)
    end
end

vehicle_utils.set_vehicle_paint = function(pid, vehicle, commands)
    local main_color
    local secondary_color
    local paint_type
    if commands and commands[2] then
        for i, command in ipairs(commands) do
            if not main_color then
                main_color = vehicle_utils.get_command_color(command)
                --if command_color then
                --    main_color = command_color
                ----    if command_color.a then
                ----        paint_type = get_paint_type(command_color.a)
                ----    end
                --end
            end
            if command == "and" and vehicle_utils.get_command_color(commands[i+1]) then
                secondary_color = vehicle_utils.get_command_color(commands[i+1])
            end
            --if command == "compliment" then
            --    secondary_color = colorsRGB.COMPLIMENT(main_color)
            --end
            local command_paint_type = constants.VEHICLE_PAINT_TYPES[command:upper()]
            if command_paint_type then
                paint_type = command_paint_type
            end
        end
        if not secondary_color then
            secondary_color = main_color
        end
        if not main_color then
            cc_utils.help_message(pid, "Paint color not found")
            return
        end
        cc_utils.help_message(pid, "Painting vehicle "..build_color_messages(main_color, secondary_color))
    else
        main_color = vehicle_utils.get_random_vehicle_color()
        cc_utils.help_message(pid, "Painting vehicle random color: "..main_color.name)
    end
    --if paint_type == nil then
    --    paint_type = main_color.paint_type
    --end
    vehicle_utils.set_vehicle_colors(vehicle, main_color, secondary_color)
    --VEHICLE.SET_VEHICLE_MOD(vehicle, constants.VEHICLE_MOD_TYPES.MOD_LIVERY, -1)
end

vehicle_utils.randomize_livery = function(vehicle)
    vehicle_utils.set_mod_to_random(vehicle, constants.VEHICLE_MOD_TYPES.MOD_LIVERY)
end

---
--- Performance
---

vehicle_utils.set_performance_tuning_max = function(vehicle)
    vehicle_utils.set_mod_to_max(vehicle, constants.VEHICLE_MOD_TYPES.MOD_ENGINE)
    vehicle_utils.set_mod_to_max(vehicle, constants.VEHICLE_MOD_TYPES.MOD_TRANSMISSION)
    vehicle_utils.set_mod_to_max(vehicle, constants.VEHICLE_MOD_TYPES.MOD_BRAKES)
    vehicle_utils.set_mod_to_max(vehicle, constants.VEHICLE_MOD_TYPES.MOD_ARMOR)
    vehicle_utils.set_mod_to_max(vehicle, constants.VEHICLE_MOD_TYPES.MOD_SPOILER)
    VEHICLE.TOGGLE_VEHICLE_MOD(vehicle, constants.VEHICLE_MOD_TYPES.MOD_TURBO, true)
    -- If few roof options, assume its a weapon and max it
    if VEHICLE.GET_NUM_VEHICLE_MODS(vehicle, constants.VEHICLE_MOD_TYPES.MOD_ROOF) < 5 then
        vehicle_utils.set_mod_to_max(vehicle, constants.VEHICLE_MOD_TYPES.MOD_ROOF)
    end
    VEHICLE.SET_VEHICLE_TYRES_CAN_BURST(vehicle, false)
end

---
--- Vehicle Mods
---

vehicle_utils.set_mod = function(vehicle, mod_index, mod_value)
    if mod_value == nil then
        local max_mod_value = VEHICLE.GET_NUM_VEHICLE_MODS(vehicle, mod_index) - 1
        mod_value = math.random(-1, max_mod_value)
    end
    if mod_value ~= nil then
        entities.set_upgrade_value(vehicle, mod_index, tonumber(mod_value))
        return mod_value
    end
end

vehicle_utils.set_all_mods_to_random = function(vehicle)
    VEHICLE.SET_VEHICLE_MOD_KIT(vehicle, 0)
    VEHICLE.SET_VEHICLE_WINDOW_TINT(vehicle, math.random(-1, constants.VEHICLE_MAX_OPTIONS.WINDOW_TINTS))
    for mod_name, mod_number in pairs(constants.VEHICLE_MOD_TYPES) do
        -- Don't randomize performance, wheels, or livery
        if not (mod_number == constants.VEHICLE_MOD_TYPES.MOD_ARMOR
                or mod_number == constants.VEHICLE_MOD_TYPES.MOD_TRANSMISSION
                or mod_number == constants.VEHICLE_MOD_TYPES.MOD_ENGINE
                or mod_number == constants.VEHICLE_MOD_TYPES.MOD_BRAKES
                or mod_number == constants.VEHICLE_MOD_TYPES.MOD_FRONTWHEELS
                or mod_number == constants.VEHICLE_MOD_TYPES.MOD_BACKWHEELS
                or mod_number == constants.VEHICLE_MOD_TYPES.MOD_LIVERY
        ) then
            vehicle_utils.set_mod_to_random(vehicle, mod_number)
        end
    end
    for mod_number = 17, 22 do
        if not (mod_number == constants.VEHICLE_MOD_TYPES.MOD_TURBO) then
            VEHICLE.TOGGLE_VEHICLE_MOD(vehicle, mod_number, math.random() > 0.5)
        end
    end
    VEHICLE.SET_VEHICLE_XENON_LIGHT_COLOR_INDEX(vehicle, math.random(-1, 12))
end

vehicle_utils.set_mod_to_max = function(vehicle, vehicle_mod)
    local max = entities.get_upgrade_max_value(vehicle, vehicle_mod)
    --util.log("Setting max mod "..vehicle_mod.." to "..max)
    entities.set_upgrade_value(vehicle, vehicle_mod, max)
end

vehicle_utils.set_mod_to_random = function(vehicle, vehicle_mod)
    local max = entities.get_upgrade_max_value(vehicle, vehicle_mod)
    if max > 0 then
        local rand_value = math.random(-1, max)
        entities.set_upgrade_value(vehicle, vehicle_mod, rand_value)
    end
end

vehicle_utils.set_all_mods_to_max = function(vehicle)
    --VEHICLE.SET_VEHICLE_MOD_KIT(vehicle, 0)
    --VEHICLE.SET_VEHICLE_WINDOW_TINT(vehicle, math.random(-1, constants.VEHICLE_MAX_OPTIONS.WINDOW_TINTS))
    for mod_name, mod_number in pairs(constants.VEHICLE_MOD_TYPES) do
        if mod_name ~= "MOD_LIVERY" then
            vehicle_utils.set_mod_to_max(vehicle, mod_number)
        end
    end
    for x = 17, 22 do
        VEHICLE.TOGGLE_VEHICLE_MOD(vehicle, x, true)
    end
    VEHICLE.SET_VEHICLE_TYRES_CAN_BURST(vehicle, false)
end

vehicle_utils.set_all_mods_to_min = function(vehicle)
    --VEHICLE.SET_VEHICLE_MOD_KIT(vehicle, 0)
    --VEHICLE.SET_VEHICLE_WINDOW_TINT(vehicle, math.random(-1, constants.VEHICLE_MAX_OPTIONS.WINDOW_TINTS))
    for mod_name, mod_number in pairs(constants.VEHICLE_MOD_TYPES) do
        entities.set_upgrade_value(vehicle, mod_number, -1)
    end
    for x = 17, 22 do
        VEHICLE.TOGGLE_VEHICLE_MOD(vehicle, x, false)
    end
end

---
--- Wheels
---

vehicle_utils.randomize_wheels = function(vehicle)
    vehicle_utils.set_wheels(vehicle)
end

vehicle_utils.set_wheels = function(vehicle, commands)
    local wheels = {
        name="",
        type=nil,
        kind=nil
    }
    if commands and commands[2] == "stock" and commands[3] == nil then
        commands[3] = "-1"
    end
    if commands and commands[2] then
        wheels.type = constants.VEHICLE_WHEEL_TYPES[commands[2]:upper()]
        if not wheels.type then
            return false
        end
    else
        wheels.type = math.random(-1, constants.VEHICLE_MAX_OPTIONS.WHEEL_TYPES)
    end
    wheels.max_kinds = VEHICLE.GET_NUM_VEHICLE_MODS(vehicle, constants.VEHICLE_MOD_TYPES.MOD_FRONTWHEELS) - 1
    if commands and commands[3] then
        wheels.kind = commands[3]
    else
        wheels.kind = math.random(-1, wheels.max_kinds)
    end
    wheels.name = wheels.type
    for wheel_type_name, wheel_type_number in pairs(constants.VEHICLE_WHEEL_TYPES) do
        if wheel_type_number == tonumber(wheels.type) then
            wheels.name = wheel_type_name
        end
    end
    VEHICLE.SET_VEHICLE_WHEEL_TYPE(vehicle, wheels.type)
    entities.set_upgrade_value(vehicle, constants.VEHICLE_MOD_TYPES.MOD_FRONTWHEELS, wheels.kind)
    entities.set_upgrade_value(vehicle, constants.VEHICLE_MOD_TYPES.MOD_BACKWHEELS, wheels.kind)
end

---
--- Nameplate
---

vehicle_utils.set_plate_type = function(pid, vehicle, plate_type_num)
    if type(plate_type_num) == "string" then
        plate_type_num = constants.VEHICLE_PLATE_TYPES[plate_type_num:upper()]
    end
    if plate_type_num == nil then
        plate_type_num = math.random(0, 5)
    end
    local plate_type_name = cc_utils.get_enum_value_name(constants.VEHICLE_PLATE_TYPES, plate_type_num)
    ENTITY.SET_ENTITY_AS_MISSION_ENTITY(vehicle, true, true)
    VEHICLE.SET_VEHICLE_NUMBER_PLATE_TEXT_INDEX(vehicle, plate_type_num)
    return plate_type_name
end

local function plateify_text(plate_text)
    --if config.custom_plate_texts ~= nil and config.custom_plate_texts[plate_text] ~= nil then
    --    -- Custom overrides
    --    if type(config.custom_plate_texts[plate_text]) == "table" then
    --        local plates = config.custom_plate_texts[plate_text]
    --        plate_text = plates[math.random(1, #plates)]
    --    else
    --        plate_text = config.custom_plate_texts[plate_text]
    --    end
    --end
    if string.len(plate_text) > 8 then
        -- Special characters
        plate_text = plate_text:gsub("[^A-Za-z0-9]", "")
    end
    if string.len(plate_text) > 8 then
        -- Ending numbers
        plate_text = plate_text:gsub("[0-9]+$", "")
    end
    if string.len(plate_text) > 8 then
        -- Vowels
        plate_text = plate_text:gsub("[AEIOUaeiou]", "")
    end
    plate_text = string.sub(plate_text, 1, 8)
    return plate_text
end

vehicle_utils.set_plate_for_player = function(vehicle, pid)
    VEHICLE.SET_VEHICLE_NUMBER_PLATE_TEXT(vehicle, plateify_text(players.get_name(pid)))
end

return vehicle_utils
