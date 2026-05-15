-------------------------------------------
------ WORMHOLE LABS ----------------------
------ REAPER DarkMode Configurator -------
------ version 1.4 (2026) -----------------
-------------------------------------------

local ctx = reaper.ImGui_CreateContext('RobConfigFinal')
local ini_path = reaper.GetResourcePath() .. '/UserPlugins/reaper_darkmode.ini'

local function rgb(r, g, b)
  return (r << 24) | (g << 16) | (b << 8) | 0xFF
end

local is_enabled = true
local pending_enabled = true
local sync_theme_colors = false
local pending_sync_theme = false
local global_pin = false
local pending_global_pin = false

-- THEME BACKUP STATE VARIABLES
local orig_theme_name = ""
local orig_col_main_bg = -1
local orig_window_bg = -1
local orig_col_main_editbk = -1
local orig_col_listbg_grid = -1
local orig_col_main_text = -1
local orig_unfocused_bg = -1

-- Default values
local settings = {
  {key = "TitleBarColor", label = "Window Title Bar", def =                        rgb(12, 12, 12)},
  {key = "ColorMain", label = "Inner window Background", def =                     rgb(48, 48, 48)},  
  {key = "ColorChild", label = "Main Window Background *", def =                   rgb(32, 32, 32)},  
  {key = "ColorEditBackground", label = "Edit Fields", def =                       rgb(35, 35, 35)},  
  {key = "TextColor", label = "Text Color", def =                                  rgb(160, 160, 160)},  
  {key = "DisabledTextColor", label = "Disabled Text", def =                       rgb(120, 120, 120)},  
  {key = "MainWindowBorder", label = "Main Window Border", def =                   rgb(60, 60, 60)},
  {key = "BorderColor", label = "Internal Borders", def =                          rgb(70, 70, 70)},  
  {key = "GroupBoxColor", label = "GroupBox Labels", def =                         rgb(160, 160, 160)},
  {key = "HeaderBackground", label = "Table Header Background", def =              rgb(80, 80, 80)},  
  {key = "HeaderTextColor", label = "Table Header Text", def =                     rgb(210, 210, 210)},  
  {key = "TreeSelectionTextColor", label = "Selected Item Text", def =             rgb(255, 255, 255)},
  {key = "MenuBarBackground", label = "Menu Bar Background", def =                 rgb(22, 22, 22)},
  {key = "MenuBarHover", label = "Menu Bar Hover", def =                           rgb(62, 62, 62)},
  {key = "MenuTextColor", label = "Menu Bar Text", def =                           rgb(220, 220, 220)},
  {key = "MenuTextDisabled", label = "Menu Text Disabled (possibly unused)", def = rgb(120, 120, 120)},
  {key = "TabBackground", label = "Inactive Tab Background", def =                 rgb(56, 56, 56)},
  {key = "TabSelected", label = "Active Tab Background", def =                     rgb(32, 32, 32)},
  {key = "SystemWindowsColor", label = "System Dialogs (Save/Export...)", def =    rgb(75, 75, 75)},
  {key = "GridLinesColor", label = "List Gridlines *", def =                       rgb(44, 44, 44)},
  {key = "TreeSelectionBgColor", label = "Selected Item Background", def =       rgb(90, 90, 90)},
  {key = "ThemedWindowText", label = "Themed Window Text *", def =                 rgb(147, 147, 147)},
  {key = "TreeUnfocusedSelectionBgColor", label = "Unfocused Item Background", def = rgb(60, 60, 60)},
}

function push_dark_style()
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_WindowBg(),         0x202020FF)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_TitleBg(),          0x121212FF)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_TitleBgActive(),    0x161616FF)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(),             0xDDDDDDFF)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_TextDisabled(),     0x888888FF)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Header(),           0x333333FF)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_HeaderHovered(),    0x444444FF)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_HeaderActive(),     0x222222FF)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(),           0x333333FF)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(),    0x444444FF)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(),     0x222222FF)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Border(),           0x555555FF)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_FrameBg(),          0x333333FF)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_FrameBgHovered(),   0x444444FF)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_FrameBgActive(),    0x222222FF)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_PopupBg(),          0x1E1E1EFF)
end

function push_light_style()
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_WindowBg(),         0xE6E6E6FF)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_TitleBg(),          0xDCDCDCFF)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_TitleBgActive(),    0xCFCFCFFF)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(),             0x202020FF)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_TextDisabled(),     0x808080FF)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Header(),           0xDDDDDDFF)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_HeaderHovered(),    0xCCCCCCFF)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_HeaderActive(),     0xBBBBBBFF)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(),           0xDDDDDDFF)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(),    0xCCCCCCFF)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(),     0xBBBBBBFF)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Border(),           0xAAAAAAFF)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_FrameBg(),          0xFFFFFFFf)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_FrameBgHovered(),   0xEEEEEEFF)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_FrameBgActive(),    0xDDDDDDFF)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_PopupBg(),          0xFFFFFFFF)
end

