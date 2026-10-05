-- Copyright (C) 2025 かにふぁん
-- SPDX-License-Identifier: GPL-3.0-or-later

local utils = require("mp.utils")

local BASE = mp.command_native({ "expand-path", "~~/" })

local CURL = "curl"
local PYTHON = "python"

local function post(endpoint, v)
	mp.command_native_async({
		name = "subprocess",
		args = {
			CURL,
			"-s",
			"-X",
			"POST",
			"http://127.0.0.1:6969" .. endpoint,
			"--json",
			v,
		},
	})
end

local function post_init(v)
	local temp = BASE .. "/autocards_temp.json"
	local f = io.open(temp, "w")
	if not f then
		return
	end
	f:write(v)
	f:close()
	utils.subprocess({
		args = {
			CURL,
			"-s",
			"-X",
			"POST",
			"http://127.0.0.1:6969" .. "/init",
			"--json",
			"@" .. temp,
		},
	})
	os.remove(temp)
end

local HAS_SERVER = false
local SERVER_FILE
local pending_time
local pending_update_timer

local function update(t)
	local delay = mp.get_property_native("sub-delay")
	local payload = utils.format_json({
		time = t - delay,
		delay = delay,
	})
	return post("/update", payload)
end

local function get_sub_info(track)
	if track["external"] then
		return { type = "external", path = track["external-filename"] }
	else
		-- ff-index is the stream index used by ffmpeg
		return { type = "internal", index = track["ff-index"], codec = track["codec"] }
	end
end

local function get_active_sub()
	local tracks = mp.get_property_native("track-list") or {}

	-- When two subtitles are selected, both are marked as selected. MPV uses
	-- main-selection=0 for the primary sid and 1 for secondary-sid.
	for _, track in ipairs(tracks) do
		if track["type"] == "sub" and track["selected"] and track["main-selection"] == 0 then
			return get_sub_info(track)
		end
	end

	-- Compatibility fallback for MPV versions without main-selection.
	local sid = tonumber(mp.get_property("sid") or "")
	if sid then
		for _, track in ipairs(tracks) do
			if track["type"] == "sub" and track["selected"] and tonumber(track["id"]) == sid then
				return get_sub_info(track)
			end
		end
	end

	-- If neither primary-selection signal is available, retain the old
	-- single-selected-subtitle behavior.
	for _, track in ipairs(tracks) do
		if track["type"] == "sub" and track["selected"] then
			return get_sub_info(track)
		end
	end

	return nil
end

local function get_active_audio_track_id()
	local tracks = mp.get_property_native("track-list")
	for _, track in ipairs(tracks) do
		if track["type"] == "audio" and track["selected"] then
			return track["id"]
		end
	end
	return nil
end

local function init(k, v)
	if not v or SERVER_FILE == v then
		return
	end

	mp.msg.info(mp.get_property("path"))

	local started_server = false
	if not HAS_SERVER then
		mp.command_native_async({
			name = "subprocess",
			args = { PYTHON, BASE .. "/autocards/server.py" },
			playback_only = false,
		})
		utils.subprocess({ args = { PYTHON, BASE .. "/autocards/wait.py" }, playback_only = false })

		HAS_SERVER = true
		started_server = true
	end

	local sub_info = get_active_sub()
	local audio_track_id = get_active_audio_track_id()
	local payload = utils.format_json({
		video = v,
		sub = sub_info,
		aid = audio_track_id,
	})

	post_init(payload)

	if started_server then
		update(mp.get_property_native("time-pos"))
	end
end

local function tick(k, v)
	if not v or not HAS_SERVER then
		return
	end

	-- The page polls /update every 250 ms. Coalesce faster time-pos events so
	-- playback doesn't spawn a subprocess for every video frame.
	pending_time = v
	if pending_update_timer then
		return
	end

	pending_update_timer = mp.add_timeout(0.25, function()
		pending_update_timer = nil
		local latest_time = pending_time
		pending_time = nil
		if latest_time and HAS_SERVER then
			update(latest_time)
		end
	end)
end

local function on_sub_change(name, value)
	if HAS_SERVER then
		local path = mp.get_property("path")
		if path then
			-- Re-init with new subtitle selection
			init(nil, path)
		end
	end
end

local function on_aid_change(name, value)
	if HAS_SERVER then
		local aid = get_active_audio_track_id()
		local payload = utils.format_json({ aid = aid })
		post("/aid", payload)
	end
end

mp.register_event("file-loaded", function()
	init(nil, mp.get_property("path"))
end)
mp.observe_property("time-pos", "number", tick)
mp.observe_property("sid", "string", on_sub_change)
mp.observe_property("aid", "string", on_aid_change)
