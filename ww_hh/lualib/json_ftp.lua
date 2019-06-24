--[[

this lua code contains functions and structures to support data output in text (JSON/XML) format
 in case of custom defined tool/result data

---------------------------------------------------------------------------------------
--
--   C++ API
--
--  LUA_GetJSON(tool, tool_type, station, part_seq,bolt_seq)
--
--
----------------------------------------------------------------------------------------

 - tool specific implementations

	1. process_param_list(tool)

- tool specific json format string:

	1. JsonFmt

 Each tool type, that needs custom specific data output,
 has to register its own function implementations using method:

	lua_known_tool_types.add_type(...)

internal structures:

	result 	= {}     -- contains all available actual result values and parameters listed by name
	mb 		= {}     -- contains all available actual result values and parameters by index

]]
---------------------------------------------------------------------------------------------------
--common JSON output support object:

json_lua_output = {
	result 	= {},     -- array by names,  containing all available result values and parameters
	mb 		= {},     -- indexed array,   containing all available result values and parameters

	compiled_fmt_array = {},  -- for each type: compiled format string  (param names are replaced with '%s')
	name_list_array    = {},  -- for each type: list of parameters extracted from JsonFmt string
}


function _as_str(n) return param_as_str(json_lua_output.mb[n]) end

function json_lua_output.create_json_file(fmt)
	return string.format(fmt,
			_as_str( 1),_as_str( 2),_as_str( 3),_as_str( 4),_as_str( 5),_as_str( 6),_as_str( 7),_as_str( 8),_as_str( 9),_as_str(10),
			_as_str(11),_as_str(12),_as_str(13),_as_str(14),_as_str(15),_as_str(16),_as_str(17),_as_str(18),_as_str(19),_as_str(20),
			_as_str(21),_as_str(22),_as_str(23),_as_str(24),_as_str(25),_as_str(26),_as_str(27),_as_str(28),_as_str(29),_as_str(30),
			_as_str(31),_as_str(32),_as_str(33),_as_str(34),_as_str(35),_as_str(36),_as_str(37),_as_str(38),_as_str(39),_as_str(40),
			_as_str(41),_as_str(42),_as_str(43),_as_str(44),_as_str(45),_as_str(46),_as_str(47),_as_str(48),_as_str(49),_as_str(50))
end

---------------------------------------------------------------------------------------------------
function json_lua_output.compile_format_string(list, str)

local cnt = 0;
local new_str = '';
local pattern = '$!'
local pos_beg = 0
local pos_end = 1
local pos_rep = 1


	while (pos_beg ~= nil and pos_end ~= nil)
	do	if  pos_beg < pos_end
			then
				if pos_end  - pos_beg > 2  then
					cnt = cnt + 1
					list[cnt] = string.sub(str, pos_beg + 2, pos_end -1)
					new_str = new_str .. string.sub(str, pos_rep, pos_beg -1) ..'%s'
					pos_rep = pos_end + 2
				end
				pos_beg = string.find(str, '$!',pos_end, true)
			else pos_end = string.find(str, '!$',pos_beg, true)
		end
	end
	if pos_rep > 0 then
		new_str = new_str .. string.sub(str, pos_rep, -1)
	end

	return new_str, cnt