local selected_idx = 1
local temp_color = settings[1].def
local last_selected = -1
local pending_modal = false  
local show_modal = false
local modal_message = ""

local function rgba_to_string(rgba)
  return string.format( "%d, %d, %d",(rgba >> 24) & 0xFF,(rgba >> 16) & 0xFF,(rgba >> 8) & 0xFF)
end

local function load_ini()
  local content = ""
  local file = io.open(ini_path, "r")

  if file then
    content = file:read("*all")
    file:close()
    content = content:gsub("%z", "")
  end

  local enabled_match = content:match("Enabled%s*=%s*(%d)")
  if enabled_match then
    is_enabled = (tonumber(enabled_match) == 1)
    pending_enabled = is_enabled
  end
  
  local sync_match = content:match("SyncThemeColors%s*=%s*(%d)")
  if sync_match then
    sync_theme_colors = (tonumber(sync_match) == 1)
    pending_sync_theme = sync_theme_colors
  end

  -- NEW: READ GLOBAL PIN
  local pin_match = content:match("GlobalPin%s*=%s*(%d)")
  if pin_match then
    global_pin = (tonumber(pin_match) == 1)
    pending_global_pin = global_pin
  end

  -- LOAD BACKUP DATA FROM INI
  local theme_match = content:match("OrigThemeName%s*=%s*([^\r\n]+)")
  if theme_match then orig_theme_name = theme_match end

  local bg_match = content:match("OrigColMainBg%s*=%s*(%-?%d+)")
  if bg_match then orig_col_main_bg = tonumber(bg_match) end

  local win_match = content:match("OrigWindowBg%s*=%s*(%-?%d+)")
  if win_match then orig_window_bg = tonumber(win_match) end
  
  local editbk_match = content:match("OrigEditBk%s*=%s*(%-?%d+)")
  if editbk_match then orig_col_main_editbk = tonumber(editbk_match) end
  
  local grid_match = content:match("OrigGridLines%s*=%s*(%-?%d+)")
  if grid_match then orig_col_listbg_grid = tonumber(grid_match) end
  
  local text_match = content:match("OrigMainText%s*=%s*(%-?%d+)")
  if text_match then orig_col_main_text = tonumber(text_match) end
  
  local unfocused_match = content:match("OrigUnfocusedBg%s*=%s*(%-?%d+)")
  if unfocused_match then orig_unfocused_bg = tonumber(unfocused_match) end
    
  for _, item in ipairs(settings) do
    local color_val = item.def
    local r, g, b = content:match(item.key .. "%s*=%s*(%d+)%s*,%s*(%d+)%s*,%s*(%d+)")
    if r and g and b then
      color_val = (tonumber(r) << 24) | (tonumber(g) << 16) | (tonumber(b) << 8) | 0xFF
    end
    item.color = color_val
    item.ini_color = color_val
  end
end

load_ini()
 
