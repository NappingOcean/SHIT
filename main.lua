gdebug.log_info("SHIT mod: Main Online.")

local mod = game.mod_runtime[game.current_mod]
local storage = game.mod_storage[game.current_mod]

mod.mut_ponder1 = "QUICK_THOUGHT"
mod.mut_ponder2 = "DEEP_THOUGHT"

storage.dirty = 0

storage.paper_usage = 0

--메시지를 띄우는 함수.
mod.popup = function (msg)
    local ui_popup = QueryPopup.new()
    ui_popup:message(msg)
    ui_popup:message_color(Color.c_white)
    ui_popup:allow_any_key(true)
    ui_popup:query()
    return 0
end

mod.hours = function (int)
    return TimeDuration.from_hours(int)
end

-- 발병 함수
mod.disease_20 = function (chance)
    local user = gapi.get_avatar()
    local disease = {
        EffectTypeId.new("skin_infected"),
        EffectTypeId.new("typhoid_fever")
    }
    for _, dis in ipairs(disease) do
        local dis_die = math.random(20)
        local dis_dur = math.random(24, 72)
        if chance > dis_die then
            user:add_effect(dis, mod.hours(dis_dur))
        end
    end
end

-- 불결성 업데이트 함수.
mod.update_dirty = function (dirty_num)
    local old_dirty = storage.dirty
    local new_dirty = old_dirty + dirty_num

    if new_dirty < -20 then
        new_dirty = -20
    end

    storage.dirty = new_dirty
end

-- 위생 평가 함수
-- 위생이 나쁠 경우 피부병이나 장티푸스 등의 질병에 걸리게 된다.
mod.check_hygiene = function ()
    local dirty = storage.dirty
    local user = gapi.get_avatar()
    local eff_clean = EffectTypeId.new("SHIT_clean")
    local SQUEAM_bool = user:has_trait(MutationBranchId.new("SQUEAMISH"))
    local feel_dirty = MoraleTypeDataId.new("SHIT_too_dirty")

    if dirty > 20 then
        -- 더러움 20 이상. 이런 세상이라 쳐도 정말 더러움. 질병 확률 높음.
        mod.disease_20(20)
        if SQUEAM_bool then
            -- add_morale(Character, MoraleTypeDataId, int(for bonus), int(for limiting previous one), TimeDuration, TimeDuration(for starting to decay))
            -- You can ignore bool or ItypeRaw. It's optional.
            user:add_morale(feel_dirty, -10, -30, mod.hours(12), mod.hours(4))
        else
            user:add_morale(feel_dirty, -5, -20, mod.hours(6), mod.hours(2))
        end
    elseif dirty > 0 then
        -- 더러움 0 ~ 20. 꼬질꼬질함. 이런 세상에서 이 정도면 양반이다. 질병 확률 낮음.
        mod.disease_20(dirty)
        if SQUEAM_bool then
            user:add_morale(feel_dirty, -8, -25, mod.hours(12), mod.hours(4))
        else
        end
    else
        -- 더러움 0 ~ -20 이하. 깨끗함. 좀비 세상에선 비인간적일 정도의 청결 수준.
        if SQUEAM_bool then
            -- 결벽증과 호궁합!
            user:add_effect(eff_clean, mod.hours(6), nil, 2)
        else
            user:add_effect(eff_clean, mod.hours(6))
        end
    end
end

-- 여기까지가 every_x_hook 에 들어가는 함수 내용임. --


-- 이 이후부터는 아이템 사용 훅에 들어가는 함수 내용임. --

--빠른 사색
mod.process_no_1 = function(who)
    local spell = SpellTypeId.new("toilet_spell_no1")
    local mut = MutationBranchId.new(mod.mut_ponder1)
    local detect_bladder = who:get_effect_int(EffectTypeId.new("bladder_boom"))
    if detect_bladder == 0 then
        mod.popup(locale.gettext("아직은 사색할 필요가 없을 것 같군요."))
        return 0
    else
        --WARNING: Pondering freezes you. If you want to move again, you should wait for a while and press \'e\' key.
        gapi.popup(locale.gettext("경고: 사색 중에는 움직일 수 없습니다."))
        who:set_mutation(mut)
        who:set_moves(-100*60)
        SpellSimple.prompt_cast(spell, who:get_pos_ms())
    end
    return 0
end

