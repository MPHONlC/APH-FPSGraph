--[[
    Copyright © 2026 @APHONlC. All rights reserved.

    No copying, modification, distribution, or sale without prior written permission.
    AI/ML ingestion and training are strictly prohibited (TDM opt-out).

    See LICENSE.md for full terms and maintenance exceptions.
]]

local FG = APHFPSGraphCore
local S = {}
FG.Sampler = S

local floor, sqrt, ceil, min, max = math.floor, math.sqrt, math.ceil, math.min, math.max
local GetFrameDeltaSeconds = GetFrameDeltaSeconds

local NS = FG.name .. "Sampler"
local CAPACITY = 16384
local MAX_FRAME_S = 2
local FINE_MS, FINE_BINS = 0.25, 256
local WIDE_MS, WIDE_BINS = 4, 256
local FINE_TOP = FINE_MS * FINE_BINS
local BINS = FINE_BINS + WIDE_BINS + 1
local MAX_COLUMNS = 240
local MAX_TIMELINE = 1200
local ROUNDING = 1e-9

S.CAPACITY, S.MAX_FRAME_S, S.BINS, S.MAX_COLUMNS = CAPACITY, MAX_FRAME_S, BINS, MAX_COLUMNS

local ring, ring_bin = {}, {}
local hist, session_hist = {}, {}
local head, filled = 0, 0
local window_ms, window_sq = 0, 0

local session = {}
local bucket_frames, bucket_ms, bucket_worst = 0, 0, 0
local columns = { fps = {}, low = {}, ping = {}, count = 0 }
local running = false
local skipped = 0
local rec
local session_line

local function NewLine()
	return { fps = {}, low = {}, ping = {}, step_ms = FG.saved and FG.saved.bucket_ms or 500 }
end

local function BinOf(ms)
	if ms < FINE_TOP then return floor(ms / FINE_MS) + 1 end
	local wide = floor((ms - FINE_TOP) / WIDE_MS)
	if wide >= WIDE_BINS then return BINS end
	return FINE_BINS + wide + 1
end
S.BinOf = BinOf

local function BinMid(bin)
	if bin <= FINE_BINS then return (bin - 0.5) * FINE_MS end
	if bin == BINS then return FINE_TOP + WIDE_MS * WIDE_BINS end
	return FINE_TOP + (bin - FINE_BINS - 0.5) * WIDE_MS
end
S.BinMid = BinMid

local function ClearTable(t)
	for k in pairs(t) do t[k] = nil end
end

function S.Reset()
	for i = 1, BINS do
		hist[i] = 0
		session_hist[i] = 0
	end
	head, filled, window_ms, window_sq = 0, 0, 0, 0
	session.frames, session.ms, session.sq, session.stutters, session.worst = 0, 0, 0, 0, 0
	session.stutter_total, session.ping_sum, session.ping_n, session.ping_max = 0, 0, 0, 0
	session.ping_sq, session.ping_min = 0, 0
	session_line = NewLine()
	bucket_frames, bucket_ms, bucket_worst = 0, 0, 0
	ClearTable(columns.fps)
	ClearTable(columns.low)
	ClearTable(columns.ping)
	columns.count = 0
	skipped = 0
end

local function WindowLimitMs()
	return (FG.saved and FG.saved.graph_seconds or 60) * 1000
end

local function Evict(slot)
	local ms = ring[slot]
	window_ms = window_ms - ms
	window_sq = window_sq - ms * ms
	local bin = ring_bin[slot]
	hist[bin] = hist[bin] - 1
	filled = filled - 1
end

local function Push(ms)
	head = head % CAPACITY + 1
	if filled == CAPACITY then Evict(head) end
	local bin = BinOf(ms)
	ring[head], ring_bin[head] = ms, bin
	hist[bin] = hist[bin] + 1
	filled = filled + 1
	window_ms = window_ms + ms
	window_sq = window_sq + ms * ms
	local limit = WindowLimitMs()
	while window_ms > limit and filled > 1 do
		Evict((head - filled) % CAPACITY + 1)
	end

	session.frames = session.frames + 1
	session.ms = session.ms + ms
	session.sq = session.sq + ms * ms
	session_hist[bin] = session_hist[bin] + 1
	if ms > session.worst then session.worst = ms end
	if ms >= FG.saved.stutter_ms then
		session.stutters = session.stutters + 1
		session.stutter_total = session.stutter_total + ms
	end
	if rec then
		rec.frames = rec.frames + 1
		rec.ms = rec.ms + ms
		rec.sq = rec.sq + ms * ms
		rec.hist[bin] = rec.hist[bin] + 1
		if ms > rec.worst then rec.worst = ms end
		if ms >= FG.saved.stutter_ms then
			rec.stutters = rec.stutters + 1
			rec.stutter_total = rec.stutter_total + ms
		end
	end
end

