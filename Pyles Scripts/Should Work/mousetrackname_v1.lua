-- MingLee - Show trackname near mouse pointer
-- Requirements: js_ReaScriptAPI + ReaImGui

local PAD_X = 8
local PAD_Y = 4
local OFFSET_X = 16

local ctx = reaper.ImGui_CreateContext('TrackTooltip')

local function loop()
  local x, y = reaper.GetMousePosition()
  local track = reaper.GetTrackFromPoint and reaper.GetTrackFromPoint(x, y)

  local flags = reaper.ImGui_WindowFlags_NoTitleBar()
              | reaper.ImGui_WindowFlags_NoResize()
              | reaper.ImGui_WindowFlags_NoScrollbar()
              | reaper.ImGui_WindowFlags_NoInputs()
              | reaper.ImGui_WindowFlags_NoMove()
              | reaper.ImGui_WindowFlags_NoSavedSettings()
              | reaper.ImGui_WindowFlags_NoFocusOnAppearing()

  if track then
    local _, name = reaper.GetTrackName(track)
    local num = reaper.GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER")
    local label = string.format("---- %d : %s", num, name)
    local tw = reaper.ImGui_CalcTextSize(ctx, label)
    local win_w = tw + PAD_X * 2
    local win_h = 13 + PAD_Y * 2
    local win_x = x - win_w - OFFSET_X
    local win_y = y - win_h / 2

    reaper.ImGui_SetNextWindowPos(ctx, win_x, win_y)
    reaper.ImGui_SetNextWindowSize(ctx, win_w, win_h)
    reaper.ImGui_SetNextWindowBgAlpha(ctx, 0.85)

    local visible = reaper.ImGui_Begin(ctx, 'tracktooltip', true, flags)
    if visible then
      reaper.ImGui_Text(ctx, label)
    end
    reaper.ImGui_End(ctx)
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