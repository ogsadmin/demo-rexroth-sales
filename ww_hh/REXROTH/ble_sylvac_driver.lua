local bluegiga = require("luabluegiga")
XTRACE(16, "Using luabluegiga runtime version: " .. bluegiga.version())
local m = {
	port = nil,		-- port, e.g. 'COM17' (shared between tools)
	dev = nil,		-- device instance (as returned from bluegiga.new(port)), also shared between tools
	state_cur = 0,
	state_old = 0,
	channels = {},	-- reverse lookup for ble <=> channels
}
--- helpers ------------------------------------------------------------
-- return the channel object from a given ble mac address
local getChnFromMac = function(mac)
	-- TODO: HACK: only support a single tool at the moment
	for k, v in pairs(m.channels) do
		return v
	end
end
local getChnFromHandle = function(connection)
	-- TODO: HACK: only support a single tool at the moment
	for k, v in pairs(m.channels) do
		return v
	end
end

--- callbacks ----------------------------------------------------------
function on_ble_version(major, minor, patch, build, ll_version, proto_version, hw)
    XTRACE(16, string.format("BLE version = %d.%d.%d.%d, ll = %d, proto = %d, hw = %d", major, minor, patch, build, ll_version, proto_version, hw))
    m.state_cur = m.state_cur + 1
end
--function on_ble_scan_response()
--end    
function on_ble_conn_status(connection, flags, bd_addr, addr_type, conn_interval, timeout, latency, bonding)
    if flags % (2*0x01) >= 0x01 then  -- test if bit 0 is set (0x01)
		XTRACE(16, string.format("BLE connected, handle = %d", connection))
		local channel = getChnFromMac(bd_addr)
		if channel ~= nil then
			channel.ble_state = 1 
			channel.ble_handle = connection
			-- NOTE: this is a shortcut, we already know the service/characteristic handles, so
			--       we don't need to go through reading the handles
			--       Here handle 12 is the value configuration
			--[[
				// Handle for Temperature Measurement configuration already known
				if (thermometer_handle_configuration) {
					change_state(state_listening_measurements);
					enable_indications(msg->connection, thermometer_handle_configuration);
				}
				// Find primary services
				else {
					change_state(state_finding_services);
					ble_cmd_attclient_read_by_group_type(msg->connection, FIRST_HANDLE, LAST_HANDLE, 2, primary_service_uuid);
				}
			]]--
			-- enable indications (0x0002) on the handle
			m.dev:attclient_attribute_write(channel.ble_handle, 12, {0x02, 0x00});
		else
			XTRACE(1, string.format("Bluegiga: no channel found for handle = %d", connection))
		end
    end
end    
function on_ble_attr_group_found()
end    
function on_ble_attr_procedure_done()
end    
function on_ble_attr_info_found()
end    
function on_ble_attr_value(connection, attr_handle, value_type, value)
	local n = tonumber(value)
	XTRACE(16, string.format('H=%d, vt=%d, value = %s', attr_handle, value_type, tostring(n)))

	local channel = getChnFromHandle(connection)
	if channel ~= nil then
		if channel.task_state == lua_task_processing then

			-- setup return data
			-- check limits
			local ll = tonumber(channel.CfgValues.Param1_min)
			local ul = tonumber(channel.CfgValues.Param1_max)
			if ll == nil then ll = -1000000000 end
			if ul == nil then ul =  1000000000 end
			local error_code = 0 -- OK
			if n > ul then error_code = 8 end	
			if n < ll then error_code = 16 end

			local values = { }
			values[1] = n
			values[2] = ll
			values[3] = ul
			status = lua_tool_result_response(channel.tool, error_code, 0, 'A2', values)

			if status == 0 then
				XTRACE(16, 'channel.tool ' ..param_as_str(channel.tool)..' is not active')
			elseif status < 0 then
				XTRACE(16, string.format('tool [%d] invalid parameter set (error=%d)', channel.tool, status))
			end

			-- notify core: finished with results:
			channel.task_state  = lua_task_completed
		else
			XTRACE(2, 'Data received in non-active state')
		end
	end
end    
function on_ble_conn_disconnect(connection, reason)
	XTRACE(16, string.format("DISCONNECTED: reason = %d", reason))
	local channel = getChnFromHandle(connection)
	if channel ~= nil then
		channel.ble_state = 0 
		channel.t_conn = os.clock()
		m.dev:gap_connect_direct(channel.cfg.mac, bluegiga.GAP_ADDRESS_TYPE_RANDOM, 0x60, 0x70, 100, 0)
	else
		XTRACE(1, string.format("Bluegiga: no channel found for handle = %d", connection))
	end
