-- Shared State

local shared_state = {}

-- Set global var from defaults above
if CONTEXT_MENU_SHARED_STATE == nil then
    CONTEXT_MENU_SHARED_STATE = shared_state
end

-- Return global var
return CONTEXT_MENU_SHARED_STATE
