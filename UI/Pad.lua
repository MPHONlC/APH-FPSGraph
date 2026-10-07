--[[
    Copyright © 2026 @APHONlC. All rights reserved.

    No copying, modification, distribution, or sale without prior written permission.
    AI/ML ingestion and training are strictly prohibited (TDM opt-out).

    See LICENSE.md for full terms and maintenance exceptions.
]]

local FG = APHFPSGraphCore
local Pad = {}
FG.Pad = Pad

local LAYER = "APHFPSGraph_Focus"
local WAIT_JOB = "APHFPSGraph_PadControl"
local HINT_GAP = 4
local HINT_PAD = 6

local focus = false
local dismissed = false
local watching = false
local hint_box, hint_lbl
local order = { "graph" }

local function IsPad() return IsConsoleUI() or IsInGamepadPreferredMode() end

local function PadKey(action)
	return LibAPH.GetKeybindMarkup(action)
end

local WINDOWS = {
	timeline = function()
		if FG.Timeline.IsShown() then return FG.Timeline.Window(), FG.Timeline.Mover(), FG.Timeline.Resizer() end
	end,
	summary = function()
		if FG.Summary.IsShown() then return FG.Summary.Window(), FG.Summary.Mover(), FG.Summary.Resizer() end
	end,
	graph = function()
		if FG.Graph.IsOpen() then return FG.Graph.Window(), not FG.Graph.IsPinned() and FG.Graph.Mover() or nil, FG.Graph.Resizer() end
	end,
}

function Pad.Active()
	for i = #order, 1, -1 do
		local win, mover, resizer = WINDOWS[order[i]]()
		if win then return order[i], win, mover, resizer end
	end
	for _, kind in ipairs({ "timeline", "summary", "graph" }) do
		local win, mover, resizer = WINDOWS[kind]()
		if win then return kind, win, mover, resizer end
	end
	return nil
end

