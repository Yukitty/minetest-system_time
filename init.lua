--[[
	system_time - Automatically synchronizes the in-game time to the server's system clock.
	Copyright © 2019 by Yukita Mayako ("JTE") <catgirl@goddess.moe>

	This library is free software; you can redistribute it and/or
	modify it under the terms of the GNU Lesser General Public
	License as published by the Free Software Foundation; either
	version 2.1 of the License, or (at your option) any later version.

	This library is distributed in the hope that it will be useful,
	but WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
	Lesser General Public License for more details.

	You should have received a copy of the GNU Lesser General Public
	License along with this library; if not, write to the Free Software
	Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301
	USA
]]

--
--		Hardcoded script constants
--

-- Print debug messages? (Also spams the chatlog.)
local DEBUG = false

-- Delay between clock checks, in seconds. SHORT_TIME is used when smoothing over smaller time differences.
local LONG_TIME, SHORT_TIME = 5.0, 1.0

--
--		Function localizations
--

-- Localize engine table
local engine = minetest or core

-- Localize `minetest.settings:get(key)` as `get_setting(key)`
-- Localize `minetest.settings:set(key, value)` as `set_setting(key, value)`
local get_setting, set_setting
do
	local self = engine.settings
	do
		local super = self.get
		function get_setting(key)
			return super(self, key)
		end
	end
	do
		local super = self.set
		function set_setting(key, value)
			return super(self, key, value)
		end
	end
end

-- Localize math
local floor, max, abs, tonumber = math.floor, math.max, math.abs, tonumber

-- `system_time( [multiplier = 1.0], [offset = 0] )`
-- Returns current system clock in millihours (0-23999), DST boolean.
local system_time
do
	local super = os.date
	function system_time(multiplier, offset)
		local t = super('*t') -- Prefix with ! for UTC.
		return (floor((t.hour * 1000 + t.min / 60 * 1000 + t.sec / 60 * 1000 / 60) * (multiplier or 1.0)) + (offset or 0)) % 24000, t.isdst
	end
end

-- `get_time()`
-- Returns current millihours (0-23999)
local get_time
do
	local super = engine.get_timeofday
	function get_time()
		return floor(super() * 24000)
	end
end

-- `set_time(t)`
-- Instantly set timeofday to a specific millihour (0-23999)
local set_time
do
	local super = engine.set_timeofday
	function set_time(t)
		t = t % 24000
		super(t / 24000)
	end
end

local function debug() end
if DEBUG then
	local super = engine.log
	local chat = engine.chat_send_all
	function debug(msg)
		super(msg)
		chat('Debug: ' .. msg)
	end
end

--
--		Mod contents
--

-- SHORT_TIME must be at least server_step
SHORT_TIME = max(SHORT_TIME, tonumber(get_setting('dedicated_server_step')) or 0.09)
local MAX_DIFF = 5.0 + (tonumber(get_setting('dedicated_server_step')) or 0.09)

-- Alias for consistency.
local function get_time_speed()
	return floor(tonumber(get_setting('time_speed')) or 72)
end

local sram = minetest.get_mod_storage()

-- Clear old catch_up values.
if sram:contains('catch_up') then
	if get_time_speed() == sram:get_int('catch_up') then
		set_setting('time_speed', sram:get_int('time_speed'))
	end
	sram:set_string('catch_up', '')
	sram:set_string('time_speed', '')
end

-- Leave time alone if time_speed is 0, otherwise update time on the first server tick as if time_speed has changed.
local time_mul = 0
local catch_up = false
local time_offset = tonumber(get_setting('system_time_offset')) or 0

-- Adjust time and time_speed as needed.
-- Returns seconds until next check.
local function check_clock()
	-- First check if the system_time_offset setting has changed and change time accordingly.
	do
		local new_offset = tonumber(get_setting('system_time_offset')) or 0
		if time_offset ~= new_offset then
			debug('system_time_offset changed.')
			time_offset = new_offset
			set_time(system_time(time_mul, time_offset))
			catch_up = false
			sram:set_string('catch_up', '')
			sram:set_string('time_speed', '')
			return LONG_TIME
		end
	end

	-- Next check if time_speed has been changed externally (by another mod or server admin). If so, change the time accordingly.
	do
		local time_speed = get_time_speed()
		if not catch_up and time_speed ~= time_mul or catch_up and time_speed ~= catch_up then
			debug('time_speed changed.')
			time_mul = time_speed
			if time_mul > 0 then
				set_time(system_time(time_mul, time_offset))
			end
			catch_up = false
			sram:set_string('catch_up', '')
			sram:set_string('time_speed', '')
			return LONG_TIME
		end
	end

	-- Now get the current time and compare it with the time we should be seeing.
	local now_time = get_time()

	local want_time
	if time_mul == 0 then
		-- If time isn't moving anyway, then don't try to adjust it.
		want_time = now_time
	else
		want_time = system_time(time_mul, time_offset)
	end

	-- time_diff is the difference between the current time and the target time, in a range from -12000 to 12000.
	local time_diff = want_time - now_time
	if time_diff > 12000 then
		time_diff = 24000 - time_diff
	end

	-- time_diff_seconds is how many seconds (realtime) of difference between the system time and the game time.
	-- because millihours themselves are not as granular as seconds in a day, the minimum unit of difference at a time_speed of 1 is 3.6 seconds.
	local time_diff_seconds = abs(time_diff) * 3.6 / time_mul

	-- If we're adjusting the time, watch carefully to make sure it's going well.
	if catch_up then
		-- We're done catching up, go back to normal time.
		if time_diff_seconds <= MAX_DIFF
		-- oops, passed it.
		or catch_up <= 0 and time_diff > 0
		or catch_up > 0 and time_diff < 0 then
			debug('Done catching up.')
			set_setting('time_speed', time_mul)
			set_time(want_time)
			catch_up = false
			sram:set_string('catch_up', '')
			sram:set_string('time_speed', '')
			return LONG_TIME
		end
		return SHORT_TIME
	end

	-- If the time difference is too great, just jump ahead.
	if abs(time_diff) > 1250 then
		debug('Visually significant time jump detected (' .. time_diff .. '), correcting it...')
		set_time(want_time)
		catch_up = false
		sram:set_string('catch_up', '')
		sram:set_string('time_speed', '')
		return LONG_TIME

	-- Check if we need to initiate catch-up.
	elseif time_diff_seconds > MAX_DIFF then
		debug('A time_diff of greater than ' .. MAX_DIFF .. ' seconds (' .. time_diff .. ', ' .. (abs(time_diff) * 3.6 / time_mul) .. ' seconds) was detected.')
		sram:set_int('time_speed', time_mul)
		if time_diff < 0 then
			debug('Initiating stopped time catch up. (want time ' .. want_time .. ' < now time ' .. now_time .. ')')
			catch_up = 0
			sram:set_int('catch_up', 0)
			set_setting('time_speed', '0')
		else
			debug('Initiating fast time catch up. (want time ' .. want_time .. ' > now time ' .. now_time .. ')')
			catch_up = time_mul * 2
			sram:set_int('catch_up', catch_up)
			set_setting('time_speed', tostring(catch_up))
		end
		return SHORT_TIME

	elseif time_diff ~= 0 then
		debug('Ignoring minor time difference of ' .. time_diff_seconds .. ' seconds.')
	end

	return LONG_TIME
end

-- Update the clock.
do
	local next_check = 0.0
	engine.register_globalstep(function(dt)
		next_check = next_check - dt
		if next_check <= 0.0 then
			next_check = check_clock()
		end
	end)
end
