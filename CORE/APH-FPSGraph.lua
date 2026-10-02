--[[
    Copyright © 2026 @APHONlC. All rights reserved.

    No copying, modification, distribution, or sale without prior written permission.
    AI/ML ingestion and training are strictly prohibited (TDM opt-out).

    See LICENSE.md for full terms and maintenance exceptions.
]]

APHFPSGraphCore = APHFPSGraphCore or {}
local FG = APHFPSGraphCore

FG.name = "APH-FPSGraph"
FG.VERSION = "2026.10.03.06.13"

function FG.L(key, ...)
	local id = _G["SI_APHFPS_" .. key]
	local text = id and GetString(id) or key
	if select("#", ...) > 0 then return string.format(text, ...) end
	return text
end

local DEFAULTS = {
	enabled = true,
	graph_seconds = 60,
	bucket_ms = 500,
	target_fps = 60,
	top_fps = 0,
	stutter_ms = 50,
	ping_warn_ms = 150,
	show_lows = true,
	show_frametime = true,
	show_ping = true,
	show_memory = true,
	show_graph = true,
	detail_level = 4,
	screen_position = "custom",
	window_opacity = 1,
	graph_opacity = 1,
	text_opacity = 1,
	locked = false,
	everywhere = false,
	measure_hidden = false,
	chat_logs = false,
	width = 826,
	height = 479,
	warned_about_libraries = false,
}
FG.DEFAULTS = DEFAULTS

local logger

function FG.ChatLogsOn()
	return FG.saved == nil or FG.saved.chat_logs ~= false
end

function FG.Print(text, always)
	if not always and not FG.ChatLogsOn() then return false end
	logger = logger or LibAPH.CreateChatLogger("FPS", "9CD04C")
	logger:Print(text)
	return true
end

function FG.ResetToDefaults()
	for key, value in pairs(DEFAULTS) do FG.saved[key] = value end
	FG.saved.x, FG.saved.y, FG.saved.point = nil, nil, nil
	FG.saved.summary_x, FG.saved.summary_y, FG.saved.summary_point = nil, nil, nil
	FG.saved.summary_w, FG.saved.summary_h = nil, nil
	FG.saved.timeline_x, FG.saved.timeline_y, FG.saved.timeline_point = nil, nil, nil
	FG.saved.timeline_w, FG.saved.timeline_h = nil, nil
	FG.Apply()
end

function FG.IsShown()
	return FG.Graph ~= nil and FG.Graph.IsOpen()
end

function FG.ShouldMeasure()
	return (FG.saved.enabled and FG.IsShown()) or FG.saved.measure_hidden == true or FG.Sampler.IsRecording()
end

local MAX_RUNS = 10
FG.MAX_RUNS = MAX_RUNS
FG.view = { show = nil, compare = nil }

function FG.Runs() return FG.saved.runs end

function FG.DescribeRun(run)
	if not run then return FG.L("THIS_RUN") end
	return string.format("%s  %d frames  %.2f s", GetDateStringFromTimestamp(run.when or 0), run.frames or 0, run.seconds or 0)
end

function FG.RefreshResults()
	if FG.Summary then FG.Summary.Refresh() end
	if FG.Timeline then FG.Timeline.Refresh() end
	if FG.Pad then FG.Pad.Refresh() end
end

function FG.SetShowing(run)
	FG.view.show = run
	FG.RefreshResults()
end

function FG.SetCompare(run)
	FG.view.compare = run
	FG.RefreshResults()
end

function FG.StartRecording()
	if not FG.Sampler.StartRecording() then
		FG.Print(FG.L("ALREADY_RECORDING"))
		return false
	end
	FG.Apply()
	FG.Print(FG.L("RECORDING_STARTED"))
	return true
end

function FG.StopRecording()
	if not FG.Sampler.IsRecording() then
		FG.Print(FG.L("NOT_RECORDING"))
		return false
	end
	local run = FG.Sampler.StopRecording()
	if run.frames == 0 then
		FG.Print(FG.L("NOTHING_MEASURED_YET"))
	else
		local runs = FG.Runs()
		runs[#runs + 1] = run
		while #runs > MAX_RUNS do table.remove(runs, 1) end
		FG.view.show = run
		FG.Print(FG.L("RECORDING_SAVED", FG.FormatDuration(run.seconds), run.avg_fps, run.low1_fps, run.stutters))
	end
	FG.Apply()
	FG.RefreshResults()
	return true
end

function FG.DeleteLastRun()
	local runs = FG.Runs()
	local gone = table.remove(runs)
	if gone == FG.view.show then FG.view.show = nil end
	if gone == FG.view.compare then FG.view.compare = nil end
	FG.RefreshResults()
end

function FG.DeleteAllRuns()
	FG.saved.runs = {}
	FG.view.show, FG.view.compare = nil, nil
	FG.RefreshResults()
end

function FG.Apply()
	if not FG.saved then return false end
	if FG.saved.enabled then FG.Graph.Open() else FG.Graph.Close() end
	FG.Graph.Refresh()
	if FG.ShouldMeasure() then FG.Sampler.Start() else FG.Sampler.Stop() end
	if FG.Pad then
		if FG.Pad.IsFocused() and not FG.Pad.Active() then FG.Pad.Stop() else FG.Pad.Refresh() end
	end
	return true
end

function FG.Toggle()
	FG.saved.enabled = not FG.saved.enabled
	FG.Apply()
	return FG.saved.enabled
end

function FG.ResetStats()
	FG.Sampler.Reset()
	FG.Graph.Refresh()
	FG.Print(FG.L("STATS_RESET"))
end

function FG.Report()
	local s = FG.Sampler.SessionStats()
	if s.frames == 0 then
		FG.Print(FG.L("NOTHING_MEASURED_YET"), true)
		return false
	end
	FG.Print(FG.L("SESSION_REPORT", FG.FormatDuration(s.seconds), s.avg_fps, s.low1_fps, s.low01_fps,
		s.avg_ms, s.p99_ms, s.stutters, FG.saved.stutter_ms), true)
	return true
end

function FG.FormatDuration(seconds)
	seconds = math.floor(seconds + 0.5)
	if seconds >= 3600 then
		return string.format("%d:%02d:%02d", math.floor(seconds / 3600), math.floor(seconds / 60) % 60, seconds % 60)
	end
	return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end

function FG.Command(args)
	local word = zo_strlower(zo_strtrim(args or ""))
	if word == "reset" then return FG.ResetStats() end
	if word == "report" then return FG.Report() end
	if word == "record" then return FG.StartRecording() end
	if word == "stop" then return FG.StopRecording() end
	return FG.Toggle()
end

local function Init()
	LibAPH.RegisterAddonDependencies(FG.name, { "LibAPH" }, { "LibAddonMenu-2.0", "LibHarvensAddonSettings" })
	FG.saved = ZO_SavedVars:NewAccountWide("APHFPSGraph", 1, GetWorldName() or "Default", DEFAULTS)
	for key, value in pairs(DEFAULTS) do
		if FG.saved[key] == nil then FG.saved[key] = value end
	end
	FG.saved.runs = FG.saved.runs or {}
	SLASH_COMMANDS["/fpsgraph"] = FG.Command

	LibAPH.RunInitStages(FG.name, {
		function() end,
		FG.BuildSettingsPanel,
		FG.Apply,
	})
end

EVENT_MANAGER:RegisterForEvent(FG.name, EVENT_ADD_ON_LOADED, function(_, name)
	if name ~= FG.name then return end
	EVENT_MANAGER:UnregisterForEvent(FG.name, EVENT_ADD_ON_LOADED)
	Init()
end)
