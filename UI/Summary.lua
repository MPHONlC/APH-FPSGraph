--[[
    Copyright © 2026 @APHONlC. All rights reserved.

    No copying, modification, distribution, or sale without prior written permission.
    AI/ML ingestion and training are strictly prohibited (TDM opt-out).

    See LICENSE.md for full terms and maintenance exceptions.
]]

local FG = APHFPSGraphCore
local Summary = {}
FG.Summary = Summary

local floor = math.floor
local THEME = LibAPH.THEME

local NAME = "APHFPSGraphSummary"
local HEADER_H = 28
local PAD = 10
local FONT_SIZE = 14
local MIN_FONT, MAX_FONT = 10, 30
local LABEL_W = 170
local VALUE_W = 150
local MIN_SCALE, MAX_SCALE = 0.75, 2.2
local FONT_FACE = "EsoUI/Common/Fonts/Univers67.slug"
local TITLE_BAR = { 0, 0, 0, 0.92 }
local COMPARE_COLOR = { 1, 1, 1 }

local ROWS = {
	{ section = "SECTION_RUN" },
	{ "SUM_LENGTH", "seconds", "time" },
	{ "SUM_FRAMES", "frames", "count" },
	{ "SUM_TARGET", "target_fps", "count" },
	{ section = "SECTION_FPS" },
	{ "SUM_AVG_FPS", "avg_fps", "fps" },
	{ "SUM_MEDIAN_FPS", "median_fps", "fps" },
	{ "SUM_LOW1", "low1_fps", "fps" },
	{ "SUM_LOW01", "low01_fps", "fps" },
	{ "SUM_LOWEST_FPS", "lowest_fps", "fps" },
	{ "SUM_HIGHEST_FPS", "highest_fps", "fps" },
	{ section = "SECTION_FRAME_TIME" },
	{ "SUM_AVG_MS", "avg_ms", "ms" },
	{ "SUM_P50_MS", "p50_ms", "ms" },
	{ "SUM_P95_MS", "p95_ms", "ms" },
	{ "SUM_P99_MS", "p99_ms", "ms" },
	{ "SUM_P999_MS", "p999_ms", "ms" },
	{ "SUM_MAX_MS", "max_ms", "ms" },
	{ "SUM_JITTER", "jitter_ms", "plain" },
	{ section = "SECTION_HITCHES" },
	{ "SUM_SLOW", "slow_frames", "slow" },
	{ "SUM_STUTTERS", "stutters", "lower" },
	{ "SUM_STUTTER_TIME", "stutter_total_ms", "total" },
	{ section = "SECTION_PING" },
	{ "SUM_PING_AVG", "ping_avg", "ping" },
	{ "SUM_PING_MIN", "ping_min", "ping" },
	{ "SUM_PING_MAX", "ping_max", "ping" },
	{ "SUM_PING_JITTER", "ping_jitter", "plain" },
	{ "SUM_PING_WARN", "ping_warn", "count" },
}
Summary.ROWS = ROWS

local LOWER_IS_BETTER = { ms = true, plain = true, slow = true, lower = true, total = true, ping = true }

local win, title, sticky, position, mover, resizer
local cells = {}
local built = false
local scale = 1

local function Font()
	return FONT_FACE .. "|" .. zo_clamp(zo_round(FONT_SIZE * scale), MIN_FONT, MAX_FONT) .. "|soft-shadow-thin"
end

local function Saved() return FG.saved end

local function Label(parent, suffix, align)
	local label = WINDOW_MANAGER:CreateControl(NAME .. suffix, parent, CT_LABEL)
	label:SetFont(Font())
	label:SetColor(THEME.TEXT[1], THEME.TEXT[2], THEME.TEXT[3], 1)
	label:SetMaxLineCount(1)
	label:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
	if align then label:SetHorizontalAlignment(align) end
	return label
end

function Summary.Source()
	if FG.view.show then return FG.view.show end
	return FG.Sampler.RecordingStats() or FG.Sampler.SessionStats()
end

function Summary.SourceName(run)
	if run then return GetDateStringFromTimestamp(run.when or 0) .. "  " .. FG.FormatDuration(run.seconds or 0) end
	if FG.Sampler.IsRecording() then return FG.L("RECORDING") end
	return FG.L("THIS_RUN")
