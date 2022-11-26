--[[
Copyright © 2020, Ekrividus
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.
    * Neither the name of autoMB nor the
      names of its contributors may be used to endorse or promote products
      derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL Ekrividus BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
]]

_addon.version = '0.8.0'
_addon.name = 'autoAssist'
_addon.author = 'Ekrividus'
_addon.commands = {'autoAssist', 'aassist', 'aa'}
_addon.lastUpdate = '12/11/2020'
_addon.windower = '4'

local config = require('config') 

local defaults = {}
defaults.show_debug = false
defaults.approach = true
defaults.retreat = true
defaults.min_range = 1.0
defaults.max_range = 3.0
defaults.face_target = true
defaults.update_time = 0.25
defaults.assist_target = ""
defaults.engage = true
defaults.engage_delay = 2
defaults.reposition = false
defaults.use_fastfollow = false
defaults.follow_target = ""

local running = false

local approaching = false
local retreating = false

local player = windower.ffxi.get_player()
local player_body = windower.ffxi.get_mob_by_id(player.id)
local mob = nil
local start_position = {x=nil, y=nil}
local is_following = false

local settings = config.load(defaults)
settings.show_debug = false
settings.min_range = settings.min_range or 1.0

local last_check_time = os.clock()
local next_check_time = 0

function proper_case(s)
    return s:sub(1,1):upper()..s:sub(2)
end

function message(str, debug_msg)
    if (debug_msg) then
        if (settings.show_debug and settings.show_debug == true) then
            windower.add_to_chat(207, _addon.name.." (debug): "..str)
        end
        return
    end
    windower.add_to_chat(207, _addon.name..": "..str)
end

function buff_active(id)
    if T(windower.ffxi.get_player().buffs):contains(id) == true then
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
    local assist_target = nil
    if (settings.assist_target and settings.assist_target ~= '') then
        assist_target = windower.ffxi.get_mob_by_name(settings.assist_target)
    else
        return
    end
    if (assist_target and assist_target.status == 1) then
        mob = windower.ffxi.get_mob_by_index(assist_target.target_index)
        if (not mob) then -- or not mob.claim_id or mob.claim_id == 0) then
            return
        end

        -- Assist our assist target and then engage
        local tgt = windower.ffxi.get_mob_by_target('t')
        if (not tgt or tgt.id ~= mob.id) then
            windower.send_command("input /assist \""..settings.assist_target.."\"")
            if (settings.engage and player.status == 0) then
                reposition(false)
                approach(false)
                windower.send_command("wait "..(settings.engage_delay >= 1 and settings.engage_delay or 1)..";input /attack on")
            end
        elseif (settings.engage and player.status == 0) then
            reposition(false)
            approach(false)
            windower.send_command("wait "..(settings.engage_delay >= 0 and settings.engage_delay or 0)..";input /attack on")
        end
    end
end

function is_facing_target()
    if (player == nil) then
        player = windower.ffxi.get_player()
    end
    mob = windower.ffxi.get_mob_by_target("t")
    if (not mob) then
        return
    end

    local player_body = windower.ffxi.get_mob_by_id(player.id)
    local angle = (math.atan2((mob.y - player_body.y), (mob.x - player_body.x))*180/math.pi)
    local heading = player_body.heading*180/math.pi*-1

    if (math.abs(math.abs(heading) - math.abs(angle)) < 5) then
        return true
    end
    return false
end

function face_target()
    message("Turning to face Target", true)
    if (player == nil) then
        player = windower.ffxi.get_player()
    end
    mob = windower.ffxi.get_mob_by_target("t")
    if (not mob) then
        return
    end

    local player_body = windower.ffxi.get_mob_by_id(player.id)
    local angle = (math.atan2((mob.y - player_body.y), (mob.x - player_body.x))*180/math.pi)*-1
    local rads = angle:radian()
    windower.ffxi.turn(rads)
end

function is_in_range()
    mob = windower.ffxi.get_mob_by_target("t")
    if (not mob) then
        return nil
    end
    local dist = mob.distance:sqrt() - (mob.model_size/2 + windower.ffxi.get_mob_by_id(player.id).model_size/2 - 1)
    if (dist > settings.max_range) then
        return "approach"
    elseif (dist < settings.min_range) then
        return "retreat"
    end
    return nil
end

function approach(start)
    if (start) then
        retreat(false)
        message("Approaching", true)
        mob = windower.ffxi.get_mob_by_target("t")

        if (not mob) then
            windower.ffxi.run(false)
            approaching = false
            return
        end
    
        local player_body = windower.ffxi.get_mob_by_id(player.id)
        local angle = (math.atan2((mob.y - player_body.y), (mob.x - player_body.x))*180/math.pi)*-1
        local rads = angle:radian()

        windower.ffxi.run(rads)
        approaching = true
        return
    else
        windower.ffxi.run(false)
        approaching = false
    end
end

function retreat(start)
    if (start) then
        message("Retreating", true)
        approach(false)
        mob = windower.ffxi.get_mob_by_target("t")

        if (not mob) then
            windower.ffxi.run(false)
            retreating = false
            return
        end
    
        local player_body = windower.ffxi.get_mob_by_id(player.id)
        local angle = (math.atan2((mob.y - player_body.y), (mob.x - player_body.x))*180/math.pi)
        local rads = angle:radian()

        windower.ffxi.run(rads)
        retreating = true
        return
    else
        windower.ffxi.run(false)
        retreating = false
    end
end

function set_position()
    player = windower.ffxi.get_player()
    local player_body = windower.ffxi.get_mob_by_id(player.id)
    start_position.x = player_body.x
    start_position.y = player_body.y
    message("Setting return position to ("..start_position.x..", "..start_position.y..")", true)
end