function loop()

  if is_enabled then
    push_dark_style()
  else
    push_light_style()
  end

  reaper.ImGui_PushStyleVar(
    ctx,
    reaper.ImGui_StyleVar_FrameRounding(),
    6.0
  )

  reaper.ImGui_PushStyleVar(ctx,reaper.ImGui_StyleVar_FrameBorderSize(),1.0)

  reaper.ImGui_SetNextWindowSize(ctx,485,495,reaper.ImGui_Cond_Always())

  local window_flags =
    reaper.ImGui_WindowFlags_NoResize() |
    reaper.ImGui_WindowFlags_NoCollapse()

  local visible, open =reaper.ImGui_Begin(ctx,'DarkMode Configurator',true,window_flags)

  if visible then

    if last_selected ~= selected_idx then
      temp_color = settings[selected_idx].color
      last_selected = selected_idx
    end

    reaper.ImGui_BeginChild(ctx, "left_pane", 235, 0, 1)

    if reaper.ImGui_CollapsingHeader(ctx, "Windows and Menus") then
      for _, i in ipairs({1, 13, 14, 15, 16}) do
        local item = settings[i]

        reaper.ImGui_ColorButton(ctx,"##c" .. item.key,item.color,0,12,12)

        reaper.ImGui_SameLine(ctx)

        if reaper.ImGui_Selectable(ctx,item.label,selected_idx == i) then
          selected_idx = i
        end
      end
    end

    if reaper.ImGui_CollapsingHeader(ctx, "Backgrounds and Borders") then
      for _, i in ipairs({19, 3, 2, 7, 8, 10, 4, 17, 18, 20, 21, 23}) do
        local item = settings[i]

        reaper.ImGui_ColorButton(ctx,"##c" .. item.key,item.color,0,12,12)

        reaper.ImGui_SameLine(ctx)

        if reaper.ImGui_Selectable(
          ctx,
          item.label,
          selected_idx == i
        ) then
          selected_idx = i
        end
      end
    end

    if reaper.ImGui_CollapsingHeader(ctx, "Text & Labels") then
      for _, i in ipairs({5, 6, 22, 12, 11, 9}) do
        local item = settings[i]

        reaper.ImGui_ColorButton(ctx,"##c" .. item.key,item.color,0,12,12)

        reaper.ImGui_SameLine(ctx)

        if reaper.ImGui_Selectable(ctx,item.label,selected_idx == i) then
          selected_idx = i
        end
      end
    end

    reaper.ImGui_EndChild(ctx)
    reaper.ImGui_SameLine(ctx)

    reaper.ImGui_BeginGroup(ctx)

    -- DARKMODE CHECKBOX ON/OFF
    local changed_en, new_en = reaper.ImGui_Checkbox(ctx, "Enable Dark Mode", pending_enabled)
    if changed_en then pending_enabled = new_en end
    
    -- SYNC THEME COLORS CHECKBOX
    local changed_sync, new_sync = reaper.ImGui_Checkbox(ctx, "Sync Theme Colors (*)", pending_sync_theme)
    if changed_sync then pending_sync_theme = new_sync end

    -- NEW: GLOBAL PIN CHECKBOX
    local changed_pin, new_pin = reaper.ImGui_Checkbox(ctx, "Auto-Pin Windows (except Mixer)", pending_global_pin)
    if changed_pin then pending_global_pin = new_pin end
    
    reaper.ImGui_Separator(ctx)
    reaper.ImGui_Spacing(ctx)

    local current = settings[selected_idx]

    reaper.ImGui_Text(
      ctx,
      "Editing: " .. current.label
    )

    reaper.ImGui_Separator(ctx)

    reaper.ImGui_Text(ctx, "Current:")
    reaper.ImGui_SameLine(ctx, 65)

    reaper.ImGui_ColorButton(ctx,"##old",current.color,0,35,18)
    reaper.ImGui_SameLine(ctx, 115)
    reaper.ImGui_Text(ctx, "New:")
    reaper.ImGui_SameLine(ctx, 155)
    reaper.ImGui_ColorButton(ctx,"##new",temp_color,0,35,18)

    reaper.ImGui_Spacing(ctx)

    reaper.ImGui_SetNextItemWidth(ctx, 225)

    local p_flags =
      reaper.ImGui_ColorEditFlags_NoSidePreview() |
      reaper.ImGui_ColorEditFlags_NoSmallPreview() |
      reaper.ImGui_ColorEditFlags_NoInputs() |
      reaper.ImGui_ColorEditFlags_NoLabel()

    local changed, new_temp =
      reaper.ImGui_ColorPicker4(ctx,"##picker",temp_color,p_flags)

    if changed then
      temp_color = new_temp
    end

    reaper.ImGui_Spacing(ctx)

    local r_c =(temp_color >> 24) & 0xFF
    local g_c =(temp_color >> 16) & 0xFF
    local b_c =(temp_color >> 8) & 0xFF

    reaper.ImGui_SetNextItemWidth(ctx, 69)
    local rv, r_n =
    reaper.ImGui_InputInt(ctx, "##r", r_c, 0, 0)
    reaper.ImGui_SameLine(ctx)
    reaper.ImGui_SetNextItemWidth(ctx, 69)
    local gv, g_n = reaper.ImGui_InputInt(ctx, "##g", g_c, 0, 0)

    reaper.ImGui_SameLine(ctx)
    reaper.ImGui_SetNextItemWidth(ctx, 69)
    local bv, b_n = reaper.ImGui_InputInt(ctx, "##b", b_c, 0, 0)

    if rv or gv or bv then
      temp_color =
        ((r_n or r_c) << 24) |
        ((g_n or g_c) << 16) |
        ((b_n or b_c) << 8) |
        0xFF
    end

    reaper.ImGui_Spacing(ctx)

    if reaper.ImGui_Button(ctx, 'APPLY', 69, 25) then
      settings[selected_idx].color = temp_color
    end

    reaper.ImGui_SameLine(ctx)

    if reaper.ImGui_Button(ctx, 'REVERT', 69, 25) then
      temp_color = settings[selected_idx].ini_color
      settings[selected_idx].color = settings[selected_idx].ini_color
    end

    reaper.ImGui_SameLine(ctx)

    if reaper.ImGui_Button(ctx, 'DEFAULT', 69, 25) then
      temp_color = settings[selected_idx].def
      settings[selected_idx].color = settings[selected_idx].def
    end

    reaper.ImGui_Separator(ctx)

    if reaper.ImGui_Button(ctx,'RESET ALL TO DEFAULTS',225,25) then
      for _, item in ipairs(settings) do
        item.color = item.def
      end

      temp_color = settings[selected_idx].def
    end

    if reaper.ImGui_Button(ctx, 'SAVE & APPLY CHANGES', 225, 25) then
          
          local current_theme = reaper.GetLastColorThemeFile()
    
          local currently_hijacking = (is_enabled and sync_theme_colors)
          local will_hijack = (pending_enabled and pending_sync_theme)
    
