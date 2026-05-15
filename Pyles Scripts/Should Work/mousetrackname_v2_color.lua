-- MingLee - Show trackname near mouse pointer
-- Requirements: js_ReaScriptAPI + ReaImGui

local PAD_X = 10
local PAD_Y = 6
local OFFSET_X = 16
local ROUNDING = 10
local BORDER_THICKNESS = 1.5

local ctx = reaper.ImGui_CreateContext('TrackTooltip')

local function rgba_to_imgui(r, g, b, a)
  return reaper.ImGui_ColorConvertDouble4ToU32(
    r / 255, g / 255, b / 255, (a or 255) / 255
  )
end

local function get_track_border_color(track)
  local native = reaper.GetTrackColor(track)
  if native == 0 then
    return rgba_to_imgui(120, 220, 40, 255) -- fallback green
  end

  local r, g, b = reaper.ColorFromNative(native)
  return rgba_to_imgui(r, g, b, 255)
end

local function loop()
  local x, y = reaper.GetMousePosition()
  local track = reaper.GetTrackFromPoint and reaper.GetTrackFromPoint(x, y)

  local flags =
      reaper.ImGui_WindowFlags_NoDecoration()
    | reaper.ImGui_WindowFlags_NoScrollbar()
    | reaper.ImGui_WindowFlags_NoInputs()
    | reaper.ImGui_WindowFlags_NoMove()
    | reaper.ImGui_WindowFlags_NoSavedSettings()
    | reaper.ImGui_WindowFlags_NoFocusOnAppearing()
    | reaper.ImGui_WindowFlags_AlwaysAutoResize()

  if track then
    local _, name = reaper.GetTrackName(track)
    local num = reaper.GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER")
    local label = string.format("%d  %s", num, name)

    local text_w, text_h = reaper.ImGui_CalcTextSize(ctx, label)
    local win_w = text_w + PAD_X * 2
    local win_h = text_h + PAD_Y * 2
    local win_x = x - win_w - OFFSET_X
    local win_y = y - win_h / 2

    local border_col = get_track_border_color(track)
    local bg_col = rgba_to_imgui(20, 20, 20, 235)
    local text_col = rgba_to_imgui(220, 220, 220, 255)

    reaper.ImGui_SetNextWindowPos(ctx, win_x, win_y)
    reaper.ImGui_SetNextWindowSize(ctx, win_w, win_h)
    reaper.ImGui_SetNextWindowBgAlpha(ctx, 0)

    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_WindowRounding(), ROUNDING)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_WindowPadding(), PAD_X, PAD_Y)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_WindowBorderSize(), 0)

    local visible = reaper.ImGui_Begin(ctx, 'tracktooltip', true, flags)
    if visible then
      local dl = reaper.ImGui_GetWindowDrawList(ctx)
      local wx, wy = reaper.ImGui_GetWindowPos(ctx)
      local ww, wh = reaper.ImGui_GetWindowSize(ctx)

      reaper.ImGui_DrawList_AddRectFilled(dl, wx, wy, wx + ww, wy + wh, bg_col, ROUNDING)
      reaper.ImGui_DrawList_AddRect(dl, wx, wy, wx + ww, wy + wh, border_col, ROUNDING, 0, BORDER_THICKNESS)

      reaper.ImGui_SetCursorPos(ctx, PAD_X, PAD_Y)
      reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), text_col)
      reaper.ImGui_Text(ctx, label)
      reaper.ImGui_PopStyleColor(ctx)
    end
    reaper.ImGui_End(ctx)

    reaper.ImGui_PopStyleVar(ctx, 3)
  else
    reaper.ImGui_SetNextWindowPos(ctx, -9999, -9999)
    reaper.ImGui_SetNextWindowSize(ctx, 1, 1)
    reaper.ImGui_SetNextWindowBgAlpha(ctx, 0)
    reaper.ImGui_Begin(ctx, 'tracktooltip', true, flags)
    reaper.ImGui_End(ctx)
  end

  reaper.defer(loop)
end

loop()