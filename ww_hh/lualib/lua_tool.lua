------------------------------------------
--	base class    "lua_known_tool_types"
------------------------------------------

lua_known_tool_types = {
	registered_tools = {}
}
---------------------------------------------------------------------------------------
function lua_known_tool_types.add_type(type_obj)
	lua_known_tool_types[type_obj.type] = type_obj
end

function lua_known_tool_types.add_tool(tool, tool_type)
	lua_known_tool_types.registered_tools[tool] = tool_type
end

function lua_known_tool_types.get_tool_type(tool)
	return lua_known_tool_types.registered_tools[tool]
end
--------------------------------------------------------------
function lua_known_tool_types.get_impl(tool_type, function_name)

	local type_impl = lua_known_tool_types[tool_type]
	if type_impl == nil then return nil end

	local func_impl = type_impl[function_name]
	if type(func_impl) ~= 'function' then
		return lua_tool_script_error   -- 'invalid LUA registration function'
	end
	return func_impl

end
---------------------------------------------------------------------------------------
--
--   C++ API for LUA tool DLL
--
--  lua_tool_registration(tool, tool_type, params)
--  lua_tool_poll(tool, state)
--  lua_tool_start(tool, state)
--  lua_tool_get_conn_attr(tool)
--  lua_tool_save_results(tool, values)
--
----------------------------------------------------------------------------------------
--  constants
---------------------------------------------------------------------------------------
-- lua tool states on dll side (dll_tool_xxx):
dll_tool_idle 			= 0
dll_tool_wait_release 	= 1
dll_tool_enable 		= 2
dll_tool_disable 		= 3

-- lua tool states on lua side (lua_tool_xxx): channel.conn_state values:

lua_tool_reg_error		= -1	-- tool not registered
lua_tool_conn_error		= -2	-- not connected
lua_tool_script_error	= -3	-- invalid LUA configuration
lua_tool_param_error	= -4	-- parameter missing or invalid
lua_tool_connecting		=  0	-- connecting
lua_tool_connected		=  1	-- connected

-- lua task states  (lua_task_xxx): channel.task_state values

lua_task_idle			=  0	-- idle
lua_task_not_ready		=  4	-- TOOL_wait_RDY       = 4  -- wait for Rdy signal
lua_task_processing		=  6	-- task in processing
lua_task_completed 		=  17	-- task completed

lua_task_started        = 1  	-- start requested
lua_task_reset_act_en   = 2  	-- reset ActEn signal
lua_task_info_sent      = 3  	-- Info block sent
lua_task_wait_rdy       = 4  	-- wait for Rdy signal
lua_task_wait_incy      = 5  	-- wait for InCy
lua_task_wait_cycmp     = 6  	-- wait for CyCmp
lua_task_wait_ftp       = 7  	-- wait for tightening result/ftp telegram
lua_task_wait_noack     = 8  	-- wait for NOK acknowledge or release trigger
lua_task_fault          = 9  	-- missing NOFAULT signal
lua_task_wait_ext_releas = 10 -- wait for external release
lua_task_wait_cw        = 11  -- wait for CW in case of CCW is not allowed
lua_task_wait_ccw_incy  = 12  -- wait for loosen InCy
lua_task_wait_acten_off = 13  -- wait for active enable change
lua_task_cnt_reset      = 14  -- wait for counter reset
lua_task_invalid_prg    = 15  -- tightening program invalid
lua_task_wait_en_reset  = 16  -- wait for En reset

--------------------------------------------------------------
function lua_tool_registration(tool, tool_type, params)

	local reg_status = 'invalid parameter'
	local func = lua_known_tool_types.get_impl(tool_type,'registration')
	if type(func) == 'function' then
		reg_status = func(tool, params)

		if reg_status == 'OK' then
			lua_known_tool_types.add_tool(tool, tool_type)
		end

	end
	return reg_status
end
--------------------------------------------------------------
function lua_tool_poll(tool, state)

	local tool_type = lua_known_tool_types.get_tool_type(tool)
	if tool_type == nil then return lua_tool_reg_error end  -- tool not registered

	local func =lua_known_tool_types.get_impl(tool_type,'poll')
	if type(func) ~= 'function' then  return func end
	return func(tool, state)
end
--------------------------------------------------------------
function lua_tool_start(tool, prg)

	local tool_type = lua_known_tool_types.get_tool_type(tool)
	if tool_type == nil then return lua_tool_reg_error end  -- tool not registered

	local func =lua_known_tool_types.get_impl(tool_type,'start')
	if type(func) ~= 'function' then  return func end
	return func(tool, prg)
end
---------------------------------------------------------------------------------------
function lua_tool_get_conn_attr(tool)

	local tool_type = lua_known_tool_types.get_tool_type(tool)
	if tool_type == nil then return lua_tool_reg_error end  -- tool not registered

	local func =lua_known_tool_types.get_impl(tool_type,'get_conn_attr')
	if type(func) ~= 'function' then  return func end
	return func(tool)
end
---------------------------------------------------------------------------------------
function lua_tool_save_results(tool, values)

	local tool_type = lua_known_tool_types.get_tool_type(tool)
	if tool_type == nil then return lua_tool_reg_error end  -- tool not registered

	local func =lua_known_tool_types.get_impl(tool_type,'save_results')
	if type(func) ~= 'function' then  return func end
	return func(tool, values)
end
---------------------------------------------------------------------------------------
