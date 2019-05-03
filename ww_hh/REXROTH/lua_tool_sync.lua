--require('lua_tool')
json = require('json')
require "luasignalr"

lua_tool_sync = {
	type = 'SYNC', 	-- type identifier (as in INI file)
	channels = {},  	-- regisrered channels
	sync_start = os.time (),
}

lua_known_tool_types.add_type(lua_tool_sync)

-- create a new Instance of a SignalR connection
local myHub = SignalR()
local SignalR = {
	Enabled = false,
	TraceLevel = 3, --31,
	URL = '', -- 'http://localhost:8080',
	HUB = '', -- 'MyHub2'
	conn_state = lua_tool_connecting,
	SyncName = '',
	SyncCount = 0,
	tool = 0
}

-------------------------------------------------------------

function lua_tool_sync.registration(tool, ini_params)

	channel = lua_tool_sync.channels[tool]
	if channel ~= nil then
		return 'multiple tool definition'
	end

	if SignalR.enabled then
		return 'SyncTool: only allows one instance!'
	end

	-- check initialization parameters
	SignalR.Enabled = true
	if type(ini_params.TRACELEVEL) == "number" then
		SignalR.TraceLevel = ini_params.TRACELEVEL
	end
	if ini_params.URL == nil or ini_params.HUB == nil then
		return 'SyncTool: URL and HUB must not be empty!'
	end
	SignalR.URL = ini_params.URL
	SignalR.HUB = ini_params.HUB
	SignalR.tool = tool

	-- SignalR initialization
	myHub:set_debug(1)
	myHub:Init(SignalR.URL, SignalR.HUB, SignalR.TraceLevel)
	myHub:Connect()

	-- register the callbacks with core.
	XTRACE(16, "SIGNALR[Sync]: Registering callbacks.")
	if StatePollFunctions ~= nil then
		StatePollFunctions.add(myHub.SignalR_StatePoll)
	end


	-- register channel

	lua_tool_sync.channels[tool] = {
		tool = tool,
		ini_params = CloneTable(ini_params),
		--conn_state = lua_tool_connecting,
		task_state = lua_task_idle,
		dll_state  = dll_tool_idle,
		conn_attr = {
			--ip = '192.168.5.29',
			--port = 9999,
		},
	}
	return 'OK'
end

------------------------------------------------------------------------------
--
-- SignalR event handlers (called through the poll function, see below)
--
------------------------------------------------------------------------------

-- Trace callback
myHub.OnTrace = function(mc, msg, src)
	--XTRACE(16, "SIGNALR[Sync]: TRACE[" .. mc .. "] " .. tostring(msg) .." (" .. tostring(src) ..")")
end

-- SignalR connection state change callback
myHub.OnState = function(oldState, newState)
	-- SignalR connection state changed. Only relevant here is newState == 1
	-- (newly connected). In this case any subscriptions should be re-issued.
	--XTRACE(16, "SIGNALR[Sync]: STATE: "..tostring(oldState).." --> "..tostring(newState))
	if newState == 1 then
		Config.SignalR.StationID = Config.Id
		--SignalR_ReportCS(true)
		SignalR.conn_state = lua_tool_connected
		myHub:Subscribe("SyncPointChanged")
	else
		--SignalR_ReportCS(false)
		SignalR.conn_state = lua_tool_conn_error
	end
end

-- SignalR event occurred
myHub.OnEvent = function(eventName, eventParams)
	--XTRACE(16, "SIGNALR: EVENT: "..tostring(eventName).."("..tostring(eventParams)..")")
	if eventName == "SyncPointChanged" then
		--XTRACE(16, "SIGNALR[Sync]: NEW MESSAGE from server!")
		local o = json.decode(eventParams)
		--tprint(o)
		SignalR_SyncPointChanged(o)
	else
		--XTRACE(2, "SIGNALR[Sync]: Unknown event!")
	end
end

-- Process SignalR events
myHub.Poll = function()
	-- get SignalR events from the queue
	repeat
		res,item = myHub:QueueGet()
		if res ~= 0 then
			-- dispatch to callbacks
			if item.mc == 1 then myHub.OnTrace(item.i1, item.s1, item.s2)
			elseif item.mc == 2 then myHub.OnState(item.i1, item.i2)
			elseif item.mc == 3 then myHub.OnEvent(item.s1, item.s2)
			end
		end
	until (res == 0)
end

------------------------------------------------------------------------------
--
-- Custom Handlers for the SyncPoint application
--
------------------------------------------------------------------------------

-- handle the Notification from the SignalR server
function SignalR_SyncPointChanged(o)
	-- decode object passed in through stationUpdate SignalR event
	tprint(o, 8)
	local SPName = o.SyncPointName
	local SPCount = tonumber(o.Count)

	-- check if number of syncpoints reached..
	if SPName == SignalR.SyncName and SPCount >= SignalR.SyncCount then
		-- done.
		lua_tool_sync.save_results_ok(SignalR.tool)

		-- release lock on syncpoint
		SignalR_SyncPointLeave(SPName)
	end
end

-- Send a SyncPoint enter request
function SignalR_SyncPointEnter(SyncPointName)
	XTRACE(16, "SIGNALR[Sync]: SyncPointEnter(" .. SyncPointName .. ")")
	myHub:Invoke("SyncPointEnter", '[ "' .. SyncPointName .. '" ]' )
