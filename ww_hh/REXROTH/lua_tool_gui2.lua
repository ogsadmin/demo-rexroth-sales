
gui_lua_tool2 = {
	type = 'GUI_INP2', 	-- type identifier (as in INI file)
	channels = {},  	-- registered channels
}

lua_known_tool_types.add_type(gui_lua_tool2)

gui_lua_tool2.gui_params = {

	{ name = 'Param 1 m2:',	 	type = 'float',	default = '250',min =   '0', 	max = ''	},
	{ name = 'Param 2 °C:' , 	type = 'float', default = '0',	min ='-2000', 	max = '2000'},
	{ name = 'Param 3 deg:' ,	type = 'int', 	default = '0', 	min = '0.0', 	max = ''	},
	{ name = 'Speed Km/h:',	 	type = 'int',   default = '0', 	min =   '0', 	max = '' 	},
	{ name = 'Resistence Om:', 	type = 'float',	default ='300',	min = '0.0', 	max = ''	},
	{ name = 'Height sm.:',		type = 'float', default = '0', 	min = '0.0', 	max = '2000'},
}

-------------------------------------------------------------

function gui_lua_tool2.registration(tool, ini_params)

	channel = gui_lua_tool2.channels[tool]
	if channel ~= nil then
		return 'multiple tool definition'
	end

	-- check initialization parameters

		-- TODO:: ini_params

	-- register channel

	gui_lua_tool2.channels[tool] = {
		tool = tool,
		ini_params = CloneTable(ini_params),
		conn_state = lua_tool_connected,
		task_state = lua_task_idle,
		dll_state  = dll_tool_idle,
		conn_attr = {
			ip = ini_params.IP,
			port = ini_params.PORT,
		},
	}
	return 'OK'
end

-------------------------------------------------------------
function gui_lua_tool2.poll(tool, state)

	channel = gui_lua_tool2.channels[tool]
	if channel == nil then
		channel.task_state = lua_task_not_ready
		return lua_task_not_ready
	end

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

	    channel.task_state = lua_task_processing

		local res = ShowLuaToolGUI(tool, gui_lua_tool2.type, gui_lua_tool2.gui_params)
		if res <= 0 then
			channel.task_state = lua_task_not_ready
			local tmp = string.format('lua_tool_request: %d %s  error code: %d', tool, gui_lua_tool2.type, res)
			XTRACE(16, tmp)
		end
	end

	return channel.task_state
end

-----------------------------------------------------------------------------------
function gui_lua_tool2.get_conn_attr(tool)

	channel = gui_lua_tool2.channels[tool]
	if channel == nil then
		return lua_tool_reg_error
	end
	return channel.conn_attr, channel.conn_state

end
-----------------------------------------------------------------------------------

function gui_lua_tool2.save_results(tool, values)

	channel = gui_lua_tool2.channels[tool]
	if channel == nil then
		XTRACE(16, 'Tool '.. param_as_str(tool)..' is not registered')
		return lua_tool_reg_error
	end

	channel.task_state = lua_task_completed

	error_code = 0 -- OK
	seq = 0
	step = 'A2'
	status = lua_tool_result_response(tool, error_code, seq, step, values)

	if status == 0 then
		XTRACE(16, tool..' '..param_as_str(tool)..' is not active')
	else  if status < 0 then
			XTRACE(16, string.format('tool [%d] invalid parameter set (error=%d)', tool, status))
		  end
	end
	return 0
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

function  gui_lua_tool2.get_tool_units(tool)

	return 'm2','°C'

end
----------------------------------------------------------------------------------------------
-- process raw values from DLL
-- @param tool: channel number as configured in station.ini
-- @output: values ready to show and to save into database

function gui_lua_tool2.process_tool_result(tool)

	local ResultValues = gui_lua_support.ResultValues
	if tool ~= ResultValues.Tool then
		return lua_tool_param_error
	end

	ResultValues.Step = '3A'
	return 1 --  processing completed
	--return 0 --  use raw values without preprocessing

end
------------------------------------------------
-- Get the tool specific result string

function gui_lua_tool2.get_tool_result_string(tool)

	local ResultValues = gui_lua_support.ResultValues
	if tool ~= ResultValues.Tool then
		return 'invalid tool'
	end
	local p1 = number_as_text(ResultValues.Param1, '---')
	local p2 = number_as_text(ResultValues.Param2, '---')
	return string.format('%s m2 %s °C', p1, p2)
