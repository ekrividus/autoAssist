_addon.version = '0.7.0'
_addon.name = 'autoAssist'
_addon.author = 'Ekrividus'
_addon.commands = {'autoAssist', 'aassist', 'aa'}
_addon.lastUpdate = '12/11/2020'
_addon.windower = '4'

config = require('config')

defaults = {}
defaults.show_debug = false
defaults.approach = true
defaults.max_range = 3.5
defaults.face_target = true
defaults.update_time = 2
defaults.assist_target = nil
defaults.engage = true

local running = false
local approaching = false
local player = nil
local mob = nil

settings = config.load(defaults)

settings.show_debug = true

last_check_time = os.clock()
next_check_time = 0

function proper_case(s)
    return s:sub(1,1):upper()..s:sub(2)
end

function message(str, debug)
    if (debug and debug == true) then
        if (settings.show_debug and settings.show_debug == true) then
            windower.add_to_chat(17, _addon.name.." (debug): "..str)
        end
        return
    end
    windower.add_to_chat(17, _addon.name..": "..str)
end

function buff_active(id)
    if T(windower.ffxi.get_player().buffs):contains(BuffID) == true then
        return true
    end
    return false
end

function is_disabled()
    if (buff_active(0)) then -- KO
        return true
    elseif (buff_active(2)) then -- Sleep
        return true
    elseif (buff_active(6)) then -- Silence
        return true
    elseif (buff_active(7)) then -- Petrification
        return true
    elseif (buff_active(10)) then -- Stun
        return true
    elseif (buff_active(14)) then -- Charm
        return true
    elseif (buff_active(28)) then -- Terrorize
        return true
    elseif (buff_active(29)) then -- Mute
        return true
    elseif (buff_active(193)) then -- Lullaby
        return true
    elseif (buff_active(262)) then -- Omerta
        return true
    end
    return false
end

function engage()
    if (settings.assist_target and windower.ffxi.get_mob_by_name(settings.assist_target)) then
        windower.send_command("input /assist \""..settings.assist_target.."\"")
        if (settings.engage) then
            windower.send_command("wait 1.25; input /attack on")
        end
    end
end

function is_facing_target()
	local self_vector = windower.ffxi.get_mob_by_index(player.index or 0)
    local mob = windower.ffxi.get_mob_by_target("t")
    if (not mob) then
        return
    end

    local angle = (math.atan2((mob.y - self_vector.y), (mob.x - self_vector.x))*180/math.pi)
    message("Facing Target "..tostring(angle).." degrees", true)

    if (angle > 150 and angle < 180) then
        return true
    end
    return false
end

function face_target()
    message("Turning to face Target", true)
	local self_vector = windower.ffxi.get_mob_by_index(player.index or 0)
    local mob = windower.ffxi.get_mob_by_target("t")
    if (not mob) then
        return
    end

    local angle = (math.atan2((mob.y - self_vector.y), (mob.x - self_vector.x))*180/math.pi)*-1
    local rads = angle:radian()
    windower.ffxi.turn(rads)
end

function is_in_range()
    local m = windower.ffxi.get_mob_by_target("t")
    if (m and m.distance:sqrt() > settings.max_range) then
        message("Out of Range", true)
        return false
    end
    message("In Range", true)
    return true
end

function approach(start)
    if (start) then
        message("Approaching", true)
        local self_vector = windower.ffxi.get_mob_by_index(windower.ffxi.get_player().index or 0)
        local mob = windower.ffxi.get_mob_by_target("t")
        if (not mob) then
            return
        end
    
        local angle = (math.atan2((mob.y - self_vector.y), (mob.x - self_vector.x))*180/math.pi)*-1
        local rads = angle:radian()

        windower.ffxi.run(rads)
        approaching = true
        return
    end
    windower.ffxi.run(false)
    approaching = false
end

--[[ Windower Events ]]--
windower.register_event('prerender', function(...)
    if (approaching) then
        if (is_in_range()) then
            approach(false)
        end
    end
    if (not running) then
        next_check_time = 0
        return
    end

    local time = os.clock()
	local delta_time = time - last_check_time
	last_check_time = time

    if (time < next_check_time) then
        return
    end
    next_check_time = time + settings.update_time
    player = windower.ffxi.get_player()
    mob = windower.ffxi.get_mob_by_target("t")

    if (mob and player.status == 1) then 
        if (not is_facing_target()) then
            face_target()
        end
        if (not is_in_range()) then
            approach(true)
        end
        return
    end

    if (player.status == 0 and not is_disabled()) then
        engage()
    end
end)

-- Stop checking if logout happens
windower.register_event('logout', function(...)
	windower.send_command('autoAssist off')
	player = nil
	return
end)

-- Process incoming commands
windower.register_event('addon command', function(...)
	local cmd = ''
	if (#arg > 0) then
		cmd = arg[1]:lower()
	end

    if (cmd == nil or cmd == '') then
        running = not running
        message((running and "Starting" or "Stopping"))
    elseif (cmd == 'test') then
        message("Quick Test")
        engage()
        is_facing_target()
        face_target()
        is_in_range()
        approach()
    elseif (T{'on','start','go'}:contains(cmd)) then 
        running = true
        message("Starting")
    elseif (T{'off','stop','end'}:contains(cmd)) then
        running = false
        message("Stopping")
    elseif (cmd == 'assist') then
        message("Setting assist target to "..proper_case(arg[2]))
        if (#arg < 2) then
            message("You need to specify a player to assist.")
            return
        end
        if (windower.ffxi.get_mob_by_name(arg[2]) == nil) then
            message("You need to specify a valid player to assist.")
            return
        end
        settings.assist_target = arg[2]
    elseif (cmd == 'engage') then
        settings.engage = not settings.engage
        message("Will now "..(settings.engage and "engage" or "not engage"))
    elseif (cmd == 'approach') then
        settings.approach = not settings.approach
        message("Will now "..(settings.engage and "approach" or "not approach"))
    elseif (cmd == 'range') then
        settings.max_range = tonumber(arg[2]) or 3.5
        message("Will close to "..settings.max_range.."'")
    elseif (cmd == 'face') then
        settings.face_target = not settings.face_target
        message("Will now "..(settings.engage and "" or "not").." face target")
    elseif (cmd == 'update') then
        settings.update_time = tonumber(arg[2]) or 2
        message("Time between updates "..settings.update_time.." second(s)")
    elseif (cmd == 'debug') then
        settings.show_debug = not settings.show_debug
        message("Debug info will be shown.")
    elseif (cmd == 'save') then
        settings:save()
        message("Settings saved.")
    elseif (cmd == 'show') then
        for k,v in pairs(settings) do
            windower.add_to_chat(17, tostring(k)..": "..tostring(v))
        end
    end
end)