end
------------------------------------------------------------------------------------------
--[[
	List of parameters available for use in JsonFmt format string:

		$!station_name!$	-	station name
		$!ip!$ 				-	ip address
		$!time!$ 			-	time stamp
		$!worker!$ 			-	worker
		$!job_name!$ 	 	-	part/job name
		$!bolt_name!$ 	 	-	bolt name
		$!tool_name!$ 	 	-	tool name
		$!tool_sn!$			-	tool serial number
		$!operation!$		-   operation name
		$!status!$ 	 		-   status (OK/NOK)
		$!qc!$ 		 		- 	quality code
		$!seq!$				-   tool result sequence
		$!rack!$			-   rack (necessary for Sys3xxGateway/Database)
		$!slot!$			-   slot (necessary for Sys3xxGateway/Database)
		$!barcode!$			-   action barcode (can be from previous task step if previous tool was BARCODE_READER)
		$!prg!$ 		 	-	program number

		$!value1!$ 	 		- 	measurement value 1
		$!value2!$ 	 		- 	measurement value 2
		$!value3!$ 	 		- 	measurement value 3
		$!value4!$ 	 		- 	measurement value 4
		$!value5!$ 	 		- 	measurement value 5
		$!value6!$ 	 		- 	measurement value 6

		$!system_type!$     -   system type ( 0 - unknown, 1 - Bosch Rexroth System, ...)


WARNING!!! 	Don't use format specifiers % in format string. If necessary use %% instead.
			Use a quote ' only to open and close a string but not within a string.


	All parameters are defined in 'lualib/mblib' file , in function "MBGetParamList"
	If  some parameters need a preprocessing please redefine function ProcessParamList(Params) below

]]
-------------------------------------
function json_lua_output.get_by_names_array(tool, t, st_res, part_res,bolt_res)


	local rack = 0
	local slot = 1
	if (tool < 128 and tool > 1) then
		rack = math.floor ((tool-1)/6)
		slot = math.floor((tool-1)%6+1)
	end

	json_lua_output.result.system_type  = 0      -- 0 = unknown, 1 = Bosch Tightening system
	json_lua_output.result.station_name = st_res.name
	json_lua_output.result.ip 			= st_res.host
	json_lua_output.result.time 		= string.format('%04d-%02d-%02d %02d:%02d:%02d',t.year,t.month,t.day,t.hour,t.min,t.sec)
	json_lua_output.result.id			= st_res.info
	json_lua_output.result.worker 		= st_res.worker
	--	st_res.master = master
	json_lua_output.result.job_name 	= part_res.name

	json_lua_output.result.bolt_name 	= bolt_res.name
	json_lua_output.result.tool_name 	= bolt_res.tool
	json_lua_output.result.tool_sn		= bolt_res.tool_sn
	json_lua_output.result.prg 			= bolt_res.prg
	json_lua_output.result.operation  	= bolt_res.operation
	json_lua_output.result.rack 		= rack
	json_lua_output.result.slot 		= slot
	json_lua_output.result.barcode 		= bolt_res.barcode

	json_lua_output.result.value 		= {}
	json_lua_output.result.value1 		= bolt_res.torque
	json_lua_output.result.value2 		= bolt_res.angle
	json_lua_output.result.value3 		= bolt_res.torque_min
	json_lua_output.result.value4 		= bolt_res.torque_max
	json_lua_output.result.value5 		= bolt_res.angle_min
	json_lua_output.result.value6 		= bolt_res.angle_max

	json_lua_output.result.status 		= bolt_res.result
	json_lua_output.result.qc 			= bolt_res.qc
	json_lua_output.result.seq			= bolt_res.seq


end
--------------------------------------------------------------------------------------------
function json_lua_output.get_indexed_array(name_list)

	for i = 1,50,1 do json_lua_output.mb[i] = nil end
	for k,v in pairs(name_list) do json_lua_output.mb[k] = json_lua_output.result[v] end
