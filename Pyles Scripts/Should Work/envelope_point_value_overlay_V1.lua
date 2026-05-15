-- @description Envelope point value overlay (optimized, all visible track envelopes)
-- @about
--   Displays formatted value labels near visible points of active/visible track envelope lanes.
--   This is an overlay approximation, not a native REAPER theme/UI modification.
--
--   Runtime requirements:
--     - ReaImGui
--     - js_ReaScriptAPI
--     - SWS Extension
--
--   Use:
--     1) Make one or more track envelope lanes visible.
--     2) Run this script.
--     3) Run it again to stop it.
--
--   Notes:
--     - Track envelopes are supported.
--     - Take envelopes are not supported.
--     - Automation items are supported.
--     - Optimized to rebuild only when the view/project changes, with capped update rate.

local r = reaper

-- =========================
-- User settings
-- =========================
-- Color format is 0xRRGGBBAA.
local SHOW_SELECTED_ONLY = false      -- true = label only selected points
local INCLUDE_AUTOMATION_ITEMS = true -- include points inside automation items
local SHOW_ALL_VISIBLE_ENVELOPES = true -- false = selected envelope only

local MAX_LABELS_TOTAL = 180          -- total safety cap per rebuild
local MAX_LABELS_PER_ENV = 48         -- per-envelope cap

local FONT_SIZE = 11
local LABEL_PAD_X = 3
local LABEL_PAD_Y = 1
local LABEL_Y_OFFSET = 16
local POINT_RADIUS = 2.0
local CONNECTOR = false
local BG_COLOR = 0x101010B8
local TEXT_COLOR = 0xFFFFFFFF
local POINT_COLOR = 0xFFFFFFFF
local LINE_COLOR = 0xFFFFFF80
local STATUS_BG = 0x101010CC
local STATUS_TEXT = 0xE8E8E8FF
local STATUS_PADDING = 8
local OVERLAP_MARGIN = 3
local LEFT_EDGE_LABEL_PAD = 12        -- keeps labels away from the arrange/TCP boundary
local RIGHT_EDGE_LABEL_PAD = 4
local TOP_EDGE_LABEL_PAD = 2

local ACTIVE_FPS = 90                 -- while view/project is changing (horizontal scroll etc.)
local DRAG_FPS = 120                 -- while dragging/editing with mouse held in arrange
local REBUILD_ACTIVE_FPS = 60        -- cap for heavier point rescans while active/dragging
local IDLE_FPS = 7                    -- while idle
local ACTIVE_GRACE_SEC = 0.20         -- stay in active mode briefly after motion/editing
local IDLE_RESCAN_SEC = 0.75          -- refresh visible envelopes periodically even if nothing changed
local HORIZ_PREFETCH_FRACTION = 0.35  -- cache extra points outside the visible time range for smoother scroll
local TIME_EPS = 1e-9

local EXT_SECTION = 'OpenAI_EnvelopePointValueOverlay'

local _, _, _, cmd_id = r.get_action_context()
local RUN_KEY = ('cmd_%s'):format(tostring(cmd_id))

local function set_running(v)
  r.SetExtState(EXT_SECTION, RUN_KEY, v and '1' or '0', false)
end

local function is_running()
  return r.GetExtState(EXT_SECTION, RUN_KEY) == '1'
end

if is_running() then
  set_running(false)
  return
end

if not r.ImGui_CreateContext then
  r.ShowMessageBox('This script requires the ReaImGui extension.', 'Envelope point value overlay', 0)
  return
end

if not r.JS_Window_FindChildByID then
  r.ShowMessageBox('This script requires the js_ReaScriptAPI extension.', 'Envelope point value overlay', 0)
  return
end

if not r.BR_EnvAlloc then
  r.ShowMessageBox('This script requires the SWS extension.', 'Envelope point value overlay', 0)
  return
end

set_running(true)

local ctx = r.ImGui_CreateContext('Envelope point value overlay')
local font = r.ImGui_CreateFont('sans-serif', FONT_SIZE)
r.ImGui_Attach(ctx, font)

