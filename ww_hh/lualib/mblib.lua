
ModbusCfgValues = {
	Param1_target = 0.0,
	Param1_min 	= 0.0,
	Param1_max 	= 0.0,
	Param2_target = 0.0,
	Param3_min 	= 0.0,
	Param3_max 	= 0.0,
	Prg 		= 0,
	Tool 		= 0,
	Tooltype 	= 0,   -- MODBUS Tool Type

}

ModbusResultValues 	= {
	Param1 		= 0.0,
	Param1_min 	= 0.0,
	Param1_max 	= 0.0,
	Param2 		= 0.0,
	Param2_min 	= 0.0,
	Param2_max 	= 0.0,
	Prg 		= 0,
	Tool 		= 0,
	Tooltype 	= 0,   -- MODBUS Tool Type
	QC 			= 1,   -- OK
	Seq 		= 0,
	Step 		= 'A1',
}

MBToolDef = { }

MBToolDef[0] =  {
					Scale1	    = 100,  -- scale factor for the first parameter (pressure)
					Scale2      = 10,   -- scale factor for the second parameter(temperature)
					Unit1		= 'Pa', -- first unit (pressure)
					Unit2		= '°C', -- second unit (temperature)
				}



------------------------------------------------

MBValues = { }
MBList 	 = {}
MBFmtImp = ''
mb = {}

function MBCreateJson(fmt)
	return string.format(fmt,
			param_as_str(mb[ 1]),param_as_str(mb[ 2]),param_as_str(mb[ 3]),param_as_str(mb[ 4]),param_as_str(mb[ 5]),param_as_str(mb[ 6]),param_as_str(mb[ 7]),param_as_str(mb[ 8]),param_as_str(mb[ 9]),param_as_str(mb[10]),
			param_as_str(mb[11]),param_as_str(mb[12]),param_as_str(mb[13]),param_as_str(mb[14]),param_as_str(mb[15]),param_as_str(mb[16]),param_as_str(mb[17]),param_as_str(mb[18]),param_as_str(mb[19]),param_as_str(mb[20]),
			param_as_str(mb[21]),param_as_str(mb[22]),param_as_str(mb[23]),param_as_str(mb[24]),param_as_str(mb[25]),param_as_str(mb[26]),param_as_str(mb[27]),param_as_str(mb[28]),param_as_str(mb[29]),param_as_str(mb[30]),
			param_as_str(mb[31]),param_as_str(mb[32]),param_as_str(mb[33]),param_as_str(mb[34]),param_as_str(mb[35]),param_as_str(mb[36]),param_as_str(mb[37]),param_as_str(mb[38]),param_as_str(mb[39]),param_as_str(mb[40]),
			param_as_str(mb[41]),param_as_str(mb[42]),param_as_str(mb[43]),param_as_str(mb[44]),param_as_str(mb[45]),param_as_str(mb[46]),param_as_str(mb[47]),param_as_str(mb[48]),param_as_str(mb[49]),param_as_str(mb[50]))
end


function fillNameList(list, str)

local cnt = 0;
local new_str = '';
local pattern = '$!'
local pos_beg = 0
local pos_end = 1
local pos_rep = 1

for i = 1,50,1 do mb[i] = nil end

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

------------------------------------------------
-- Get the tool specific scale factors for modbus <=> data mapping
-- @param tool: channel number as configured in station.ini
function GetModbusScaleFactors(tool)

	local tool_def = MBToolDef[tool]
	if tool_def == nil then tool_def = MBToolDef[0] end

	return tool_def.Scale1, tool_def.Scale2

end

------------------------------------------------
-- Get the tool specific measurement units for modbus <=> data mapping
-- @param tool: channel number as configured in station.ini
-- @output:  applicable only for the first two values (from 6)
function GetModbusUnits(tool)

	local tool_def = MBToolDef[tool]
	if tool_def == nil then tool_def = MBToolDef[0] end

	return tool_def.Unit1, tool_def.Unit2

end
------------------------------------------------
-- Get the tool specific result string