local function AddPoint(line, fps, low, ping)
	local n = #line.fps + 1
	line.fps[n], line.low[n], line.ping[n] = fps, low, ping
	if n <= MAX_TIMELINE then return end
	local f, l, p = {}, {}, {}
	for i = 1, n, 2 do
		local j = i + 1
		local k = #f + 1
		if line.fps[j] then
			f[k], l[k], p[k] = (line.fps[i] + line.fps[j]) / 2, min(line.low[i], line.low[j]), max(line.ping[i], line.ping[j])
		else
			f[k], l[k], p[k] = line.fps[i], line.low[i], line.ping[i]
		end
	end
	line.fps, line.low, line.ping, line.step_ms = f, l, p, line.step_ms * 2
end
S.AddPoint = AddPoint

local function AddPing(t, ping)
	t.ping_sum, t.ping_n, t.ping_sq = t.ping_sum + ping, t.ping_n + 1, t.ping_sq + ping * ping
	if ping > t.ping_max then t.ping_max = ping end
	if t.ping_n == 1 or ping < t.ping_min then t.ping_min = ping end
end

function S.PingStats(list, first, last, out)
	out = out or {}
	local n, sum, sq, low, high = 0, 0, 0, nil, 0
	for i = first or 1, last or #list do
		local p = list[i]
		if p then
			n, sum, sq = n + 1, sum + p, sq + p * p
			if not low or p < low then low = p end
			if p > high then high = p end
		end
	end
	local avg = n > 0 and sum / n or 0
	out.ping_avg, out.ping_min, out.ping_max = avg, low or 0, high
	out.ping_jitter = n > 0 and sqrt(max(0, sq / n - avg * avg)) or 0
	return out
end

local function PushColumn(fps, low, ping)
	local limit = min(MAX_COLUMNS, max(1, floor(FG.saved.graph_seconds * 1000 / FG.saved.bucket_ms + 0.5)))
	local c = columns.count + 1
	columns.fps[c], columns.low[c], columns.ping[c] = fps, low, ping
	columns.count = c
	if c > limit then
		local drop = c - limit
		for i = 1, limit do
			columns.fps[i], columns.low[i], columns.ping[i] = columns.fps[i + drop], columns.low[i + drop], columns.ping[i + drop]
		end
		for i = limit + 1, c do
			columns.fps[i], columns.low[i], columns.ping[i] = nil, nil, nil
		end
		columns.count = limit
	end
end

local function CloseBucket()
	local fps = bucket_frames * 1000 / bucket_ms
	local low = bucket_worst > 0 and 1000 / bucket_worst or fps
	local ping = GetLatency()
	PushColumn(fps, low, ping)
	AddPoint(session_line, fps, low, ping)
	AddPing(session, ping)
	if rec then
		AddPoint(rec.line, fps, low, ping)
		AddPing(rec, ping)
	end
	bucket_frames, bucket_ms, bucket_worst = 0, 0, 0
	if FG.Graph then FG.Graph.OnBucket() end
end

function S.AddFrame(seconds)
	if seconds <= 0 or seconds > MAX_FRAME_S then
		skipped = skipped + 1
		return false
	end
	local ms = seconds * 1000
	Push(ms)
	bucket_frames = bucket_frames + 1
	bucket_ms = bucket_ms + ms
	if ms > bucket_worst then bucket_worst = ms end
	if bucket_ms >= FG.saved.bucket_ms then CloseBucket() end
	return true
end

local function OnFrame()
	S.AddFrame(GetFrameDeltaSeconds())
end

function S.Start()
	if running then return false end
	running = true
	EVENT_MANAGER:RegisterForUpdate(NS, 0, OnFrame)
	return true
end

function S.Stop()
	if not running then return false end
	running = false
	EVENT_MANAGER:UnregisterForUpdate(NS)
	return true
end

function S.IsRunning() return running end
function S.Skipped() return skipped end
function S.Columns() return columns end

local function Lows(h, n, share)
	local want = max(1, ceil(n * share - ROUNDING))
	local taken, sum = 0, 0
	for bin = BINS, 1, -1 do
		local count = h[bin]
		if count > 0 then
			local use = min(count, want - taken)
			taken = taken + use
			sum = sum + use * BinMid(bin)
			if taken >= want then break end
		end
	end
	if taken == 0 then return 0 end
	return 1000 / (sum / taken)
end

local function Percentile(h, n, share)
	local want = max(1, ceil(n * (1 - share) - ROUNDING))
	local seen = 0
	for bin = BINS, 1, -1 do
		seen = seen + h[bin]
		if seen >= want then return BinMid(bin) end
	end
	return 0
end

local function Highest(h)
	for bin = BINS, 1, -1 do
		if h[bin] > 0 then return BinMid(bin) end
	end
	return 0
end

local function Lowest(h)
	for bin = 1, BINS do
		if h[bin] > 0 then return BinMid(bin) end
	end
	return 0
end

local function SlowerThan(h, ms)
	local count = 0
	for bin = BinOf(ms) + 1, BINS do count = count + h[bin] end
	return count
end

function S.Budget(target)
	return 1000 / (target - 0.5)
end