local function push_font_safe()
  if not font then return false end
  local ok = pcall(r.ImGui_PushFont, ctx, font, FONT_SIZE)
  if ok then return true end
  ok = pcall(r.ImGui_PushFont, ctx, font)
  return ok
end

local function pop_font_safe(pushed)
  if pushed then pcall(r.ImGui_PopFont, ctx) end
end

local function cleanup()
  set_running(false)
  if ctx then
    pcall(r.ImGui_DestroyContext, ctx)
    ctx = nil
  end
end

r.atexit(cleanup)

local function clamp(x, a, b)
  if x < a then return a end
  if x > b then return b end
  return x
end

local function approx_equal(a, b, eps)
  return math.abs(a - b) <= (eps or TIME_EPS)
end

local function rects_overlap(a, b)
  return not (a.r < b.l or a.l > b.r or a.b < b.t or a.t > b.b)
end

local function get_arrange_rect()
  local hwnd = r.JS_Window_FindChildByID(r.GetMainHwnd(), 1000)
  if not hwnd then return nil end

  local ok, left, top, right, bottom = r.JS_Window_GetRect(hwnd)
  if not ok then return nil end
  if type(left) ~= 'number' or type(top) ~= 'number' or type(right) ~= 'number' or type(bottom) ~= 'number' then
    return nil
  end

  return {
    hwnd = hwnd,
    l = left,
    t = top,
    r = right,
    b = bottom,
    w = right - left,
    h = bottom - top,
  }
end

local function get_arrange_time_range()
  local start_time, end_time = r.GetSet_ArrangeView2(0, false, 0, 0, 0, 0)
  return start_time, end_time
end

local function get_env_props(env)
  local br_env = r.BR_EnvAlloc(env, false)
  if not br_env then return nil end

  local active, visible, armed, inLane, laneHeight, defaultShape,
        minValue, maxValue, centerValue, envType, faderScaling =
        r.BR_EnvGetProperties(br_env, true, true, true, true, 0, 0, 0, 0, 0, 0, false)

  r.BR_EnvFree(br_env, false)

  return {
    active = active,
    visible = visible,
    armed = armed,
    inLane = inLane,
    laneHeight = laneHeight,
    defaultShape = defaultShape,
    minValue = minValue,
    maxValue = maxValue,
    centerValue = centerValue,
    envType = envType,
    faderScaling = faderScaling,
  }
end

local function get_lane_rect(env)
  local track = r.Envelope_GetParentTrack(env)
  if not track then return nil end

  local track_screen_y = r.GetMediaTrackInfo_Value(track, 'I_TCPSCREENY')
  local env_y = r.GetEnvelopeInfo_Value(env, 'I_TCPY_USED')
  local env_h = r.GetEnvelopeInfo_Value(env, 'I_TCPH_USED')

  if env_h <= 0 then
    env_y = r.GetEnvelopeInfo_Value(env, 'I_TCPY')
    env_h = r.GetEnvelopeInfo_Value(env, 'I_TCPH')
  end

  if env_h <= 0 then return nil end

  return {
    top = track_screen_y + env_y,
    h = env_h,
    bottom = track_screen_y + env_y + env_h,
  }
end

local function point_to_screen_x(time, arrange, t0, t1)
  if t1 <= t0 then return arrange.l end
  local norm = (time - t0) / (t1 - t0)
  return arrange.l + norm * arrange.w
end

local function point_to_screen_y(env, raw_value, lane, props)
  local scaling_mode = r.GetEnvelopeScalingMode(env)
  local display_value = r.ScaleFromEnvelopeMode(scaling_mode, raw_value)

  local min_v = props.minValue
  local max_v = props.maxValue
  if max_v == min_v then
    return lane.top + lane.h * 0.5
  end

  local norm = (display_value - min_v) / (max_v - min_v)
  norm = clamp(norm, 0, 1)
  return lane.top + (1 - norm) * lane.h
end