function Pad.HintText()
	local parts = {}
	local function Add(text, ...)
		local keys = {}
		for _, action in ipairs({ ... }) do keys[#keys + 1] = PadKey(action) end
		parts[#parts + 1] = table.concat(keys, "") .. " " .. text
	end
	if LibAPH.GetContextMenuDepth() > 0 then
		Add(FG.L("PAD_CHOOSE"), "UI_SHORTCUT_PRIMARY")
		Add(FG.L("PAD_BACK"), "UI_SHORTCUT_NEGATIVE")
		return table.concat(parts, "   ")
	end
	local kind, _, mover, resizer = Pad.Active()
	Add(FG.Sampler.IsRecording() and FG.L("STOP_RECORDING") or FG.L("START_RECORDING"), "UI_SHORTCUT_SECONDARY")
	Add(FG.L("PAD_MENU"), "UI_SHORTCUT_TERTIARY")
	Add(FG.Summary.IsShown() and FG.L("HIDE_SUMMARY") or FG.L("SUMMARY"), "UI_SHORTCUT_LEFT_SHOULDER")
	Add(FG.Timeline.IsShown() and FG.L("HIDE_TIMELINE") or FG.L("TIMELINE"), "UI_SHORTCUT_RIGHT_SHOULDER")
	if kind == "timeline" or kind == "graph" then
		Add(FG.L("PAD_ZOOM"), "UI_SHORTCUT_LEFT_TRIGGER", "UI_SHORTCUT_RIGHT_TRIGGER")
		Add(FG.L("PAD_PAN"), "UI_SHORTCUT_INPUT_LEFT", "UI_SHORTCUT_INPUT_RIGHT")
	end
	if mover then Add(mover:IsMoving() and FG.L("PAD_MOVING") or FG.L("PAD_MOVE"), "UI_SHORTCUT_RIGHT_STICK") end
	if resizer then Add(resizer:IsResizing() and FG.L("PAD_RESIZING") or FG.L("PAD_RESIZE"), "UI_SHORTCUT_LEFT_STICK") end
	Add(kind == "graph" and FG.L("PAD_DONE") or FG.L("PAD_CLOSE"), "UI_SHORTCUT_NEGATIVE")
	return table.concat(parts, "   ")
end

local function BuildHints()
	if hint_box then return end
	hint_box = WINDOW_MANAGER:CreateTopLevelWindow("APHFPSGraphPadHints")
	hint_box:SetDrawTier(DT_HIGH)
	hint_box:SetHidden(true)
	LibAPH.ApplyPanelBackdrop(hint_box, "APHFPSGraphPadHintsBG", LibAPH.THEME.BG_HUD)
	hint_lbl = WINDOW_MANAGER:CreateControl("APHFPSGraphPadHintsText", hint_box, CT_LABEL)
	hint_lbl:SetFont("ZoFontGamepad18")
	hint_lbl:SetColor(0.9, 0.9, 0.9, 1)
	hint_lbl:SetAnchor(TOPLEFT, hint_box, TOPLEFT, HINT_PAD, HINT_PAD)
end

function Pad.Refresh()
	if not hint_box then return false end
	local _, owner = Pad.Active()
	local show = focus and IsPad() and owner ~= nil
	hint_box:SetHidden(not show)
	if not show then return false end
	local width = math.max(owner:GetWidth(), 300)
	hint_lbl:SetWidth(width - HINT_PAD * 2)
	hint_lbl:SetText(Pad.HintText())
	local height = hint_lbl:GetTextHeight() + HINT_PAD * 2
	hint_box:SetDimensions(width, height)
	hint_box:ClearAnchors()
	if owner:GetBottom() + HINT_GAP + height > GuiRoot:GetHeight() then
		hint_box:SetAnchor(BOTTOMLEFT, owner, TOPLEFT, 0, -HINT_GAP)
	else
		hint_box:SetAnchor(TOPLEFT, owner, BOTTOMLEFT, 0, HINT_GAP)
	end
	return true
end

function Pad.GetHintText()
	if not hint_box or hint_box:IsHidden() then return nil end
	return hint_lbl:GetText()
end

local function SetLayer(on)
	local active = IsActionLayerActiveByName(LAYER)
	if on and not active then
		PushActionLayerByName(LAYER)
	elseif not on and active then
		RemoveActionLayerByName(LAYER)
	end
end

local function StopTools()
	for _, get in ipairs({ FG.Graph.Mover, FG.Summary.Mover, FG.Timeline.Mover }) do
		local mover = get()
		if mover then mover:ToggleGamepadMove(false) end
	end
	for _, get in ipairs({ FG.Graph.Resizer, FG.Summary.Resizer, FG.Timeline.Resizer }) do
		local resizer = get()
		if resizer then resizer:ToggleGamepadResize(false) end
	end
end

function Pad.IsFocused() return focus end

function Pad.Stop()
	if not focus then return false end
	focus = false
	SetLayer(false)
	LibAPH.CloseContextMenu()
	StopTools()
	Pad.Refresh()
	return true
end

function Pad.Start()
	if not IsPad() or not Pad.Active() then return false end
	BuildHints()
	focus = true
	SetLayer(true)
	Pad.Refresh()
	return true
end

function Pad.ToggleFocus()
	if focus then return Pad.Stop() end
	if not FG.Graph.IsOpen() and not FG.Summary.IsShown() and not FG.Timeline.IsShown() then
		FG.saved.enabled = true
		FG.Apply()
	end
	return Pad.Start()
end

local function GameScreenShown()
	return LibAPH.IsGameScreenShown()
end

function Pad.EnsureConsoleControl()
	if not IsConsoleUI() or focus or dismissed or not Pad.Active() then return false end
	if GameScreenShown() then return Pad.Start() end
	LibAPH.ScheduleWait(WAIT_JOB, GameScreenShown, function()
		if not focus and not dismissed and Pad.Active() then Pad.Start() end
	end)
	return true
end

local function WatchScenes()
	if watching or not IsConsoleUI() then return end
	watching = true
	SCENE_MANAGER:RegisterCallback("SceneStateChanged", function(scene, _, new_state)
		local name = scene and scene:GetName()
		local game_screen = name == "hud" or name == "hudui"
		if new_state == SCENE_SHOWN and game_screen then
			Pad.EnsureConsoleControl()
		elseif new_state == SCENE_SHOWING and not game_screen and focus then
			Pad.Stop()
		end
	end)
end

function Pad.Opened(kind)
	for i = #order, 1, -1 do
		if order[i] == kind then table.remove(order, i) end
	end
	order[#order + 1] = kind
	dismissed = false
	WatchScenes()
	Pad.EnsureConsoleControl()
	return Pad.Refresh()
end

function Pad.OpenResults()
	FG.Summary.Show()
	if not IsPad() then return true end
	if GameScreenShown() then return Pad.Start() end
	SCENE_MANAGER:ShowBaseScene()
	LibAPH.ScheduleWait(WAIT_JOB, GameScreenShown, function() Pad.Start() end)
	return true
end

local function ToggleMove()
	local kind, _, mover, resizer = Pad.Active()
	if not mover then return false end
	local moving = not mover:IsMoving()
	if moving and kind == "graph" and FG.Graph.IsPinned() then return false end
	if moving and resizer then resizer:ToggleGamepadResize(false) end
	mover:ToggleGamepadMove(moving)
	if moving and kind == "graph" then FG.Graph.WatchAlign() end
	return true
end

local function ToggleResize()
	local _, _, mover, resizer = Pad.Active()
	if not resizer then return false end
	local resizing = not resizer:IsResizing()
	if resizing and mover then mover:ToggleGamepadMove(false) end
	resizer:ToggleGamepadResize(resizing)
	return true
end

local function Back()
	local kind, _, mover, resizer = Pad.Active()
	if mover and mover:IsMoving() then
		mover:ToggleGamepadMove(false)
	elseif resizer and resizer:IsResizing() then
		resizer:ToggleGamepadResize(false)
	elseif kind == "timeline" then
		FG.Timeline.Hide()
	elseif kind == "summary" then
		FG.Summary.Hide()
	else
		dismissed = true
		Pad.Stop()
	end
	return true
end

local function OnView(name)
	return function()
		local kind = Pad.Active()
		if kind == "timeline" then FG.Timeline[name]() elseif kind == "graph" then FG.Graph[name]() end
		return true
	end
end

local ACTIONS = {
	record = function()
		if FG.Sampler.IsRecording() then FG.StopRecording() else FG.StartRecording() end
		return true
	end,
	menu = function()
		local _, owner = Pad.Active()
		FG.Graph.OpenMenu(owner)
		LibAPH.MoveContextMenuFocus(1)
		return true
	end,
	summary = function() return FG.Summary.Toggle() or true end,
	timeline = function() return FG.Timeline.Toggle() or true end,
	zoom_in = OnView("ZoomIn"),
	zoom_out = OnView("ZoomOut"),
	pan_left = OnView("PanLeft"),
	pan_right = OnView("PanRight"),
	move = ToggleMove,
	resize = ToggleResize,
	back = Back,
}

function Pad.Move(direction)
	if not focus then return false end
	if LibAPH.GetContextMenuDepth() > 0 then
		LibAPH.MoveContextMenuFocus(direction)
		Pad.Refresh()
	end
	return true
end

function Pad.Select()
	if not focus then return false end
	if LibAPH.GetContextMenuDepth() > 0 then LibAPH.ActivateContextMenuFocus() end
	Pad.Refresh()
	return true
end

function Pad.Action(name)
	if not focus or not IsPad() then return false end
	if LibAPH.GetContextMenuDepth() > 0 then
		if name == "back" then LibAPH.CloseContextMenuLevel() end
		Pad.Refresh()
		return true
	end
	local action = ACTIONS[name]
	if not action then return false end
	action()
	if not Pad.Active() then Pad.Stop() end
	Pad.Refresh()
	return true
end
