function main()
    local num_tracks = reaper.CountTracks(0)
    reaper.Main_OnCommand(40297, 0)  -- Unselect all tracks
    
    for i = 0, num_tracks - 1 do
        local track = reaper.GetTrack(0, i)
        local folder_depth = reaper.GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH")
        
        if folder_depth > 0 then  -- This is a folder start
            for j = i + 1, num_tracks - 1 do
                local next_track = reaper.GetTrack(0, j)
                local next_folder_depth = reaper.GetMediaTrackInfo_Value(next_track, "I_FOLDERDEPTH")
                
                if next_folder_depth < 0 then  -- This is the last track in the folder
                    reaper.SetTrackSelected(next_track, true)  -- Select the last track in the folder
                    break
                end
            end
        end
    end
    reaper.TrackList_AdjustWindows(false)
end

main()
reaper.UpdateArrange()

