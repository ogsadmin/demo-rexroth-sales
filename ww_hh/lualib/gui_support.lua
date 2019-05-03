
--[[

this lua code contains functions and structures to support user interface
 in case of custom defined tool/result data

 functions:
	1.	process_tool_result(tool, tool_type)
	2.  get_tool_result_string(tool, tool_type)
	3.  get_footer_string(tool, tool_type)
	4.  get_prg_string(tool,tool_type)
	4.  get_tool_units(tool,tool_type)

 Each tool type, that needs custom specific data presentation in monitor GUI,
 has to register its own function implementations using method:

	register_gui_support(tool_type, ....)

structures:

	CfgValues = {}  	- contains pre configured limits and targets (in heOpCfg.exe).
						  c++ code fills out this structure before tool start

	ResultValues = {}   contains actual task results.
						c++ code fills out this structure after tool start.

]]
---------------------------------------------------------------------------------------------------
--common GUI Lua support object:

gui_lua_support = {

	CfgValues = {
		Param1_target = 0.0,
		Param1_min 	= 0.0,
		Param1_max 	= 0.0,
		Param2_target = 0.0,
		Param3_min 	= 0.0,
		Param3_max 	= 0.0,
		Prg 		= 0,
		Tool 		= 0,
	},

	ResultValues 	= {
		Param1 		= 0.0,
		Param1_min 	= 0.0,
		Param1_max 	= 0.0,
		Param2 		= 0.0,
		Param2_min 	= 0.0,
		Param2_max 	= 0.0,
		Prg 		= 0,
		Tool 		= 0,
		QC 			= 1,   -- OK
		Seq 		= 0,
		Step 		= 'A1',
	}

}

	XTRACE(16, '"gui_lua_support" object ceated')


---------------------------------------------------------------------------------------------------
--
--   C++ API for GUI support in monitor
--
--	process_tool_result(tool)
--  get_tool_result_string(tool)
--  get_footer_string(tool)
--  get_prg_string(tool)
--  get_tool_units(tool)
--
--------------------------------------------------------------
function process_tool_result(tool)

	if tool ~= gui_lua_support.ResultValues.Tool then
		return lua_tool_param_error
	end

	local tool_type = lua_known_tool_types.get_tool_type(tool)
	if tool_type == nil then return lua_tool_reg_error end  -- tool not registered

	local func =lua_known_tool_types.get_impl(tool_type,'process_tool_result')
	if type(func) ~= 'function' then  return func end
	return func(tool)
end
--------------------------------------------------------------
function  get_tool_result_string(tool)

	if tool ~= gui_lua_support.ResultValues.Tool then
		return ''
	end

	local tool_type = lua_known_tool_types.get_tool_type(tool)
	if tool_type == nil then return lua_tool_reg_error end  -- tool not registered

	local func =lua_known_tool_types.get_impl(tool_type,'get_tool_result_string')
	if type(func) ~= 'function' then  return func end
	return func(tool)
end
--------------------------------------------------------------
function  get_footer_string(tool)

	if tool ~= gui_lua_support.CfgValues.Tool then
		return 'invalid tool'
	end

	local tool_type = lua_known_tool_types.get_tool_type(tool)
	if tool_type == nil then return lua_tool_reg_error end  -- tool not registered

	local func =lua_known_tool_types.get_impl(tool_type,'get_footer_string')
	if type(func) ~= 'function' then  return func end
	return func(tool)
end
--------------------------------------------------------------
function get_prg_string(tool)

	if tool ~= gui_lua_support.CfgValues.Tool then
		return 'invalid tool'
	end
	local tool_type = lua_known_tool_types.get_tool_type(tool)
	if tool_type == nil then return lua_tool_reg_error end  -- tool not registered

	local func =lua_known_tool_types.get_impl(tool_type,'get_prg_string')
	if type(func) ~= 'function' then  return func end
	return func(tool)
end
--------------------------------------------------------------
function get_tool_units(tool)

	local tool_type = lua_known_tool_types.get_tool_type(tool)
	if tool_type == nil then return 'Nm','Deg' end  -- unregistered tool -> use defaults

	local func =lua_known_tool_types.get_impl(tool_type,'get_tool_units')
	if type(func) ~= 'function' then  return nil,nil end
	return func(tool)
end
--------------------------------------------------------------



--============================================================================================
--  							Service function
--============================================================================================
function number_as_text(number,empty_value)

	local n = tonumber(number)
	if n ~= nil then
		if n < 9223372030000000000 and n > -9223372030000000000 then
			return string.format ('%.2f', n)
		end
	end
	return empty_value
end
--------------------------------------------------------------

