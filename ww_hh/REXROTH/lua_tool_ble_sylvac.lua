local drv = require(current_project.base_folder .. "\\ble_sylvac_driver")

lua_ble_sylvac = {
	type = 'BLE_SYLVAC', 	-- type identifier (as in INI file)
	channels = {},  		-- registered channels
}

lua_known_tool_types.add_type(lua_ble_sylvac)

-------------------------------------------------------------

function lua_ble_sylvac.registration(tool, ini_params)

	channel = lua_ble_sylvac.channels[tool]
	if channel ~= nil then
		return 'multiple tool definition'
	end
	
	-- check initialization parameters
	local cfg = {}

	-- csv file base path
    cfg.port = ini_params.BLE_PORT
	cfg.mac  = ini_params.BLE_MAC
	-- TODO: check, if all channels for this driver use the same cfg.port value!
	
	-- register channel
	lua_ble_sylvac.channels[tool] = {
		tool = tool,
		ini_params = CloneTable(ini_params),
		conn_state = lua_tool_connected,
		task_state = lua_task_idle,
		dll_state  = dll_tool_idle,
		conn_attr = {	-- for GUI/Alarms/JSON data output
			ip = cfg.port,
			port = cfg.mac,
		},
		cfg = CloneTable(cfg),
	}
	
	-- init driver instance
	drv.init(lua_ble_sylvac.channels[tool])
	
	return 'OK'
end

-------------------------------------------------------------
function lua_ble_sylvac.start(tool, prg)

	channel = lua_ble_sylvac.channels[tool]
	if channel == nil then
		channel.task_state = lua_task_not_ready
		return
	end
	
	local CfgValues = gui_lua_support.CfgValues
	if tool ~= CfgValues.Tool then
		channel.task_state = lua_task_not_ready
		return 
	end
	-- add the parameters to the channel object (TODO: that should be in the core)
	channel.CfgValues = CfgValues
	
	-- call driver
	drv.start(channel, prg)
end	
-------------------------------------------------------------
function lua_ble_sylvac.poll(tool, state)

	channel = lua_ble_sylvac.channels[tool]
	if channel == nil then
		channel.task_state = lua_task_not_ready
		return lua_task_not_ready
	end

	-- call driver
	drv.poll(channel)
	
	if channel.conn_state ~= lua_tool_connected then
		channel.task_state = lua_task_not_ready
		return lua_task_not_ready
	end

	channel.dll_state = state

	if (state == dll_tool_idle) 	or
  	   (state == dll_tool_disable)  or
	   (state == dll_tool_wait_release) then

		-- todo:: stop tool
		channel.task_state = lua_task_idle
		return lua_task_idle

	end

	if (state == dll_tool_enable) then

		if (channel.task_state  == lua_task_processing) or
		   (channel.task_state  == lua_task_completed)  then
		   return channel.task_state
		end

	end

	return channel.task_state
end

-----------------------------------------------------------------------------------
function lua_ble_sylvac.get_conn_attr(tool)

	channel = lua_ble_sylvac.channels[tool]
	if channel == nil then
		return lua_tool_reg_error
	end

	return channel.conn_attr, channel.conn_state

end
-----------------------------------------------------------------------------------


--=================================================================================================
--
--				API implementation for gui_support interface (gui_support.lua)
--
--=================================================================================================

------------------------------------------------
-- Get the tool specific measurement units for modbus <=> data mapping
-- @param tool: channel number as configured in station.ini
-- @output:  applicable only for the first two values (from 6)

function  lua_ble_sylvac.get_tool_units(tool)

	return 'mm',''

end
----------------------------------------------------------------------------------------------
-- process raw values from DLL
-- @param tool: channel number as configured in station.ini
-- @output: values ready to show and to save into database
function lua_ble_sylvac.process_tool_result(tool)
--[[
	local ResultValues = gui_lua_support.ResultValues
	if tool ~= ResultValues.Tool then
		return lua_tool_param_error
	end

	ResultValues.Param1 		= ResultValues.Param1
	ResultValues.Param1_min 	= ResultValues.Param1_min
	ResultValues.Param1_max 	= ResultValues.Param1_max
	ResultValues.Param2 		= ResultValues.Param2
	ResultValues.Param2_min 	= ResultValues.Param2_min
	ResultValues.Param2_max 	= ResultValues.Param2_max
	ResultValues.Step = '3A'
	return 1 --  processing completed
]]--
	return 0 --  no change in values
end
------------------------------------------------
-- Get the tool specific result string

function lua_ble_sylvac.get_tool_result_string(tool)

	local ResultValues = gui_lua_support.ResultValues
	if tool ~= ResultValues.Tool then
		return 'invalid tool'
	end
	local p1 = number_as_text(ResultValues.Param1, '---')
	--local p2 = number_as_text(ResultValues.Param2, '---')
	return string.format('%s mm', p1)
end
------------------------------------------------
-- Get the tool specific footer string
function lua_ble_sylvac.get_footer_string(tool)

	local CfgValues = gui_lua_support.CfgValues
	if tool ~= CfgValues.Tool then
		return 'invalid tool'
	end


	local result = 'lua_error'

	local p1 = tonumber(CfgValues.Param1_min)
	local p2 = tonumber(CfgValues.Param1_max)

	if (p1 ~= nil) and (p2 ~= nil) then
		result = string.format('Limits (mm) MAX=%.2f MIN=%.2f', p1, p2)
	end

	return result
end
------------------------------------------------
-- Get the tool specific program name
function lua_ble_sylvac.get_prg_string(tool)

	local CfgValues = gui_lua_support.CfgValues
	if tool ~= CfgValues.Tool then
		return 'invalid tool'
	end

	local result = 'lua_error'

	local p1 = tonumber(CfgValues.Prg)

	if (p1 ~= nil) then
		result = string.format('Prg %d', p1 )
	end

	return result
end

--=================================================================================================
--
--				API implementation for json/xml output (json_ftp.lua)
--
--=================================================================================================

-- process task attributes and results before using in json output
-- @input  tm: timestamp contains lua datetime structure
-- 		Param: see the list of available result parameters in "json_ftp.lua"
-- @output: file name to save
function lua_ble_sylvac.process_param_list(tm, Param)

	Param.job_name = string.sub(Param.job_name, 1, 30)
	local file = '' -- string.format('GUI_INP\\%04d%02d%02d%02d%02d%02d.json',tm.year,tm.month,tm.day,tm.hour,tm.min,tm.sec)
	return file    -- set empty to use default filename for FTP Client -> Sys3xxGateway -> Database
end

-----------------------------------------------------------------------------------------
-- return system_type and an array[6] of tag names
-- NOTE: system type is registered in the database [dbo.CellType]
--       see https://gogs.haller-erne.de/he/heOpGui/wiki/Data+output+format+-+Sys3xxGateway+custom+units 
function json_lua_output.default_get_tags(tool)
	return 3, {  'ML', 'ML-', 'ML+' }
end






