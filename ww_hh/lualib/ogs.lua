--- @module lualib.ogs
--- Provide a global "class" (module-table) with functions used throughout OGS.
--- Make this "luaisch" (see https://github.com/luarocks/lua-style-guide)
---
--- Usage:
---
---    local ogs = require("lualib.ogs")
---

current_project =  {}

local ogs = {}

-- User configuration table should be configured in "config.lua" file in custom folder (function parameter: base_folder)
-- The configuration table is expected in the following format:
--     requires = {
--					"barcode",
--					"user_manager",
--					"SignalR"
--				}
--
--------------------------------------------------------------------------------------------------

function ogs.Initialize(base_folder)

	XTRACE(16, "Initialize custom project: '".. base_folder .. "'", "ogs.lua", 1)

	current_project.base_folder = base_folder

	-- load custom configuration
	require(base_folder .. "\\config")


end

--------------------------------------------------------------------------------------------------
function OnInitComplete()

-- 	Add new tool/system drivers for OGS
require('lualib/lua_tool')
require('lualib/json_ftp')
require('lualib/gui_support')

-- 	Add base classes for OGS
require('lualib/barcode_base')
require('lualib/user_manager_base')


	-- load others...using config.lua (new)
	for k,r in ipairs(requires) do require(current_project.base_folder ..'\\'.. r) end


	-- load others...using monitor.lua (old)
	for req , lua_file in pairs(current_project) do  -- load all lua files
		if 'require' == string.sub(req,1 ,7)  then
			require(lua_file)
		end
	end
end

-- override globals:
-- hack require to log loaded lua modules
local r_old = require
local r_new = function(x)
	local s2 = debug.getinfo(2, "nSl")
	local file = s2.short_src
	XTRACE(16, "require '" .. x .. "'", file, s2.currentline)
    return r_old(x)
end
require = r_new

-- Return "this" module-table
return ogs
