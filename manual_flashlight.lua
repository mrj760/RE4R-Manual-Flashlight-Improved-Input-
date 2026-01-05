-- set to different key
local keyboard_key_name = "X"

-- set to different gamepad buttons, press both at same time to trigger flashlight.
-- setting to the same button twice would mean you only have to press that one.
local gamepad_key_name_1  = "LTrigBottom"
local gamepad_key_name_2 = "Decide"

local GP_GRACE_FRAMES = 3
local gp_release_timer_1 = -1
local gp_release_timer_2 = -1

local keyboard_singleton = sdk.get_native_singleton("via.hid.Keyboard")
local keyboard_typedef = sdk.find_type_definition("via.hid.Keyboard")
local keyboardkey_typedef = sdk.find_type_definition("via.hid.KeyboardKey")
local gamepad_singleton = sdk.get_native_singleton("via.hid.GamePad")
local gamepad_typedef = sdk.find_type_definition("via.hid.GamePad")
local gamepadbutton_typedef = sdk.find_type_definition("via.hid.GamePadButton")

local kb_button_data = keyboardkey_typedef:get_field(keyboard_key_name):get_data(nil)
local gp_button_data_1 = gamepadbutton_typedef:get_field(gamepad_key_name_1):get_data(nil)
local gp_button_data_2 = gamepadbutton_typedef:get_field(gamepad_key_name_2):get_data(nil)

local kb = sdk.call_native_func(keyboard_singleton, keyboard_typedef, "get_Device")
local gp = sdk.call_native_func(gamepad_singleton, gamepad_typedef, "get_Device")

local light_switch_zone_manager = sdk.get_managed_singleton("chainsaw.LightSwitchZoneManager")
local character_manager = sdk.get_managed_singleton("chainsaw.CharacterManager")

local light_state = false
local allow_change = false

local function get_player_id()
    player = character_manager:call("getPlayerContextRef")
    if player ~= nil then
        id = player:get_field("<KindID>k__BackingField")
        if id == 100000 or id == 380000 then -- return if leon or ada
            return id
        end
    end
    return -1
end

local function prevent_auto_switch(args)
    local id = sdk.to_int64(args[3])
    if not allow_change and id == get_player_id() then
        return sdk.PreHookResult.SKIP_ORIGINAL
    end
    allow_change = false
end

sdk.hook(
    light_switch_zone_manager.notifyLightSwitch,
    prevent_auto_switch,
    function(x) return x end
)

re.on_frame(function()
    local kb_release = kb:call("isRelease", kb_button_data)

    local gp_release_1 = gp:call("isRelease", gp_button_data_1)
    local gp_release_2 = gp:call("isRelease", gp_button_data_2)

    -- Start timers when either stick is released
    if gp_release_1 then
        gp_release_timer_1 = GP_GRACE_FRAMES
    end

    if gp_release_2 then
        gp_release_timer_2 = GP_GRACE_FRAMES
    end

    -- Count timers down
    if gp_release_timer_1 >= 0 then
        gp_release_timer_1 = gp_release_timer_1 - 1
    end

    if gp_release_timer_2 >= 0 then
        gp_release_timer_2 = gp_release_timer_2 - 1
    end

    -- Both sticks released close enough together
    local gp_combo =
        gp_release_timer_1 >= 0 and
        gp_release_timer_2 >= 0

    if kb_release or gp_combo then
        local id = get_player_id()
        if id == -1 then
            return
        end

        -- Reset timers so it only fires once
        gp_release_timer_1 = -1
        gp_release_timer_2 = -1

        allow_change = true
        light_state = not light_state
        light_switch_zone_manager:notifyLightSwitch(id, light_state)
    end
end)