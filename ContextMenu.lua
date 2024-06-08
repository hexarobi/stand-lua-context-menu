-- Context Menu
-- by Hexarobi
-- with code from Wiri, aarroonn, and Davus

local SCRIPT_VERSION = "0.33"

---
--- Auto Updater
---

local auto_update_config = {
    source_url="https://raw.githubusercontent.com/hexarobi/stand-lua-context-menu/main/ContextMenu.lua",
    script_relpath=SCRIPT_RELPATH,
    project_url="https://github.com/hexarobi/stand-lua-context-menu",
    branch="main",
    dependencies={
        "lib/context_menu/constants.lua",
        "lib/context_menu/shared_state.lua",
        "lib/context_menu/vehicle_utils.lua",
        -- ContextMenu Options
        "lib/ContextMenus/clean.lua",
        "lib/ContextMenus/copy.lua",
        "lib/ContextMenus/dance.lua",
        "lib/ContextMenus/destroy.lua",
        "lib/ContextMenus/enter.lua",
        "lib/ContextMenus/flip.lua",
        "lib/ContextMenus/freeze.lua",
        "lib/ContextMenus/paste.lua",
        "lib/ContextMenus/ped_scenario.lua",
        "lib/ContextMenus/player_menu.lua",
        "lib/ContextMenus/repair.lua",
        "lib/ContextMenus/save.lua",
        "lib/ContextMenus/spawn.lua",
        "lib/ContextMenus/teleport.lua",
    },
}

util.ensure_package_is_installed('lua/auto-updater')
local auto_updater = require('auto-updater')
if auto_updater == true then
    auto_updater.run_auto_update(auto_update_config)
end

---
--- Dependencies
---

util.require_natives("3095a")

util.ensure_package_is_installed('lua/inspect')
local inspect = require("inspect")
local constants = require("context_menu/constants")
local item_browser = require("context_menu/item_browser")

-- Constructor lib is required for some commands, so install it from repo if its not already
util.ensure_package_is_installed('lua/Constructor')

---
--- Config
---

local config = {
    debug_mode = false,
    context_menu_enabled=true,
    disable_in_vehicles=true,
    disable_when_armed=true,
    controls ={
        keyboard={
            open_menu=238,
            close_menu=177,
            select_option=176,
        },
        controller={
            open_menu=52,
            close_menu=177,
            select_option=176,
        },
    },
    hot_keys_enabled=true,
    use_aarons_model_hash=true,
    wrap_read_model_with_pcall=false,
    ped_preview = {
        enabled=true,
        preset_name="PAUSE_SINGLE_LEFT",
        preset_slot=0,
        pos={
            x=0.0,
            y=-1.0,
            z=0.0,
        },
    },
    target_player_distance=5000,
    target_vehicle_distance=100,
    target_ped_distance=30,
    target_object_distance=10,
    target_snap_distance={
        player=0.08,
        vehicle=0.04,
        ped=0.02,
        object=0.01,
    },
    color = {
        options_circle={r=1, g=1, b=1, a=0.1},
        option_text={r=1, g=1, b=1, a=1},
        help_text={r=0.8, g=0.8, b=0.8, a=1},
        option_wedge={r=1, g=1, b=1, a=0.3},
        selected_option_wedge={r=1, g=0, b=1, a=0.3},
        crosshair={r=1,g=1,b=1,a=0.8},
        target_ball={r=1,g=0,b=1,a=0.8},
        target_bounding_box={r=1,g=0,b=1,a=1},
        line_to_target={ r=1, g=1, b=1, a=0.5},
    },
    target_ball_size=0.4,
    selection_distance=600.0,
    menu_radius=0.15,
    option_label_distance=0.75,
    option_wedge_deadzone=0.10,
    option_wedge_padding=0.0,
    menu_release_delay=3,
    show_target_name=true,
    show_target_owner=true,
    show_option_help=true,
    menu_options_scripts_dir="lib/ContextMenus",
    trace_flag_options = {
        --{name="All", value=511, enabled=false},
        {name="World", value=1, enabled=true},
        {name="Vehicle", value=2, enabled=true},
        {name="Ped", value=4, enabled=true},
        {name="Ragdoll", value=8, enabled=true},
        {name="Object", value=16, enabled=true},
        {name="Pickup", value=32, enabled=true},
        {name="Glass", value=64, enabled=false},
        {name="River", value=128, enabled=false},
        {name="Foliage", value=256, enabled=true},
    },
    trace_flag_value=0,
}

---
--- Vars
---

local cmm = {
    menu_options = {},
}
local menus = {}
local state = {}

local pointx = memory.alloc()
local pointy = memory.alloc()

local CONTEXT_MENUS_DIR = filesystem.scripts_dir()..config.menu_options_scripts_dir
filesystem.mkdirs(CONTEXT_MENUS_DIR)

---
--- Utilities
---

local function debug_log(text)
    util.log("[ContextMenuManager] "..text)
end

local function round(num, numDecimalPlaces)
    local mult = 10^(numDecimalPlaces or 0)
    return math.floor(num * mult + 0.5) / mult
end

local function deep_table_copy(obj)
    if type(obj) ~= 'table' then
        return obj
    end
    local res = setmetatable({}, getmetatable(obj))
    for k, v in pairs(obj) do
        res[deep_table_copy(k)] = deep_table_copy(v)
    end
    return res
end

---
--- Main Menu Draw Tick
---

cmm.context_menu_draw_tick = function()
    if not cmm.is_menu_available() then return true end
    cmm.disable_controls()

    if state.is_menu_open then
        cmm.refresh_screen_pos(state.current_target)
    else
        directx.draw_circle(0.5, 0.5, 0.001, config.color.crosshair)
        state.current_target = cmm.find_nearest_target()
    end

    local target = state.current_target
    if target ~= nil and target.pos ~= nil then
        cmm.draw_selection(target)
        if state.is_menu_open then
            cmm.update_menu(target)
            if cmm.is_menu_select_control_pressed() then
                cmm.execute_selected_action(target)
            end
            if cmm.is_menu_close_control_pressed() then
                if target.previous_relevant_options then
                    cmm.build_relevant_options(target, target.previous_relevant_options.relevant_options)
                    target.previous_relevant_options = target.previous_relevant_options.parent
                else
                    cmm.close_options_menu(target)
                end
            end
            -- TODO: why doesnt disabling here work?
            --PAD.DISABLE_CONTROL_ACTION(2, 245, true) --chat
        else
            if cmm.is_menu_open_control_pressed() then
                cmm.open_options_menu(target)
            end
        end
    end

    return true
end

cmm.is_menu_select_control_pressed = function()
    if PAD.IS_USING_KEYBOARD_AND_MOUSE(2) then
        return PAD.IS_DISABLED_CONTROL_JUST_PRESSED(2, config.controls.keyboard.select_option)
    else
        return PAD.IS_DISABLED_CONTROL_JUST_PRESSED(2, config.controls.controller.select_option)
    end
end

cmm.is_menu_open_control_pressed = function()
    if HUD.IS_PAUSE_MENU_ACTIVE() then return false end
    if PAD.IS_USING_KEYBOARD_AND_MOUSE(2) then
        return PAD.IS_DISABLED_CONTROL_JUST_PRESSED(2, config.controls.keyboard.open_menu)
    else
        return PAD.IS_DISABLED_CONTROL_JUST_PRESSED(2, config.controls.controller.open_menu)
    end
end

cmm.is_menu_close_control_pressed = function()
    if HUD.IS_PAUSE_MENU_ACTIVE() then return true end
    if PAD.IS_USING_KEYBOARD_AND_MOUSE(2) then
        return PAD.IS_DISABLED_CONTROL_JUST_PRESSED(2, config.controls.keyboard.close_menu)
            or PAD.IS_DISABLED_CONTROL_JUST_PRESSED(2, config.controls.keyboard.open_menu)
    else
        return PAD.IS_DISABLED_CONTROL_JUST_PRESSED(2, config.controls.controller.close_menu)
            or PAD.IS_DISABLED_CONTROL_JUST_PRESSED(2, config.controls.controller.open_menu)
    end
end

