gdebug.log_info("SHIT mod: Preload Online.")

local mod = game.mod_runtime[game.current_mod]

local time_interval_6 = TimeDuration.from_hours(6)

-- 화장실을 사용하는 함수
game.iuse_functions["using_toilet"] = function (...)
    return mod.iuse_function_toilet(...)
end

-- 화장지를 사용하는 함수
game.iuse_functions["finish_pondering"] = function (...)
    return mod.finish_pondering(...)
end

game.iuse_functions["SHIT_use_toiletry"] = function(...)
    return mod.iuse_toiletry(...)
end

-- 퇴비통을 사용하는 함수
game.iuse_functions["use_composter"] = function (...)
    return mod.iuse_composter(...)
end

mod.time_checker = function()
    -- 6시간마다 더러움 수치 상승.
    -- 사흘 이상 안 씻으면 정말 심각한 수준이 됨.
    mod.update_dirty(2)
    mod.check_hygiene()
    mod.manure_aging()
end

gapi.add_on_every_x_hook(time_interval_6, mod.time_checker)