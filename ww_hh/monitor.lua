XTRACE(16, "Loading monitor.lua...", "monitor.lua", 1)

-- Global objects
require('lualib/system')		-- lualib/system.lua

-- Initialize custom project
local ogs = require("lualib/ogs")
ogs.Initialize('REXROTH') 


