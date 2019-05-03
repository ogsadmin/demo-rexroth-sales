--XTRACE(16, "Loading lualib/system.lua...", "system.lua", 1)

-- Add additional LUA paths
AddDllDirectory("lualib/mqtt")
package.cpath = package.cpath .. ";./lualib/signalr/?.dll;./lualib/mqtt/?.dll"

process = {}

version = '1.0'
station_results = {}

TOOL_TYPE = { ERGOSPIN=1, GWK=2, NEXO=3, ByHAND=4, NEWTYPE=5, CONFIRMATION=6, MODBUS=7 }
CurrentOperation = { Scope='', JobName='Job1', ToolType=TOOL_TYPE.NEXO, ToolName='NEXO1', Prg=0, BoltName='B1', BoltNumber=1, Name='Op1', Number=1, Total=1, Loosen=0, ByHandAck=0 }

assembly_in_process = 0
TargetSocket = 0


------------------------------------------------------------------------------------------
-- Callback handler
StatePollFunctions = {
	list = {},
	add = function(fn)
		StatePollFunctions.list[fn] = fn
	end,
	exec = function(arg)
		for k, v in pairs(StatePollFunctions.list) do
			v(arg)
		end
	end
}
function StatePoll(info)
	-- forward to interested parties...
	StatePollFunctions.exec(info)
end


-- StateChanged is called each time the workflow state, tool state or
-- job/operation state changes.
StateChangedFunctions = {
	list = {},
	add = function(fn)
		StateChangedFunctions.list[fn] = fn
	end,
	exec = function(arg)
		for k, v in pairs(StateChangedFunctions.list) do
			v(arg)
		end
	end
}
function StateChanged(info)
	-- forward to interested parties...
	StateChangedFunctions.exec(info)
end

-- StateShutdown is called just befor the Lua instance gets destroyed
-- Cleanup everything here (especially shutdown threads)
StateShutdownFunctions = {
	list = {},
	add = function(fn)
		StateShutdownFunctions.list[fn] = fn
	end,
	exec = function()
		for k, v in pairs(StateShutdownFunctions.list) do
			v()
		end
	end
}
function StateShutdown()
	-- forward to interested parties...
	StateShutdownFunctions.exec()
end

------------------------------------------------------------------------------------------