cmm.disable_controls = function()
    PAD.DISABLE_CONTROL_ACTION(2, 25, true) --aim
    PAD.DISABLE_CONTROL_ACTION(2, 24, true) --attack
    PAD.DISABLE_CONTROL_ACTION(2, 257, true) --attack2
    PAD.DISABLE_CONTROL_ACTION(2, config.controls.keyboard.open_menu, false)
    PAD.DISABLE_CONTROL_ACTION(2, config.controls.controller.open_menu, false)
end

cmm.is_menu_available = function()
    if not config.context_menu_enabled then return false end
    if config.disable_in_vehicles then if PED.IS_PED_IN_ANY_VEHICLE(players.user_ped()) then return false end end
    if config.disable_when_armed and WEAPON.IS_PED_ARMED(players.user_ped(), 7) then return false end
    return true
end

cmm.draw_ped_preview = function(target)
    if not config.ped_preview.enabled or target.type ~= "PLAYER" then return end
    if GRAPHICS.UI3DSCENE_IS_AVAILABLE() then
        if GRAPHICS.UI3DSCENE_PUSH_PRESET(config.ped_preview.preset_name) then
            GRAPHICS.UI3DSCENE_ASSIGN_PED_TO_SLOT(
                config.ped_preview.preset_name, target.handle, config.ped_preview.preset_slot,
                config.ped_preview.pos.x, config.ped_preview.pos.y, config.ped_preview.pos.z
            )
            GRAPHICS.UI3DSCENE_MAKE_PUSHED_PRESET_PERSISTENT()
            GRAPHICS.UI3DSCENE_CLEAR_PATCHED_DATA()
        end
    end
end

---
--- Targetting
---

cmm.get_distance_from_player = function(target)
    local player_pos = ENTITY.GET_ENTITY_COORDS(players.user_ped(), 1)
    if target.handle then
        target.pos = ENTITY.GET_ENTITY_COORDS(target.handle, 1)
        target.distance_from_player = SYSTEM.VDIST(player_pos.x, player_pos.y, player_pos.z, target.pos.x, target.pos.y, target.pos.z)
    elseif target.pos then
        target.distance_from_player = SYSTEM.VDIST(player_pos.x, player_pos.y, player_pos.z, target.pos.x, target.pos.y, target.pos.z)
    end
end

local function expand_target_screen_pos(target)
    local player_pos = ENTITY.GET_ENTITY_COORDS(players.user_ped(), 1)
    target.distance_from_player = SYSTEM.VDIST(
        player_pos.x, player_pos.y, player_pos.z,
        target.position.x, target.position.y, target.position.z
    )
    if GRAPHICS.GET_SCREEN_COORD_FROM_WORLD_COORD(target.position.x, target.position.y, target.position.z, pointx, pointy) then
        target.screen_pos = { x=memory.read_float(pointx), y=memory.read_float(pointy)}
        target.screen_distance = SYSTEM.VDIST(0.5, 0.5, 0.0, target.screen_pos.x, target.screen_pos.y, 0.0)
    end
end

local function build_handle_target(handle)
    local target = {
        handle=handle,
        position=ENTITY.GET_ENTITY_COORDS(handle),
    }
    cmm.update_target_data(target)
    expand_target_screen_pos(target)
    return target
end

local function check_handles_for_nearest_target(handles, result, max_distance, snap_distance)
    if max_distance == nil then max_distance = 9999999 end
    for _, handle in handles do
        if handle ~= players.user_ped() then
            local target = build_handle_target(handle)
            if target.distance_from_player < max_distance
                and target.screen_distance ~= nil
                and target.screen_distance < snap_distance
                and (
                    result.closest_target.screen_distance == nil
                    or target.screen_distance < result.closest_target.screen_distance
                )
            then
                result.closest_target = target
            end
        end
    end
end

local function build_pointer_target(pointer)
    local target = {
        pointer=pointer,
        position=entities.get_position(pointer),
    }
    expand_target_screen_pos(target)
    return target
end

local function check_pointers_for_closest_target(pointers, result, max_distance, max_screen_distance)
    local player_pointer = entities.handle_to_pointer(players.user_ped())
    if result.closest_target.screen_distance == nil then result.closest_target.screen_distance = 9999999 end
    for _, pointer in pointers do
        local target = build_pointer_target(pointer)
        if pointer ~= player_pointer
            and target.distance_from_player < max_distance
            and target.screen_distance ~= nil
            and target.screen_distance < max_screen_distance
            and target.screen_distance < result.closest_target.screen_distance
        then
            result.closest_target = target
        end
    end
end

local function get_all_players_as_handles()
    local player_handles = {}
    for _, pid in players.list(false) do
        table.insert(player_handles, PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(pid))
    end
    return player_handles
end

cmm.find_nearest_target = function()
    local result = {
        min_distance = 9999,
        closest_target = {}
    }

    check_handles_for_nearest_target(get_all_players_as_handles(), result, config.target_player_distance, config.target_snap_distance.player)
    --check_handles_for_nearest_target(entities.get_all_vehicles_as_handles(), result, config.target_vehicle_distance, config.target_snap_distance.vehicle)
    --check_handles_for_nearest_target(entities.get_all_peds_as_handles(), result, config.target_ped_distance, config.target_snap_distance.ped)
    --check_handles_for_nearest_target(entities.get_all_objects_as_handles(), result, config.target_object_distance, config.target_snap_distance.object)

    check_pointers_for_closest_target(entities.get_all_vehicles_as_pointers(), result, config.target_vehicle_distance, config.target_snap_distance.vehicle)
    check_pointers_for_closest_target(entities.get_all_peds_as_pointers(), result, config.target_ped_distance, config.target_snap_distance.ped)
    --check_pointers_for_closest_target(entities.get_all_objects_as_pointers(), result, config.target_object_distance, config.target_snap_distance.object)

    if result.closest_target.pointer then
        result.closest_target.handle = entities.pointer_to_handle(result.closest_target.pointer)
    end
    if result.closest_target.handle then
        cmm.expand_target_model(result.closest_target)
        return result.closest_target
    end

    return cmm.get_raycast_target()
end

---
--- Menu Options
---

cmm.add_context_menu_option = function(menu_option, options_list)
    cmm.default_menu_option(menu_option)
    debug_log("Adding menu option "..menu_option.name or "Unknown")
    table.insert(options_list, menu_option)
end

local unique_id_counter = 0
cmm.default_menu_option = function(menu_option)
    if menu_option.name == nil then menu_option.name = "Unknown Name" end
    if menu_option.enabled == nil then menu_option.enabled = true end
    if menu_option.priority == nil then menu_option.priority = 0 end
    if menu_option.id == nil then
        unique_id_counter = unique_id_counter + 1
        menu_option.id = unique_id_counter
    end
    if menu_option.items ~= nil then
        for _, child_item in menu_option.items do
            cmm.default_menu_option(child_item)
        end
    end
end

cmm.empty_menu_option = function()
    return {
        name="",
        priority=-1,
        is_empty=true
    }
end

