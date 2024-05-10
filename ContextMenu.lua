-- Context Menu Manager
-- by Hexarobi
-- with code from Wiri, aarroonn, and Davus

local SCRIPT_VERSION = "0.10"

-- Auto Updater from https://github.com/hexarobi/stand-lua-auto-updater
local status, auto_updater = pcall(require, "auto-updater")
if not status then
    if not async_http.have_access() then
        util.toast("Failed to install auto-updater. Internet access is disabled. To enable automatic updates, please stop the script then uncheck the `Disable Internet Access` option.")
    else
        local auto_update_complete = nil util.toast("Installing auto-updater...", TOAST_ALL)
        async_http.init("raw.githubusercontent.com", "/hexarobi/stand-lua-auto-updater/main/auto-updater.lua",
                function(raw_result, raw_headers, raw_status_code)
                    local function parse_auto_update_result(result, headers, status_code)
                        local error_prefix = "Error downloading auto-updater: "
                        if status_code ~= 200 then util.toast(error_prefix..status_code, TOAST_ALL) return false end
                        if not result or result == "" then util.toast(error_prefix.."Found empty file.", TOAST_ALL) return false end
                        filesystem.mkdir(filesystem.scripts_dir() .. "lib")
                        local file = io.open(filesystem.scripts_dir() .. "lib\\auto-updater.lua", "wb")
                        if file == nil then util.toast(error_prefix.."Could not open file for writing.", TOAST_ALL) return false end
                        file:write(result) file:close() util.toast("Successfully installed auto-updater lib", TOAST_ALL) return true
                    end
                    auto_update_complete = parse_auto_update_result(raw_result, raw_headers, raw_status_code)
                end, function() util.toast("Error downloading auto-updater lib. Update failed to download.", TOAST_ALL) end)
        async_http.dispatch() local i = 1 while (auto_update_complete == nil and i < 40) do util.yield(250) i = i + 1 end
        if auto_update_complete == nil then error("Error downloading auto-updater lib. HTTP Request timeout") end
        auto_updater = require("auto-updater")
    end
end
if auto_updater == true then error("Invalid auto-updater lib. Please delete your Stand/Lua Scripts/lib/auto-updater.lua and try again") end

---
--- Auto Updater
---

local auto_update_config = {
    --source_url="https://raw.githubusercontent.com/hexarobi/stand-lua-context-menu/main/ContextMenu.lua",
    script_relpath=SCRIPT_RELPATH,
    project_url="https://github.com/hexarobi/stand-lua-context-menu",
}
if auto_updater == true then
    auto_updater.run_auto_update(auto_update_config)
end


--- Context Menu Manager
local cmm = {
    menu_options = {},
}
local menus = {}

util.require_natives("3095a")

util.ensure_package_is_installed('lua/inspect')
local inspect = require("inspect")

local config = {
    debug_mode = false,
    context_menu_enabled=true,
    color = {
        options_circle={r=1, g=1, b=1, a=0.1},
        option_text={r=1, g=1, b=1, a=1},
        help_text={r=0.8, g=0.8, b=0.8, a=1},
        option_wedge={r=1, g=1, b=1, a=0.3},
        selected_option_wedge={r=1, g=0, b=1, a=0.3},
        target_ball={r=1,g=0,b=1,a=0.8},
        target_bounding_box={r=1,g=0,b=1,a=1},
        crosshair={r=1, g=1, b=1, a=0.5},
    },
    target_ball_size=0.4,
    selection_distance=1000.0,
    menu_radius=0.1,
    option_label_distance=0.6,
    option_wedge_deadzone=0.2,
    option_wedge_padding=0.0,
    show_target_name=true,
    show_option_help=true,
    menu_options_scripts_dir="lib/ContextMenus",
}

local CONTEXT_MENUS_DIR = filesystem.scripts_dir()..config.menu_options_scripts_dir
filesystem.mkdirs(CONTEXT_MENUS_DIR)

local function debug_log(text)
    util.log("[ContextMenuManager] "..text)
end

cmm.add_context_menu_option = function(menu_option)
    cmm.default_menu_option(menu_option)
    debug_log("Adding menu option "..menu_option.name or "Unknown")
    table.insert(cmm.menu_options, menu_option)
end