end

function Summary.FieldText(kind, run, key)
	local value = run[key]
	if value == nil then return "" end
	local G = FG.Graph
	local target = run.target_fps or Saved().target_fps
	if kind == "time" then return FG.FormatDuration(value) end
	if kind == "count" then return tostring(floor(value + 0.5)) end
	if kind == "fps" then return G.FpsText(value, target) end
	if kind == "ms" then return G.MsText(value, target) end
	if kind == "plain" then return G.Fmt(value, 1) end
	if kind == "ping" then return FG.L("MS_VALUE", G.PingText(value, run.ping_warn or Saved().ping_warn_ms)) end
	if kind == "total" then return G.Tint(FG.L("MS_VALUE", G.Fmt(value)), value > 0 and G.BAD or G.GOOD) end
	if kind == "slow" then
		local text = tostring(floor(value + 0.5))
		if run.slow_pct then text = text .. " (" .. G.Fmt(run.slow_pct, 1) .. "%)" end
		return G.Tint(text, value > 0 and G.BAD or G.GOOD)
	end
	return G.Tint(tostring(floor(value + 0.5)), value > 0 and G.BAD or G.GOOD)
end

function Summary.DeltaText(kind, value, other)
	if value == nil or other == nil or kind == "time" or kind == "count" then return "" end
	local diff = value - other
	if math.abs(diff) < 0.05 then return "" end
	local better
	if LOWER_IS_BETTER[kind] then better = diff < 0 else better = diff > 0 end
	local G = FG.Graph
	return " " .. G.Tint((diff > 0 and "+" or "") .. G.Fmt(diff, 1), better and G.GOOD or G.BAD)
end

