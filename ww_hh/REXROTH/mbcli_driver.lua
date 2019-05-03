XTRACE(16, "Loading mbcli_driver.lua...", "mbcli_driver.lua", 1)

-- simulate the MBToolCli
local mb = require("luamodbus")
local m = {}

XTRACE(16, "using libmodbus runtime version: " .. mb.version())

-- see http://lua-users.org/wiki/CsvUtils
-- Convert from CSV string to table (converts a single line of a CSV file)
local fromCSV = function(s)
  s = s .. ','        -- ending comma
  local t = {}        -- table to collect fields
  local fieldstart = 1
  repeat
    -- next field is quoted? (start with `"'?)
    if string.find(s, '^"', fieldstart) then
      local a, c
      local i  = fieldstart
      repeat
        -- find closing quote
        a, i, c = string.find(s, '"("?)', i+1)
      until c ~= '"'    -- quote not followed by quote?
      if not i then error('unmatched "') end
      local f = string.sub(s, fieldstart+1, i-1)
      table.insert(t, (string.gsub(f, '""', '"')))
      fieldstart = string.find(s, ',', i) + 1
    else                -- unquoted; find next comma
      local nexti = string.find(s, ',', fieldstart)
      table.insert(t, string.sub(s, fieldstart, nexti-1))
      fieldstart = nexti + 1
    end
  until fieldstart > string.len(s)
  return t
end

-- read the first line of a csv file into a table, return the table
local readcsvfile = function(path)
  local file = io.open(path, "rb")
  if not file then
    -- if the file cannot be found, then show an ogs ALARM!
    SetLuaAlarm('mbcli', -2, 'Cannot find file ' .. path .. '!');
	XTRACE(1, 'Cannot find file ' .. path .. '!')
    return nil
  end

  for line in io.lines(path) do
    -- we only read the first line,
    file:close()
    return fromCSV(line)
  end
  return nil
end

-- Write PRG and ID-Code to tool when starting the tool
local set_id_and_prg = function(channel)
    local ok, res, err

    if channel.connstate ~= 4 then
        XTRACE(1, string.format('tool [%d]: Modbus ste_id_and_prg: ERROR: NOT CONNECTED!', channel.tool))
        channel.task_state = lua_task_not_ready
        return false
    end

    XTRACE(16, string.format('tool [%d]: Modbus write PRG: Adr=%d, Val=%d...', channel.tool, channel.cfg.ioMBPrgAdr, channel.prg))
  	res, err = channel.dev:write_registers(channel.cfg.ioMBPrgAdr, channel.prg)
	if not res then
		XTRACE(16, string.format('          ERR: %s', tostring(err)));
		return false
	end

    if channel.cfg.ioMBIDAdr > 32 then
        -- write CSV data
        local csvname = channel.cfg.csvBasePath .."\\".. BarCode_GetCSVFilename()
        XTRACE(16, '          Reading Barcode file: '..csvname..'...')
        local csvdata = readcsvfile(csvname)
        local insertfloat = function(tbl, data)
            local val = tonumber(data)
            local r1, r2 = mb.set_f32(val)
            XTRACE(16, "CSV=" .. tostring(val))
            table.insert(tbl, r2)
            table.insert(tbl, r1)
        end
        -- first 5 values are 16-bit numbers
        local mbdata = {}
        table.insert(mbdata, tonumber(csvdata[2]))
        table.insert(mbdata, tonumber(csvdata[3]))
        table.insert(mbdata, tonumber(csvdata[4]))
        table.insert(mbdata, tonumber(csvdata[5]))
        table.insert(mbdata, tonumber(csvdata[6]))
        table.insert(mbdata, tonumber(csvdata[15]))
        insertfloat(mbdata, csvdata[7])
        insertfloat(mbdata, csvdata[8])
        insertfloat(mbdata, csvdata[9])
        insertfloat(mbdata, csvdata[10])
        insertfloat(mbdata, csvdata[11])
        insertfloat(mbdata, csvdata[12])
        insertfloat(mbdata, csvdata[13])
        insertfloat(mbdata, csvdata[14])
        insertfloat(mbdata, csvdata[16])
        insertfloat(mbdata, csvdata[17])
        insertfloat(mbdata, csvdata[18])
		XTRACE(16, string.format('tool [%d]: Modbus write PARAMS: Adr=%d...', channel.tool, channel.cfg.ioMBPrgAdr+32))
        res, err = channel.dev:write_registers(channel.cfg.ioMBIDAdr+32, mbdata)
		if not res then
			XTRACE(16, string.format('          ERR: %s', tostring(err)));
			return false
		end
    end

	-- write Tool ID-Code
	local id = string.sub(GetIDCode(), 1, 64)
    XTRACE(16, string.format('tool [%d]: Modbus write ID: Adr=%d, Val=%s...', channel.tool, channel.cfg.ioMBIDAdr, id))
    local buf = {}
    for i = 1,#id,2 do
        local v = string.byte(id, i)
        if i+1 < #id then
        v = v + string.byte(id, i+1) * 256
        end
        table.insert(buf, v)
    end
    res, err = channel.dev:write_registers(channel.cfg.ioMBIDAdr, buf)
	if not res then
		XTRACE(16, string.format('          ERR: %s', tostring(err)));
		return false
	end
	return true
end

-- read tool results
local read_results = function(channel)
    local ok, regs, err

    if channel.connstate ~= 4 then
        XTRACE(1, string.format('tool [%d]: Modbus read_results: ERROR: NOT CONNECTED!', channel.tool))
        channel.task_state = lua_task_not_ready
        return false
    end

	regs, err = channel.dev:read_input_registers(channel.cfg.ioMBResAdr, channel.cfg.ioMBResLen)
	if not regs then
        XTRACE(1, string.format('tool [%d]: Modbus read_input_registers: ERROR: %s!', channel.tool, tostring(err)))
		return false
	end

	XTRACE(16, string.format("chn=%d, sta=%d, prg=%d, seq=%d", regs[1], regs[2], regs[3], regs[4]*0x10000 + regs[5]))
	local values = { }

	values[1] = mb.get_f32(regs[ 8], regs[ 7])
	values[2] = mb.get_f32(regs[10], regs[ 9])
	values[3] = mb.get_f32(regs[12], regs[11])
	values[4] = mb.get_f32(regs[14], regs[13])
	values[5] = mb.get_f32(regs[16], regs[15])
	values[6] = mb.get_f32(regs[18], regs[17])
	XTRACE(16, "RES[1]=" .. tostring(values[1]))

	-- setup return data
	local error_code = regs[2] -- OK
	local seq = regs[4]*0x10000 + regs[5]
	local step = 'A2'
	local status = lua_tool_result_response(channel.tool, error_code, seq, step, values)

	if status == 0 then
		XTRACE(16, 'channel.tool ' ..param_as_str(channel.tool)..' is not active')
	elseif status < 0 then
		XTRACE(16, string.format('tool [%d] invalid parameter set (error=%d)', channel.tool, status))
	else
		XTRACE(16, string.format('tool [%d] result saved', channel.tool))
		return true
	end
	return false
end


-- state machine for modbus connection handling
local int_poll = function(obj)
  local ok, err

  if obj.connstate == nil or obj.connstate == 0 then
    -- not yet initialized
    obj.connstate = 1

  elseif obj.connstate == 1 then
    -- idle, not connected. Try to connect (with a max. 500ms response time)
	if obj.dev:is_connected() then
		-- we are connected!
        XTRACE(16, string.format('tool [%d]: Modbus connected', obj.tool))
		obj.connstate = 3
    end

  elseif obj.connstate == 3 then
    -- We are connected for the first time
    obj.dodx(obj, true)
    obj.connstate = 4

  elseif obj.connstate == 4 then
    -- We are connected and the device is initialized. Do the DX
    if obj.dodx(obj, false) ~= 0 then
      -- some error - disconnect and reconnect
      XTRACE(1, string.format('tool [%d]: Modbus DX ERROR', obj.tool))
      obj.connstate = 1
    end
	if not obj.dev:is_connected() then
		-- we are not connected anymore!
        XTRACE(1, string.format('tool [%d]: Modbus LOST CONNECTION', obj.tool))
		obj.connstate = 1
    end
  end
end

local isConnected = function (obj)
    return obj.connstate == 4
end

-- see http://lua-users.org/wiki/BitUtils
local isbitset = function(val, bit)
  return val % (2*bit) >= bit
end



-- Function is called cyclically whenerver a modbus connection is up and running
-- return 0 if everything ok, < 0 to disconnect/reconnect
mb_reg1 = -1

local dodx = function(obj, firstRun)
  local ok, err, regs, in_cur
  local ticker = os.clock()

  if ticker - obj.last_ticker > 0.5 then
    XTRACE(1, "dodx timeout: " .. tostring(ticker - obj.last_ticker) .. "s")
  end
  obj.last_ticker = ticker

  -- cyclically update status / write command
  obj.val.control = 0
  if obj.phase100ms >= 5 then obj.val.control = obj.val.control + 1 end  -- Alive bit
  if isbitset(obj.val.status, 2) then obj.val.control = obj.val.control + 2 end -- Mirror bit
  if obj.xOutEnable > 0 then obj.val.control = obj.val.control + 4 end -- Enable bit

  ok = obj.dev:write_cyclic_io(0, obj.val.control)
  regs, err = obj.dev:read_cyclic_io(0, 1)
  if not regs then
    XTRACE(1, "read failed: " .. tostring(err))
    --obj.state = 1
    return -1
  end
  obj.val.status = regs[1]
  obj.xInEnabled = isbitset(obj.val.status, 4)
  obj.xInRunning  = isbitset(obj.val.status, 8)
  obj.xInFinished = isbitset(obj.val.status, 0x10)
  obj.xInReady   = isbitset(obj.val.status, 0x8000)

  obj.phase100ms = obj.phase100ms + 1
  if obj.phase100ms > 9 then obj.phase100ms = 0 end

  return 0
end


m.init = function(channel)
	--channel.dev = mb.new_tcp_pi(channel.cfg.CONN_ADDR,channel.cfg.CONN_PORT)
	channel.dev = mb.new_tcp_pi_x(
		channel.cfg.CONN_ADDR, channel.cfg.CONN_PORT,
		100,       					-- update rate in milliseconds
		channel.cfg.ioMBCtlAdr, 1,  -- cyclic write register address/len ("control")
		channel.cfg.ioMBStaAdr, 1,  -- cyclic read register address/len ("status")
		1,        					-- read/write mode (1 = FC23, 0 = FC3/FC16)
		channel.cfg.initMBAdr, { channel.cfg.initMBVal } -- initial write register address and table of values
	)
	-- set connect/response timeout to 500ms for further communications
	channel.dev:set_response_timeout(0, 500000)

	channel.dodx = dodx
	channel.val = {
		control = 0,
		status = 0,
	}
	channel.prg = 0

	-- init internal state
    channel.tOld = os.clock()
    channel.blink = 1
    channel.out = 1
    channel.in_old = 0
    channel.phase100ms = 0
    channel.xInEnabled = 0
    channel.xInRunning = 0
	channel.xInFinished = 0
    channel.xInReady = 0
	channel.xOutEnable = 0
	channel.last_ticker = channel.tOld

end

m.poll = function(channel)
	-- poll modbus
	int_poll(channel)

	-- provide tool driver connection state
	if channel.connstate == 4 then
		channel.conn_state = lua_tool_connected
	else
		channel.conn_state = lua_tool_conn_error
		if channel.driverstate ~= 0 then
			XTRACE(1, string.format('tool [%d] aborted due to disconnect', channel.tool))
			channel.driverstate = 0
		end
	end

	-- driver state machine ------------

	-- abort from dll
	if channel.dll_state ~= dll_tool_enable then
		channel.driverstate = 0
		channel.task_state = lua_task_idle
	end

	-- state machine
	if channel.driverstate == nil then
		channel.driverstate = 0

	elseif channel.driverstate == 0 then
		if channel.connstate ~= 4 then
			channel.task_state = lua_task_not_ready
		else
			-- we are connected, check dll to start tool
			if channel.xInEnabled or channel.xInFinished then
				-- pending I/O signals! WAIT for enable = 0 and finished = 0!
				channel.task_state = lua_task_wait_en_reset
			else
				if not channel.xInReady then
					-- Device is not ready
					channel.task_state = lua_task_fault
				else
					-- Enable and Finished are not set
					if channel.dll_state == dll_tool_enable then
						-- send tool parameters
						if set_id_and_prg(channel) then
							-- successfully send prg
							channel.driverstate = 1
							channel.task_state = lua_task_wait_incy
						end
					end
				end
			end
		end

	elseif channel.driverstate == 1 then
		-- wait for enable acknowledge from tool
		if not channel.xInReady then
			-- Device is not ready
			channel.task_state = lua_task_fault
		elseif channel.xInEnabled then
			-- enabled and no fault
			channel.driverstate = 2
			channel.task_state = lua_task_wait_ftp
		end

	elseif channel.driverstate == 2 then
		-- wait for response from tool
		if not channel.xInReady then
			-- Device is not ready
			channel.task_state = lua_task_fault
		end
		if channel.xInFinished then
			-- finished and no fault, read results
			if read_results(channel) then
				channel.driverstate = 0
				channel.task_state = lua_task_completed
			else
				-- ERROR reading results - disconnect
				-- Device is not ready
				channel.task_state = lua_task_fault
			end
		end
	end

	-- set outputs
	if channel.dll_state == dll_tool_enable then
		channel.xOutEnable = 1
	else
		channel.xOutEnable = 0
	end

end

m.start = function(channel, prg)
  -- start operation
  XTRACE(16, string.format('tool [%d]: starting prg=%d...', channel.tool, prg))
	channel.last_ticker = os.clock()
	channel.prg = prg

end



return m