function valid_str(a)

	if a == nil then return false end
	local b = tostring(a)
	if  b == 'nil' then return false end
	return (#b ~= 0)
end
function param_as_str(param)  if valid_str(param) then return tostring(param) end return '' end
------------------------------------------------------------------------------------------
function CloneTable(original)
    local copy = {}
    for k, v in pairs(original) do
        -- as before, but if we find a table, make sure we copy that too
        if type(v) == 'table' then
            v = CloneTable(v)
        end
        copy[k] = v
    end
    return copy
end
----------------------------------------------------------------------
function create_station_result(name, host, time, info, worker, master, result)

	if valid_str(name) then
		station_results[name] = {}  -- clear station result
		local st_res = station_results[name]
		st_res.name   = name
		st_res.host   = host
		st_res.time   = time
		st_res.info   = info
		st_res.worker = worker
		st_res.master = master
		st_res.result = result
		st_res.parts  = {}
	end

end
----------------------------------------------------------------------
function create_part_result(station, part_seq, name, time, result)

	if station_results[station] ~= nil then
		station_results[station].parts[part_seq] = {}  -- clear part result
		local part_res = station_results[station].parts[part_seq]
		part_res.name = name
		part_res.time = time
		part_res.result = result
		part_res.bolts  = {}
	end
end
----------------------------------------------------------------------
function create_bolt_result(station, part_seq, bolt_seq, name, tool, prg,
							 torque, torque_min, torque_max, angle, angle_min, angle_max, result,
							 qc, seq, tool_sn , operation)

	if station_results[station] ~= nil then

	    local part_res = station_results[station].parts[part_seq]

		if part_res ~= nil then

			part_res.bolts[bolt_seq] = {}
			local bolt_res = part_res.bolts[bolt_seq]

			bolt_res.name 		= name
			bolt_res.tool 		= tool
			bolt_res.prg 		= prg
			bolt_res.torque 	= torque
			bolt_res.torque_min = torque_min
			bolt_res.torque_max = torque_max
			bolt_res.angle 		= angle
			bolt_res.angle_min 	= angle_min
			bolt_res.angle_max 	= angle_max
			bolt_res.result 	= result
			bolt_res.qc 		= qc
			bolt_res.seq        = seq
			bolt_res.tool_sn 	= tool_sn
			bolt_res.operation  = operation
		end
	end
end
------------------------------------------------------------
function GetParamsByDriverName(DriverName)

	local drv_name = string.lower(DriverName)
	for k,v in pairs(OutputDrivers) do
		if string.lower (k) == drv_name and  type(v)=="table" then
			set_properties_by_tablename('drv_type','output')
			for k2,v2 in pairs(v) do
				set_properties_by_tablename(k2,v2)
			end
			return;
		end
    end

	for k,v in pairs(InputDrivers) do
		if string.lower (k) == drv_name and  type(v)=="table" then
			set_properties_by_tablename('drv_type','input')
			for k2,v2 in pairs(v) do
				set_properties_by_tablename(k2,v2)
			end
			return;
		end
    end

end

----------------------------------------------------------------------
function GetCurveFileName(
    -- station params		  tightening result			          time stamp
	     Name,IP,		IDCode,Rack,Slot,Prg,Seq,QC,	Year,Month,Day,Hour,Minute,Second, IDSeq)
	if IDSeq == nil then IDSeq = '000' end
	local FileName = string.format('%s\\%s\\Ch%02d.%d\\Seq_%08d.crv',heCSSDLL_settings.base_directory, IP,Rack,Slot,Seq)
	return FileName
end
----------------------------------------------------------------------

function GetIDCode()
	return BarCode_GetOperationID(CurrentOperation, BarCode_CheckPartID(active_barcodes))
end

------------------------------------------------------------------------------------------
function TrimOrFillLeft(str, max, pad_char)

	if (str == nil) or (#str == 0) then
        return string.rep(pad_char, max)
	end

	if max <= 0 then return str end

	local len = #str
	if len > max then
		str = string.sub(str,1 ,max)
		len = max
	end

	if len < max then
		str = string.rep(pad_char, max - len)..str
	end

	return str

end


function TrimOrFill(str, max, pad_char)

	if (str == nil) or (#str == 0) then
        return string.rep(pad_char, max)
	end

	local len = #str
	if len > max then
		str = string.sub(str,1 ,max)
		len = max
	end

	if len < max then
		str = str .. string.rep(pad_char, max - len)
	end

	return str

end

--------------------------------------------------------------------------------------------
--[[**********************************************************************************]]
xml_text_beg =
	'<?xml version="1.0" encoding="ISO-8859-1"?>\n'
..	'<prozess  id="%s" typ="%s" version="%s">\n'
xml_text_end =
	'</prozess>\n'
--[[**********************************************************************************]]
xml_station_beg =
	'\t<station name ="%s" host="%s" zeitstempel="%s" kundeninfo="%s" werker="%s" meister="%s" ergebnis="%s">\n'
xml_station_end =
	'\t</station>\n'
--[[**********************************************************************************]]
xml_part_beg =
	'\t\t<bauteil name ="%s" zeitstempel="%s" ergebnis="%s">\n'
..	'\t\t\t<schrauben>\n'
xml_part_end =
	'\t\t\t</schrauben>\n'
..  '\t\t</bauteil>\n'
--[[**********************************************************************************]]
xml_bolt =
	'\t\t\t\t<schraube num="%s" name="%s" werkzeug="%s" prg="%s" moment="%s" mommin="%s" mommax="%s" winkel="%s" winmin="%s" winmax="%s" ergebnis="%s"/>\n'
--[[**********************************************************************************]]
--------------------------------------------------------------------------------------------
function GetXMLFile(id,type)

	process.version = '1.0'   -- data format version
    process.type   	= nil     -- assambly type
	process.id  	= nil     -- id code/barcode

	t = os.date('*t')
	local t_as_str = string.format('%02d%02d%02d-%02d%02d%02d',t.day,t.month,t.year%100,t.hour,t.min,t.sec)
	local filename = string.format('%s-%s.xml',id,t_as_str)
	local text     = string.format(xml_text_beg,param_as_str(id),param_as_str(type), param_as_str(version))
	for st_name , st_res in pairs(station_results) do -- write station results
		local txt_station = string.format(xml_station_beg, 	param_as_str(st_name),
									param_as_str(st_res.host),
									param_as_str(st_res.time),
									param_as_str(st_res.info),
									param_as_str(st_res.worker),
									param_as_str(st_res.master),
									param_as_str( st_res.result))

		for part_num , part_res in pairs(st_res.parts) do  -- write all part results
			if part_res ~= nil  then
				local txt_part = string.format(xml_part_beg, param_as_str(part_res.name),
									param_as_str(part_res.time),
									param_as_str(part_res.result))

				for bolt_num , bolt_res in pairs(part_res.bolts) do   -- write all bolt results
					if bolt_res ~= nil  then
						txt_part = txt_part .. string.format(xml_bolt,  bolt_num,
									param_as_str(bolt_res.name),
									param_as_str(bolt_res.tool),
									param_as_str(bolt_res.prg),
									param_as_str(bolt_res.torque),
									param_as_str(bolt_res.torque_min),
									param_as_str(bolt_res.torque_max),
									param_as_str(bolt_res.angle),
									param_as_str(bolt_res.angle_min),
									param_as_str(bolt_res.angle_max),
									param_as_str(bolt_res.result))
					end
				end
				txt_station = txt_station .. txt_part .. xml_part_end
			end
		end
		text = text .. txt_station .. xml_station_end
	end
	text = text ..xml_text_end
    return filename , text
end


--------------------------------------------------------------------------------------------
function CheckExternalConditions(secondsRunning, Socket)

	if ( (0 == Socket) or (secondsRunning >= 5)) then return 0 end -- close the process screen and return to start view
	if 0 ~= Socket 			then return 1 end  -- show notification
	return 2;   -- wait   while secondsRunning < 5
end
--------------------------------------------------------------------------------------------

debug_values = {  release = 0, Pos = 0, Inputs = 0, inp = 0 }

function EvaluateExternalIO(Tool, Socket, Inputs, Outputs, Pos)

	local release = 0
	local inp = math.floor(Inputs/256)
    -- if inp == Pos then release = 1 end
    if inp == 1 then release = 1 end

	if 	(release ~=  debug_values.release) or
	    (Pos ~=  debug_values.Pos) or
		(inp ~=  debug_values.inp) or
		(Inputs ~=  debug_values.Inputs) then
		 XTRACE(16, 'EvaluateExternalIO change')
		 XTRACE(16, ' release: '.. param_as_str(release).. ' <- ' .. param_as_str(debug_values.release))
		 XTRACE(16, ' Pos: ' 	.. param_as_str(Pos) 	.. ' <- ' .. param_as_str(debug_values.Pos))
		 XTRACE(16, ' inp: ' 	.. param_as_str(inp) 	.. ' <- ' .. param_as_str(debug_values.inp))
		 XTRACE(16, ' Inputs: ' .. param_as_str(Inputs) .. ' <- ' .. param_as_str(debug_values.Inputs))

	 	debug_values.release=  release
	    debug_values.Pos 	=  Pos
		debug_values.inp 	=  inp
		debug_values.Inputs =  Inputs
	end
	return Outputs, release
end
--------------------------------------------------------------------------------------------
function CheckConfigTable(P1, P2)
	return  string.format("%d - %s - %s",Config.Number,Config.Name,Config.Id)
end

-- print a table (for debugging)
function tprint (tbl, indent)
  if not indent then indent = 0 end
  for k, v in pairs(tbl) do
    formatting = string.rep("  ", indent) .. k .. ": "
    if type(v) == "table" then
      XTRACE(16, formatting)
      tprint(v, indent+4)
    elseif type(v) == 'boolean' then
      XTRACE(16, formatting .. tostring(v))
    else
      XTRACE(16, formatting .. v)
    end
  end
end

--------------------------------------------------------------------------------------------
function GetOperationResultByKeyInput(tool , operation_name, key)
--[[
		This function returns an error code of the manual operation depending on Key input
		See error code list in  ..\Tables\Templates\error_table_en.txt:
		// MANUAL CONFIRMATION: NOK CODES
			0=OK
			1000=CANCELED
			1001=NIO
			1002=SKIPPED
]]
	if key == 112 then return 0 end
	if key == 113 then return 1001 end

	return -1;  --invalid Key input --> continue operation
end

--------------------------------------------------------------------------------------------
connection_drivers = {}

function register_communication(Name, IP, Port, Param, State)
	Name = param_as_str(Name)
	local conn = {}
	conn.err_msg   = ''
	conn.err_code  = 0
	conn.seq       = 0
	conn.ip        = param_as_str(IP)
	conn.port	   = Port
	conn.param     = Param
	conn.state     = State
	conn.name	   = Name

	for k,v in pairs(connection_drivers) do
		if v.name == Name then
			connection_drivers[k] = conn
			return
		end
	end
	connection_drivers[ #connection_drivers + 1 ] = conn
end
--------------------------------------------------------------------------------------------

function communication_state(Name, State, ErrCode, ErrMsg, Seq)
	Name = param_as_str(Name)
	for k,v in pairs(connection_drivers) do
		if v.name == Name then
			lua_lock(Name)
			v.state = State
			v.err_code = ErrCode
			v.err_msg = param_as_str(ErrMsg)
			if (Seq ~= nil) and (Seq ~= 0) then v.seq = Seq end
			lua_unlock(Name)
			break
		end
	end
end

--------------------------------------------------------------------------------------------