function GetModbusResultString(tool)

	local tool_def = MBToolDef[ModbusResultValues.Tool]
	if tool_def == nil then tool_def = MBToolDef[0] end

	local result = 'lua_error'

	local p1 = tonumber(ModbusResultValues.Param1)
	local p2 = tonumber(ModbusResultValues.Param2)

	if (p1 ~= nil) and (p2 ~= nil) then
		result = string.format('%.2f %s %.2f %s', p1, tool_def.Unit1, p2, tool_def.Unit2)
	end

	return result
end
------------------------------------------------
-- Get the tool specific result string

function GetModbusFooterString(tool)

	local result = 'lua_error'

	local p1 = tonumber(ModbusCfgValues.Param1_min)
	local p2 = tonumber(ModbusCfgValues.Param1_max)

	if (p1 ~= nil) and (p2 ~= nil) then
		result = string.format('Pressure (Pa) MAX=%.2f MIN=%.2f', p1, p2)
	end

	return result
end
------------------------------------------------
function GetModbusPrgString(tool)

	local result = 'lua_error'

	local p1 = tonumber(ModbusCfgValues.Prg)

	if (p1 ~= nil) then
		result = string.format('Prg %02d', p1 )
	end

	return result
end
------------------------------------------------

function CheckModbusLimits(tool, Val1, Val2)

	local result = -1

	local check_val = tonumber(Val1)

	local p1 = tonumber(ModbusCfgValues.Param1_min)
	local p2 = tonumber(ModbusCfgValues.Param1_max)

	if (p1 ~= nil) and (p2 ~= nil) and (check_val ~= nil) then
		check_val = check_val
		result = 1   		-- OK
		if p1 >= p2 then return 1 end -- not valid limits
		if check_val < p1 then result = 2 end -- too small
		if check_val > p2 then result = 8 end -- too big
	end

	return result
end

function ProcessParamList(Params) end

-------------------------------------
function MBGetParamList(t, st_res, part_res,bolt_res)

	MBValues.station_name 	= st_res.name
	MBValues.ip 			= st_res.host
	MBValues.time 			= string.format('%04d-%02d-%02d %02d:%02d:%02d',t.year,t.month,t.day,t.hour,t.min,t.sec)
	MBValues.id				= st_res.info
	MBValues.worker 		= st_res.worker
	--	st_res.master = master
	MBValues.job_name 	= part_res.name

	MBValues.bolt_name 	= bolt_res.name
	MBValues.tool_name 	= bolt_res.tool
	MBValues.tool_sn	= bolt_res.tool_sn
	MBValues.prg 		= bolt_res.prg
	MBValues.operation  = bolt_res.operation

	MBValues.values 	= {}
	MBValues.values1 	= bolt_res.torque
	MBValues.values2 	= bolt_res.angle
	MBValues.values3 	= bolt_res.torque_min
	MBValues.values4 	= bolt_res.torque_max
	MBValues.values5 	= bolt_res.angle_min
	MBValues.values6 	= bolt_res.angle_max

	MBValues.status 	= bolt_res.result
	MBValues.qc 		= bolt_res.qc
	MBValues.seq		= bolt_res.seq

	ProcessParamList(MBValues)


end
-------------------------------------
function MBGetJSON(station, part_seq,bolt_seq)

	if #MBFmtImp == 0 then
		MBFmtImp = fillNameList(MBList, MBFmt)
	end

	if #MBFmtImp == 0 then
		XTRACE(16, "invalid JSON format string")
	end

	local st_res = station_results[station]
	if st_res == nil then return nil,nil end
	local part_res = st_res.parts[part_seq]
	if part_res == nil then return nil,nil end
	local bolt_res = part_res.bolts[bolt_seq]
	if bolt_res == nil then return nil,nil end
	local t = os.date('*t') --	st_res.time

	MBGetParamList(t, st_res, part_res,bolt_res)

	for k,v in pairs(MBList) do mb[k] = MBValues[v] end

	local json = MBCreateJson(MBFmtImp)
	local file = string.format('MODBUS\\%04d%02d%02d%02d%02d%02d.json',t.year,t.month,t.day,t.hour,t.min,t.sec)

return json , file

end