end

-- Send a SyncPoint leave request
function SignalR_SyncPointLeave(SyncPointName)
	XTRACE(16, "SIGNALR[Sync]: SyncPointLeave(" .. SyncPointName .. ")")
	myHub:Invoke("SyncPointLeave", '[ "' .. SyncPointName .. '" ]' )
end


-------------------------------------------------------------
function lua_tool_sync.poll(tool, state)

	channel = lua_tool_sync.channels[tool]
	if channel == nil then
		channel.task_state = lua_task_not_ready
		return lua_task_not_ready
	end

	if SignalR.conn_state ~= lua_tool_connected then
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
		XTRACE(16, "SIGNALR[Sync]: Start tool")

		-- read action parameters from database
		SignalR.SyncName = get_object_property(3, 'syncpoint')
		if SignalR.SyncName == nil then
			XTRACE(1, "SIGNALR[Sync]: Parameter 'syncpoint' missing or empty")
			return lua_tool_param_error
		end
		SignalR.SyncCount = get_object_property(3, 'synccount')
		if SignalR.SyncCount == nil then
			SignalR.SyncCount = 2
		else
			SignalR.SyncCount = tonumber(SignalR.SyncCount)
		end
		XTRACE(16, "SIGNALR[Sync]:     syncpoint=[" .. tostring(SignalR.SyncName) .. "] synccount=" .. tostring(SignalR.SyncCount))

		SignalR_SyncPointEnter(SignalR.SyncName)
	    channel.task_state = lua_task_processing
		lua_tool_sync.sync_start = os.time ()

	end

	return channel.task_state
end

-----------------------------------------------------------------------------------
function lua_tool_sync.get_conn_attr(tool)

	channel = lua_tool_sync.channels[tool]
	if channel == nil then
		return lua_tool_reg_error
	end

	return channel.conn_attr, SignalR.conn_state

end
-----------------------------------------------------------------------------------

function lua_tool_sync.save_results_ok(tool)

	channel = lua_tool_sync.channels[tool]
	if channel == nil then
		XTRACE(16, 'Tool '.. param_as_str(tool)..' is not registered')
		return lua_tool_reg_error
	end

	channel.task_state = lua_task_completed

	error_code = 0 -- OK
	seq = 0
	step = 'A2'
	local diff = os.difftime (os.time () , lua_tool_sync.sync_start)
	local values = {
		diff, 0, 0, 0, 0, 0
	}

	status = lua_tool_result_response(tool, error_code, seq, step, values)

	if status == 0 then
		XTRACE(16, tool..' '..param_as_str(tool)..' is not active')
	else  if status < 0 then
			XTRACE(16, string.format('tool [%d] invalid parameter set (error=%d)', tool, status))
		  end
	end
	return 0
end

------------------------------------------------------------------------------
--
-- State handlers - notify SignalR in case of Workflow state changes
--
------------------------------------------------------------------------------
local ticker = os.clock()
local heartbeat = os.clock()
local idleTicker = os.clock()

-- StatePoll is cyclically called every 100-200ms
function myHub.SignalR_StatePoll(info)

	myHub.Poll()						-- consume SignalR events

	-- call the HeartBeat Method on the SignalR Hub every now and then (30 seconds)
	if os.clock() - heartbeat > 30 then
		--XTRACE(16, "HeartBeat " .. "[ '" .. signalROpNum .. "' ]")
		--myHub:Invoke("HeartBeat", "[ '" .. signalROpNum .. "' ]")
		heartbeat = os.clock()
	end
--[[
	if SignalR.WorkflowState == 0 and SignalR.pending then
		if os.clock() - idleTicker > 2 then
			-- feed the pending barcodes (after a short delay)...
			ProcessSignalRcodes()
		end
	end
]]--
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

function  lua_tool_sync.get_tool_units(tool)

	return 's.', '.'

end
----------------------------------------------------------------------------------------------
-- process raw values from DLL
-- @param tool: channel number as configured in station.ini
-- @output: values ready to show and to save into database

function lua_tool_sync.process_tool_result(tool)
	return 0 --  use raw values without preprocessing
end
------------------------------------------------
-- Get the tool specific result string

function lua_tool_sync.get_tool_result_string(tool)

	local ResultValues = gui_lua_support.ResultValues
	if tool ~= ResultValues.Tool then
		return 'invalid tool'
	end

	local result = 'lua_error'

	local p1 = tonumber(ResultValues.Param1)
	if (p1 ~= nil) then
		result = string.format("duration: %d s.", p1)
	end

	return result
end
------------------------------------------------
-- Get the tool specific footer string

function lua_tool_sync.get_footer_string(tool)

	local CfgValues = gui_lua_support.CfgValues
	if tool ~= CfgValues.Tool then
		return 'invalid tool'
	end
	local result = 'lua_error'
	local p1 = get_object_property(3, 'syncpoint')
	if SyncName ~= nil then
		result = string.format('Sync: %s', p1)
	end
	return result
end
------------------------------------------------
-- Get the tool specific program name

function lua_tool_sync.get_prg_string(tool)

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

