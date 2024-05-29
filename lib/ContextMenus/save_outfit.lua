
local OUTFITS_DIR = filesystem.stand_dir() .. 'Outfits\\'

local menu_refs = {
    male=menu.ref_by_path("Self>Appearance>Transform>Playable Characters>Online Male"),
    female=menu.ref_by_path("Self>Appearance>Transform>Playable Characters>Online Female"),
}

local function string_ends(string, suffix)
    return string:sub(-#suffix) == suffix
end

local function file_exists(name)
    local f=io.open(name,"r")
    if f~=nil then io.close(f) return true else return false end
end

local function build_unique_filename(outfit_name)
    local filename
    local filename_counter = 1
    while filename_counter < 999 do
        if filename_counter > 1 then
            filename = outfit_name .. filename_counter
        else
            filename = outfit_name
        end
        local filepath = OUTFITS_DIR .. filename .. ".txt"
        if file_exists(filepath) then
            util.log("File already exists at "..filepath..". Retrying with new name...")
            filename_counter = filename_counter + 1
        else
            return filename
        end
    end
    error("Failed to generate unique filepath, too many copies of this name already exist.")
end

local function get_player_gender(pid)
    local model = ENTITY.GET_ENTITY_MODEL(PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(pid))
    if model == util.joaat("MP_M_Freemode_01") then
        return "female"
    elseif model == util.joaat("MP_F_Freemode_01") then
        return "male"
    end
end

local function set_player_gender(gender)
    if gender == "female" then
        menu.trigger_command(menu_refs.female)
    elseif gender == "male" then
        menu.trigger_command(menu_refs.male)
    end
end

local function wear_players_outfit(player_id)
    local menu_copy_outfit = menu.ref_by_rel_path(menu.player_root(player_id), "Copy Outfit")
    if menu.is_ref_valid(menu_copy_outfit) then
        menu.trigger_command(menu_copy_outfit)
    else
        error("Invalid ref by path for copy")
    end
end

local delay_time = 500

return {
    name = "Save Outfit",
    help = "Save the selected player's outfit to your Stand wardrobe",
    applicable_to = {"PLAYER"},
    hotkey = "O",
    execute = function(target)
        menu.trigger_commands("saveoutfit cmlastoutfit")
        util.yield(delay_time)

        if not target.player_id then
            error("Invalid player id "..tostring(target.player_id))
        end

        local player_gender = get_player_gender(players.user())
        local target_player_gender = get_player_gender(target.player_id)
        local target_player_name = PLAYER.GET_PLAYER_NAME(target.player_id)

        util.log("Copying player gender from "..target_player_name.." : "..target_player_gender)

        set_player_gender(target_player_gender)
        util.yield(delay_time)

        wear_players_outfit(target.player_id)
        util.yield(delay_time)
        
        local savedOutfitName = build_unique_filename(target_player_name)
        menu.trigger_commands("saveoutfit " .. savedOutfitName)
        util.toast("Saved outfit as "..savedOutfitName, TOAST_ALL)

        util.yield(delay_time)
        set_player_gender(player_gender)
        menu.trigger_commands("outfit cmlastoutfit")
    end
}
