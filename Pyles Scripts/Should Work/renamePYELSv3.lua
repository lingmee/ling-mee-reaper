-- Batch rename tracks from chapter/take markers inside selected items

local function msg(s)
  reaper.ShowConsoleMsg(tostring(s) .. "\n")
end

reaper.Undo_BeginBlock()

local num_items = reaper.CountSelectedMediaItems(0)
if num_items == 0 then
  msg("No items selected.")
  return
end

for i = 0, num_items - 1 do
  local item = reaper.GetSelectedMediaItem(0, i)
  local take = reaper.GetActiveTake(item)
  local track = reaper.GetMediaItemTrack(item)

  if take and track then
    local item_start = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
    local item_len   = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
    local item_end   = item_start + item_len

    local num_markers = reaper.GetNumTakeMarkers(take)

    for m = 0, num_markers - 1 do
      local retval, name, pos = reaper.GetTakeMarker(take, m)
      if retval and name ~= "" then
        local marker_pos = pos + reaper.GetMediaItemInfo_Value(item, "D_POSITION")
        if marker_pos >= item_start and marker_pos <= item_end then
          reaper.GetSetMediaTrackInfo_String(track, "P_NAME", name, true)
          break
        end
      end
    end
  end
end

reaper.Undo_EndBlock("Batch rename tracks from item chapter markers", -1)

