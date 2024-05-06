-- Context Menu Manager
-- by Hexarobi
-- with code from Wiri

local SCRIPT_VERSION = "0.4"

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
    source_url="https://raw.githubusercontent.com/hexarobi/stand-lua-context-menu/main/ContextMenu.lua",
    script_relpath=SCRIPT_RELPATH,
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
    color = {
        options_circle={r=1, g=1, b=1, a=0.1},
        option_text={r=1, g=1, b=1, a=1},
        help_text={r=0.8, g=0.8, b=0.8, a=1},
        option_wedge={r=1, g=1, b=1, a=0.3},
        selected_option_wedge={r=1, g=0.5, b=0.5, a=0.5},
        target_bounding_box={r=255,g=0,b=0,a=255},
        crosshair={r=1, g=1, b=1, a=0.5},
    },
    selection_distance=1000.0,
    menu_radius=0.1,
    option_label_distance=0.6,
    option_wedge_deadzone=0.15,
    option_wedge_padding=0.9,

    menu_options_scripts_dir="lib/ContextMenus",
}

local CONTEXT_MENUS_DIR = filesystem.scripts_dir()..config.menu_options_scripts_dir
filesystem.mkdirs(CONTEXT_MENUS_DIR)

local function debug_log(text)
    util.log("[ContextMenuManager] "..text)
end

local function is_in(needle, list)
    for _, item in pairs(list) do if item == needle then return true end end
    return false
end

cmm.add_context_menu_option = function(menu_option)
    cmm.default_menu_option(menu_option)
    debug_log("Adding menu option "..menu_option.name or "Unknown")
    table.insert(cmm.menu_options, menu_option)
end

cmm.default_menu_option = function(menu_option)
    if menu_option.enabled == nil then menu_option.enabled = true end
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

-- From GridSpawn
context_menu.draw_bounding_box = function(entity, colour)
    if colour == nil then
        colour = {r=255,g=0,b=0,a=255}
    end

    MISC.GET_MODEL_DIMENSIONS(ENTITY.GET_ENTITY_MODEL(entity), minimum, maximum)
    local minimum_vec = v3.new(minimum)
    local maximum_vec = v3.new(maximum)
    context_menu.draw_bounding_box_with_dimensions(entity, colour, minimum_vec, maximum_vec)
end

context_menu.draw_bounding_box_with_dimensions = function(entity, colour, minimum_vec, maximum_vec)

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


local function build_wedge_points(target, option, option_index, option_width)

    local radius = config.menu_radius
    local option_angle = ((option_index-1) * option_width) - 90
    local option_text_coords = get_circle_coords(target.menu_pos, radius*config.option_label_distance, option_angle)
    context_menu.draw_text_with_shadow(option_text_coords.x, option_text_coords.y, option.name, 5, 0.5, config.color.option_text, true)

    local point_angles = {
        option_angle - (option_width / 2 * config.option_wedge_padding),
        option_angle - (option_width / 4 * config.option_wedge_padding),
        option_angle,
        option_angle + (option_width / 4 * config.option_wedge_padding),
        option_angle + (option_width / 2 * config.option_wedge_padding),
    }

    local top_points = {}
    local bottom_points = {}
    for _, point_angle in point_angles do
        local top_point = get_circle_coords(target.menu_pos, radius, point_angle)
        table.insert(top_points, top_point)
        local bottom_point = get_circle_coords(target.menu_pos, radius * config.option_wedge_deadzone, point_angle)
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

