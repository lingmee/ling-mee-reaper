--  Track Manager --
-- @version 0.1 --
local ctx = reaper.ImGui_CreateContext('Track Manager')
local font = reaper.ImGui_CreateFont('sans-serif', 18)
reaper.ImGui_Attach(ctx, font)

local tags, selected_tags = {}, {}
local search_text = ""
local solo_mode, hide_muted, pending_changes = false, false, false

local exclude_list = { 
    ["and"]=true, ["or"]=true, ["for"]=true, ["out"]=true, ["of"]=true, 
    ["the"]=true, ["with"]=true, ["in"]=true, ["to"]=true, ["is"]=true,
    ["on"]=true, ["at"]=true, ["by"]=true, ["from"]=true
}

function update_tags()
    local seen = {}
    tags = {}
    for i = 0, reaper.CountTracks(0) - 1 do
        local tr = reaper.GetTrack(0, i)
        local _, name = reaper.GetSetMediaTrackInfo_String(tr, "P_NAME", "", false)
        if name and name ~= "" then
            for tag in name:gmatch("[%w%-_]+") do
                local low = tag:lower()
                if #tag > 1 and not tag:match("%d") and not exclude_list[low] then 
                    if not seen[low] then table.insert(tags, tag) seen[low] = true end
                end
            end
        end
    end
    table.sort(tags, function(a,b) return a:lower() < b:lower() end)
end

function filter_tracks()
    reaper.Undo_BeginBlock()
    reaper.PreventUIRefresh(1)
    
    local any_selected = false
    for _ in pairs(selected_tags) do any_selected = true break end
    local track_count = reaper.CountTracks(0)
    local visibility = {}

    if not any_selected then
        for i = 0, track_count - 1 do visibility[reaper.GetTrack(0, i)] = true end
    else
        for i = 0, track_count - 1 do
            local tr = reaper.GetTrack(0, i)
            local _, name = reaper.GetSetMediaTrackInfo_String(tr, "P_NAME", "", false)
            local match = false
            for tag, _ in pairs(selected_tags) do 
                if name:lower():find(tag:lower(), 1, true) then match = true break end 
            end
            if match then
                visibility[tr] = true
                if reaper.GetMediaTrackInfo_Value(tr, "I_FOLDERDEPTH") == 1 then
                    local d = 1
                    for j = i + 1, track_count - 1 do
                        local child = reaper.GetTrack(0, j)
                        visibility[child] = true
                        d = d + reaper.GetMediaTrackInfo_Value(child, "I_FOLDERDEPTH")
                        if d <= 0 then break end
                    end
                end
            end
        end
    end

    for i = 0, track_count - 1 do
        local tr = reaper.GetTrack(0, i)
        local is_muted = reaper.GetMediaTrackInfo_Value(tr, "B_MUTE") == 1
        local target_v = (visibility[tr] and (not (hide_muted and is_muted))) and 1 or 0
        reaper.SetMediaTrackInfo_Value(tr, "B_SHOWINTCP", target_v)
        reaper.SetMediaTrackInfo_Value(tr, "B_SHOWINMIXER", target_v)
        if solo_mode then 
            reaper.SetMediaTrackInfo_Value(tr, "I_SOLO", (any_selected and target_v == 1) and 2 or 0) 
        end
    end

    pending_changes = false
    reaper.TrackList_AdjustWindows(false)
    reaper.UpdateArrange()
    reaper.PreventUIRefresh(-1)
    reaper.Undo_EndBlock("Dahya Track Filter", -1)
end

function loop()
    -- Ensure window starts at a usable size --
    reaper.ImGui_SetNextWindowSize(ctx, 350, 600, reaper.ImGui_Cond_FirstUseEver())
    
    reaper.ImGui_PushFont(ctx, font, 0.0) 
    local visible, open = reaper.ImGui_Begin(ctx, 'Track Manager', true)
    
    if visible then
        local color_pushed = false
        if pending_changes then 
            reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), 0xFF4444FF) 
            color_pushed = true
        end

        if reaper.ImGui_Button(ctx, "APPLY CHANGES TO PROJECT", -1, 40) then 
            filter_tracks() 
        end
        if color_pushed then reaper.ImGui_PopStyleColor(ctx) end

        if reaper.ImGui_Button(ctx, "Scan Tags", 120) then update_tags() end
        reaper.ImGui_SameLine(ctx)
        local rv1, s_val = reaper.ImGui_Checkbox(ctx, "Solo Mode", solo_mode)
        if rv1 then solo_mode = s_val; pending_changes = true end

        if reaper.ImGui_Button(ctx, "Clear All", 120) then selected_tags = {}; pending_changes = true end
        reaper.ImGui_SameLine(ctx)
        local rv2, m_val = reaper.ImGui_Checkbox(ctx, "Hide Muted", hide_muted)
        if rv2 then hide_muted = m_val; pending_changes = true end

        reaper.ImGui_Separator(ctx)
        local changed, new_text = reaper.ImGui_InputText(ctx, "Search", search_text)
        if changed then search_text = new_text end

        if reaper.ImGui_BeginChild(ctx, "TagList", 0, 0, reaper.ImGui_ChildFlags_Borders()) then
            for _, tag in ipairs(tags) do
                if search_text == "" or tag:lower():find(search_text:lower(), 1, true) then
                    local is_sel = selected_tags[tag] ~= nil
                    if reaper.ImGui_Selectable(ctx, tag, is_sel) then
                        if is_sel then selected_tags[tag] = nil else selected_tags[tag] = true end
                        pending_changes = true
                    end
                end
            end
            reaper.ImGui_EndChild(ctx)
        end
        reaper.ImGui_End(ctx)
    end
    
    reaper.ImGui_PopFont(ctx)
    
    if open then 
        reaper.defer(loop) 
    else 
        -- Safe cleanup for v0.10+ --
        if reaper.ImGui_DestroyContext then reaper.ImGui_DestroyContext(ctx) end
    end
end

-- Force initial scan and start loop --
update_tags()
reaper.defer(loop)