cmm.default_menu_option = function(menu_option)
    if menu_option.name == nil then menu_option.name = "Unknown Name" end
    if menu_option.enabled == nil then menu_option.enabled = true end
    if menu_option.priority == nil then menu_option.priority = 0 end
end

cmm.empty_menu_option = function()
    return {
        name="",
        priority=-1,
        is_empty=true
    }
end

cmm.refresh_menu_options_from_files = function(directory, path)
    if path == nil then path = "" end
    for _, filepath in ipairs(filesystem.list_files(directory)) do
        if filesystem.is_dir(filepath) then
            local _2, dirname = string.match(filepath, "(.-)([^\\/]-%.?)$")
            cmm.refresh_menu_options_from_files(filepath, path.."/"..dirname)
        else
            local _3, filename, ext = string.match(filepath, "(.-)([^\\/]-%.?)[.]([^%.\\/]*)$")
            if ext == "lua" or ext == "pluto" then
                local menu_option = require(config.menu_options_scripts_dir..path.."/"..filename)
                menu_option.filename = filename.."."..ext
                --debug_log("Loading menu option "..config.menu_options_scripts_dir..path.."/"..filename..": "..inspect(menu_option))
                --cc.expand_chat_command_defaults(command, filename, path)
                cmm.add_context_menu_option(menu_option)
            end
        end
    end
end

cmm.refresh_menu_options_from_files(CONTEXT_MENUS_DIR)

local context_menu = {}
local current_target = {}

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

context_menu.draw_bounding_box = function(target, colour)
    if colour == nil then
        colour = config.color.target_bounding_box
    end
    if target.model_hash == nil then
        debug_log("Could not draw bounding box: No model hash set")
        return
    end

    MISC.GET_MODEL_DIMENSIONS(target.model_hash, minimum, maximum)
    local minimum_vec = v3.new(minimum)
    local maximum_vec = v3.new(maximum)
    context_menu.draw_bounding_box_with_dimensions(target.handle, colour, minimum_vec, maximum_vec)
end

context_menu.draw_bounding_box_with_dimensions = function(entity, color, minimum_vec, maximum_vec)

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

    local colour = {r=color.r*255, g=color.g*255, b=color.b*255, a=color.a*255}

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

context_menu.draw_text_with_shadow = function(posx, posy, text, alignment, scale, color, force_in_bounds)
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

local TraceFlag =
{
    everything = 4294967295,
    none = 0,
    world = 1,
    vehicles = 2,
    pedsSimpleCollision = 4,
    peds = 8,
    objects = 16,
    water = 32,
    foliage = 256,
}

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
    flag = flag or TraceFlag.everything
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
--- Context Menu
---

local is_menu_open = false
local pointx = memory.alloc()
local pointy = memory.alloc()

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
    local radius = config.menu_radius
    local option_text_coords = get_circle_coords(target.menu_pos, radius*config.option_label_distance, option_angle)
    context_menu.draw_text_with_shadow(option_text_coords.x, option_text_coords.y, option.name, 5, 0.5, config.color.option_text, true)

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
        local top_point = get_circle_coords(target.menu_pos, config.menu_radius, point_angle)
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
    local mouse_movement = {
        x=PAD.GET_CONTROL_NORMAL(0, 13),
        y=PAD.GET_CONTROL_NORMAL(0, 12),
    }
    local magnitude = math.sqrt(mouse_movement.x ^ 2 + mouse_movement.y ^ 2)
    local angle = math.deg(math.atan(mouse_movement.y, mouse_movement.x))
    return angle, magnitude
end

local selected_option

local function pushback_to_center(current_pos, target_pos)
    local pushback_amount = 0.003
    local pushback_deadzone = 0.005
    local next_pos = {
        x = current_pos.x - target_pos.x,
        y = current_pos.y - target_pos.y,
    }
    --if current_pos > target_pos + pushback_deadzone then
    --    return current_pos - pushback_amount
    --elseif current_pos < target_pos - pushback_deadzone then
    --    return current_pos + pushback_amount
    --end


    --local magnitude = math.sqrt(next_pos.x ^ 2 + next_pos.y ^ 2)
    --local angle = math.deg(math.atan(next_pos.y, next_pos.x))
    --
    --return get_circle_coords(target_pos, 1 - magnitude, angle)

    return current_pos
end