context_menu.draw_options_menu = function(target, trigger_option)
    target.menu_pos = {
        x=target.screen_pos.x - target.offset.x,
        y=target.screen_pos.y - target.offset.y,
    }
    directx.draw_circle(target.menu_pos.x, target.menu_pos.y, config.menu_radius, config.color.options_circle)
    context_menu.draw_text_with_shadow(target.menu_pos.x, target.menu_pos.y - (config.menu_radius * 1.9), target.name, 5, 0.5, config.color.option_text, true)

    -- Split circle up into n slices of width `option_width` degrees
    local option_width = 360 / #target.relevant_options
    for option_index, option in target.relevant_options do
        if option.name ~= nil then

            local wedge_points = build_wedge_points(target, option, option_index, option_width)
            local vertices = build_vertices_list(wedge_points)
            local is_selected = is_point_in_polygon(0.5, 0.5, vertices)

            local draw_color = config.color.option_wedge
            if is_selected then draw_color = config.color.selected_option_wedge end

            draw_polygon(wedge_points, draw_color)

            if is_selected then
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
    if menu_option.applicable_to ~= nil and not is_in(target.type, menu_option.applicable_to) then
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
    if #relevant_options == 1 then table.insert(relevant_options, {}) end
    return relevant_options
end

context_menu.build_target = function(handle)
    local new_target = {}
    new_target.handle = handle
    new_target.model_hash = ENTITY.GET_ENTITY_MODEL(new_target.handle)
    new_target.model = util.reverse_joaat(new_target.model_hash)
    new_target.name = new_target.model
    new_target.type = ENTITY_TYPES[ENTITY.GET_ENTITY_TYPE(new_target.handle)]
    if new_target.type == "VEHICLE" and VEHICLE.GET_DISPLAY_NAME_FROM_VEHICLE_MODEL(new_target.model_hash) then
        new_target.name = VEHICLE.GET_DISPLAY_NAME_FROM_VEHICLE_MODEL(new_target.model_hash)
    end
    new_target.relevant_options = context_menu.get_relevant_options(new_target)
    new_target.screen_pos = {
        x=0.5, y=0.5,
    }
    new_target.offset = {x=0, y=0}
    return new_target
end

context_menu.get_raycast_target = function()
    local flag = TraceFlag.peds | TraceFlag.vehicles | TraceFlag.pedsSimpleCollision | TraceFlag.objects
    local raycastResult = get_raycast_result(config.selection_distance, flag)
    if raycastResult.didHit and ENTITY.DOES_ENTITY_EXIST(raycastResult.hitEntity) then
        return context_menu.build_target(raycastResult.hitEntity)
    end
end

menu.my_root():toggle_loop("Context Menu", {}, "Enable right-click on in-game objects for context menu.", function(value)
    directx.draw_circle(0.5, 0.5, 0.001, config.color.crosshair)
    if not is_menu_open then
        current_target = context_menu.get_raycast_target()
    end
    if current_target ~= nil then
        --if not is_menu_open then
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
        --end
        if current_target.screen_pos.x > 0 and current_target.screen_pos.y > 0 then
            context_menu.draw_bounding_box(current_target.handle, config.color.target_bounding_box)
            PAD.DISABLE_CONTROL_ACTION(2, 25, true) --aim
            if PAD.IS_DISABLED_CONTROL_PRESSED(2, 25) then
                if not is_menu_open then
                    current_target.offset = {
                        x= current_target.screen_pos.x - 0.5,
                        y= current_target.screen_pos.y - 0.5,
                    }
                end
                is_menu_open = true
                context_menu.draw_options_menu(current_target, false)
            else
                if is_menu_open then
                    context_menu.draw_options_menu(current_target, true)
                end
                is_menu_open = false
            end
        end
    end
end)

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
--- About Menu
---

local script_meta_menu = menu.my_root():list("About ContextMenu", {}, "Information about the script itself")
script_meta_menu:divider("ContextMenu")
script_meta_menu:readonly("Version", SCRIPT_VERSION)
--if auto_update_config and auto_updater then
--    script_meta_menu:action("Check for Update", {}, "The script will automatically check for updates at most daily, but you can manually check using this option anytime.", function()
--        auto_update_config.check_interval = 0
--        if auto_updater.run_auto_update(auto_update_config) then
--            util.toast("No updates found")
--        end
--    end)
--end
script_meta_menu:hyperlink("Github Source", "https://github.com/hexarobi/stand-lua-context-menu", "View source files on Github")
script_meta_menu:hyperlink("Discord", "https://discord.gg/RF4N7cKz", "Open Discord Server")
