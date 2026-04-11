-- set Device to... You have to edit "USERDEVICE"
-- Set the desired device ID
local inputID = 4096.0 -- Enter your desired device ID here

-- Get the number of selected tracks
local numTracks = reaper.CountSelectedTracks(0)

-- Begin undo block
reaper.Undo_BeginBlock()

-- Loop through all selected tracks
for i = 0, numTracks - 1 do
    -- Get the track
    local track = reaper.GetSelectedTrack(0, i)
    
    -- Set the specified ID as the input for the track
    reaper.SetMediaTrackInfo_Value(track, "I_RECINPUT", inputID)
end

-- End undo block
reaper.Undo_EndBlock("Set selected track(s) input to device ID " .. inputID, -1)