context_menu.draw_options_menu = function(target, trigger_option)
    target.menu_pos = { x=0.5, y=0.5, }
    directx.draw_circle(target.menu_pos.x, target.menu_pos.y, config.menu_radius, config.color.options_circle)
    directx.draw_line(0.5, 0.5, target.screen_pos.x, target.screen_pos.y, config.color.crosshair)
    --directx.draw_circle(target.cursor_pos.x, target.cursor_pos.y, 0.001, config.color.crosshair)

    if config.show_target_name and target.name ~= nil then
        context_menu.draw_text_with_shadow(target.menu_pos.x, target.menu_pos.y - (config.menu_radius * 1.9), target.name, 5, 0.5, config.color.option_text, true)
    end

    PAD.DISABLE_CONTROL_ACTION(0, 1, false) --x
    PAD.DISABLE_CONTROL_ACTION(0, 2, false) --y
    if PAD.IS_USING_KEYBOARD_AND_MOUSE(1) then
        HUD.SET_MOUSE_CURSOR_THIS_FRAME()
        HUD.SET_MOUSE_CURSOR_STYLE(1)
        target.cursor_pos = {
            x=PAD.GET_CONTROL_NORMAL(0, 239),
            y=PAD.GET_CONTROL_NORMAL(0, 240),
        }
    else
        local angle, magnitude = get_controls_angle_magnitude()
        -- TODO: controller work
    end


    -- If only one option then assume two so the menu isnt just a single circle
    local num_options = math.max(#target.relevant_options, 2)
    -- Split circle up into n slices of width `option_width` degrees
    local option_width = 360 / num_options
    for option_index, option in target.relevant_options do
        if option.name ~= nil then

            local option_angle = ((option_index-1) * option_width) - 90
            local point_angles = calculate_point_angles(target, option, option_angle, option_width)
            local wedge_points = build_wedge_points(point_angles, target)

            --if angle then
            --    local first_point_angle = point_angles[1]
            --    local last_point_angle = point_angles[#point_angles]
            --    local is_option_pointed_at = is_angle_between(angle, first_point_angle, last_point_angle)
            --    if is_option_pointed_at and magnitude > 0.1 then
            --        selected_option = option
            --    elseif selected_option == option and (not is_option_pointed_at) then
            --        selected_option = nil
            --    end
            --end
            --local is_selected = selected_option == option

            local vertices = build_vertices_list(wedge_points)
            local is_selected = is_point_in_polygon(target.cursor_pos.x, target.cursor_pos.y, vertices)
            if is_selected then
                selected_option = option
            elseif selected_option == option then
                selected_option = nil
            end

            local draw_color = config.color.option_wedge
            if is_selected then draw_color = config.color.selected_option_wedge end

            draw_polygon(wedge_points, draw_color)

            if config.show_option_help and is_selected then
                context_menu.draw_text_with_shadow(target.menu_pos.x, target.menu_pos.y + (config.menu_radius * 1.9), option.help, 5, 0.5, config.color.help_text, true)
            end

            if trigger_option and is_selected then
                if option.execute ~= nil and type(option.execute) == "function" then
                    util.log("Triggering option "..option.name)
                    option.execute(target)
                end
            end
        end
    end

end

local function is_menu_option_relevant(menu_option, target)
    if menu_option.enabled == false then
        return false
    end
    if menu_option.applicable_to ~= nil and not table.contains(menu_option.applicable_to, target.type) then
        return false
    end
    return true
end

context_menu.get_relevant_options = function(target)
    local relevant_options = {}
    for _, option in cmm.menu_options do
        if is_menu_option_relevant(option, target) then
            table.insert(relevant_options, option)
        end
    end
    --if #relevant_options == 1 then table.insert(relevant_options, cmm.empty_menu_option()) end
    table.sort(relevant_options, function(a,b) return a.name > b.name end)
    table.sort(relevant_options, function(a,b) return a.priority > b.priority end)
    return relevant_options
end

local function get_target_type(new_target)
    local entity_type = ENTITY_TYPES[ENTITY.GET_ENTITY_TYPE(new_target.handle)] or "WORLD_OBJECT"
    if entity_type == "PED" and entities.is_player_ped(new_target.handle) then
        return "PLAYER"
    end
    return entity_type
end

local function get_target_name(new_target)
    if new_target.type == "PLAYER" then
        for _, pid in players.list() do
            local player_ped = PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(pid)
            if player_ped == new_target.handle then
                return PLAYER.GET_PLAYER_NAME(pid)
            end
        end
    end
    return new_target.model
end

-- credit to the amazing aarroonn
local function get_model_hash(handle_or_ptr)
    if handle_or_ptr < 0xFFFFFF then
        handle_or_ptr = entities.handle_to_pointer(handle_or_ptr)
    end
    local model_info = memory.read_long(handle_or_ptr + 0x20)
    if model_info ~= 0 then
        return memory.read_int(model_info + 0x18)
    end
end

context_menu.build_target = function(raycastResult)
    local new_target = {}
    local model_hash
    if raycastResult.didHit then
        model_hash = get_model_hash(raycastResult.hitEntity)
    end

    if config.debug_mode then
        util.draw_debug_text("didhit = "..raycastResult.didHit)
        util.draw_debug_text("handle = "..raycastResult.hitEntity)
        util.draw_debug_text("endcoords = "..raycastResult.endCoords.x..","..raycastResult.endCoords.y)
        util.draw_debug_text("hash = "..tostring(model_hash))
    end

    if raycastResult.endCoords.x ~= 0 and raycastResult.endCoords.y ~= 0 then
        new_target.type = "COORDS"
        new_target.pos = {x=raycastResult.endCoords.x, y=raycastResult.endCoords.y, z=raycastResult.endCoords.z}
        new_target.name = "Coords: "..string.format("%.3f", new_target.pos.x)..","..string.format("%.3f", new_target.pos.y)
    end

    if raycastResult.didHit and model_hash ~= nil then
        if raycastResult.hitEntity ~= nil and ENTITY.DOES_ENTITY_EXIST(raycastResult.hitEntity) then
            new_target.handle = raycastResult.hitEntity
            new_target.model_hash = get_model_hash(new_target.handle)
            if new_target.model_hash then
                new_target.model = util.reverse_joaat(new_target.model_hash)
            end
            new_target.type = get_target_type(new_target)
            new_target.name = get_target_name(new_target)
        end
    end

    if new_target.type == "VEHICLE" and VEHICLE.GET_DISPLAY_NAME_FROM_VEHICLE_MODEL(new_target.model_hash) then
        new_target.name = VEHICLE.GET_DISPLAY_NAME_FROM_VEHICLE_MODEL(new_target.model_hash)
    end
    new_target.relevant_options = context_menu.get_relevant_options(new_target)
    new_target.screen_pos = { x=0.5, y=0.5, }
    return new_target
end

context_menu.get_raycast_target = function()
    --local flag = TraceFlag.peds | TraceFlag.vehicles | TraceFlag.pedsSimpleCollision | TraceFlag.objects
    local flag = TraceFlag.everything
    local raycastResult = get_raycast_result(config.selection_distance, flag)
    return context_menu.build_target(raycastResult)
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

context_menu.open = function()
    if not is_menu_open then
        selected_option = nil
        current_target.cursor_pos = { x=0.5, y=0.5, }
        PAD.SET_CURSOR_POSITION(current_target.cursor_pos.x, current_target.cursor_pos.y)
    end
    is_menu_open = true
    context_menu.draw_options_menu(current_target, false)
end

context_menu.close = function()
    if is_menu_open then
        context_menu.draw_options_menu(current_target, true)
    end
    is_menu_open = false
end

--local probe_start_pos_out = memory.alloc()
--local probe_end_pos_out = memory.alloc()

--local function get_mouse_cursor_dir()
--    SHAPETEST.START_SHAPE_TEST_MOUSE_CURSOR_LOS_PROBE(probe_start_pos_out, probe_end_pos_out, 0, 0, 0)
--    local probe_dir = v3.new(probe_end_pos_out)
--    probe_dir:sub(v3.new(probe_start_pos_out))
--    return probe_dir
--end

local function context_menu_draw_tick()
    if not config.context_menu_enabled then return true end

    PAD.DISABLE_CONTROL_ACTION(2, 25, true) --aim
    PAD.DISABLE_CONTROL_ACTION(2, 24, true) --attack
    PAD.DISABLE_CONTROL_ACTION(2, 257, true) --attack2

    if not is_menu_open then
        current_target = context_menu.get_raycast_target()
    end
    if current_target ~= nil and current_target.pos ~= nil then
        if current_target.type ~= "COORDS" and current_target.handle ~= nil then
            if not is_menu_open then
                local player_screen_pos = {x=0, y=0}
                local myPos = players.get_position(players.user())
                if GRAPHICS.GET_SCREEN_COORD_FROM_WORLD_COORD(myPos.x, myPos.y, myPos.z, pointx, pointy) then
                    player_screen_pos = {x=memory.read_float(pointx), y=memory.read_float(pointy)}
                end
                current_target.screen_pos = { x=0, y=0}
                current_target.pos = ENTITY.GET_ENTITY_COORDS(current_target.handle, true)
                if GRAPHICS.GET_SCREEN_COORD_FROM_WORLD_COORD(current_target.pos.x, current_target.pos.y, current_target.pos.z, pointx, pointy) then
                    current_target.screen_pos = { x=memory.read_float(pointx), y=memory.read_float(pointy)}
                end
            end
            if current_target.screen_pos.x > 0 and current_target.screen_pos.y > 0 then
                context_menu.draw_bounding_box(current_target)
                if PAD.IS_DISABLED_CONTROL_PRESSED(2, 25) then
                    context_menu.open()
                else
                    context_menu.close()
                end
            end
        else
            util.draw_sphere(
                current_target.pos,
                config.target_ball_size,
                config.color.target_ball.r*255,
                config.color.target_ball.g*255,
                config.color.target_ball.b*255,
                config.color.target_ball.a*255,
                40
            )
            if PAD.IS_DISABLED_CONTROL_PRESSED(2, 25) then
                if GRAPHICS.GET_SCREEN_COORD_FROM_WORLD_COORD(current_target.pos.x, current_target.pos.y, current_target.pos.z, pointx, pointy) then
                    current_target.screen_pos = { x=memory.read_float(pointx), y=memory.read_float(pointy)}
                end
                context_menu.open()
            else
                context_menu.close()
            end
        end
    else
    end

    return true
end

menu.my_root():toggle("Context Menu enabled", {}, "Right-click on in-game objects to open context menu.", function(value)
    config.context_menu_enabled = value
end, config.context_menu_enabled)

---
--- Menu Options
---

menus.menu_options = menu.my_root():list("Menu Options", {}, "Enable or disable specific context menu options.")
menus.menu_options:action("Open ContextMenus Folder", {}, "Add ContextMenu scripts to this folder", function()
    util.open_folder(CONTEXT_MENUS_DIR)
end)

local function build_menu_option_description(menu_option)
    local text = menu_option.help or ""
    if menu_option.author then text = text.."\nAuthor: "..menu_option.author end
    if menu_option.filename then text = text.."\nFilename: "..menu_option.filename end
    return text
end

menus.menu_options:divider("Menu Options")
for _, menu_option in cmm.menu_options do
    menus.menu_options:toggle(menu_option.name, {}, build_menu_option_description(menu_option), function(value)
        menu_option.enabled = value
    end, menu_option.enabled)
end

---
--- Settings Menu
---

menus.settings = menu.my_root():list("Settings", {}, "Configuration options for this script.")
menus.settings:toggle("Show Target Name", {}, "Should the target model name be displayed above the menu", function(value)
    config.show_target_name = value
end, config.show_target_name)
menus.settings:toggle("Show Option Help", {}, "Should the selected option help text be displayed below the menu", function(value)
    config.show_option_help = value
end, config.show_option_help)
menus.settings:slider("Selection Distance", {}, "The range that the context menu can find clickable targets", 1, 2000, config.selection_distance, 10, function(value)
    config.selection_distance = value
end)
menus.settings:slider("Menu Radius", {}, "The size of the context menu disc", 5, 25, config.menu_radius * 100, 1, function(value)
    config.menu_radius = value / 100
end)
menus.settings:slider("Deadzone", {}, "The center of the menu where no option is selected", 5, 30, config.option_wedge_deadzone * 100, 1, function(value)
    config.option_wedge_deadzone = value / 100
end)
menus.settings:slider("Option Padding", {}, "The spacing between options", 0, 25, config.option_wedge_padding * 100, 1, function(value)
    config.option_wedge_padding = value / 100
end)

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

---
--- Tick Handlers
---

util.create_tick_handler(context_menu_draw_tick)