function Summary.Lines()
	local shown, cmp = Summary.Source(), FG.view.compare
	local lines = { { "", FG.Graph.Tint(Summary.SourceName(FG.view.show), THEME.ACCENT),
		cmp and FG.Graph.Tint(Summary.SourceName(cmp), COMPARE_COLOR) or "" } }
	for _, row in ipairs(ROWS) do
		if row.section then
			lines[#lines + 1] = { FG.Graph.Tint(FG.L(row.section), THEME.ACCENT), "", "", section = true }
		else
			local label, key, kind = FG.L(row[1]), row[2], row[3]
			if key == "stutters" then label = FG.L("SUM_STUTTERS_AT", shown.stutter_ms or Saved().stutter_ms) end
			local value = Summary.FieldText(kind, shown, key)
			if cmp then value = value .. Summary.DeltaText(kind, shown[key], cmp[key]) end
			lines[#lines + 1] = { label, value, cmp and Summary.FieldText(kind, cmp, key) or "" }
		end
	end
	return lines
end

local function Columns()
	return FG.view.compare and 3 or 2
end

function Summary.NaturalSize(columns, count)
	return PAD * 2 + LABEL_W + VALUE_W * (columns - 1), HEADER_H + PAD + count * (FONT_SIZE + 5)
end

local function Draw()
	if not built or win:IsHidden() then return false end
	local lines = Summary.Lines()
	local columns = Columns()
	local natural_w, natural_h = Summary.NaturalSize(columns, #lines)
	local s = Saved()
	local w, h = natural_w, natural_h
	if s.summary_w and s.summary_h then
		scale = zo_clamp(math.min(s.summary_w / natural_w, s.summary_h / natural_h), MIN_SCALE, MAX_SCALE)
		w, h = s.summary_w, s.summary_h
	else
		scale = 1
	end
	local font = Font()
	local row_h = (FONT_SIZE + 5) * scale
	local label_w, value_w = LABEL_W * scale, VALUE_W * scale
	title:SetFont(font)
	for i, line in ipairs(lines) do
		local row = cells[i]
		local y = HEADER_H + PAD / 2 + (i - 1) * row_h
		for c = 1, 3 do
			local cell = row[c]
			cell:SetFont(font)
			cell:ClearAnchors()
			local x = PAD + (c == 1 and 0 or label_w + (c - 2) * value_w)
			cell:SetAnchor(TOPLEFT, win, TOPLEFT, x, y)
			cell:SetWidth(c == 1 and label_w - 6 or value_w - 6)
			cell:SetText(line[c] or "")
			cell:SetHidden(c > columns)
		end
	end
	win:SetDimensions(math.max(w, PAD * 2 + label_w + value_w * (columns - 1)), math.max(h, HEADER_H + PAD + #lines * row_h))
	return true
end
Summary.Draw = Draw

local function PlaceDefault(control)
	control:ClearAnchors()
	control:SetAnchor(CENTER, GuiRoot, CENTER, -200, 0)
end

local function SaveSize()
	Saved().summary_w, Saved().summary_h = floor(win:GetWidth() + 0.5), floor(win:GetHeight() + 0.5)
end

local function Build()
	if built then return win end
	built = true
	win = WINDOW_MANAGER:CreateTopLevelWindow(NAME)
	win:SetClampedToScreen(true)
	win:SetMouseEnabled(true)
	win:SetMovable(true)
	win:SetHidden(true)
	win:SetDrawTier(DT_HIGH)
	LibAPH.ApplyPanelBackdrop(win, NAME .. "BG", THEME.BG_HUD)
	local header = LibAPH.CreateHeaderStrip(win, NAME .. "Header", HEADER_H)
	header:SetColor(TITLE_BAR[1], TITLE_BAR[2], TITLE_BAR[3], TITLE_BAR[4])
	title = Label(win, "Title")
	title:SetText("|c" .. THEME.TITLE_HEX .. "APH-FPSGraph|r  " .. FG.L("SUMMARY"))
	title:SetAnchor(LEFT, win, TOPLEFT, PAD, HEADER_H / 2)
	LibAPH.CreateThemedCloseButton(win, NAME .. "Close", function() Summary.Hide() end, 4, 2)
	for i = 1, #ROWS + 1 do
		cells[i] = { Label(win, "Row" .. i .. "a"), Label(win, "Row" .. i .. "b"), Label(win, "Row" .. i .. "c") }
	end
	win:SetHandler("OnMouseUp", function(_, button, upInside)
		if upInside and button == MOUSE_BUTTON_INDEX_RIGHT then FG.Graph.OpenMenu(win) end
	end)

	LibAPH.MakeWindowResizable(win, {
		handleSize = 8,
		minWidth = 200, minHeight = 160,
		onResizing = function()
			SaveSize()
			Draw()
		end,
		onResizeStop = function()
			SaveSize()
			Draw()
		end,
	})
	mover = LibAPH.CreateGamepadMover(win)
	position = LibAPH.CreateWindowPosition(win, {
		get = function() return Saved().summary_x, Saved().summary_y, Saved().summary_point end,
		set = function(x, y, point) Saved().summary_x, Saved().summary_y, Saved().summary_point = x, y, point end,
		placeDefault = PlaceDefault,
		mover = mover,
	})
	win:SetHandler("OnMoveStop", function() position:Save() end)
	mover:RegisterCallback(FG.name .. "_SummaryMove", 2, function()
		position:Save()
		if FG.Pad then FG.Pad.Refresh() end
	end)
	resizer = LibAPH.CreateGamepadResizer(win, {
		minWidth = 200, minHeight = 160,
		onResizing = function()
			SaveSize()
			Draw()
		end,
		onResizeStop = function()
			if FG.Pad then FG.Pad.Refresh() end
		end,
	})
	sticky = LibAPH.CreateStickyFragment(win, { "hud", "hudui" })
	return win
end

function Summary.Show()
	Build()
	position:Apply()
	sticky:Open()
	Draw()
	if FG.Pad then FG.Pad.Opened("summary") end
	return true
end

function Summary.Hide()
	if not built then return false end
	sticky:Close()
	if mover then mover:ToggleGamepadMove(false) end
	if resizer then resizer:ToggleGamepadResize(false) end
	if FG.Pad then FG.Pad.Refresh() end
	return true
end

function Summary.IsShown() return built and sticky:IsOpen() end

function Summary.Toggle()
	if Summary.IsShown() then return Summary.Hide() end
	return Summary.Show()
end

function Summary.Refresh()
	return Draw()
end

function Summary.OnBucket()
	if FG.view.show == nil then Draw() end
end

function Summary.Window() return win end
function Summary.Mover() return mover end
function Summary.Resizer() return resizer end

function Summary.ResetPosition()
	if not built then return false end
	position:Reset()
	return true
end