-- === THEME BACKUP & RESTORE LOGIC ===
          if will_hijack and not currently_hijacking then
            -- TRANSITION: NO SYNC -> SYNC (Take Backup)
            if orig_col_main_bg == -1 then
              orig_theme_name = current_theme
              orig_col_main_bg = reaper.GetThemeColor("col_main_bg", 0)
              orig_window_bg = reaper.GetThemeColor("window_bg", 0)
              orig_col_main_editbk = reaper.GetThemeColor("col_main_editbk", 0)
              orig_col_listbg_grid = reaper.GetThemeColor("genlist_grid", 0)
              orig_col_main_text = reaper.GetThemeColor("col_main_text", 0)
              orig_unfocused_bg = reaper.GetThemeColor("col_main_unselbk", 0)
            end
    
          elseif not will_hijack and currently_hijacking then
          
            -- TRANSITION: SYNC -> NO SYNC (Restore Original)
            if orig_col_main_bg ~= -1 then 
              reaper.SetThemeColor("col_main_bg", orig_col_main_bg, 0)
              reaper.SetThemeColor("window_bg", orig_window_bg, 0)
              reaper.SetThemeColor("col_main_editbk", orig_col_main_editbk, 0)
              
              -- Vedno preveri z ~= -1 pred klicem!
              if orig_col_listbg_grid ~= -1 then reaper.SetThemeColor("genlist_grid", orig_col_listbg_grid, 0) end
              if orig_col_main_text ~= -1 then reaper.SetThemeColor("col_main_text", orig_col_main_text, 0) end
              if orig_unfocused_bg ~= -1 then reaper.SetThemeColor("col_main_unselbk", orig_unfocused_bg, 0) end
              
              reaper.ThemeLayout_RefreshAll()
            end
            
            if orig_unfocused_bg ~= -1 then reaper.SetThemeColor("col_main_unselbk", orig_unfocused_bg, 0) end
            
            -- Full Reset backup variables
            orig_theme_name = "" 
            orig_col_main_bg = -1
            orig_window_bg = -1
            orig_col_main_editbk = -1
            orig_col_listbg_grid = -1
            orig_col_main_text = -1
            orig_unfocused_bg = -1
          end
          -- ====================================
    
          -- SAVE TO INI FILE
          local f = io.open(ini_path, "w")
          if f then
            f:write("[Settings]\n")
            f:write("Enabled=" ..(pending_enabled and "1" or "0") .."\n")
            f:write("SyncThemeColors=" ..(pending_sync_theme and "1" or "0") .."\n")
            f:write("GlobalPin=" ..(pending_global_pin and "1" or "0") .."\n") -- NEW: WRITE GLOBAL PIN
            
            -- Write backup data
            f:write("OrigThemeName=" .. orig_theme_name .. "\n")
            f:write("OrigColMainBg=" .. tostring(orig_col_main_bg) .. "\n")
            f:write("OrigWindowBg=" .. tostring(orig_window_bg) .. "\n")
            f:write("OrigEditBk=" .. tostring(orig_col_main_editbk) .. "\n")
            f:write("OrigGridLines=" .. tostring(orig_col_listbg_grid) .. "\n")
            f:write("OrigMainText=" .. tostring(orig_col_main_text) .. "\n\n") 
            f:write("OrigUnfocusedBg=" .. tostring(orig_unfocused_bg) .. "\n")
            f:write("[Colors]\n")
            for _, item in ipairs(settings) do
              f:write(item.key .."=" ..rgba_to_string(item.color) .."\n")
              item.ini_color = item.color
            end
            f:close()
          end
            
          -- === APPLY DARK MODE COLORS ===
          if will_hijack then
            local sync_color = nil
            local grid_color = nil
            local text_color = nil 
            
            for _, item in ipairs(settings) do
              if item.key == "ColorChild" then
                sync_color = item.color
              elseif item.key == "GridLinesColor" then
                grid_color = item.color
              elseif item.key == "ThemedWindowText" then
                text_color = item.color
              elseif item.key == "TreeUnfocusedSelectionBgColor" then
                 unfocused_color = item.color
              end
            end
            
            if sync_color then
              local r = (sync_color >> 24) & 0xFF
              local g = (sync_color >> 16) & 0xFF
              local b = (sync_color >> 8) & 0xFF
              local native_color = reaper.ColorToNative(r, g, b)
              
              reaper.SetThemeColor("col_main_bg", native_color, 0)
              reaper.SetThemeColor("window_bg", native_color, 0)
              reaper.SetThemeColor("col_main_editbk", native_color, 0)
            end
            
            if grid_color then
              local r = (grid_color >> 24) & 0xFF
              local g = (grid_color >> 16) & 0xFF
              local b = (grid_color >> 8) & 0xFF
              local native_grid = reaper.ColorToNative(r, g, b)
              reaper.SetThemeColor("genlist_grid", native_grid, 0)
            end

            if text_color then
              local r = (text_color >> 24) & 0xFF
              local g = (text_color >> 16) & 0xFF
              local b = (text_color >> 8) & 0xFF
              local native_text = reaper.ColorToNative(r, g, b)
              reaper.SetThemeColor("col_main_text", native_text, 0)
            end
            
            if unfocused_color then
              local r = (unfocused_color >> 24) & 0xFF
              local g = (unfocused_color >> 16) & 0xFF
              local b = (unfocused_color >> 8) & 0xFF
              reaper.SetThemeColor("col_main_unselbk", reaper.ColorToNative(r, g, b), 0)
            end
                
            reaper.ThemeLayout_RefreshAll()
          end
          -- =======================================
            
          is_enabled = pending_enabled
          sync_theme_colors = pending_sync_theme
          global_pin = pending_global_pin -- NEW
            
          reaper.SetExtState("RobDarkMode","Update","1",false)
          reaper.TrackList_UpdateAllExternalSurfaces()
            
          -- SET MODAL MESSAGE
          pending_modal = true
          if will_hijack then
            modal_message = "Changes will be applied!\nPlease make sure your Windows Personalization Colors are set to DARK!"
          else
            modal_message = "Changes will be applied!\nOriginal REAPER theme colors are active."
          end
        end

    reaper.ImGui_EndGroup(ctx)
  end

  -- pending - wait one frame before displaying
  if pending_modal then
    show_modal = true
    pending_modal = false
  end

  -- Non-blocking Dialog Window
