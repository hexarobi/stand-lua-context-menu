-- Context Menu
-- by Hexarobi
-- with code from Wiri

util.require_natives("3095a")

local config = {
    color = {
        options_circle={r=1, g=1, b=1, a=0.1},
        option_text={r=1, g=1, b=1, a=1},
        option_wedge={r=1, g=0.5, b=0.5, a=0.3},
        target_bounding_box={r=255,g=0,b=0,a=255},
        crosshair={r=1, g=1, b=1, a=0.5},
    }
}

local atest = {}

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
atest.draw_bounding_box = function(entity, colour)
    if colour == nil then
        colour = {r=255,g=0,b=0,a=255}
    end

    MISC.GET_MODEL_DIMENSIONS(ENTITY.GET_ENTITY_MODEL(entity), minimum, maximum)
    local minimum_vec = v3.new(minimum)
    local maximum_vec = v3.new(maximum)
    atest.draw_bounding_box_with_dimensions(entity, colour, minimum_vec, maximum_vec)
end

atest.draw_bounding_box_with_dimensions = function(entity, colour, minimum_vec, maximum_vec)

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

---
---
---

local target = {}
local isMenuOpen = false
local pointx = memory.alloc()
local pointy = memory.alloc()

local options = {
    {
        name="Option #1",
    },
    {
        name="Option #2",
    },
    {
        name="Option #3",
    },
    {
        name="Option #4",
    },
    {
        name="Option #5",
    },
    {
        name="Option #6",
    },
    {
        name="Option #7",
    },
    {
        name="Option #8",
    }
}

local function get_circle_coords(origin, radius, angle_degree)
    local angle_radian = math.rad(angle_degree)
    return {
        x=(radius) * math.cos(angle_radian) + origin.x,
        y=(radius) * math.sin(angle_radian) + origin.y
    }
end

atest.draw_options_menu = function(target)
    local radius = 0.2
    directx.draw_circle(target.screen_pos.x, target.screen_pos.y, radius, config.color.options_circle)
    local text = util.reverse_joaat(ENTITY.GET_ENTITY_MODEL(target.handle))
    directx.draw_text(target.screen_pos.x, target.screen_pos.y, text, 5, 0.5, config.color.option_text, true)

    local option_width = 360 / #options
    for option_index, option in options do

        local option_text_angle = (option_index-1) * option_width
        local option_text_coords = get_circle_coords(target.screen_pos, radius, option_text_angle)
        directx.draw_text(option_text_coords.x, option_text_coords.y, option.name, 5, 0.5, config.color.option_text, true)

        local option_start_angle = option_text_angle - (option_width/2.1)
        local option_start_coords = get_circle_coords(target.screen_pos, radius, option_start_angle)
        local option_end_angle = option_text_angle + (option_width/2.1)
        local option_end_coords = get_circle_coords(target.screen_pos, radius, option_end_angle)

        directx.draw_triangle(
            target.screen_pos.x, target.screen_pos.y,
            option_start_coords.x, option_start_coords.y,
            option_end_coords.x, option_end_coords.y,
            config.color.option_wedge
        )
    end

end

menu.my_root():toggle_loop("Crosshair", {}, "", function(value)
    directx.draw_circle(0.5, 0.5, 0.001, config.color.crosshair)
    if not isMenuOpen then
        local flag = TraceFlag.peds | TraceFlag.vehicles | TraceFlag.pedsSimpleCollision | TraceFlag.objects
        local raycastResult = get_raycast_result(500.0, flag)
        if raycastResult.didHit and ENTITY.DOES_ENTITY_EXIST(raycastResult.hitEntity) then
            target.handle = raycastResult.hitEntity
        else
            target.handle = nil
        end
    end
    if target.handle ~= nil then
        local player_screen_pos = {x=0, y=0}
        local myPos = players.get_position(players.user())
        if GRAPHICS.GET_SCREEN_COORD_FROM_WORLD_COORD(myPos.x, myPos.y, myPos.z, pointx, pointy) then
            player_screen_pos = {x=memory.read_float(pointx), y=memory.read_float(pointy)}
        end
        target.screen_pos = {x=0, y=0}
        target.pos = ENTITY.GET_ENTITY_COORDS(target.handle, true)
        if GRAPHICS.GET_SCREEN_COORD_FROM_WORLD_COORD(target.pos.x, target.pos.y, target.pos.z, pointx, pointy) then
            target.screen_pos = {x=memory.read_float(pointx), y=memory.read_float(pointy)}
        end
        if target.screen_pos.x > 0 and target.screen_pos.y > 0 then
            --directx.draw_line(player_screen_pos.x, player_screen_pos.y, target.screen_pos.x, target.screen_pos.y, draw_color)
            atest.draw_bounding_box(target.handle, config.color.target_bounding_box)

            PAD.DISABLE_CONTROL_ACTION(2, 25, true) --aim
            PAD.DISABLE_CONTROL_ACTION(2, 24, true) --attack
            PAD.DISABLE_CONTROL_ACTION(2, 257, true) --attack2
            if PAD.IS_DISABLED_CONTROL_PRESSED(2, 25) then
                isMenuOpen = true
                CAM.POINT_CAM_AT_ENTITY(CAM.GET_RENDERING_CAM(), target.handle, 0, 0, 0, true)
                atest.draw_options_menu(target)
            else
                isMenuOpen = false
            end

        end

    end
end)