end
------------------------------------------------
-- Get the tool specific footer string

function gui_lua_tool2.get_footer_string(tool)

	local CfgValues = gui_lua_support.CfgValues
	if tool ~= CfgValues.Tool then
		return 'invalid tool'
	end


	local result = 'lua_error'

	local p1 = tonumber(CfgValues.Param1_min)
	local p2 = tonumber(CfgValues.Param1_max)

	if (p1 ~= nil) and (p2 ~= nil) then
		result = string.format('Param 1 (m2) MAX=%.2f MIN=%.2f', p1, p2)
	end

	return result
end
------------------------------------------------
-- Get the tool specific program name

function gui_lua_tool2.get_prg_string(tool)

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
function gui_lua_tool2.process_param_list(tm, Param)

	Param.job_name = string.sub(Param.job_name, 1, 30)
	local file = '' -- string.format('GUI_INP\\%04d%02d%02d%02d%02d%02d.json',tm.year,tm.month,tm.day,tm.hour,tm.min,tm.sec)
	return file    -- set empty to use default filename for FTP Client -> Sys3xxGateway -> Database
end
-----------------------------------------------------------------------------------------------
--  See in "json_ftp.lua" the list of parameters available for use in JSONFmt format string:
-----------------------------------------------------------------------------------------------
gui_lua_tool2.JsonFmt = "{"
			-- header
		..'	"format":	"channel",\n'
		..'	"ip0":	"$!ip!$",\n'        -- IP address
		..'	"node id":	"$!rack!$.$!slot!$",\n'   --  Rack/Slot
		..'	"result":	"$!status!$",\n'        	-- OK/NOK
		..'	"location name":	["Engine", "Line 1", "$!station_name!$", "default", "", "", ""],\n'
		..'	"channel":	"$!tool_name!$",\n'      -- channnel name
		..'	"prg nr":	$!prg!$,\n'              -- program number
		..'	"prg name":	"$!operation!$",\n'      -- program name
		..'	"SST":	"$!bolt_name!$",\n'      	-- bolt name
		..'	"cycle":	$!seq!$,\n'              --
		..'	"date":	"$!time!$",\n'  		-- 2017-01-11 10:59:19
		..'	"id code":	"$!id!$",\n'      -- ID code
		..'	"tool serial":	$!tool_sn!$,\n'     	-- tool serial number   (interger)
			-- steps
		..'	"tightening steps":	[{\n'
		..'			"row":	"2",\n'            		-- row integer
		..'			"column":	"A",\n'        		-- column
		..'			"name":	"step",\n'        		-- step name
		..'			"quality code":	"$!qc!$",\n'
		..'			"category":	0,\n'
		..'			"docu buffer":	1,\n'
		..'			"result":	"$!status!$",\n'        -- OK/NOK
				-- functions
		..'			"tightening functions":	[\n'
					-- function 1
		..'				{\n'
		..'					"name":	"Param1",\n'  	-- function name
		..'					"act":	$!value1!$\n'   -- actual value
		..'				},\n'
					-- function 2
		..'				{\n'
		..'					"name":	"Param2",\n'  	-- function name
		..'					"act":	$!value2!$\n'   -- actual value
		..'				},\n'
					-- function 3
		..'				{\n'
		..'					"name":	"Param3",\n'  		-- function name
		..'					"act":	$!value3!$\n'   -- actual value
		..'				},\n'
					-- function 4
		..'				{\n'
		..'					"name":	"Param4",\n'  		-- function name
		..'					"act":	$!value4!$\n'   -- actual value
		..'				},\n'
					-- function 5
		..'				{\n'
		..'					"name":	"Param5",\n'  		-- function name
		..'					"act":	$!value5!$\n'   -- actual value
		..'				},\n'
					-- function 6
		..'				{\n'
		..'					"name":	"Param6",\n'  		-- function name
		..'					"act":	$!value6!$\n'   -- actual value
		..'				}\n'

		..'			]\n'-- end of functions
		..'		}\n'-- end of tightening step 2A
		..'	]\n'	-- end of tightening steps
		..'}'		-- end of text
----------------------------------------------------------------------------------------------------





