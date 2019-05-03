local mb = require(current_project.base_folder .. "\\mbcli_driver")

lua_modbus_client = {
	type = 'MODBUS_CLIENT', -- type identifier (as in INI file)
	channels = {},  	-- registered channels
}

lua_known_tool_types.add_type(lua_modbus_client)

-------------------------------------------------------------

function lua_modbus_client.registration(tool, ini_params)

	channel = lua_modbus_client.channels[tool]
	if channel ~= nil then
		return 'multiple tool definition'
	end
	
	-- check initialization parameters

	local cfg = {}

	-- csv file base path
    cfg.csvBasePath = ini_params.CSV_BASE_PATH

	-- Modbus init
	cfg.initMBAdr = tonumber(ini_params.INIT_REG_ADDR) --(nil/0 = do not initialize)
    cfg.initMBVal = tonumber(ini_params.INIT_REG_VAL)
    --   ID code transfer
    cfg.ioMBIDAdr = tonumber(ini_params.IDCODE_REG_ADDR)
    cfg.ioMBIDLen = tonumber(ini_params.IDCODE_REG_LENGTH) --(64 words, 128 bytes)
    --   Program number
    cfg.ioMBPrgAdr = tonumber(ini_params.PROGRAM_REG_ADDR)
    --   cyclic IO / control register
    cfg.ioMBCtlAdr = tonumber(ini_params.CONTROL_REG_ADDR)
    -- Modbus inputs
    --   cyclic IO / status register
    cfg.ioMBStaAdr = tonumber(ini_params.STATUS_REG_ADDR)
    --   Result
    cfg.ioMBResAdr = tonumber(ini_params.RESULT_REG_ADDR)
    cfg.ioMBResLen = tonumber(ini_params.RESULT_REG_LENGTH) --(length in Words)

		
	cfg.CONN_ADDR=ini_params.CONN_ADDR			--10.10.2.14
	cfg.CONN_PORT= 502
	if ini_params.CONN_PORT ~= nil then
		cfg.CONN_PORT=tonumber(ini_params.CONN_PORT) --502
	end	
	
	-- register channel

	lua_modbus_client.channels[tool] = {
		tool = tool,
		ini_params = CloneTable(ini_params),
		conn_state = lua_tool_connected,
		task_state = lua_task_idle,
		dll_state  = dll_tool_idle,
		conn_attr = {	-- for GUI/Alarms/JSON data output
			ip = cfg.CONN_ADDR,
			port = cfg.CONN_PORT,
		},
		cfg = CloneTable(cfg),
	}
	
	-- init driver instance
	mb.init(lua_modbus_client.channels[tool])
	
	return 'OK'
end

-------------------------------------------------------------
function lua_modbus_client.start(tool, prg)

	channel = lua_modbus_client.channels[tool]
	if channel == nil then
		channel.task_state = lua_task_not_ready
		return
	end

	-- call driver
	mb.start(channel, prg)
end	
-------------------------------------------------------------
function lua_modbus_client.poll(tool, state)

	channel = lua_modbus_client.channels[tool]
	if channel == nil then
		channel.task_state = lua_task_not_ready
		return lua_task_not_ready
	end

	-- call driver
	mb.poll(channel)
	
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
function lua_modbus_client.get_conn_attr(tool)

	channel = lua_modbus_client.channels[tool]
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

function  lua_modbus_client.get_tool_units(tool)

	return 'Pa','Grad'

end
----------------------------------------------------------------------------------------------
-- process raw values from DLL
-- @param tool: channel number as configured in station.ini
-- @output: values ready to show and to save into database

function lua_modbus_client.process_tool_result(tool)

	local ResultValues = gui_lua_support.ResultValues
	if tool ~= ResultValues.Tool then
		return lua_tool_param_error
	end

	ResultValues.Param1 		  = ResultValues.Param1
	ResultValues.Param1_min 	= ResultValues.Param1_min
	ResultValues.Param1_max 	= ResultValues.Param1_max
	ResultValues.Param2 		  = ResultValues.Param2
	ResultValues.Param2_min 	= ResultValues.Param2_min
	ResultValues.Param2_max 	= ResultValues.Param2_max
	
	ResultValues.Step = '3A'
	return 1 --  processing completed
	--return 0 --  use raw values without preprocessing

end
------------------------------------------------
-- Get the tool specific result string

function lua_modbus_client.get_tool_result_string(tool)

	local ResultValues = gui_lua_support.ResultValues
	if tool ~= ResultValues.Tool then
		return 'invalid tool'
	end
	local p1 = number_as_text(ResultValues.Param1, '---')
	local p2 = number_as_text(ResultValues.Param2, '---')
	return string.format('%s Pa %s Grad', p1, p2)
end
------------------------------------------------
-- Get the tool specific footer string

function lua_modbus_client.get_footer_string(tool)

	local CfgValues = gui_lua_support.CfgValues
	if tool ~= CfgValues.Tool then
		return 'invalid tool'
	end


	local result = 'lua_error'

	local p1 = tonumber(CfgValues.Param1_min)
	local p2 = tonumber(CfgValues.Param1_max)

	if (p1 ~= nil) and (p2 ~= nil) then
		result = string.format('Pressure (Pa) MAX=%.2f MIN=%.2f', p1, p2)
	end

	return result
end
------------------------------------------------
-- Get the tool specific program name

function lua_modbus_client.get_prg_string(tool)

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
function lua_modbus_client.process_param_list(tm, Param)

	Param.job_name = string.sub(Param.job_name, 1, 30)
	local file = '' -- string.format('GUI_INP\\%04d%02d%02d%02d%02d%02d.json',tm.year,tm.month,tm.day,tm.hour,tm.min,tm.sec)
	return file    -- set empty to use default filename for FTP Client -> Sys3xxGateway -> Database
end
-----------------------------------------------------------------------------------------------
--  See in "json_ftp.lua" the list of parameters available for use in JSONFmt format string:
-----------------------------------------------------------------------------------------------
lua_modbus_client.JsonFmt = "{"
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
		..'					"name":	"Kraft",\n'  	-- function name
		..'					"act":	$!value1!$\n'   -- actual value
		..'				},\n'
					-- function 2
		..'				{\n'
		..'					"name":	"Temp",\n'  	-- function name
		..'					"act":	$!value2!$\n'   -- actual value
		..'				},\n'
					-- function 3
		..'				{\n'
		..'					"name":	"P3",\n'  		-- function name
		..'					"act":	$!value3!$\n'   -- actual value
		..'				},\n'
					-- function 4
		..'				{\n'
		..'					"name":	"P4",\n'  		-- function name
		..'					"act":	$!value4!$\n'   -- actual value
		..'				},\n'
					-- function 5
		..'				{\n'
		..'					"name":	"P5",\n'  		-- function name
		..'					"act":	$!value5!$\n'   -- actual value
		..'				},\n'
					-- function 6
		..'				{\n'
		..'					"name":	"P6",\n'  		-- function name
		..'					"act":	$!value6!$\n'   -- actual value
		..'				}\n'

		..'			]\n'-- end of functions
		..'		}\n'-- end of tightening step 2A
		..'	]\n'	-- end of tightening steps
		..'}'		-- end of text
----------------------------------------------------------------------------------------------------





