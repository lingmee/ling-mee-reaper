-- @description Find MIDI device ID value
-- @author ling mee 69 (thanks to strachupl)
-- @version 1.0
-- @about
-- Find out device ID value

-- Get the first selected track
local track = reaper.GetSelectedTrack(0, 0)

-- Check if the track exists
if track then
    -- Get the Input ID
    local input_id = reaper.GetMediaTrackInfo_Value(track, "I_RECINPUT")
    
    -- Display the Input ID in the console
    reaper.ShowConsoleMsg("Input ID: " .. tostring(input_id) .. "\n")
else
    -- Display a message if no track is selected
    reaper.ShowConsoleMsg("No track selected.\n")
end
