-- Prompt the user to input the desired device ID
local retval, inputID_str = reaper.GetUserInputs("Set Input Device ID", 1, "Enter Device ID:", "")

-- Check if the user provided an input
if retval then
    -- Convert the input to a number
    local inputID = tonumber(inputID_str)

    -- Check if the conversion was successful
    if inputID then
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
    else
        -- Display an error message if the input was not a valid number
        reaper.ShowConsoleMsg("Invalid device ID entered.\n")
    end
else
    -- Display a message if the user cancelled the input dialog
    reaper.ShowConsoleMsg("User cancelled the input.\n")
end