end
---------------------------------------------------------------------------------------------
function LUA_GetJSON(tool, station, part_seq,bolt_seq)

	local tool_type = lua_known_tool_types.get_tool_type(tool)
	if tool_type == nil then
		return nil,nil		-- invalid tool type
	end

	local process_param_list =lua_known_tool_types.get_impl(tool_type,'process_param_list')
	if type(process_param_list) ~= 'function' then
			return nil,nil		-- invalid tool type
	end

	local get_tags =lua_known_tool_types.get_impl(tool_type,'get_tags')
	if type(get_tags) ~= 'function' then
		get_tags = json_lua_output.default_get_tags
	end

	local type_impl = lua_known_tool_types[tool_type]


	local JsonFmt = type_impl['JsonFmt']
	if type(JsonFmt) ~= 'string' or #JsonFmt == 0 then
		XTRACE(1, "invalid JSON format string tool=" ..tostring(tool)  )
		return nil,nil		-- invalid format string
	end

	local compiled_fmt 	= json_lua_output.compiled_fmt_array[tool_type]
	local name_list 	= json_lua_output.name_list_array[tool_type]

	if compiled_fmt == nil or name_list == nil then
		name_list = {}
		compiled_fmt = json_lua_output.compile_format_string(name_list, JsonFmt)
		json_lua_output.compiled_fmt_array[tool_type]	= compiled_fmt
		json_lua_output.name_list_array[tool_type] 		= name_list

	end

	local st_res = station_results[station]
	if st_res == nil then return nil,nil end
	local part_res = st_res.parts[part_seq]
	if part_res == nil then return nil,nil end
	local bolt_res = part_res.bolts[bolt_seq]
	if bolt_res == nil then return nil,nil end
	local t = os.date('*t') --	st_res.time

	json_lua_output.get_by_names_array(tool, t, st_res, part_res,bolt_res)
	json_lua_output.fill_tag_table(get_tags(tool))

	local file = process_param_list(t, json_lua_output.result)

	json_lua_output.get_indexed_array(name_list)

	local json = json_lua_output.create_json_file(compiled_fmt)

return json , file

end

------------------------------------------------------------------------------------------
function json_lua_output.fill_tag_table(system_type, tags)

	json_lua_output.result.system_type = system_type
	for i = 1,6,1 do
		if valid_str(tags[i]) then
			json_lua_output.result['tag'..i] = param_as_str(tags[i])
		else
			json_lua_output.result['tag'..i] = 'Tag '..i
		end
	end

end

-----------------------------------------------------------------------------------------
-- return system_type and an array[6] of tag names
function json_lua_output.default_get_tags(tool)

	return 0 , {  'Tag 1', 'Tag 2', 'Tag 3', 'Tag 4', 'Tag 5', 'Tag 6' }

end

------------------------------------------------------------------------------------------
json_lua_output.default_JsonFmt = "{"
			-- header
		..'	"format":	"channel",\n'
		..'	"ip0":	"$!ip!$",\n'        -- IP address
		..'	"node id":	"$!rack!$.$!slot!$",\n'   --  Rack/Slot
		..'	"result":	"$!status!$",\n'        	-- OK/NOK
		..'	"location name":	["$!system_type!$", "Line 1", "$!station_name!$", "default", "", "", ""],\n'
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
		..'					"name":	"$!tag1!$",\n' 	-- function name
		..'					"act":	$!value1!$\n'   	-- actual value
		..'				},\n'
					-- function 2
		..'				{\n'
		..'					"name":	"$!tag2!$",\n' 	-- function name
		..'					"act":	$!value2!$\n'   	-- actual value
		..'				},\n'
					-- function 3
		..'				{\n'
		..'					"name":	"$!tag3!$",\n' 	-- function name
		..'					"act":	$!value3!$\n'   	-- actual value
		..'				},\n'
					-- function 4
		..'				{\n'
		..'					"name":	"$!tag4!$",\n'	-- function name
		..'					"act":	$!value4!$\n'   	-- actual value
		..'				},\n'
					-- function 5
		..'				{\n'
		..'					"name":	"$!tag5!$",\n'	-- function name
		..'					"act":	$!value5!$\n'   	-- actual value
		..'				},\n'
					-- function 6
		..'				{\n'
		..'					"name":	"$!tag6!$",\n' 	-- function name
		..'					"act":	$!value6!$\n'   	-- actual value
		..'				}\n'

		..'			]\n'-- end of functions
		..'		}\n'-- end of tightening step 2A
		..'	]\n'	-- end of tightening steps
		..'}'		-- end of text
----------------------------------------------------------------------------------------------------

