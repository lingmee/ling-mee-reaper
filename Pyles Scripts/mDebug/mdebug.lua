package.cpath = package.cpath .. ";" .. reaper.GetResourcePath() ..'/Scripts/Classes Mobdebug/socket module/?.dll'    -- WINDOWS ONLY: Add socket module path for .dll files
package.path = package.path .. ";" .. reaper.GetResourcePath()   ..'/Scripts/Classes Mobdebug/socket module/?.lua'      -- Add all lua socket modules to the path  

require("mobdebug").start() -- Start mobdebug module