if show_modal then
  reaper.ImGui_OpenPopup(ctx, "Settings Saved")
  reaper.ImGui_SetNextWindowSize(ctx, 470, 110, reaper.ImGui_Cond_Always())

  -- center popup to main window
  local main_pos_x, main_pos_y = reaper.ImGui_GetWindowPos(ctx)
  local main_w, main_h = reaper.ImGui_GetWindowSize(ctx)

  local popup_w, popup_h = 470, 110
  local center_x = main_pos_x + (main_w - popup_w) / 2
  local center_y = main_pos_y + (main_h - popup_h) / 2

  reaper.ImGui_SetNextWindowPos(ctx, center_x, center_y, reaper.ImGui_Cond_Always())

  show_modal = false
end

local modal_flags =
  reaper.ImGui_WindowFlags_NoResize() |
  reaper.ImGui_WindowFlags_NoCollapse()

if reaper.ImGui_BeginPopupModal(ctx, "Settings Saved", true, modal_flags) then
  reaper.ImGui_TextWrapped(ctx, modal_message)
  reaper.ImGui_Spacing(ctx)
  reaper.ImGui_Spacing(ctx)

  local button_width = 100
  local avail_width = reaper.ImGui_GetContentRegionAvail(ctx)
  local center_pos = (avail_width - button_width) / 2
  reaper.ImGui_SetCursorPosX(ctx, center_pos)

  if reaper.ImGui_Button(ctx, "OK##close_modal", button_width, 0) then
    reaper.ImGui_CloseCurrentPopup(ctx)
  end

  reaper.ImGui_EndPopup(ctx)
end

  reaper.ImGui_End(ctx)

  reaper.ImGui_PopStyleColor(ctx, 16)
  reaper.ImGui_PopStyleVar(ctx, 2)

  if open then
    reaper.defer(loop)
  end
end

reaper.defer(loop)