local function Build(out, h, n, total_ms, total_sq)
	out.frames = n
	out.seconds = total_ms / 1000
	if n == 0 or total_ms <= 0 then
		out.avg_fps, out.avg_ms, out.low1_fps, out.low01_fps, out.p99_ms, out.max_ms, out.jitter_ms = 0, 0, 0, 0, 0, 0, 0
		out.p50_ms, out.p95_ms, out.p999_ms, out.min_ms, out.median_fps, out.lowest_fps, out.highest_fps = 0, 0, 0, 0, 0, 0, 0
		out.slow_frames, out.slow_pct = 0, 0
		return out
	end
	local avg = total_ms / n
	out.avg_ms = avg
	out.avg_fps = n * 1000 / total_ms
	out.low1_fps = Lows(h, n, 0.01)
	out.low01_fps = Lows(h, n, 0.001)
	out.p99_ms = Percentile(h, n, 0.99)
	out.max_ms = Highest(h)
	out.jitter_ms = sqrt(max(0, total_sq / n - avg * avg))
	out.p50_ms = Percentile(h, n, 0.5)
	out.p95_ms = Percentile(h, n, 0.95)
	out.p999_ms = Percentile(h, n, 0.999)
	out.min_ms = Lowest(h)
	out.median_fps = out.p50_ms > 0 and 1000 / out.p50_ms or 0
	out.lowest_fps = out.max_ms > 0 and 1000 / out.max_ms or 0
	out.highest_fps = out.min_ms > 0 and 1000 / out.min_ms or 0
	out.slow_frames = SlowerThan(h, S.Budget(FG.saved and FG.saved.target_fps or 60))
	out.slow_pct = out.slow_frames * 100 / n
	return out
end

local window_stats, session_stats, rec_stats = {}, {}, {}

function S.WindowStats()
	Build(window_stats, hist, filled, window_ms, window_sq)
	window_stats.current_fps = columns.count > 0 and columns.fps[columns.count] or window_stats.avg_fps
	window_stats.ping = columns.count > 0 and columns.ping[columns.count] or 0
	S.PingStats(columns.ping, 1, columns.count, window_stats)
	return window_stats
end

local function Extras(out, t, line)
	out.stutters, out.worst_ms, out.stutter_total_ms = t.stutters, t.worst, t.stutter_total
	out.ping_avg = t.ping_n > 0 and t.ping_sum / t.ping_n or 0
	out.ping_max, out.ping_min = t.ping_max, t.ping_min
	out.ping_jitter = t.ping_n > 0 and sqrt(max(0, t.ping_sq / t.ping_n - out.ping_avg * out.ping_avg)) or 0
	out.ping_warn = FG.saved.ping_warn_ms
	out.fps, out.low, out.ping, out.step_ms = line.fps, line.low, line.ping, line.step_ms
	out.target_fps, out.stutter_ms = FG.saved.target_fps, FG.saved.stutter_ms
	return out
end

function S.SessionStats()
	Build(session_stats, session_hist, session.frames, session.ms, session.sq)
	return Extras(session_stats, session, session_line)
end

function S.StartRecording()
	if rec then return false end
	rec = { frames = 0, ms = 0, sq = 0, stutters = 0, worst = 0, stutter_total = 0, ping_sum = 0, ping_n = 0, ping_max = 0,
		ping_sq = 0, ping_min = 0,
		hist = {}, line = NewLine(), started = GetTimeStamp() }
	for i = 1, BINS do rec.hist[i] = 0 end
	return true
end

function S.IsRecording() return rec ~= nil end
function S.RecordingSeconds() return rec and rec.ms / 1000 or 0 end

function S.RecordingStats()
	if not rec then return nil end
	Build(rec_stats, rec.hist, rec.frames, rec.ms, rec.sq)
	return Extras(rec_stats, rec, rec.line)
end

local function Round(v) return floor(v * 10 + 0.5) / 10 end

local function RoundList(list)
	local out = {}
	for i = 1, #list do out[i] = Round(list[i]) end
	return out
end

local RUN_FIELDS = {
	"avg_fps", "median_fps", "low1_fps", "low01_fps", "lowest_fps", "highest_fps",
	"avg_ms", "p50_ms", "p95_ms", "p99_ms", "p999_ms", "max_ms", "min_ms", "jitter_ms",
	"slow_pct", "stutter_total_ms", "ping_avg", "ping_jitter",
}

function S.StopRecording()
	if not rec then return nil end
	local s = S.RecordingStats()
	local run = {
		when = rec.started, seconds = Round(s.seconds), frames = s.frames, slow_frames = s.slow_frames,
		stutters = s.stutters, stutter_ms = s.stutter_ms, target_fps = s.target_fps, ping_max = s.ping_max,
		ping_min = s.ping_min, ping_warn = s.ping_warn,
		step_ms = s.step_ms, fps = RoundList(s.fps), low = RoundList(s.low), ping = RoundList(s.ping),
	}
	for _, key in ipairs(RUN_FIELDS) do run[key] = Round(s[key]) end
	rec = nil
	return run
end

S.Reset()