function in_position()
    player = windower.ffxi.get_player()
    local player_body = windower.ffxi.get_mob_by_id(player.id)
    if (not player_body or use_fastfollow == true) then
        return true
    end
    local dist = ((player_body.x - start_position.x)^2 + (player_body.y - start_position.y)^2):sqrt()
    if (dist <= 2) then
        reposition(false)
        return true
    end
    return false
end

function reposition(start)
    if (start) then
        local player_body = windower.ffxi.get_mob_by_id(player.id)
        local angle = (math.atan2((start_position.y - player_body.y), (start_position.x - player_body.x))*180/math.pi)*-1
        local rads = angle:radian()

        windower.ffxi.run(rads)
        returning = true
    else
        windower.ffxi.run(false)
        returning = false
    end
end

--[[ Windower Events ]]--
windower.register_event('prerender', function(...)
    if (approaching) then
        if (not mob or mob.hpp <= 0 or is_in_range() ~= 'approach') then
            approach(false)
        end
    elseif (retreating) then
        if (not mob or mob.hpp <= 0 or is_in_range() ~= 'retreat') then
            retreat(false)
        end
    elseif (returning) then
        if (in_position()) then
            reposition(false)
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
    assist = windower.ffxi.get_mob_by_name(settings.assist_target)

    if (mob and player.status == 1) then 
        if (is_following and settings.use_fastfollow == true and settings.follow_target and settings.follow_target ~= "") then
            message("Disabling Fastfollow!", true)
            windower.send_command("ffo stop")
            --windower.chat.input("//ffo stop")
            is_following = false
        end
        if (not is_facing_target() and settings.face_target == true) then
            face_target()
        end
        local should_move = is_in_range()
        if (should_move == "approach" and settings.approach == true) then
            approach(true)
        elseif (should_move == "retreat" and settings.retreat == true) then
            retreat(true)
        end
        return
    elseif (assist and assist.status == 1 and player.status == 0 and not is_disabled()) then
        engage()
    elseif (player.status ~= 1 and not is_following and settings.use_fastfollow == true and settings.follow_target and settings.follow_target ~= "") then
        message("Enabling Fastfollow!", true)
        windower.send_command("ffo "..settings.follow_target)
        --windower.chat.input("//ffo "..settings.follow_target)
        is_following = true
    elseif (player.status == 0 and not is_disabled() and not settings.use_fastfollow and not in_position() and settings.reposition == true) then
        reposition(true)
    end
end)

-- Stop checking if logout happens
windower.register_event('job change', 'zone change', 'logout', function(...)
    if (not running) then return false end
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
        if (running) then
            set_position()
        end
        message((running and "Starting" or "Stopping"))
    elseif (cmd == 'test') then
        message("Quick Test")
        engage()
        is_facing_target()
        face_target()
        is_in_range()
        approach()
    elseif (T{'on','start','go'}:contains(cmd)) then 
        player = windower.ffxi.get_player()
        set_position()
        running = true
        message("Starting")
    elseif (T{'off','stop','end'}:contains(cmd)) then
        running = false
        message("Stopping")
    elseif (T{'reposition', 'reset', 'return'}:contains(cmd)) then
        settings.reposition = not settings.reposition
        message("Will "..(settings.reposition and "" or "not ").."reposition after mob death.")
    elseif (T{'setposition', 'setpos', 'position', 'pos'}:contains(cmd)) then
        set_position()
        message("New return position set.")
    elseif (cmd == 'assist') then
        local person = proper_case(arg[2])
        message("Setting assist target to "..person)
        if (#arg < 2) then
            message("You need to specify a player to assist.")
            return
        end
        if (windower.ffxi.get_mob_by_name(person) == nil) then
            message("You need to specify a valid player to assist.")
            return
        end
        settings.assist_target = person
    elseif (cmd == 'engage') then
        settings.engage = not settings.engage
        message("Will now "..(settings.engage and "engage" or "not engage"))
    elseif (cmd == 'delay' or cmd == 'ed') then
        settings.engage_delay = tonumber(arg[2]) and tonumber(arg[2]) or 1
        message("Engage delay set to "..settings.engage_delay.." seconds")
    elseif (cmd == 'approach') then
        settings.approach = not settings.approach
        message("Will "..(settings.approach and "approach" or "not approach"))
    elseif (cmd == 'range') then
        settings.max_range = tonumber(arg[2]) or 3.5
        message("Will close to "..settings.max_range.."'")
    elseif (cmd == 'face') then
        settings.face_target = not settings.face_target
        message("Will "..(settings.face_target and "face target" or "not face target"))
    elseif (cmd == 'update') then
        settings.update_time = tonumber(arg[2]) or 2
        message("Time between updates "..settings.update_time.." second(s)")
    elseif (cmd == 'debug') then
        settings.show_debug = not settings.show_debug
        message("Debug info will "..(settings.show_debug and 'be shown' or 'not be shown'))
    elseif (T{'fastfollow','ffo'}:contains(cmd)) then
        settings.use_fastfollow = not settings.use_fastfollow
        message("Autoassist will "..(settings.use_fastfollow and 'follow ' or 'not follow ')..settings.follow_target..".")
    elseif (T{'follow','ft'}:contains(cmd)) then
        local person = proper_case(arg[2])
        message("Setting follow target to "..tostring(person))
        if (#arg < 2) then
            message("You need to specify a player to follow.")
            return
        end
        if (windower.ffxi.get_mob_by_name(person) == nil) then
            message("You need to specify a valid player to follow.")
            return
        end
        settings.follow_target = person
    elseif (cmd == 'save') then
        settings:save()
        message("Settings saved.")
    elseif (cmd == 'show') then
        for k,v in pairs(settings) do
            windower.add_to_chat(207, tostring(k)..": "..tostring(v))
        end
    end
end)