--깊은 사색
mod.process_no_2 = function (who)
    local spell = SpellTypeId.new("toilet_spell_no2")
    local mut = MutationBranchId.new(mod.mut_ponder2)
    local whose_pos = who:get_pos_ms()
    -- 변의 총량
    local detect_r = who:get_effect_int(EffectTypeId.new("over_thought"))
    --[[
    아래의 두 지역 변수는 함께 존재할 수 없는 두 효과의 수를 비교하기 위함.
    양수면 해당 효과의 비타민이 풍부, 음수면 부족하단 의미.
    ]]--
    local detect_fat = who:get_effect_int(EffectTypeId.new("fat_alert")) - who:get_effect_int(EffectTypeId.new("fat_alert_lack"))
    local detect_fiber = who:get_effect_int(EffectTypeId.new("fiber_alert")) - who:get_effect_int(EffectTypeId.new("fiber_alert_lack"))
    if detect_r == 0 then
        -- You are not ready to ponder deeply.
        mod.popup(locale.gettext("아직은 깊게 사색할 필요가 없을 것 같군요."))
        return 0
    else
        who:set_mutation(mut)
        -- You are concentrating for pondering...
        gapi.add_msg(locale.gettext("사색에 집중하기 시작합니다..."))
        gapi.popup(locale.gettext("경고: 사색 중에는 움직일 수 없습니다."))
        if detect_fat < detect_r and detect_fiber < detect_r then
            --둘 다 부족하여 불완전 사색 발생
            SpellSimple.prompt_cast(spell, whose_pos, spell:max_level()//4*3)
            who:set_moves(-100*60*12)
            storage.paper_usage = 3
        elseif detect_fat < detect_r then
            --변비 발생
            SpellSimple.prompt_cast(spell, whose_pos, spell:max_level()//3)
            who:set_moves(-100*60*30)
            storage.paper_usage = 4
        elseif detect_fiber < detect_r then
            --설사 발생
            SpellSimple.prompt_cast(spell, whose_pos, spell:max_level()//3*2)
            who:set_moves(-100*60*15)
            storage.paper_usage = 6
        else
            --정상 배변
            SpellSimple.prompt_cast(spell, whose_pos, spell:max_level())
            who:set_moves(-100*60*10)
            storage.paper_usage = 4
        end
    end
    return 0
end

-- --다들 아시는 그거
-- --이거는 나중에 만들도록 하자고. 지금으로선 아이템을 변수로 넣기가 힘들다.
-- mod.process_x = function (who)
--     return 0
-- end

-- 화장실을 쓴다!
mod.iuse_function_toilet = function (who, item, pos)
    local map = gapi.get_map()
    local toilet_list = {
        FurnId.new("f_toilet"),
        FurnId.new("SHIT_f_toilet_improvised"),
        FurnId.new("SHIT_f_toilet_wellmade")
    }
    local r_u_in_toilet = false

    for _, toilet in pairs(toilet_list) do
        if map:get_furn_at(pos) == toilet:int_id() then
            r_u_in_toilet = true
        end
    end
    if not r_u_in_toilet then
        -- This is not an appropriate place for a cultured person to \'ponder\'! Please sit properly on the toilet.
        mod.popup(locale.gettext("여기는 교양인이 '사색'하기에는 부적절한 장소입니다! 제대로 변기에 앉으세요."))
        return 0
    else
        if who:wearing_something_on(BodyPartTypeIntId.new(BodyPartTypeId.new("leg_l"))) or who:wearing_something_on(BodyPartTypeIntId.new(BodyPartTypeId.new("leg_r"))) then
            -- A cultured person cannot \'ponder\' while wearing their pants!
            mod.popup("교양인은 바지를 입은 채로 \'사색\'할 수 없습니다!")
            return 0
        else
            
            local ui_ponder_select = UiList.new()
            --교양인으로서 어떻게 사색할 건가?
            ui_ponder_select:title(locale.gettext("Do what?"))
            ui_ponder_select:add(1, locale.gettext("가볍게 사색하기"))
            ui_ponder_select:add(2, locale.gettext("깊게 사색하기"))
            -- ui_ponder_select:add(3, locale.gettext("…아니면 다른거."))
            local ponder_select = ui_ponder_select:query()
            if ponder_select < 1 then
                gapi.add_msg(locale.gettext("Nevermind."))
                return 0
            elseif ponder_select == 1 then
                return mod.process_no_1(who)
            elseif ponder_select == 2 then
                return mod.process_no_2(who)
            -- elseif ponder_select == 3 then
            --     if who:is_wielding("mag_porn") then
            --         return mod.process_x(who)
            --     else
            --         -- You don't have such literature to expand your knowledge of… indecent matters.
            --         mod.popup("불미스런 교양을 채우기엔 그런 분야의 책을 들고 있지 않군요.")
            --         return 0
            --     end
                
            end
        end
    end
end

-- use toilet paper!
-- 화장지를 사용하는 함수
mod.finish_pondering = function (who, item, pos)
    local sophi = MutationBranchId.new("SOPHISTICATE")
    
    if not who:has_trait(sophi) then
        -- 사색을 하지 않은 상태에서 호출
        gapi.add_msg(locale.gettext("굳이 지금 사용하지 않아도 될 것 같군요."))
        return 0
    else
        -- 사색을 마친 직후라면
        local ui_afterwork = UiList.new()
        ui_afterwork:title(locale.gettext("Do what?"))
        ui_afterwork:add(1, locale.gettext("사색을 마무리하기"))
        local aw_select = ui_afterwork.query()
        if aw_select < 1 then
            gapi.add_msg(locale.gettext("Nevermind."))
            return 0
        else
            gapi.add_msg(locale.gettext("교양인으로서 사색을 마무리하는 과정을 가졌습니다."))
            who:unset_mutation(sophi)
            local usage_cur = 0
            usage_cur = usage_cur + storage.paper_usage
            storage.paper_usage = 0
            if item:get_type():str() == "SHIT_t_paper_rough" then
                local text_die = math.random(4)
                local after_text = {
                    locale.gettext("너무 거칠거칠합니다...!"),
                    locale.gettext("사색의 끝이 가혹합니다!"),
                    locale.gettext("종이가 교양적이지 못한 게 안타깝군요."),
                    locale.gettext("오늘따라 예전의 문명사회가 더욱 그립습니다...")
                }
                gapi.add_msg(after_text[text_die])

            elseif item:get_type():str() == "SHIT_t_paper_soft" then
                local text_die = math.random(3)
                local after_text ={
                    locale.gettext("교양적인 부드러움을 느꼈습니다."),
                    locale.gettext("사색의 끝은 완벽한 마무리였습니다."),
                    locale.gettext("문명사회는 아직 끝나지 않은 듯한 착각이 들었습니다.")
                }
                gapi.add_msg(after_text[text_die])
            end
            return usage_cur
        end
    end
end

-- 퇴비통 함수! --

storage.compo = {}

-- 시간 함수에 들어가게 될 것.
mod.manure_aging = function ()
    for _,compo_data in ipairs(storage.compo) do
        if compo_data.is_fermenting then
            compo_data.age = compo_data.age + 0.25
        end
    end
end

-- 퇴비통 사용 함수
mod.iuse_composter = function ( who, item, pos )
    local spell = SpellTypeId.new("composter_magic")
    local ui_compo = UiList.new()
    local map = gapi.get_map()
    -- hacky trick for boolean.
    local valid_compo = {
        ["SHIT_composter_running"] = true
    }

    local new_compo = {}

    -- 저장된 compo data가 아무거나 있는가?
    local found_data = false

    --finding where fresh composter is.--
    local adj_tri = {}
    for y = -1, 1 do
        for x = -1, 1 do
            local new_tri = Tripoint.new(pos.x + x, pos.y + y, pos.z)
            if valid_compo[map:get_furn_at(new_tri):str_id():str()] then
                adj_tri[#adj_tri+1] = new_tri
            end
        end
    end
    local sel_pos = Tripoint.new()
    local sel_pos_abs = Tripoint.new(pos)
    
    if #adj_tri == 0 then
        gdebug.log_info("주변에 퇴비통이 없음에도 퇴비통 사용자가 발생했습니다.")
        return 0
    elseif #adj_tri == 1 then
        sel_pos = adj_tri[1]
    else
        repeat
            sel_pos = gapi.choose_adjacent(locale.gettext("사용하려는 퇴비통을 선택해주세요."), false)
            if sel_pos == nil then
                gapi.add_msg(locale.gettext("Nevermind."))
                return 0
            end
            if not valid_compo[map:get_furn_at(sel_pos):str_id():str()] then
                mod.popup(locale.gettext("그곳에는 퇴비통이 없습니다! 다시 선택해주세요."))
            end
        until valid_compo[map:get_furn_at(sel_pos):str_id():str()]
    end
    sel_pos_abs = map:get_abs_ms(sel_pos)
    -- sel_pos 는 현재 맵에서의 상대 좌표로서 등록.
    -- sel_pos_abs 는 절대 좌표로서 등록될 것이다.
    --END: finding where composter is.--
    
    local compo_order = 0
    -- 저장되어 있는 new_compo로부터 현재 위치와 일치하는 값을 불러온다.
    for _, compo_data in ipairs(storage.compo) do
        compo_order = compo_order + 1
        if compo_data.where == sel_pos_abs then
            new_compo = compo_data
            found_data = true
            break
        end
    end
    if not found_data then
        new_compo = {
            where         = sel_pos_abs,
            is_upset      = false,
            is_fermenting = false,
            age           = 0
        }
        storage.compo[#storage.compo+1] = new_compo
        compo_order = compo_order + 1
    end

    if not new_compo.is_fermenting then
        --this means the compo is not "SHIT_composter_running"
        ui_compo:title(locale.gettext("퇴비통으로 무엇을 하시겠습니까?"))
        ui_compo:add(1, locale.gettext("퇴비 발효 시작하기"))
        local select1 = ui_compo:query()
        if select1 == 1 then
            gapi.add_msg(locale.gettext("뚜껑을 덮고 발효를 시작했습니다. 중간에 뒤집어주면 더 빨리 될 것 같습니다."))
            new_compo.is_fermenting = true
            map:set_furn_at(sel_pos, FurnId.new("SHIT_composter_running"):int_id())
            return 0
        else
            gapi.add_msg(locale.gettext("Nevermind."))
            return 0
        end
    elseif new_compo.age <= 4 then
        mod.popup(locale.gettext("퇴비가 발효 중입니다. 뒤집기에는 아직 이른 것 같습니다."))
        return 0
    elseif new_compo.age <= 7 and not new_compo.is_upset then
        ui_compo:title(locale.gettext("퇴비가 발효 중입니다. 무엇을 하시겠습니까?"))
        ui_compo:add(1, locale.gettext("퇴비통을 뒤집는다"))
        local select2 = ui_compo:query()
        if select2 == 1 then
            new_compo.is_upset = true
            gapi.add_msg(locale.gettext("퇴비가 뒤집히면서 내부의 가라앉은 공기와 함께 뒤섞입니다."))
            new_compo.age = new_compo.age + 3
            return 0
        else
            gapi.add_msg(locale.gettext("Nevermind."))
            return 0
        end
    elseif new_compo.age < 10 then
        mod.popup(locale.gettext("퇴비가 발효 중입니다. 또 뒤집을 필요는 없을 것 같습니다."))
        return 0
    else
        mod.popup(locale.gettext("발효가 끝났습니다! 보다 흙냄새에 가까워진 그것을 당신은 조심스레 줍습니다."))
        new_compo.is_fermenting = false
        map:set_furn_at(sel_pos, FurnId.new("SHIT_composter"):int_id())
        SpellSimple.prompt_cast(spell, sel_pos, 25)
        table.remove(storage.compo, compo_order)
        return 0
    end
end

mod.iuse_toiletry = function(who, item, pos)
    local ui_toiletry = UiList.new()
    ui_toiletry:title(locale.gettext("세면도구로 무엇을 하시겠습니까?"))
    ui_toiletry:add(1, locale.gettext("얼굴을 씻기(3)"))
    ui_toiletry:add(2, locale.gettext("몸을 닦기(8)"))

    local sel_ui = ui_toiletry:query()
    if sel_ui < 1 then
        gapi.add_msg(locale.gettext("Nevermind."))
        return 0
    elseif sel_ui == 1 then
        gapi.add_msg(locale.gettext("얼굴을 깨끗하게 씻었습니다."))
        mod.update_dirty(-3)
        return 3
    elseif sel_ui == 2 then
        gapi.add_msg(locale.gettext("전신을 깨끗하게 닦았습니다. 샤워가 조금 그립지만 이 정도도 감지덕지죠."))
        mod.update_dirty(-8)
        return 8
    end
end