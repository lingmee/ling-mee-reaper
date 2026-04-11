-- Function to print the input IDs of all enabled MIDI devices
local function printEnabledMIDIInputIDs()
    -- get number of inputs
    local numMIDIInputs = reaper.GetNumMIDIInputs()
    
    -- print header msg
    reaper.ShowConsoleMsg("Enabled MIDI Input Device IDs:\n")
    
    for i = 0, numMIDIInputs - 1 do
        -- Get the device name and enabled state
        local retval, deviceName = reaper.GetMIDIInputName(i, "")
        if retval then
            -- Get the input ID for the MIDI device
            local inputID = i 
            -- Print the input ID and device name to the console
            reaper.ShowConsoleMsg("Input ID: " .. tostring(inputID) .. ", Name: " .. deviceName .. "\n")
        end
    end

    -- Print a message if no MIDI devices are enabled
    if numMIDIInputs == 0 then
        reaper.ShowConsoleMsg("No MIDI devices enabled.\n")
    end
end

printEnabledMIDIInputIDs()

