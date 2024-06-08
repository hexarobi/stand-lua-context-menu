-- Construct ContextMenu

local config = {
    construct_file="example.json"
}

local vehicle_utils = require("context_menu/vehicle_utils")
local state = require("context_menu/shared_state")

local CONSTRUCTS_DIR = filesystem.stand_dir() .. 'Constructs\\'

local function read_file(filepath)
    local file, err = io.open(filepath, "r")
    if file then
        local read_status, data = pcall(function() return file:read("*a") end)
        if not read_status then
            util.toast("Invalid construct file. "..filepath, TOAST_ALL)
            return
        end
        file:close()
        return data
    else
        error("Could not read file '" .. filepath .. "': " .. err, TOAST_ALL)
    end
end

return {
    name="Construct",
    help="Construct given thing here",
    applicable_to={"COORDS"},
    execute=function(target)
        local construct = soup.json.decode(read_file(CONSTRUCTS_DIR..construct_file))
        if construct == nil then
            util.toast("Failed to load construct file.")
        else
            util.toast("Spawning "..construct.name.." at "..target.pos.x..","..target.pos.y)
            construct.position = target.pos
            local camera_rotation = CAM.GET_FINAL_RENDERED_CAM_ROT(2)
            construct.world_rotation.z = camera_rotation.z
            vehicle_utils.spawn_construct(construct)
        end
    end,
    config_menu=function(menu_root)
        menu_root:text_input("Select Construct File", {"cmmselectconstruct"}, "What construct file will be loaded", function(value)
            config.construct_file = value
        end, config.construct_file)
    end
}