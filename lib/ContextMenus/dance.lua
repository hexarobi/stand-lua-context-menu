local function load_animation_dictionary(dictionary, timeout)
    if timeout == nil then timeout = 6000 end
    STREAMING.REQUEST_ANIM_DICT(dictionary)
    local end_time = util.current_time_millis() + timeout
    repeat util.yield() until STREAMING.HAS_ANIM_DICT_LOADED(dictionary) or util.current_time_millis() >= end_time
end

local animation_flags = {
    ANIM_FLAG_NORMAL = 0,
    ANIM_FLAG_REPEAT = 1,
    ANIM_FLAG_STOP_LAST_FRAME = 2,
    ANIM_FLAG_UPPERBODY = 16,
    ANIM_FLAG_ENABLE_PLAYER_CONTROL = 32,
    ANIM_FLAG_CANCELABLE = 120
}

local dance_animations = {
    {
        clip = "hi_dance_facedj_17_v2_male^5",
        dictionary = "anim@amb@nightclub@dancers@podium_dancers@",
        loop = true,
        name = "Dance"
    }, {
        clip = "high_center_down",
        dictionary = "anim@amb@nightclub@mini@dance@dance_solo@male@var_b@",
        loop = true,
        name = "Dance 2"
    }, {
        clip = "high_center",
        dictionary = "anim@amb@nightclub@mini@dance@dance_solo@male@var_a@",
        loop = true,
        name = "Dance 3"
    }, {
        clip = "high_center_up",
        dictionary = "anim@amb@nightclub@mini@dance@dance_solo@male@var_b@",
        loop = true,
        name = "Dance 4"
    }, {
        clip = "med_center",
        dictionary = "anim@amb@casino@mini@dance@dance_solo@female@var_a@",
        loop = true,
        name = "Dance 5"
    }, {
        clip = "dance_loop_tao",
        dictionary = "misschinese2_crystalmazemcs1_cs",
        loop = true,
        name = "Dance 6"
    }, {
        clip = "dance_loop_tao",
        dictionary = "misschinese2_crystalmazemcs1_ig",
        loop = true,
        name = "Dance 7"
    }, {
        clip = "dance_m_default",
        dictionary = "missfbi3_sniping",
        loop = true,
        name = "Dance 8"
    }, {
        clip = "med_center_up",
        dictionary = "anim@amb@nightclub@mini@dance@dance_solo@female@var_a@",
        loop = true,
        name = "Dance 9"
    }, {
        clip = "mi_dance_facedj_17_v1_female^1",
        dictionary = "anim@amb@nightclub@dancers@solomun_entourage@",
        loop = true,
        name = "Dance F"
    }, {
        clip = "high_center",
        dictionary = "anim@amb@nightclub@mini@dance@dance_solo@female@var_a@",
        loop = true,
        name = "Dance F2"
    }, {
        clip = "high_center_up",
        dictionary = "anim@amb@nightclub@mini@dance@dance_solo@female@var_a@",
        loop = true,
        name = "Dance F3"
    }, {
        clip = "hi_dance_facedj_09_v2_female^1",
        dictionary = "anim@amb@nightclub@dancers@crowddance_facedj@hi_intensity",
        loop = true,
        name = "Dance F4"
    }, {
        clip = "hi_dance_facedj_09_v2_female^3",
        dictionary = "anim@amb@nightclub@dancers@crowddance_facedj@hi_intensity",
        loop = true,
        name = "Dance F5"
    }, {
        clip = "high_center_up",
        dictionary = "anim@amb@nightclub@mini@dance@dance_solo@female@var_a@",
        loop = true,
        name = "Dance F6"
    },
    --{
    --    clip = "ambclub_13_mi_hi_sexualgriding_laz",
    --    controllable = true,
    --    dictionary = "anim@amb@nightclub@lazlow@hi_railing@",
    --    loop = true,
    --    name = "Dance Glowsticks",
    --    props = { {
    --                  bone = 28422,
    --                  placement = { 0.07, 0.14, 0.0, -80.0, 20.0 },
    --                  prop = "ba_prop_battle_glowstick_01"
    --              }, {
    --                  bone = 60309,
    --                  placement = { 0.07, 0.09, 0.0, -120.0, -20.0 },
    --                  prop = "ba_prop_battle_glowstick_01"
    --              } }
    --}, {
    --    clip = "ambclub_12_mi_hi_bootyshake_laz",
    --    dictionary = "anim@amb@nightclub@lazlow@hi_railing@",
    --    loop = true,
    --    name = "Dance Glowsticks 2",
    --    props = { {
    --                  bone = 28422,
    --                  placement = { 0.07, 0.14, 0.0, -80.0, 20.0 },
    --                  prop = "ba_prop_battle_glowstick_01"
    --              }, {
    --                  bone = 60309,
    --                  placement = { 0.07, 0.09, 0.0, -120.0, -20.0 },
    --                  prop = "ba_prop_battle_glowstick_01"
    --              } }
    --}, {
    --    clip = "ambclub_09_mi_hi_bellydancer_laz",
    --    dictionary = "anim@amb@nightclub@lazlow@hi_railing@",
    --    name = "Dance Glowsticks 3",
    --    props = { {
    --                  bone = 28422,
    --                  placement = { 0.07, 0.14, 0.0, -80.0, 20.0 },
    --                  prop = "ba_prop_battle_glowstick_01"
    --              }, {
    --                  bone = 60309,
    --                  placement = { 0.07, 0.09, 0.0, -120.0, -20.0 },
    --                  prop = "ba_prop_battle_glowstick_01"
    --              },
    --              loop = true
    --    }
    --},
    {
        clip = "low_center",
        dictionary = "anim@amb@nightclub@mini@dance@dance_solo@male@var_a@",
        loop = true,
        name = "Dance Shy"
    }, {
        clip = "low_center_down",
        dictionary = "anim@amb@nightclub@mini@dance@dance_solo@female@var_b@",
        loop = true,
        name = "Dance Shy 2"
    }, {
        clip = "mnt_dnc_buttwag",
        dictionary = "special_ped@mountain_dancer@monologue_3@monologue_3a",
        loop = true,
        name = "Dance Silly"
    }, {
        clip = "fidget_short_dance",
        dictionary = "move_clown@p_m_zero_idles@",
        loop = true,
        name = "Dance Silly 2"
    }, {
        clip = "fidget_short_dance",
        dictionary = "move_clown@p_m_two_idles@",
        loop = true,
        name = "Dance Silly 3"
    }, {
        clip = "danceidle_hi_11_buttwiggle_b_laz",
        dictionary = "anim@amb@nightclub@lazlow@hi_podium@",
        loop = true,
        name = "Dance Silly 4"
    }, {
        clip = "idle_a",
        dictionary = "timetable@tracy@ig_5@idle_a",
        loop = true,
        name = "Dance Silly 5"
    }, {
        clip = "idle_d",
        dictionary = "timetable@tracy@ig_8@idle_b",
        loop = true,
        name = "Dance Silly 6"
    }, {
        clip = "high_center",
        dictionary = "anim@amb@casino@mini@dance@dance_solo@female@var_b@",
        loop = true,
        name = "Dance Silly 7"
    }, {
        clip = "the_woogie",
        dictionary = "anim@mp_player_intcelebrationfemale@the_woogie",
        loop = true,
        name = "Dance Silly 8"
    }, {
        clip = "dance_loop_tyler",
        dictionary = "rcmnigel1bnmt_1b",
        loop = true,
        name = "Dance Silly 9"
    }, {
        clip = "low_center",
        dictionary = "anim@amb@nightclub@mini@dance@dance_solo@male@var_b@",
        loop = true,
        name = "Dance Slow"
    }, {
        clip = "low_center",
        dictionary = "anim@amb@nightclub@mini@dance@dance_solo@female@var_a@",
        loop = true,
        name = "Dance Slow 2"
    }, {
        clip = "low_center_down",
        dictionary = "anim@amb@nightclub@mini@dance@dance_solo@female@var_a@",
        loop = true,
        name = "Dance Slow 3"
    }, {
        clip = "low_center",
        dictionary = "anim@amb@nightclub@mini@dance@dance_solo@female@var_b@",
        loop = true,
        name = "Dance Slow 4"
    }, {
        clip = "high_center",
        controllable = true,
        dictionary = "anim@amb@nightclub@mini@dance@dance_solo@female@var_b@",
        loop = true,
        name = "Dance Upper"
    }, {
        clip = "high_center_up",
        controllable = true,
        dictionary = "anim@amb@nightclub@mini@dance@dance_solo@female@var_b@",
        loop = true,
        name = "Dance Upper 2"
    }
}

return {
    name="Dance",
    help="Causes to ped to dance",
    applicable_to={"PED"},
    --hotkey="BACKSPACE",
    execute=function(target)
        local dance_animation = dance_animations[math.random(1, #dance_animations)]
        load_animation_dictionary(dance_animation.dictionary)
        TASK.CLEAR_PED_TASKS_IMMEDIATELY(target.handle)
        TASK.TASK_PLAY_ANIM(
            target.handle, dance_animation.dictionary, dance_animation.clip,
            8.0, 8.0, (dance_animation.emote_duration or -1), animation_flags.ANIM_FLAG_REPEAT,
            0.0, false, false, false
        )
    end
}