-- Define the number of tracks you want to select
local numTracks = 8

-- Track visibility toggle function
local function toggleTrackVisibility(track)
    local currentVisibility = reaper.GetMediaTrackInfo_Value(track, "B_SHOWINTCP")
    reaper.SetMediaTrackInfo_Value(track, "B_SHOWINTCP", not currentVisibility)
end

-- Loop through the tracks and select them
for i = 0, numTracks - 1 do
    local track = reaper.GetTrack(0, i)
    if track then
        toggleTrackVisibility(track)
        reaper.SetTrackSelected(track, true)
    end
end

-- Update the arrangement to reflect the changes
reaper.UpdateArrange()