local function format_value_uncached(env, raw_value)
  local ok, text = pcall(r.Envelope_FormatValue, env, raw_value)
  if ok and type(text) == 'string' and text ~= '' then return text end
  return string.format('%.3f', raw_value)
end

local function snap_draw_x(x)
  return math.floor(x) + 0.5
end

local function snap_draw_y(y)
  return math.floor(y) + 0.5
end

local state

local function get_text_metrics(text)
  local cache_tbl = state and state.text_size_cache
  if not cache_tbl then
    local w, h = r.ImGui_CalcTextSize(ctx, text)
    return math.floor(w + 0.5), math.floor(h + 0.5)
  end
  local cached = cache_tbl[text]
  if cached then return cached.w, cached.h end
  local w, h = r.ImGui_CalcTextSize(ctx, text)
  cached = { w = math.floor(w + 0.5), h = math.floor(h + 0.5) }
  cache_tbl[text] = cached
  return cached.w, cached.h
end

state = {
  last_rebuild_ts = 0,
  last_dirty_ts = 0,
  last_activity_ts = 0,
  last_rescan_ts = 0,
  was_active_last_frame = false,
  last_proj_state = -1,
  last_arrange = nil,
  last_t0 = nil,
  last_t1 = nil,
  value_text_cache = {},
  text_size_cache = {},
  model_cache = {
    envs = {},
    cache_t0 = nil,
    cache_t1 = nil,
    visible_sig = '',
  },
  draw_cache = {
    items = {},
    status = nil,
    capped = false,
    total_points = 0,
    total_labels = 0,
  },
}

local function get_env_key(env)
  return tostring(env)
end

local function get_mouse_pos()
  if not r.GetMousePosition then return nil, nil end
  local x, y = r.GetMousePosition()
  return x, y
end

local function is_mouse_in_rect(x, y, rect)
  if not rect or not x or not y then return false end
  return x >= rect.l and x <= rect.r and y >= rect.t and y <= rect.b
end

local function is_left_mouse_down()
  if not r.JS_Mouse_GetState then return false end
  local state_bits = r.JS_Mouse_GetState(1) or 0
  if _VERSION == 'Lua 5.3' or _VERSION == 'Lua 5.4' then
    return (state_bits & 1) == 1
  end
  return (state_bits % 2) == 1
end

local function get_point_label(env, autoidx, idx, value)
  local key = table.concat({get_env_key(env), autoidx, idx, string.format('%.17g', value)}, '|')
  local cached = state.value_text_cache[key]
  if cached then return cached end
  local text = format_value_uncached(env, value)
  state.value_text_cache[key] = text
  return text
end

