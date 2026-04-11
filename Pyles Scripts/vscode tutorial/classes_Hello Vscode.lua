dofile('C:/REAPER/Scripts/Pyles Scripts/mDebug/mdebug.lua')

local track = reaper.GetTrack(0, 0)
reaper.ShowConsoleMsg('Hello gamers!')

local t = {track, track, 10, 20, 30, {50,60,70,{80,90,100}}}
if true then
    reaper.ShowConsoleMsg('Finishing Script!')
end