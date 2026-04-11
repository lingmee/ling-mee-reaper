function print(val1)
    reaper.ShowConsoleMsg('\n' ..tostring(val1))
end

function loop()
    local track = reaper.GetSelectedTrack2(proj, trackidx, false)
    if track then
        print(track)
        reaper.defer(loop)
    end
end

function exit()
    print('closing script!')  
end

proj = 0
trackidx = 0
reaper.defer(loop)
reaper.atexit(exit)