local function enumerate_visible_track_envelopes(arrange)
  local envs = {}

  if not SHOW_ALL_VISIBLE_ENVELOPES then
    local env = r.GetSelectedEnvelope(0)
    if not env then return envs end
    if not r.Envelope_GetParentTrack(env) then return envs end

    local props = get_env_props(env)
    local lane = props and get_lane_rect(env) or nil
    if props and props.active and props.visible and props.inLane and lane and lane.h > 0 then
      if lane.bottom >= arrange.t and lane.top <= arrange.b then
        envs[#envs + 1] = { env = env, props = props, lane = lane }
      end
    end
    return envs
  end

  local track_count = r.CountTracks(0)
  for ti = 0, track_count - 1 do
    local track = r.GetTrack(0, ti)
    local env_count = r.CountTrackEnvelopes(track)
    for ei = 0, env_count - 1 do
      local env = r.GetTrackEnvelope(track, ei)
      if env then
        local props = get_env_props(env)
        if props and props.active and props.visible and props.inLane then
          local lane = get_lane_rect(env)
          if lane and lane.h > 0 and lane.bottom >= arrange.t and lane.top <= arrange.b then
            envs[#envs + 1] = { env = env, props = props, lane = lane }
          end
        end
      end
    end
  end

  table.sort(envs, function(a, b)
    if a.lane.top == b.lane.top then
      return get_env_key(a.env) < get_env_key(b.env)
    end
    return a.lane.top < b.lane.top
  end)

  return envs
end

local function get_visible_env_signature(envs)
  if not envs or #envs == 0 then return '' end
  local parts = {}
  for i = 1, #envs do
    parts[i] = get_env_key(envs[i].env)
  end
  return table.concat(parts, '|')
end

local function collect_visible_points(env, t0, t1)
  local points = {}
  local ai_spans = {}

  local function collect_ai_spans()
    if not INCLUDE_AUTOMATION_ITEMS then return end
    local ai_count = r.CountAutomationItems(env)
    for ai = 0, ai_count - 1 do
      local pos = r.GetSetAutomationItemInfo(env, ai, 'D_POSITION', 0, false)
      local len = r.GetSetAutomationItemInfo(env, ai, 'D_LENGTH', 0, false)
      local startoffs = r.GetSetAutomationItemInfo(env, ai, 'D_STARTOFFS', 0, false)
      local playrate = r.GetSetAutomationItemInfo(env, ai, 'D_PLAYRATE', 0, false)
      local loopsrc = r.GetSetAutomationItemInfo(env, ai, 'D_LOOPSRC', 0, false)
      local span_t0 = pos
      local span_t1 = pos + math.max(0, len)
      if span_t1 >= t0 and span_t0 <= t1 and len > 0 then
        ai_spans[#ai_spans + 1] = {
          t0 = span_t0,
          t1 = span_t1,
          autoidx = ai,
          pos = pos,
          len = len,
          startoffs = startoffs or 0,
          playrate = (playrate and playrate > 0) and playrate or 1.0,
          loopsrc = (loopsrc or 0) ~= 0,
        }
      end
    end
    if #ai_spans > 1 then
      table.sort(ai_spans, function(a, b)
        if a.t0 == b.t0 then return a.t1 < b.t1 end
        return a.t0 < b.t0
      end)
    end
  end

  local function time_is_covered_by_ai(time)
    for i = 1, #ai_spans do
      local span = ai_spans[i]
      if time < span.t0 then
        return false
      end
      if time >= span.t0 and time <= span.t1 then
        return true
      end
    end
    return false
  end

  local function add_point(project_time, value, selected, autoidx, idx)
    if project_time < t0 or project_time > t1 then return end
    if (not SHOW_SELECTED_ONLY) or selected then
      local text = get_point_label(env, autoidx, idx, value)
      local tw, th = get_text_metrics(text)
      points[#points + 1] = {
        time = project_time,
        value = value,
        selected = selected,
        autoidx = autoidx,
        idx = idx,
        text = text,
        tw = tw,
        th = th,
      }
    end
  end

  local function resolve_ai_project_time(ai_span, raw_time)
    if raw_time >= ai_span.t0 - TIME_EPS and raw_time <= ai_span.t1 + TIME_EPS then
      return raw_time
    end

    local pr = ai_span.playrate or 1.0
    if pr <= 0 then pr = 1.0 end

    local candidates = {
      ai_span.pos + ((raw_time - ai_span.startoffs) / pr),
      ai_span.pos + (raw_time / pr),
      ai_span.pos + raw_time,
    }

    for i = 1, #candidates do
      local c = candidates[i]
      if c >= ai_span.t0 - TIME_EPS and c <= ai_span.t1 + TIME_EPS then
        return c
      end
    end

    return raw_time
  end

  local function scan_underlying_envelope(skip_if_covered_by_ai)
    local count = r.CountEnvelopePointsEx(env, -1)
    if count <= 0 then return end

    local start_idx = r.GetEnvelopePointByTimeEx(env, -1, t0)
    if start_idx < 0 then start_idx = 0 end
    if start_idx > 0 then start_idx = start_idx - 1 end

    for i = start_idx, count - 1 do
      local ok, time, value, _, _, selected = r.GetEnvelopePointEx(env, -1, i)
      if not ok then break end
      if time > t1 then break end
      if time >= t0 and time <= t1 then
        if (not skip_if_covered_by_ai) or (not time_is_covered_by_ai(time)) then
          add_point(time, value, selected, -1, i)
        end
      end
    end
  end

  local function scan_automation_item(ai_span)
    local autoidx = ai_span.autoidx
    local count = r.CountEnvelopePointsEx(env, autoidx)
    if count <= 0 then return end

    -- Automation item point time/index behavior differs from the underlying envelope:
    -- iterate visible points directly for correctness, then resolve project time.
    for i = 0, count - 1 do
      local ok, time, value, _, _, selected = r.GetEnvelopePointEx(env, autoidx, i)
      if ok then
        local project_time = resolve_ai_project_time(ai_span, time)
        if project_time >= ai_span.t0 - TIME_EPS and project_time <= ai_span.t1 + TIME_EPS then
          add_point(project_time, value, selected, autoidx, i)
        end
      end
    end
  end

  collect_ai_spans()

  if INCLUDE_AUTOMATION_ITEMS then
    for i = 1, #ai_spans do
      scan_automation_item(ai_spans[i])
    end
  end

  scan_underlying_envelope(true)

  if #points > 1 then
    table.sort(points, function(a, b)
      if a.time == b.time then
        if a.autoidx == b.autoidx then
          return a.idx < b.idx
        end
        return a.autoidx > b.autoidx
      end
      return a.time < b.time
    end)
  end

  return points
end

local function neighbor_keys(cx, cy)
  return {
    (cx-1) .. ':' .. (cy-1), cx .. ':' .. (cy-1), (cx+1) .. ':' .. (cy-1),
    (cx-1) .. ':' .. cy,     cx .. ':' .. cy,     (cx+1) .. ':' .. cy,
    (cx-1) .. ':' .. (cy+1), cx .. ':' .. (cy+1), (cx+1) .. ':' .. (cy+1),
  }
end

local function refresh_model_lane_geometry(arrange)
  local model = state.model_cache
  local envs = model and model.envs or nil
  if not envs or #envs == 0 then return false, false end

  local changed = false
  local model_visible = {}

  for i = 1, #envs do
    local entry = envs[i]
    local lane = get_lane_rect(entry.env)
    if lane and lane.h > 0 then
      local old = entry.lane
      if (not old)
        or old.top ~= lane.top
        or old.bottom ~= lane.bottom
        or old.h ~= lane.h then
        entry.lane = lane
        changed = true
      end

      if lane.bottom >= arrange.t and lane.top <= arrange.b then
        model_visible[#model_visible + 1] = { env = entry.env }
      end
    else
      changed = true
    end
  end

  local visible_sig_changed = false
  if SHOW_ALL_VISIBLE_ENVELOPES then
    local current_visible = enumerate_visible_track_envelopes(arrange)
    local current_sig = get_visible_env_signature(current_visible)
    local cached_sig = model.visible_sig or get_visible_env_signature(model_visible)
    visible_sig_changed = current_sig ~= cached_sig
  end

  return changed, visible_sig_changed
end

local function build_model_cache(arrange, t0, t1)
  local envs = enumerate_visible_track_envelopes(arrange)
  local span = math.max(TIME_EPS, t1 - t0)
  local ext = span * HORIZ_PREFETCH_FRACTION
  local cache_t0 = t0 - ext
  local cache_t1 = t1 + ext

  local model_envs = {}
  for e = 1, #envs do
    local env_entry = envs[e]
    model_envs[#model_envs + 1] = {
      env = env_entry.env,
      props = env_entry.props,
      lane = env_entry.lane,
      points = collect_visible_points(env_entry.env, cache_t0, cache_t1),
    }
  end

  state.model_cache = {
    envs = model_envs,
    cache_t0 = cache_t0,
    cache_t1 = cache_t1,
    visible_sig = get_visible_env_signature(envs),
  }
end

local function refresh_model_points_only(t0, t1)
  local model = state.model_cache
  local envs = model and model.envs or nil
  if not envs or #envs == 0 then return false end

  local span = math.max(TIME_EPS, t1 - t0)
  local ext = span * HORIZ_PREFETCH_FRACTION
  local cache_t0 = t0 - ext
  local cache_t1 = t1 + ext

  for i = 1, #envs do
    local entry = envs[i]
    entry.props = get_env_props(entry.env) or entry.props
    entry.lane = get_lane_rect(entry.env) or entry.lane
    entry.points = collect_visible_points(entry.env, cache_t0, cache_t1)
  end

  model.cache_t0 = cache_t0
  model.cache_t1 = cache_t1
  return true
end

local function relayout_from_model(arrange, t0, t1)
  local draw_items = {}
  local total_labels = 0
  local total_points = 0
  local capped = false
  local status = nil

  local model = state.model_cache
  local envs = model.envs or {}
  if #envs == 0 then
    state.draw_cache = {
      items = draw_items,
      status = nil,
      capped = false,
      total_points = 0,
      total_labels = 0,
    }
    return
  end

  for e = 1, #envs do
    if total_labels >= MAX_LABELS_TOTAL then
      capped = true
      break
    end

    local env_entry = envs[e]
    local env = env_entry.env
    local props = env_entry.props
    local lane = env_entry.lane
    local points = env_entry.points or {}
    local env_labels = 0
    local spatial = {}
    local grid_size = math.max(32, FONT_SIZE * 6)

    for i = 1, #points do
      if total_labels >= MAX_LABELS_TOTAL or env_labels >= MAX_LABELS_PER_ENV then
        capped = true
        break
      end

      local p = points[i]
      if p.time > t1 then
        break
      end
      if p.time >= t0 and p.time <= t1 then
        total_points = total_points + 1

        local sx = point_to_screen_x(p.time, arrange, t0, t1)
        local sy = point_to_screen_y(env, p.value, lane, props)

        if sx >= arrange.l and sx <= arrange.r and sy >= arrange.t and sy <= arrange.b then
          local text = p.text or get_point_label(env, p.autoidx, p.idx, p.value)
          local tw = p.tw
          local th = p.th
          if not tw or not th then
            tw, th = get_text_metrics(text)
            p.tw, p.th = tw, th
          end

          sx = snap_draw_x(sx)
          sy = snap_draw_y(sy)

          local lx = math.floor(sx - tw * 0.5 + 0.5)
          local ly = math.floor(sy - LABEL_Y_OFFSET - th + 0.5)

          local min_l = arrange.l + LEFT_EDGE_LABEL_PAD + LABEL_PAD_X
          local max_l = arrange.r - RIGHT_EDGE_LABEL_PAD - tw - LABEL_PAD_X
          if max_l < min_l then max_l = min_l end
          lx = clamp(lx, min_l, max_l)
          ly = math.max(arrange.t + TOP_EDGE_LABEL_PAD + LABEL_PAD_Y, ly)

          local rect = {
            l = lx - LABEL_PAD_X,
            t = ly - LABEL_PAD_Y,
            r = lx + tw + LABEL_PAD_X,
            b = ly + th + LABEL_PAD_Y,
          }

          local cx = math.floor(rect.l / grid_size)
          local cy = math.floor(rect.t / grid_size)
          local overlap = false
          local keys = neighbor_keys(cx, cy)

          for nk = 1, #keys do
            local bucket = spatial[keys[nk]]
            if bucket then
              for bi = 1, #bucket do
                local prev = bucket[bi]
                local grown = {
                  l = prev.l - OVERLAP_MARGIN,
                  t = prev.t - OVERLAP_MARGIN,
                  r = prev.r + OVERLAP_MARGIN,
                  b = prev.b + OVERLAP_MARGIN,
                }
                if rects_overlap(rect, grown) then
                  overlap = true
                  break
                end
              end
            end
            if overlap then break end
          end

          if not overlap then
            local cell_key = cx .. ':' .. cy
            if not spatial[cell_key] then spatial[cell_key] = {} end
            spatial[cell_key][#spatial[cell_key] + 1] = rect

            draw_items[#draw_items + 1] = {
              sx = sx,
              sy = sy,
              rect = rect,
              lx = lx,
              ly = ly,
              text = text,
            }
            total_labels = total_labels + 1
            env_labels = env_labels + 1
          end
        end
      end
    end
  end

  if total_labels == 0 then
    status = SHOW_SELECTED_ONLY and 'No visible selected points.' or 'No visible points.'
  end

  state.draw_cache = {
    items = draw_items,
    status = status,
    capped = capped,
    total_points = total_points,
    total_labels = total_labels,
  }
end

local function full_rebuild(arrange, t0, t1)
  build_model_cache(arrange, t0, t1)
  relayout_from_model(arrange, t0, t1)
end

local function draw_status(dl, arrange, text)
  local tw, th = r.ImGui_CalcTextSize(ctx, text)
  local x = arrange.l + 16
  local y = arrange.t + 16
  r.ImGui_DrawList_AddRectFilled(dl, x, y, x + tw + STATUS_PADDING * 2, y + th + STATUS_PADDING * 2, STATUS_BG, 6)
  r.ImGui_DrawList_AddText(dl, x + STATUS_PADDING, y + STATUS_PADDING, STATUS_TEXT, text)
end

local function draw_cached_overlay(arrange)
  local dl = r.ImGui_GetWindowDrawList(ctx)
  r.ImGui_DrawList_PushClipRect(dl, arrange.l, arrange.t, arrange.r, arrange.b, true)

  local cache = state.draw_cache
  for i = 1, #cache.items do
    local item = cache.items[i]
    if CONNECTOR then
      r.ImGui_DrawList_AddLine(dl, item.sx, item.sy - 1, item.sx, item.rect.b + 1, LINE_COLOR, 1.0)
    end
    r.ImGui_DrawList_AddRectFilled(dl, item.rect.l, item.rect.t, item.rect.r, item.rect.b, BG_COLOR, 4)
    r.ImGui_DrawList_AddText(dl, item.lx, item.ly, TEXT_COLOR, item.text)
  end

  if cache.status then
    draw_status(dl, arrange, cache.status)
  elseif cache.capped then
    local msg = ('Showing %d labels (cap reached).'):format(cache.total_labels)
    draw_status(dl, arrange, msg)
  end

  r.ImGui_DrawList_PopClipRect(dl)
end

local function get_change_flags(arrange, t0, t1, proj_state)
  local a = state.last_arrange
  local proj_changed = (proj_state ~= state.last_proj_state)
  local rect_changed = not a or a.l ~= arrange.l or a.t ~= arrange.t or a.r ~= arrange.r or a.b ~= arrange.b
  local time_changed = (state.last_t0 == nil or state.last_t1 == nil or not approx_equal(t0, state.last_t0) or not approx_equal(t1, state.last_t1))
  return proj_changed, rect_changed, time_changed
end

local function model_covers_range(t0, t1)
  local mc = state.model_cache
  return mc and mc.cache_t0 and mc.cache_t1 and t0 >= mc.cache_t0 and t1 <= mc.cache_t1
end

local function save_state_snapshot(arrange, t0, t1, proj_state, now)
  state.last_arrange = { l = arrange.l, t = arrange.t, r = arrange.r, b = arrange.b }
  state.last_t0 = t0
  state.last_t1 = t1
  state.last_proj_state = proj_state
  state.last_dirty_ts = now
  state.last_rescan_ts = now
  state.last_rebuild_ts = now
end

local function begin_overlay_window(arrange)
  local pos_x = arrange and arrange.l or 0
  local pos_y = arrange and arrange.t or 0
  local size_w = arrange and math.max(1, arrange.w) or 1
  local size_h = arrange and math.max(1, arrange.h) or 1

  local flags = (r.ImGui_WindowFlags_NoDecoration()
    | r.ImGui_WindowFlags_NoDocking()
    | r.ImGui_WindowFlags_NoInputs()
    | r.ImGui_WindowFlags_NoSavedSettings()
    | r.ImGui_WindowFlags_NoBackground())

  local ok = pcall(r.ImGui_SetNextWindowPos, ctx, pos_x, pos_y)
  if not ok then return false, false end
  ok = pcall(r.ImGui_SetNextWindowSize, ctx, size_w, size_h)
  if not ok then return false, false end

  local ok_begin, visible = pcall(r.ImGui_Begin, ctx, '##env_point_overlay', true, flags)
  if not ok_begin then return false, false end
  return true, visible
end

local function loop()
  if not is_running() then return end

  local now = r.time_precise()
  local arrange = get_arrange_rect()
  local ok_begin, visible = begin_overlay_window(arrange)
  if not ok_begin then
    set_running(false)
    return
  end

  local pushed_font = push_font_safe()
  local ok, err = xpcall(function()
    if arrange and arrange.w > 0 and arrange.h > 0 then
      local t0, t1 = get_arrange_time_range()
      local proj_state = r.GetProjectStateChangeCount(0)
      local mouse_x, mouse_y = get_mouse_pos()
      local mouse_in_arrange = is_mouse_in_rect(mouse_x, mouse_y, arrange)
      local left_down = is_left_mouse_down()

      local proj_changed, rect_changed, time_changed = get_change_flags(arrange, t0, t1, proj_state)
      local lane_geom_changed, visible_set_changed = refresh_model_lane_geometry(arrange)
      local instant_dirty = proj_changed or rect_changed or time_changed or lane_geom_changed or visible_set_changed
      local dragging_in_arrange = left_down and mouse_in_arrange

      if instant_dirty or dragging_in_arrange then
        state.last_activity_ts = now
      end

      local active_mode = instant_dirty or dragging_in_arrange or ((now - state.last_activity_ts) < ACTIVE_GRACE_SEC)
      local rebuild_target_fps = dragging_in_arrange and DRAG_FPS or (active_mode and REBUILD_ACTIVE_FPS or IDLE_FPS)
      local rebuild_interval = 1 / math.max(1, rebuild_target_fps)

      local do_full_rebuild = false
      local do_partial_rebuild = false
      local do_relayout = false

      if proj_changed then
        state.value_text_cache = {}
        state.text_size_cache = {}
        if dragging_in_arrange and state.model_cache and state.model_cache.envs and #state.model_cache.envs > 0 and not visible_set_changed then
          do_partial_rebuild = true
        else
          do_full_rebuild = true
        end
      elseif rect_changed then
        do_full_rebuild = true
      elseif visible_set_changed then
        do_full_rebuild = true
      elseif lane_geom_changed then
        do_relayout = true
      elseif time_changed then
        if model_covers_range(t0, t1) then
          do_relayout = true
        else
          do_full_rebuild = true
        end
      elseif dragging_in_arrange then
        do_partial_rebuild = true
      elseif (now - state.last_rescan_ts) >= IDLE_RESCAN_SEC then
        do_full_rebuild = true
      end

      if do_relayout then
        relayout_from_model(arrange, t0, t1)
        state.last_arrange = { l = arrange.l, t = arrange.t, r = arrange.r, b = arrange.b }
        state.last_t0 = t0
        state.last_t1 = t1
        state.last_proj_state = proj_state
        state.last_dirty_ts = now
      end

      if do_partial_rebuild or do_full_rebuild then
        if (now - state.last_rebuild_ts) >= rebuild_interval or not state.was_active_last_frame or (do_full_rebuild and not do_relayout) then
          if do_full_rebuild then
            full_rebuild(arrange, t0, t1)
          else
            refresh_model_points_only(t0, t1)
            relayout_from_model(arrange, t0, t1)
          end
          save_state_snapshot(arrange, t0, t1, proj_state, now)
        end
      end

      state.was_active_last_frame = active_mode

      if visible then
        draw_cached_overlay(arrange)
      end
    else
      state.was_active_last_frame = false
    end
  end, debug.traceback)

  pop_font_safe(pushed_font)
  pcall(r.ImGui_End, ctx)

  if not ok then
    set_running(false)
    r.ShowMessageBox(tostring(err), 'Envelope point value overlay - script error', 0)
    return
  end

  r.defer(loop)
end

loop()
