

modbus_tool = {
	type = 'MODBUS', 	-- type identifier (as in INI file)
}

lua_known_tool_types.add_type(modbus_tool)

------------------------------------------------
-- Get the tool specific measurement units for modbus <=> data mapping
-- @param tool: channel number as configured in station.ini
-- @output:  applicable only for the first two values (from 6)

function modbus_tool.get_tool_units(tool)

	return 'Pa','°C'

end
----------------------------------------------------------------------------------------------
-- process raw values from DLL
-- @param tool: channel number as configured in station.ini
-- @output: values ready to show and to save into database

function modbus_tool.process_tool_result(tool)

	local ResultValues = gui_lua_support.ResultValues
	if tool ~= ResultValues.Tool then
		return nil
	end

	local CfgValues = gui_lua_support.CfgValues
	if tool ~= CfgValues.Tool then
		return nil
	end

	--   scale raw result values

	ResultValues.Param1 		= ResultValues.Param1/100
	ResultValues.Param1_min 	= ResultValues.Param1_min/100
	ResultValues.Param1_max 	= ResultValues.Param1_max/100
	ResultValues.Param2 		= ResultValues.Param2/10
	ResultValues.Param2_min 	= ResultValues.Param2_min/10
	ResultValues.Param2_max 	= ResultValues.Param2_max/10
	--ResultValues.Prg 			=
	--ResultValues.Tool 		=
	ResultValues.Seq 			= 0
	ResultValues.Step 			= 'A1'

	-- Check actual result against limits

	local qc = 0 -- OK
	local check_val = ResultValues.Param1

	local p1 = tonumber(CfgValues.Param1_min)
	local p2 = tonumber(CfgValues.Param1_max)

	if (p1 ~= nil) and (p2 ~= nil) and (check_val ~= nil) and (p1 < p2) then
		if check_val < p1 then qc = 2 end -- too small
		if check_val > p2 then qc = 8 end -- too big
	end

	ResultValues.QC = result

	return ResultValues
end



------------------------------------------------
-- Get the tool specific result string

function modbus_tool.get_tool_result_string(tool)

	local ResultValues = gui_lua_support.ResultValues
	if tool ~= ResultValues.Tool then
		return 'invalid tool'
	end

	local result = 'lua_error'

	local p1 = tonumber(ResultValues.Param1)
	local p2 = tonumber(ResultValues.Param2)

	if (p1 ~= nil) and (p2 ~= nil) then
		result = string.format('%.2f Pa %.2f °C', p1, p2)
	end

	return result
end
------------------------------------------------
-- Get the tool specific footer string

function modbus_tool.get_footer_string(tool)

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

function modbus_tool.get_prg_string(tool)

	local CfgValues = gui_lua_support.CfgValues
	if tool ~= CfgValues.tool then
		return 'invalid tool'
	end

	local result = 'lua_error'

	local p1 = tonumber(CfgValues.Prg)

	if (p1 ~= nil) then
		result = string.format('Prg %02d', p1 )
	end

	return result
end

------------------------------------------------
-- process task attributes and results before using in json output

function modbus_tool.process_param_list(tm, Param)

	-- tm:	  contains lua datetime structure
	-- Param: see the list of available parameters in "json_ftp.lua"
	-- return value:  file  - file name 
	local file = '' -- if empty, will be created a default name for FTP transfer
	return file

end

-----------------------------------------------------------------------------------------------
--  See in "json_ftp.lua" the list of parameters available for use in JSONFmt format string:
-----------------------------------------------------------------------------------------------

modbus_tool.JsonFmt = "{"
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