end    

--- state machine for connection handling -----------------------------------
local int_poll = function(obj)
	local ok, err

	-- TODO: could/should check poll response
    m.dev:poll(0)
    
    if m.state_cur == 0 then      -- open port for the first time. should never get here!
        
    elseif m.state_cur == 1 then  -- reset system
        m.dev:system_reset(0)
        m.state_cur = m.state_cur + 1
        
    elseif m.state_cur == 2 then  -- reopen port
        ok, err = m.dev:open()
        if ok then
            m.state_cur = m.state_cur + 1
        end
        
    elseif m.state_cur == 3 then  -- query version
        m.dev:system_get_info()
        m.state_cur = m.state_cur + 1
        
    elseif m.state_cur == 4 then  -- wait for response
        
    elseif m.state_cur == 5 then  -- set bonding
        m.dev:set_bondable_mode(1)
        m.state_cur = m.state_cur + 1
        
    elseif m.state_cur == 6 then  -- connect
		-- try to connect to all devices
		-- TODO: should implement this for multiple devices - better would be to
		--       use gap_connect_multiple here...
        m.dev:gap_connect_direct(obj.cfg.mac, bluegiga.GAP_ADDRESS_TYPE_RANDOM, 0x60, 0x70, 100, 0)
        m.state_cur = m.state_cur + 1
    end

    
    if m.state_cur ~= m.state_old then
        XTRACE(16, string.format("Bluegiga: State changed %d -> %d", m.state_old, m.state_cur))
        m.state_old = m.state_cur
    end
end


-- initialize the driver
m.init = function(channel)
	-- TODO: allow multiple instances...
	if m.port ~= nil then
		if m.port ~= cfg.port then
			-- only allow a single COM port
			XTRACE(1, "Bluegiga: only a single BLE dongle is supported currently!")
			return -1
		end
	else
		m.dev = bluegiga.new(channel.cfg.port)	-- 'COM17'
		-- initialize the callbacks
		m.dev:register_callback('ble_rsp_system_get_info', on_ble_version)
		--m.dev:register_callback('ble_evt_gap_scan_response', on_ble_scan_response)   -- not yet implemented 
		m.dev:register_callback('ble_evt_connection_status', on_ble_conn_status)
		m.dev:register_callback('ble_evt_attclient_group_found', on_ble_attr_group_found)
		m.dev:register_callback('ble_evt_attclient_procedure_completed', on_ble_attr_procedure_done)
		m.dev:register_callback('ble_evt_attclient_find_information_found', on_ble_attr_info_found)
		m.dev:register_callback('ble_evt_attclient_attribute_value', on_ble_attr_value)
		m.dev:register_callback('ble_evt_connection_disconnected', on_ble_conn_disconnect)

		-- check if BLE dongle is available for connection
		local ok, err
        ok, err = m.dev:open()
        if not ok then
            XTRACE(1, "Bluegiga: open: error: " .. err)
            return -1
        end
		m.state_cur = 1		-- successfully opened port
	end
	channel.dev = m.dev
	channel.ble_state = 0
	channel.ble_handle = -1
	channel.prg = 0
	channel.t_conn = os.clock()
	-- add a reverse lookup to map BLE communication back to the channel
	m.channels[channel.cfg.mac] = channel
end

m.poll = function(channel)
	-- poll local state machine
	int_poll(channel)
	
	-- provide tool driver connection state
	if channel.ble_state > 0 then
		channel.conn_state = lua_tool_connected
	else
		-- seems like we are not connected.
		if os.clock() - channel.t_conn > 3 then
			-- only report a disconnect, if this lasts longer than 3 seconds
			channel.conn_state = lua_tool_conn_error
		end
	end
  
	-- Handle the stupid dll/task states. Make it appear immediately enabled
	if (channel.dll_state == dll_tool_enable) then
		if (channel.task_state == lua_task_processing) or
		   (channel.task_state == lua_task_completed)  then
		   return channel.task_state
		end
		-- we are not yet running, so set this now
	    channel.task_state = lua_task_processing
	end
end

-- NOTE: start is called before the DLL state is set to "xxx"
m.start = function(channel, prg)
  -- start operation
  XTRACE(16, string.format('tool [%d]: starting prg=%d (task_state=%d)...', channel.tool, prg, channel.task_state))
	channel.last_ticker = os.clock()
	channel.prg = prg

end


return m