cmm.refresh_menu_options_from_files = function(directory, path, options_list)
    if path == nil then path = "" end
    if options_list == nil then options_list = cmm.menu_options end
    for _, filepath in ipairs(filesystem.list_files(directory)) do
        if filesystem.is_dir(filepath) then
            local _2, dirname = string.match(filepath, "(.-)([^\\/]-%.?)$")
            local filerelpath = path.."/"..dirname
            local menu_option = cmm.default_container_menu_option(filerelpath, dirname)
            cmm.refresh_menu_options_from_files(filepath, filerelpath, menu_option.items)
            debug_log("Adding "..#menu_option.items.." items to "..menu_option.name)
            cmm.add_context_menu_option(menu_option, options_list)
        else
            local _3, filename, ext = string.match(filepath, "(.-)([^\\/]-%.?)[.]([^%.\\/]*)$")
            if (ext == "lua" or ext == "pluto") and filename ~= "_folder" then
                local menu_option = require(config.menu_options_scripts_dir..path.."/"..filename)
                menu_option.filename = filename.."."..ext
                menu_option.filepath = filepath
                --debug_log("Loading menu option "..config.menu_options_scripts_dir..path.."/"..filename..": "..inspect(menu_option))
                --cc.expand_chat_command_defaults(command, filename, path)
                cmm.add_context_menu_option(menu_option, options_list)
            end
        end
    end
end

local function file_exists(name)
    local f=io.open(name,"r")
    if f~=nil then io.close(f) return true else return false end
end


cmm.default_container_menu_option = function(filepath, name)
    local menu_option = {}
    local folder_info_filepath = config.menu_options_scripts_dir..filepath.."/_folder"
    local full_filepath = filesystem.scripts_dir()..folder_info_filepath..".lua"
    --debug_log("defaulting container from "..full_filepath)
    if file_exists(full_filepath) then
        local status, extra_menu_option = pcall(require, folder_info_filepath)
        if not status then
            util.toast("Failed to load context menu option "..extra_menu_option, TOAST_ALL)
        else
            menu_option = extra_menu_option
        end
    end

    if menu_option.name == nil then menu_option.name = name end
    if menu_option.items == nil then menu_option.items = {} end
    return menu_option
end

cmm.refresh_menu_options_from_files(CONTEXT_MENUS_DIR)
table.sort(cmm.menu_options, function(a,b) return a.name < b.name end)

--for _, this_option in cmm.menu_options do
--    debug_log("Sorted relevant options: "..this_option.name)
--end

local ENTITY_TYPES = {"PED", "VEHICLE", "OBJECT"}

---
--- Draw Utils
---

local minimum = memory.alloc()
local maximum = memory.alloc()
local upVector_pointer = memory.alloc()
local rightVector_pointer = memory.alloc()
local forwardVector_pointer = memory.alloc()
local position_pointer = memory.alloc()

cmm.draw_bounding_box = function(target, colour)
    if colour == nil then
        colour = config.color.target_bounding_box_output
    end
    if target.model_hash == nil then
        debug_log("Could not draw bounding box: No model hash set")
        return
    end

    MISC.GET_MODEL_DIMENSIONS(target.model_hash, minimum, maximum)
    local minimum_vec = v3.new(minimum)
    local maximum_vec = v3.new(maximum)
    cmm.draw_bounding_box_with_dimensions(target.handle, colour, minimum_vec, maximum_vec)
end

cmm.draw_bounding_box_with_dimensions = function(entity, colour, minimum_vec, maximum_vec)

    local dimensions = {x = maximum_vec.y - minimum_vec.y, y = maximum_vec.x - minimum_vec.x, z = maximum_vec.z - minimum_vec.z}

    ENTITY.GET_ENTITY_MATRIX(entity, rightVector_pointer, forwardVector_pointer, upVector_pointer, position_pointer);
    local forward_vector = v3.new(forwardVector_pointer)
    local right_vector = v3.new(rightVector_pointer)
    local up_vector = v3.new(upVector_pointer)

    local top_right =           ENTITY.GET_OFFSET_FROM_ENTITY_IN_WORLD_COORDS(entity,       maximum_vec.x, maximum_vec.y, maximum_vec.z)
    local top_right_back =      {x = forward_vector.x * -dimensions.y + top_right.x,        y = forward_vector.y * -dimensions.y + top_right.y,         z = forward_vector.z * -dimensions.y + top_right.z}
    local bottom_right_back =   {x = up_vector.x * -dimensions.z + top_right_back.x,        y = up_vector.y * -dimensions.z + top_right_back.y,         z = up_vector.z * -dimensions.z + top_right_back.z}
    local bottom_left_back =    {x = -right_vector.x * dimensions.x + bottom_right_back.x,  y = -right_vector.y * dimensions.x + bottom_right_back.y,   z = -right_vector.z * dimensions.x + bottom_right_back.z}
    local top_left =            {x = -right_vector.x * dimensions.x + top_right.x,          y = -right_vector.y * dimensions.x + top_right.y,           z = -right_vector.z * dimensions.x + top_right.z}
    local bottom_right =        {x = -up_vector.x * dimensions.z + top_right.x,             y = -up_vector.y * dimensions.z + top_right.y,              z = -up_vector.z * dimensions.z + top_right.z}
    local bottom_left =         {x = forward_vector.x * dimensions.y + bottom_left_back.x,  y = forward_vector.y * dimensions.y + bottom_left_back.y,   z = forward_vector.z * dimensions.y + bottom_left_back.z}
    local top_left_back =       {x = up_vector.x * dimensions.z + bottom_left_back.x,       y = up_vector.y * dimensions.z + bottom_left_back.y,        z = up_vector.z * dimensions.z + bottom_left_back.z}

    GRAPHICS.DRAW_LINE(
            top_right.x, top_right.y, top_right.z,
            top_right_back.x, top_right_back.y, top_right_back.z,
            colour.r, colour.g, colour.b, colour.a
    )
    GRAPHICS.DRAW_LINE(
            top_right.x, top_right.y, top_right.z,
            top_left.x, top_left.y, top_left.z,
            colour.r, colour.g, colour.b, colour.a
    )
    GRAPHICS.DRAW_LINE(
            top_right.x, top_right.y, top_right.z,
            bottom_right.x, bottom_right.y, bottom_right.z,
            colour.r, colour.g, colour.b, colour.a
    )
    GRAPHICS.DRAW_LINE(
            bottom_left_back.x, bottom_left_back.y, bottom_left_back.z,
            bottom_right_back.x, bottom_right_back.y, bottom_right_back.z,
            colour.r, colour.g, colour.b, colour.a
    )
    GRAPHICS.DRAW_LINE(
            bottom_left_back.x, bottom_left_back.y, bottom_left_back.z,
            bottom_left.x, bottom_left.y, bottom_left.z,
            colour.r, colour.g, colour.b, colour.a
    )
    GRAPHICS.DRAW_LINE(
            bottom_left_back.x, bottom_left_back.y, bottom_left_back.z,
            top_left_back.x, top_left_back.y, top_left_back.z,
            colour.r, colour.g, colour.b, colour.a
    )
    GRAPHICS.DRAW_LINE(
            top_left_back.x, top_left_back.y, top_left_back.z,
            top_right_back.x, top_right_back.y, top_right_back.z,
            colour.r, colour.g, colour.b, colour.a
    )
    GRAPHICS.DRAW_LINE(
            top_left_back.x, top_left_back.y, top_left_back.z,
            top_left.x, top_left.y, top_left.z,
            colour.r, colour.g, colour.b, colour.a
    )
    GRAPHICS.DRAW_LINE(
            bottom_right_back.x, bottom_right_back.y, bottom_right_back.z,
            top_right_back.x, top_right_back.y, top_right_back.z,
            colour.r, colour.g, colour.b, colour.a
    )
    GRAPHICS.DRAW_LINE(
            bottom_left.x, bottom_left.y, bottom_left.z,
            top_left.x, top_left.y, top_left.z,
            colour.r, colour.g, colour.b, colour.a
    )
    GRAPHICS.DRAW_LINE(
            bottom_left.x, bottom_left.y, bottom_left.z,
            bottom_right.x, bottom_right.y, bottom_right.z,
            colour.r, colour.g, colour.b, colour.a
    )
    GRAPHICS.DRAW_LINE(
            bottom_right_back.x, bottom_right_back.y, bottom_right_back.z,
            bottom_right.x, bottom_right.y, bottom_right.z,
            colour.r, colour.g, colour.b, colour.a
    )
end

cmm.draw_text_with_shadow = function(posx, posy, text, alignment, scale, color, force_in_bounds)
    if text == nil then return end
    if alignment == nil then alignment = 5 end
    if scale == nil then scale = 0.5 end
    if color == nil then color = config.color.option_text end
    if force_in_bounds == nil then force_in_bounds = true end
    local shadow_color = {r=0,g=0,b=0,a=0.3}
    local shadow_distance = 0.001
    directx.draw_text(posx + shadow_distance, posy + shadow_distance, text, alignment, scale, shadow_color, force_in_bounds)
    directx.draw_text(posx - shadow_distance, posy - shadow_distance, text, alignment, scale, shadow_color, force_in_bounds)
    directx.draw_text(posx + shadow_distance, posy - shadow_distance, text, alignment, scale, shadow_color, force_in_bounds)
    directx.draw_text(posx - shadow_distance, posy + shadow_distance, text, alignment, scale, shadow_color, force_in_bounds)

    directx.draw_text(posx + shadow_distance, posy, text, alignment, scale, shadow_color, force_in_bounds)
    directx.draw_text(posx, posy + shadow_distance, text, alignment, scale, shadow_color, force_in_bounds)
    directx.draw_text(posx - shadow_distance, posy, text, alignment, scale, shadow_color, force_in_bounds)
    directx.draw_text(posx, posy - shadow_distance, text, alignment, scale, shadow_color, force_in_bounds)

    directx.draw_text(posx, posy, text, alignment, scale, color, force_in_bounds)
end

---
--- Color Menu Outputs
---

cmm.color_menu_output = function(output_color)
    return {
        r=math.floor(output_color.r * 255),
        g=math.floor(output_color.g * 255),
        b=math.floor(output_color.b * 255),
        a=math.floor(output_color.a * 255)
    }
end
config.color.target_ball_output = cmm.color_menu_output(config.color.target_ball)
config.color.target_bounding_box_output = cmm.color_menu_output(config.color.target_bounding_box)

--------------------------
-- RAYCAST
--------------------------

---@param dist number
---@return v3
local function get_offset_from_cam(dist)
    local rot = CAM.GET_FINAL_RENDERED_CAM_ROT(2)
    local pos = CAM.GET_FINAL_RENDERED_CAM_COORD()
    local dir = rot:toDir()
    dir:mul(dist)
    local offset = v3.new(pos)
    offset:add(dir)
    return offset
end

---@class RaycastResult
---@field didHit boolean
---@field endCoords v3
---@field surfaceNormal v3
---@field hitEntity Entity

---@param dist number
---@param flag? integer
---@return RaycastResult
local function get_raycast_result(dist, flag)
    local result = {}
    flag = flag or 511 -- All=511
    local didHit = memory.alloc(1)
    local endCoords = v3.new()
    local normal = v3.new()
    local hitEntity = memory.alloc_int()
    local camPos = CAM.GET_FINAL_RENDERED_CAM_COORD()
    local offset = get_offset_from_cam(dist)

    local handle = SHAPETEST.START_EXPENSIVE_SYNCHRONOUS_SHAPE_TEST_LOS_PROBE(
            camPos.x, camPos.y, camPos.z,
            offset.x, offset.y, offset.z,
            flag,
            players.user_ped(), 7
    )
    SHAPETEST.GET_SHAPE_TEST_RESULT(handle, didHit, endCoords, normal, hitEntity)

    result.didHit = memory.read_byte(didHit) ~= 0
    result.endCoords = endCoords
    result.surfaceNormal = normal
    result.hitEntity = memory.read_int(hitEntity)
    return result
end

cmm.rebuild_trace_flag_value = function()
    local flag = 0
    for _, trace_flag_option in config.trace_flag_options do
        if trace_flag_option.enabled then
            local flag_value = trace_flag_option.value
            flag = flag | flag_value
        end
    end
    config.trace_flag_value = flag
end
cmm.rebuild_trace_flag_value()

---
--- Polygon Utils
---

local function is_point_in_polygon( x, y, vertices)
    local points= {}

    for i=1, #vertices-1, 2 do
        points[#points+1] = { x=vertices[i], y=vertices[i+1] }
    end
    local j = #points, #points
    local inside = false

    for i=1, #points do
        if ((points[i].y < y and points[j].y>=y or points[j].y< y and points[i].y>=y) and (points[i].x<=x or points[j].x<=x)) then
            if (points[i].x+(y-points[i].y)/(points[j].y-points[i].y)*(points[j].x-points[i].x)<x) then
                inside = not inside
            end
        end
        j = i
    end

    return inside
end

local function build_vertices_list(wedge_points)
    local vertices = {}
    for _, point in wedge_points do
        table.insert(vertices, point.x)
        table.insert(vertices, point.y)
    end
    return vertices
end

local function draw_polygon(wedge_points, draw_color)
    for point_index=1, (#wedge_points/2)-1 do
        local top_point = wedge_points[point_index]
        local bottom_point = wedge_points[#wedge_points - point_index + 1]
        local next_top_point = wedge_points[point_index + 1]
        local next_bottom_point = wedge_points[#wedge_points - point_index]
        directx.draw_triangle(
            top_point.x, top_point.y,
            bottom_point.x, bottom_point.y,
            next_top_point.x, next_top_point.y,
            draw_color
        )
        directx.draw_triangle(
            next_top_point.x, next_top_point.y,
            bottom_point.x, bottom_point.y,
            next_bottom_point.x, next_bottom_point.y,
            draw_color
        )
    end
end

---
--- Trig Utils
---

local function get_circle_coords(origin, radius, angle_degree)
    local angle_radian = math.rad(angle_degree)
    return {
        x=(radius * math.cos(angle_radian) * 0.9) + origin.x,
        y=(radius * math.sin(angle_radian) * 1.6) + origin.y
    }
end

local function reverse_table(tab)
    for i = 1, #tab//2, 1 do
        tab[i], tab[#tab-i+1] = tab[#tab-i+1], tab[i]
    end
    return tab
end

local function calculate_point_angles(target, option, option_angle, option_width)
    local width_scale = 1 - config.option_wedge_padding
    local point_angles = {
        option_angle - (option_width / 2 * width_scale),
        option_angle - (option_width / 4 * width_scale),
        option_angle,
        option_angle + (option_width / 4 * width_scale),
        option_angle + (option_width / 2 * width_scale),
    }
    return point_angles
end


local function build_wedge_points(point_angles, target)
    local top_points = {}
    local bottom_points = {}
    for _, point_angle in point_angles do
        local top_point = get_circle_coords(target.menu_pos, config.menu_radius * 1.05, point_angle)
        table.insert(top_points, top_point)
        local bottom_point = get_circle_coords(target.menu_pos, config.menu_radius * config.option_wedge_deadzone, point_angle)
        table.insert(bottom_points, bottom_point)
    end

    local final_points = {}
    for _, top_point in top_points do
        table.insert(final_points, top_point)
    end
    for _, bottom_point in reverse_table(bottom_points) do
        table.insert(final_points, bottom_point)
    end

    return final_points
end

--local function angular_distance(first_angle, second_angle)
--    local short_distance = second_angle - first_angle
--    local long_distance = 360 + (first_angle - second_angle)
--    return minimum(short_distance, long_distance)
--end
--
--local function is_angle_within_wedge(selection_angle, first_point_angle, last_point_angle)
--    if selection_angle > first_point_angle and selection_angle < last_point_angle then
--end

local function normalize_angle(angle)
    return (angle + 360) % 360
end

local function is_angle_between(angle, left, right)
    local normal_angle = normalize_angle(angle)
    local normal_left = normalize_angle(left)
    local normal_right = normalize_angle(right)
    --util.log("checking if "..normal_angle.." between "..normal_left.." and "..normal_right)
    if (normal_left < normal_right) then
        return (normal_left <= normal_angle and normal_angle <= normal_right)
    else
        return (normal_left <= normal_angle or normal_angle <= normal_right)
    end
end

local function get_controls_angle_magnitude()
    PAD.DISABLE_CONTROL_ACTION(0, 31, false) --x
    PAD.DISABLE_CONTROL_ACTION(0, 30, false) --y
    local mouse_movement = {
        x=PAD.GET_DISABLED_CONTROL_NORMAL(0, 30),
        y=PAD.GET_DISABLED_CONTROL_NORMAL(0, 31),
    }
    local magnitude = math.sqrt(mouse_movement.x ^ 2 + mouse_movement.y ^ 2)
    local angle = normalize_angle(math.deg(math.atan(mouse_movement.y, mouse_movement.x)))
    return angle, magnitude
end

cmm.handle_inputs = function(target)
    PAD.DISABLE_CONTROL_ACTION(0, 1, false) --x
    PAD.DISABLE_CONTROL_ACTION(0, 2, false) --y
    target.cursor_pos = nil
    target.cursor_angle = nil
    target.cursor_angle_magnitude = nil
    if PAD.IS_USING_KEYBOARD_AND_MOUSE(1) then
        HUD.SET_MOUSE_CURSOR_THIS_FRAME()
        HUD.SET_MOUSE_CURSOR_STYLE(1)
        target.cursor_pos = {
            x=PAD.GET_CONTROL_NORMAL(0, 239),
            y=PAD.GET_CONTROL_NORMAL(0, 240),
        }
    else
        local angle, magnitude = get_controls_angle_magnitude()
        target.cursor_angle = angle
        target.cursor_angle_magnitude = magnitude
    end
end

cmm.check_option_hotkeys = function(target)
    if not config.hot_keys_enabled then return end
    --PAD.DISABLE_CONTROL_ACTION(2, 245, true) --chat
    for option_index, option in target.relevant_options do
        local hotkey = option.hotkey
        if hotkey then hotkey = hotkey:upper() end
        if hotkey and constants.hotkey_map[hotkey] ~= nil then hotkey = constants.hotkey_map[hotkey] end
        if hotkey ~= nil and util.is_key_down(hotkey) then
            target.selected_option = option
            cmm.execute_selected_action(target)
        end
    end
end

cmm.find_selected_option = function(target)
    for option_index, option in target.relevant_options do
        if target.cursor_pos then
            if is_point_in_polygon(target.cursor_pos.x, target.cursor_pos.y, option.vertices) then
                target.selected_option = option
            elseif target.selected_option == option then
                -- Leaving selection
                target.selected_option.ticks_shown = nil
                target.selected_option = nil
            end
        elseif target.cursor_angle then
            local first_point_angle = option.point_angles[1]
            local last_point_angle = option.point_angles[#option.point_angles]
            local is_option_pointed_at = is_angle_between(target.cursor_angle, first_point_angle, last_point_angle)
            if target.cursor_angle_magnitude > 0.2 then
                if is_option_pointed_at and target.cursor_angle_magnitude > 0.8 then
                    target.selected_option = option
                elseif target.selected_option == option and (not is_option_pointed_at) then
                    target.selected_option = nil
                end
            end
        end
    end
end

cmm.trigger_selected_action = function(target)
    if target.selected_option ~= nil then
        -- Delay execution to make sure this trigger is intentional
        if target.selected_option.ticks_shown == nil then
            target.selected_option.ticks_shown = 0
        elseif target.selected_option.ticks_shown > config.menu_release_delay then
            cmm.execute_selected_action(target)
        else
            --util.draw_debug_text("ticks shown = "..target.selected_option.ticks_shown)
            target.selected_option.ticks_shown = target.selected_option.ticks_shown + 1
        end
    end
end

cmm.execute_selected_action = function(target)
    state.is_menu_open = false
    if not target.selected_option then return end
    if target.selected_option.execute ~= nil and type(target.selected_option.execute) == "function" then
        util.log("Triggering option "..target.selected_option.name)
        if cmm.is_target_a_player_in_vehicle(target) then
            target.handle = PED.GET_VEHICLE_PED_IS_IN(target.handle, false)
            cmm.update_target_data(target)
        end
        target.selected_option.execute(target)
    elseif target.selected_option.items ~= nil and type(target.selected_option.items) == "table" then
        state.is_menu_open = true
        target.previous_relevant_options = {
            parent=target.previous_relevant_options,
            relevant_options=deep_table_copy(target.relevant_options)
        }
        cmm.build_relevant_options(target, target.selected_option.items)
    end
end

local function get_option_wedge_draw_color(target, option)
    local draw_color = config.color.option_wedge
    if target.selected_option == option then
        if target.selected_option.ticks_shown ~= nil then
            if (target.selected_option.ticks_shown/2) % 2 == 0 then
                draw_color = config.color.option_wedge
            else
                draw_color = config.color.selected_option_wedge
            end
        else
            draw_color = config.color.selected_option_wedge
        end
    end
    return draw_color
end

cmm.draw_options_menu = function(target)
    directx.draw_circle(target.menu_pos.x, target.menu_pos.y, config.menu_radius, config.color.options_circle)

    --if target.screen_pos.x > 0 and target.screen_pos.y > 0 then
    --    directx.draw_line(0.5, 0.5, target.screen_pos.x, target.screen_pos.y, config.color.line_to_target)
    --end

    cmm.draw_target_label(target)

    for option_index, option in target.relevant_options do
        if option.name ~= nil then
            local option_text = option.name
            if option.num_relevant_children and option.num_relevant_children > 0 then
                option_text = option_text.." ("..option.num_relevant_children..")"
            end
            local option_text_coords = get_circle_coords(target.menu_pos, config.menu_radius*config.option_label_distance, option.option_angle)
            cmm.draw_text_with_shadow(option_text_coords.x, option_text_coords.y, option_text, 5, 0.5, config.color.option_text, true)

            draw_polygon(option.wedge_points, get_option_wedge_draw_color(target, option))

            if config.show_option_help and target.selected_option == option then
                cmm.draw_text_with_shadow(target.menu_pos.x, target.menu_pos.y + (config.menu_radius * 1.9), option.help, 5, 0.5, config.color.help_text, true)
                if option.hotkey and config.hot_keys_enabled then
                    cmm.draw_text_with_shadow(
                        target.menu_pos.x, target.menu_pos.y + (config.menu_radius * 1.9) + 0.02,
                        "Hotkey: "..option.hotkey, 5, 0.5, config.color.help_text, true
                    )
                end
            end
        end
    end
end

cmm.draw_target_label = function(target)
    if config.show_target_name and target.name ~= nil then
        local label = target.type .. ": " .. target.name
        if config.show_target_owner and target.owner and target.owner ~= target.name then
            label = label .. " (" .. target.owner .. ")"
        end
        cmm.get_distance_from_player(target)
        if target.distance_from_player then
            label = label .. " [" .. round(target.distance_from_player, 1) .. "m]"
        end

        if cmm.is_target_a_player_in_vehicle(target) then
            local row_offset = 0.02
            cmm.draw_text_with_shadow(target.menu_pos.x, target.menu_pos.y - (config.menu_radius * 1.9) - row_offset, label, 5, 0.5, config.color.option_text, true)
            local players_vehicle = PED.GET_VEHICLE_PED_IS_IN(target.handle, false)
            label = "VEHICLE: " .. cmm.get_vehicle_name_by_handle(players_vehicle)
            cmm.draw_text_with_shadow(target.menu_pos.x, target.menu_pos.y - (config.menu_radius * 1.9), label, 5, 0.5, config.color.option_text, true)
        else
            cmm.draw_text_with_shadow(target.menu_pos.x, target.menu_pos.y - (config.menu_radius * 1.9), label, 5, 0.5, config.color.option_text, true)
        end
    end
end

local function is_menu_option_relevant(menu_option, target)
    -- If menu option is a container, then check for at least one relevant child
    if menu_option.items ~= nil then
        menu_option.num_relevant_children = 0
        for _, child_option in menu_option.items do
            if is_menu_option_relevant(child_option, target) then
                menu_option.num_relevant_children = menu_option.num_relevant_children + 1
            end
        end
        return menu_option.num_relevant_children > 0
    end
    -- Disabled options never apply to any target
    if menu_option.enabled == false then return false end
    -- If no applicable_to set then apply to all targets
    if menu_option.applicable_to == nil then return true end
    -- If type is specifically listed as applicable then allow it
    if table.contains(menu_option.applicable_to, target.type) then
        return true
    end
    -- Also include vehicle options for players in vehicles
    if cmm.is_target_a_player_in_vehicle(target) and table.contains(menu_option.applicable_to, "VEHICLE") then
        return true
    end
    -- Disallow anything else
    return false
end

cmm.is_target_a_player_in_vehicle = function(target)
    return target.type == "PLAYER" and PED.IS_PED_IN_ANY_VEHICLE(target.handle)
end

cmm.deep_table_copy = function(obj)
    if type(obj) ~= 'table' then
        return obj
    end
    local res = setmetatable({}, getmetatable(obj))
    for k, v in pairs(obj) do
        res[cmm.deep_table_copy(k)] = cmm.deep_table_copy(v)
    end
    return res
end

cmm.build_relevant_options = function(target, options)
    if options == nil then options = cmm.menu_options end
    target.relevant_options = {}
    for _, option in options do
        if is_menu_option_relevant(option, target) then
            if option.on_open and type(option.on_open) == "function" then
                option.on_open(target, option)
            end
            table.insert(target.relevant_options, cmm.deep_table_copy(option))
        end
    end
    --if #relevant_options == 1 then table.insert(relevant_options, cmm.empty_menu_option()) end
    table.sort(target.relevant_options, function(a,b)
        if (a.priority ~= nil or b.priority ~= nil) and a.priority ~= b.priority then
            return (a.priority or 0) > (b.priority or 0)
        end
        return a.name < b.name
    end)
    cmm.build_option_wedge_points(target)
end

local function get_target_type(target)
    local entity_type = ENTITY_TYPES[ENTITY.GET_ENTITY_TYPE(target.handle)] or "WORLD_OBJECT"
    if entity_type == "PED" and entities.is_player_ped(target.handle) then
        return "PLAYER"
    end
    return entity_type
end

local function get_player_id_from_handle(handle)
    for _, pid in players.list() do
        local player_ped = PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(pid)
        if player_ped == handle then
            return pid
        end
    end
end

cmm.get_vehicle_name_by_model= function(model_hash)
    return util.get_label_text(VEHICLE.GET_DISPLAY_NAME_FROM_VEHICLE_MODEL(model_hash))
end

cmm.get_vehicle_name_by_handle = function(handle)
    return cmm.get_vehicle_name_by_model(entities.get_model_hash(handle))
end

local function get_target_name(target)
    if target.type == "PLAYER" and target.player_id then
        return PLAYER.GET_PLAYER_NAME(target.player_id)
    elseif target.type == "VEHICLE" then
        return cmm.get_vehicle_name_by_model(target.model_hash)
    end
    return target.model
end

local function get_target_owner(target)
    local owner_pid
    if target.type == "PLAYER" then
        owner_pid = get_player_id_from_handle(target.handle)
    elseif target.handle and target.type ~= "WORLD_OBJECT" then
        owner_pid = entities.get_owner(target.handle)
    end
    if owner_pid ~= nil and owner_pid > 0 then
        return PLAYER.GET_PLAYER_NAME(owner_pid)
    end
end

-- credit to the amazing aarroonn
local function get_model_hash(handle_or_ptr)
    --debug_log("Loading model hash for "..tostring(handle_or_ptr))
    if handle_or_ptr == nil or not (handle_or_ptr > 0) then return end
    local pointer = handle_or_ptr
    if handle_or_ptr < 0xFFFFFF then
        pointer = entities.handle_to_pointer(handle_or_ptr)
    end
    if pointer == nil or not (pointer > 0) then return end
    local status, model_info
    if config.wrap_read_model_with_pcall then
        status, model_info = pcall(memory.read_long, pointer + 0x20)
        if not status then
            util.toast("Warning: Access Violation for Handle: "..handle_or_ptr.." Pointer:"..pointer, TOAST_ALL)
            return
        end
    else
        --util.log("Reading model hash Handle: "..handle_or_ptr.." Pointer:"..pointer, TOAST_ALL)
        model_info = memory.read_long(pointer + 0x20)
    end
    if model_info ~= 0 then
        return memory.read_int(model_info + 0x18)
    end
end

cmm.build_target_from_pointer = function(handle)
    if not handle then return end
    local target = {}
    return target
end

cmm.update_target_data = function(target)
    target.type = get_target_type(target)
    target.player_id = get_player_id_from_handle(target.handle)
    target.name = get_target_name(target)
    target.owner = get_target_owner(target)
end

cmm.expand_target_model = function(target)
    target.model_hash = entities.get_model_hash(target.handle)
    if target.model_hash then
        target.model = util.reverse_joaat(target.model_hash)
    end
    cmm.update_target_data(target)
    target.pos = ENTITY.GET_ENTITY_COORDS(target.handle, true)
    cmm.expand_target_position(target)
end

cmm.build_target_from_handle = function(handle)
    if not handle then return end
    local target = {}
    target.handle = handle
    cmm.expand_target_model(target)
    return target
end

cmm.build_target_from_position = function(position)
    local target = {}
    target.type = "COORDS"
    target.pos = { x=round(position.x, 1), y=round(position.y, 1), z=round(position.z, 1)}
    target.name = target.pos.x..","..target.pos.y
    cmm.expand_target_position(target)
    return target
end

cmm.expand_target_position = function(target)
    target.menu_pos = { x=0.5, y=0.5, }
    target.screen_pos = { x=0.5, y=0.5, }
    cmm.refresh_screen_pos(target)
end

cmm.build_target_from_raycast_result = function(raycastResult)
    local model_hash
    if raycastResult.didHit then
        --util.log("Loading model hash from raycast: "..raycastResult.hitEntity)
        -- Aaron's model hash function works for WORLD OBJECTs that dont normally return an entity type
        -- but sometimes causes memory ACCESS_VIOLATION errors
        if config.use_aarons_model_hash then
            model_hash = get_model_hash(raycastResult.hitEntity)
        else
            local entity_type = ENTITY.GET_ENTITY_TYPE(raycastResult.hitEntity)
            util.log("Loading entity type "..entity_type)
            if entity_type > 0 then
                model_hash = entities.get_model_hash(raycastResult.hitEntity)
            end
        end
    end

    if config.debug_mode then
        util.draw_debug_text("didhit = "..raycastResult.didHit)
        util.draw_debug_text("handle = "..raycastResult.hitEntity)
        util.draw_debug_text("endcoords = "..raycastResult.endCoords.x..","..raycastResult.endCoords.y)
        util.draw_debug_text("hash = "..tostring(model_hash))
    end

    if raycastResult.didHit and model_hash ~= nil then
        -- Handle Entity Target
        if raycastResult.hitEntity ~= nil and ENTITY.DOES_ENTITY_EXIST(raycastResult.hitEntity) then
            return cmm.build_target_from_handle(raycastResult.hitEntity)
        end
    end
end

cmm.get_raycast_target = function()
    local raycastResult

    -- Raycast for Entity Objects
    raycastResult = get_raycast_result(config.selection_distance, config.trace_flag_value)
    local target = cmm.build_target_from_raycast_result(raycastResult)
    if target then return target end

    -- Raycast for World Coords
    raycastResult = get_raycast_result(config.selection_distance, constants.TRACE_FLAG.ALL)
    if raycastResult.endCoords.x ~= 0 and raycastResult.endCoords.y ~= 0 then
        return cmm.build_target_from_position(raycastResult.endCoords)
    end
end

cmm.refresh_screen_pos = function(target)
    if not target then return end
    if target.handle then
        target.pos = ENTITY.GET_ENTITY_COORDS(target.handle, true)
    end
    if target.pos and GRAPHICS.GET_SCREEN_COORD_FROM_WORLD_COORD(target.pos.x, target.pos.y, target.pos.z, pointx, pointy) then
        target.screen_pos = { x=memory.read_float(pointx), y=memory.read_float(pointy)}
    else
        target.screen_pos = {x=0, y=0}
    end
end

--local menu_cam

--local function create_cam(coords) --credits to Hexarobi for the functions and help with them.
--    --local cam_pos = ENTITY.GET_OFFSET_FROM_ENTITY_IN_WORLD_COORDS(veh, 0, 2, 5)
--    if menu_cam ~= nil then return end
--    util.toast("creating dam", TOAST_ALL)
--    local cam_rot = CAM.GET_FINAL_RENDERED_CAM_ROT(2)
--    local cam_pos = CAM.GET_FINAL_RENDERED_CAM_COORD()
--    local cam_fov = CAM.GET_FINAL_RENDERED_CAM_FOV()
--    local cam = CAM.CREATE_CAM_WITH_PARAMS(
--        "DEFAULT_SCRIPTED_CAMERA",
--            cam_pos.x, cam_pos.y, cam_pos.z,
--            cam_rot.x, cam_rot.y, cam_rot.z, cam_fov, false, 0
--    )
--    --CAM.POINT_CAM_AT_ENTITY(camera, veh, 0, 0, 0, true)
--    CAM.SET_CAM_ACTIVE(cam, true)
--    CAM.RENDER_SCRIPT_CAMS(true, true, 1000, true, true, 0)
--    util.yield(1000)
--    CAM.STOP_CAM_POINTING(cam)
--    menu_cam = cam
--    return menu_cam
--end
--
--local function destroy_cam()
--    if menu_cam ~= nil then
--        util.toast("destroying dam", TOAST_ALL)
--        CAM.RENDER_SCRIPT_CAMS(false, false, 1000, true, false, 0)
--        CAM.DESTROY_CAM(menu_cam, true)
--        CAM.DESTROY_ALL_CAMS(true)
--        menu_cam = nil
--    end
--end

cmm.update_menu = function(target)
    cmm.handle_inputs(target)
    cmm.check_option_hotkeys(target)
    cmm.find_selected_option(target)
    cmm.draw_options_menu(target)
    cmm.draw_ped_preview(target)
end

cmm.open_options_menu = function(target)
    if not state.is_menu_open then
        cmm.build_relevant_options(target)
        target.selected_option = nil
        target.cursor_pos = { x=0.5, y=0.5, }
        PAD.SET_CURSOR_POSITION(target.cursor_pos.x, target.cursor_pos.y)
        state.is_menu_open = true
        -- Re-opening the menu while a trigger is executing cancels the trigger
        if target.selected_option then target.selected_option.ticks_shown = nil end
    end
end

cmm.close_options_menu = function(target)
    --if state.is_menu_open then
    --    cmm.trigger_selected_action(target)
    --end
    --if not target.selected_option then
        state.is_menu_open = false
    --end
end

cmm.draw_pointer_line = function(target)
    cmm.refresh_screen_pos(target)
    local pos = ENTITY.GET_OFFSET_FROM_ENTITY_IN_WORLD_COORDS(players.user_ped(), 0.0, 0.0, 0.0)
    if target.screen_pos.x ~= 0 and target.screen_pos.y ~= 0
            and GRAPHICS.GET_SCREEN_COORD_FROM_WORLD_COORD(pos.x, pos.y, pos.z, pointx, pointy) then
        local player_pos = { x=memory.read_float(pointx), y=memory.read_float(pointy)}
        directx.draw_line(player_pos.x, player_pos.y, target.screen_pos.x, target.screen_pos.y, config.color.target_bounding_box)
    end
end

cmm.draw_selection = function(target)
    if target.type == "COORDS" then
        util.draw_sphere(
            target.pos,
            config.target_ball_size,
            config.color.target_ball_output.r,
            config.color.target_ball_output.g,
            config.color.target_ball_output.b,
            config.color.target_ball_output.a,
            40
        )
    else
        cmm.draw_bounding_box(target)
        cmm.draw_pointer_line(target)
    end
end

cmm.build_option_wedge_points = function(target)
    -- If only one option then assume two so the menu isnt just a single circle
    local num_options = math.max(#target.relevant_options, 2)
    -- Split circle up into n slices of width `option_width` degrees
    target.option_width = 360 / num_options
    for option_index, option in target.relevant_options do
        if option.name ~= nil then
            option.option_angle = ((option_index-1) * target.option_width) - 90
            option.point_angles = calculate_point_angles(target, option, option.option_angle, target.option_width)
            option.wedge_points = build_wedge_points(option.point_angles, target)
            option.vertices = build_vertices_list(option.wedge_points)
        end
    end
end

menu.my_root():toggle_loop("Context Menu Enabled", {}, "Right-click on in-game objects to open context menu.", function()
    config.context_menu_enabled = true
    cmm.context_menu_draw_tick()
end, function()
    config.context_menu_enabled = false
end)

---
--- Menu Options Menu
---

local function add_option_to_menu(root_menu, menu_option)
    if menu_option.menu ~= nil then return root_menu:link(menu_option.menu) end
    menu_option.menu = root_menu:list(menu_option.name, {}, "")
    menu_option.menu:divider(menu_option.name)
    menu_option.menu:toggle("Enabled", {}, "Enabled options will show up in menu", function(value)
        menu_option.enabled = value
    end, menu_option.enabled)
    menu_option.menu:text_input("Hotkey", {"cmmhotkey"..menu_option.item_id}, "Press this key while the menu is open to select this option", function(value)
        menu_option.hotkey = value
    end, menu_option.hotkey or "")
    menu_option.menu:slider("Priority", {"cmmpriority"..menu_option.item_id}, "Higher priority options appear higher in the menu order", -1000, 1000, menu_option.priority or 0, 1, function(value)
        menu_option.priority = value
    end)
    -- build_menu_option_description(menu_option)
    if menu_option.config_menu ~= nil then
        menu_option.menu:divider("Config")
        menu_option.config_menu(menu_option.menu)
    end

    return menu_option.menu
end

local function add_menu_options_menus()
    local root_item = {
        name="Menu Options",
        items=cmm.menu_options,
        description="Browsable list of all menu options you have installed"
    }
    item_browser.browse_item(menu.my_root(), root_item, add_option_to_menu)
    return root_item.menu
end

add_menu_options_menus()

---
--- Settings Menu
---

menus.settings = menu.my_root():list("Settings", {}, "Configuration options for this script.")
menus.settings:toggle("Disable When Armed", {}, "Only display the context menu when you are not holding a weapon", function(value)
    config.disable_when_armed = value
end, config.disable_when_armed)
menus.settings:toggle("Disable In Vehicles", {}, "Only display the menu when on foot, outside of a vehicle", function(value)
    config.disable_in_vehicles = value
end, config.disable_in_vehicles)

menus.settings_controls = menus.settings:list("Controls", {}, "Configure the controls to open, close, and select menu items.")
menus.settings_controls:hyperlink("Controls Reference", "https://docs.fivem.net/docs/game-references/controls/")
menus.settings_controls:divider("Keyboard")
menus.settings_controls:slider("Open Menu", {"cmmkbopenmenukey"}, "Which control input opens the menu.", 1, 360, config.controls.keyboard.open_menu, 1, function(value)
    config.controls.keyboard.open_menu = value
end)
menus.settings_controls:slider("Close Menu", {"cmmkbclosemenukey"}, "Which control input closes the menu.", 1, 360, config.controls.keyboard.close_menu, 1, function(value)
    config.controls.keyboard.close_menu = value
end)
menus.settings_controls:slider("Select Item", {"cmmkbselectmenukey"}, "Which control input selects an item from the menu.", 1, 360, config.controls.keyboard.select_option, 1, function(value)
    config.controls.keyboard.select_option = value
end)
menus.settings_controls:divider("Controller")
menus.settings_controls:slider("Open Menu", {"cmmconopenmenukey"}, "Which control input opens the menu.", 1, 360, config.controls.controller.open_menu, 1, function(value)
    config.controls.controller.open_menu = value
end)
menus.settings_controls:slider("Close Menu", {"cmmconclosemenukey"}, "Which control input closes the menu.", 1, 360, config.controls.controller.close_menu, 1, function(value)
    config.controls.controller.close_menu = value
end)
menus.settings_controls:slider("Select Item", {"cmmconselectmenukey"}, "Which control input selects an item from the menu.", 1, 360, config.controls.controller.select_option, 1, function(value)
    config.controls.controller.select_option = value
end)

menus.settings:toggle("Hot Keys Enabled", {}, "Hotkeys allow for selecting menu options by pressing keyboard keys.", function(value)
    config.hot_keys_enabled = value
end, config.hot_keys_enabled)

menus.settings:divider("Targeting")

menus.settings_snap_distance = menus.settings:list("Snap Distance", {}, "How close your crosshair needs to be to an entity to snap to it")
menus.settings_snap_distance:slider_float("Player Snap Distance", {"cmmsnapdistanceplayer"}, "How close your crosshair needs to be to a player to snap to it", 0, 100, math.floor(config.target_snap_distance.player * 100), 1, function(value)
    config.target_snap_distance.player = value / 100
end)
menus.settings_snap_distance:slider_float("Vehicle Snap Distance", {"cmmsnapdistancevehicle"}, "How close your crosshair needs to be to a vehicle to snap to it", 0, 100, math.floor(config.target_snap_distance.vehicle * 100), 1, function(value)
    config.target_snap_distance.vehicle = value / 100
end)
menus.settings_snap_distance:slider_float("Ped Snap Distance", {"cmmsnapdistanceped"}, "How close your crosshair needs to be to a ped to snap to it", 0, 100, math.floor(config.target_snap_distance.ped * 100), 1, function(value)
    config.target_snap_distance.ped = value / 100
end)
menus.settings_snap_distance:slider_float("Object Snap Distance", {"cmmsnapdistanceobject"}, "How close your crosshair needs to be to a object to snap to it", 0, 100, math.floor(config.target_snap_distance.object * 100), 1, function(value)
    config.target_snap_distance.object = value / 100
end)

menus.settings_target_distances = menus.settings:list("Target Distances", {}, "How far away an entity can be and still be targeted.")
menus.settings_target_distances:slider("Target Player Distance", {"cmmtargetplayerdistance"}, "The range that other players are targetable", 1, 5000, config.target_player_distance, 10, function(value)
    config.target_player_distance = value
end)
menus.settings_target_distances:slider("Target Vehicle Distance", {"cmmtargetvehicledistance"}, "The range that vehicles are targetable", 1, 5000, config.target_vehicle_distance, 10, function(value)
    config.target_vehicle_distance = value
end)
menus.settings_target_distances:slider("Target Ped Distance", {"cmmtargetpeddistance"}, "The range that peds are targetable", 1, 5000, config.target_ped_distance, 10, function(value)
    config.target_ped_distance = value
end)
menus.settings_target_distances:slider("Target Object Distance", {"cmmtargetobjectdistance"}, "The range that objects are targetable", 1, 5000, config.target_object_distance, 10, function(value)
    config.target_object_distance = value
end)
menus.settings_target_distances:slider("Target World Distance", {"cmmtargetworlddistance"}, "The range that world coords are targetable", 1, 600, config.selection_distance, 10, function(value)
    config.selection_distance = value
end)

menus.settings_trace_flags = menus.settings:list("Trace Flags", {}, "Set what kind of entities you can target")
for _, trace_flag_option in config.trace_flag_options do
    menus.settings_trace_flags:toggle(trace_flag_option.name, {}, "", function(value)
        trace_flag_option.enabled = value
        cmm.rebuild_trace_flag_value()
    end, trace_flag_option.enabled)
end

menus.settings:divider("Display")

menus.settings_show_target_texts = menus.settings:list("Show Target Texts", {}, "Show various text options on target")
menus.settings_show_target_texts:toggle("Show Target Name", {}, "Should the target model name be displayed above the menu", function(value)
    config.show_target_name = value
end, config.show_target_name)
menus.settings_show_target_texts:toggle("Show Target Owner", {}, "Should the player that owns the object be displayed above the menu in paranthesis", function(value)
    config.show_target_owner = value
end, config.show_target_owner)
menus.settings_show_target_texts:toggle("Show Option Help", {}, "Should the selected option help text be displayed below the menu", function(value)
    config.show_option_help = value
end, config.show_option_help)

menus.settings:slider("Target Ball Size", {"cmmtargetballsize"}, "The size of the world target cursor ball", 5, 140, config.target_ball_size * 100, 5, function(value)
    config.target_ball_size = value / 100
end)
menus.settings:slider("Menu Radius", {"cmmmenuradius"}, "The size of the context menu disc", 5, 25, config.menu_radius * 100, 1, function(value)
    config.menu_radius = value / 100
end)
menus.settings:slider("Deadzone", {"cmmdeadzone"}, "The center of the menu where no option is selected", 5, 30, config.option_wedge_deadzone * 100, 1, function(value)
    config.option_wedge_deadzone = value / 100
end)
menus.settings:slider("Option Padding", {"cmmoptionpadding"}, "The spacing between options", 0, 25, config.option_wedge_padding * 100, 1, function(value)
    config.option_wedge_padding = value / 100
end)

menus.settings_player_previews = menus.settings:list("Player Previews", {}, "Options about displaying previews when targeting other players")
menus.settings_player_previews:toggle("Enable Player Previews", {}, "Display previews of the players model when targeting", function(value)
    config.ped_preview.enabled = value
end, config.ped_preview.enabled)
menus.settings_player_previews:list_select("Preset Name", {"cmmplayerpreviewpresetname"}, "The selected preset name used for the rendering.", constants.preset_name_list, constants.preset_name_index_map[config.ped_preview.preset_name], function(value, menu_name)
    config.ped_preview.preset_name = menu_name
    menu.set_value(menus.settings_player_previews_preset_slot, config.ped_preview.preset_slot)
    menu.set_max_value(menus.settings_player_previews_preset_slot, constants.preset_slot_values[config.ped_preview.preset_name])
end)
menus.settings_player_previews_preset_slot = menus.settings_player_previews:slider("Preset Slot", {"cmmplayerpreviewpresetslot"}, "The selected preset slot used for the rendering.", 0, constants.preset_slot_values[config.ped_preview.preset_name], 0, 1, function(value)
    config.ped_preview.preset_slot = value
end)
menus.settings_player_previews:slider("Player Preview Pos X", {"cmmplayerpreviewposx"}, "", -20, 20, config.ped_preview.pos.x * 10, 1, function(value)
    config.ped_preview.pos.x = value / 10
end)
menus.settings_player_previews:slider("Player Preview Pos Y", {"cmmplayerpreviewposy"}, "", -100, 10, config.ped_preview.pos.y * 10, 1, function(value)
    config.ped_preview.pos.y = value / 10
end)
menus.settings_player_previews:slider("Player Preview Pos Z", {"cmmplayerpreviewposz"}, "", -20, 20, config.ped_preview.pos.z * 10, 1, function(value)
    config.ped_preview.pos.z = value / 10
end)

menus.settings_colors = menus.settings:list("Colors")
menu.inline_rainbow(menus.settings_colors:colour("Target Ball Color", {"cmmcolortargetball"}, "The ball cursor when no specific entity is selected", config.color.target_ball, true, function(color)
    config.color.target_ball = color
    config.color.target_ball_output = cmm.color_menu_output(config.color.target_ball)
end))
menu.inline_rainbow(menus.settings_colors:colour("Target Bounding Box Color", {"cmmcolortargetboundingbox"}, "The bounding box cursor when a specific entity is selected", config.color.target_bounding_box, true, function(color)
    config.color.target_bounding_box = color
    config.color.target_bounding_box_output = cmm.color_menu_output(config.color.target_bounding_box)
end))
menu.inline_rainbow(menus.settings_colors:colour("Menu Circle Color", {"cmmcolorcirclecolor"}, "The menu circle color", config.color.options_circle, true, function(color)
    config.color.options_circle = color
end))
menu.inline_rainbow(menus.settings_colors:colour("Option Wedge Color", {"cmmcolorwedgecolor"}, "An individual option wedge color", config.color.option_wedge, true, function(color)
    config.color.option_wedge = color
end))
menu.inline_rainbow(menus.settings_colors:colour("Selected Option Wedge Color", {"cmmcolorselectedwedgecolor"}, "The currently selected option wedge color", config.color.selected_option_wedge, true, function(color)
    config.color.selected_option_wedge = color
end))
menu.inline_rainbow(menus.settings_colors:colour("Line to Target Color", {"cmmcolortargetcolor"}, "Line from menu to target color", config.color.line_to_target, true, function(color)
    config.color.line_to_target = color
end))

---
--- About Menu
---

local script_meta_menu = menu.my_root():list("About ContextMenu", {}, "Information about the script itself")
script_meta_menu:divider("ContextMenu")
script_meta_menu:readonly("Version", SCRIPT_VERSION)
if auto_update_config and auto_updater then
    script_meta_menu:action("Check for Update", {}, "The script will automatically check for updates at most daily, but you can manually check using this option anytime.", function()
        auto_update_config.check_interval = 0
        if auto_updater.run_auto_update(auto_update_config) then
            util.toast("No updates found")
        end
    end)
end
script_meta_menu:hyperlink("Github Source", "https://github.com/hexarobi/stand-lua-context-menu", "View source files on Github")
script_meta_menu:hyperlink("Discord", "https://discord.gg/RF4N7cKz", "Open Discord Server")
script_meta_menu:divider("Credits")
script_meta_menu:readonly("Main Developer", "Hexarobi")
script_meta_menu:readonly("Player Previews", "Baiawai")
script_meta_menu:readonly("World Object Targeting", "Davus")
script_meta_menu:readonly("Model Hash Resolution", "aarroonn")
script_meta_menu:readonly("Foundational Work", "murten")
script_meta_menu:readonly("Foundational Work", "Wiri")

---
--- Tick Handlers
---

--util.create_tick_handler(cmm.context_menu_draw_tick)
