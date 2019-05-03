-----------------------------------------------------------------------------------------------
--  Company:    		"Haller + Erne GmbH"
--  Project: 			Sys3xxGateway service
--  File description:   Project LUA interface
--  WARNING !!!         Do not edit this file.
-----------------------------------------------------------------------------------------------


GlobalSettings = {

report_base_directory = os.getenv('AllUsersProfile') .. '\\Haller + Erne GmbH\\Sys3xxCSS',

result_cash_size    = 0x200000,
result_cash_timeout = 10000,
result_cash_max     = 100,
}

InputDrivers  = {}
-- list of available input drivers (state from 13.08.2013)
--InputDrivers ['heFTP.dll'] = {}
--InputDrivers ['heIPM.dll'] = {}
--InputDrivers ['heCRS.dll'] = {}

OutputDrivers = {}
-- list of available output drivers (state from 13.08.2013)
--OutputDrivers['heCSS.dll'] = {}
--OutputDrivers['heQWX.dll'] = {}
--OutputDrivers['heTXT.dll'] = {}

-- Global objects

step = {}

	step.qc 	= nil  -- quality code
    step.dp    	= nil  -- docu buffer number
	step.type  	= nil  -- step category
	step.step  	= nil  -- Bosch step identifier
	step.name   = nil  -- used for verification step only
	step.repeat_cycle = 1;  -- now uses 1 as the default

char = {}

	char.short  	= nil
    char.unit   	= nil
    char.min    	= nil
    char.max    	= nil
    char.target    	= nil
	char.act       	= nil
    char.ref    	= nil
    char.use_ref  	= nil  -- switcher between char.act and char.ref by the output for the verification study

---------------- station = station[index] ------------------------------------

stations = {}

--[[
---------------- part = parts[seq] ------------------------------------

			-- common properties

part.rawid
part.code	       	(see selected "_id_parser_..." function)
part.type			(see selected "_id_parser_..." function)
part.variant		(see selected "_id_parser_..." function)
part.serial_number  (see selected "_id_parser_..." function)
part.selector

part.line
part.line_number
part.line_short

part.station			(catalog item description)
part.station_number     (catalog item index)
part.station_short      (catalog item name)

part.name
part.short
part.number

   -- Verification part properties

part.ems_type 	= nil  (standard production - nil, EMS Study 1 - "1", EMS Study 1A - "1A")
part[seq].study_counter

------------------ bolt = bolts[seq] -------------------------------

bolt.part               - part table of the given bolt

bolt.number
bolt.name
bolt.short
bolt.rawid
bolt.position

bolt.prg
bolt.app

bolt.spindle_number
bolt.spindle_short
bolt.spindle_id

bolt.time
bolt.prg_version
bolt.pri
bolt.red
bolt.torque_decimal

	--  bolt properties by Verification study

bolt.RSSerno1
bolt.RSSerno2
bolt.act_angle = nil  (if EMS Study 1 then standard actual value, else nil)
bolt.act_torque= nil  (if EMS Study 1 then standard actual value, else nil)


]]------------------------------------------------------------------------

--//////////////////////////////////////////////////////////////////////
--                         Special functions                     --
--//////////////////////////////////////////////////////////////////////

function dump(bolt)

	for k,v in pairs(bolt) do
		log_print("bolt[" .. k .. "]=" .. v)
	end
end

function set_length(s,len)
    if s == nil then s = '' end
    local a = string.sub(s,1,len)
	while (string.len(a) < len) do
		a = '0' .. a;
	end
	return a;
end

function valid_str(a) return (type (a) == 'string') and (#a ~= 0) end

--//////////////////////////////////////////////////////////////////////
--             Inteface between C++ and Lua code
--//////////////////////////////////////////////////////////////////////
-- message types (parameter msg_type):
XP= {
		FATAL  =	  -1,  -- emergency
		ERROR  =	0x01,  -- alert? critical?
		WARN	 =	0x02,  -- warning
		DIAG1  =	0x04,  -- Information/Notice
		DIAG2  =	0x08,  -- Information/Verbose
		DEBUG  =	0x10,  -- debug level
	}

function LUA_XTRACE(msg_type, msg, debug_info)
	if type(debug_info)=="table" then
		XTRACE(msg_type, msg, debug_info.short_src,debug_info.currentline);
	else
		XTRACE(msg_type, msg, 'lua code',0);
	end
end
------------------------------------------------------------
function GetParamsByTableName(TableName)

	if type(_G[TableName])=="table" then
		for k,v in pairs(_G[TableName]) do
			set_properties_by_tablename(k,v)
		end
	end
end
------------------------------------------------------------
function GetParamsFromIndexedTable(TableName, Index)

	local tbl = _G[TableName]
	if type(tbl)=="table" then
		tbl = tbl[Index]
		if type(tbl)=="table" then
			for k,v in pairs(tbl) do
				set_properties_by_tablename(k,v)
			end
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


--//////////////////////////////////////////////////////////////////////
--                      ID code parse functions                     --
--//////////////////////////////////////////////////////////////////////
----------------------------------------------------------------------------
function GetPartName(StationName, ID, ApplName)
	if valid_str(ApplName) then return ApplName end
	return 'Part1'
end
----------------------------------------------------------------------------
function _id_parser_gm(part, IDCode)

    part.rawid = IDCode
	part.serial_number = IDCode
	part.code = IDCode
    part.type   = nil
    part.variant= nil
    local n

    if valid_str(IDCode) then
		n = string.find(IDCode, "_")
		if n and n > 0 then
		    part.serial_number = string.sub(IDCode,1 ,n-1)
			part.code          = string.sub(IDCode,n+1,-1)
			IDCode             = part.code
		end
	end

	if valid_str(IDCode) then
		n = string.find(IDCode, "_")
		if n and n > 0 then
			part.code = string.sub(IDCode,1, n-1)
		    part.type = string.sub(IDCode,n+1,-1)
			IDCode    = part.type
		end
	end

	if valid_str(IDCode) then
		n = string.find(IDCode, "_")
		if n and n > 0 then
		    part.type    = string.sub(IDCode,1, n-1)
		    part.variant = string.sub(IDCode,n+1,-1)
		end
	end

end
----------------------------------------------------------------------------
--//////////////////////////////////////////////////////////////////////
-- default GetStation(...) function : all station names are created on base of its IP adresses
--//////////////////////////////////////////////////////////////////////
----------------------------------------------------------------------------
function GetStation (	ip,idcode,
						channel_name,bolt_name,
						location_name1,
						location_name2,
						location_name3,
						location_name4,
						location_name5,
						location_name6,
						location_name7,
						location_name8,
						rack,slot )

--	create new station

	local station = {}

	-- define mandatory station parameters: ip,name,line

	station.ip        = ip
 	station.name      = ip       -- default value, it can be overridden later
	station.line      = 'default' -- default value, it can be overridden later

    -- here define station parameters, that can be overridden from custom configuration
    --
	-- end

	-- complete missing station parameters from custom confuguration table
	-- existing parameters can be overridden

	CompleteStationWithCustomCfg(station)

	-- check if the station with given name already exists

	if stations[station.name] ~= nil then return station.name end

	-- here define station parameters, that cannot be overridden from custom configuration
	--
	-- end

--	register new station

	stations[station.name] = station

	-- report parameters of new station to C++ Core

	for k,v in pairs(station) do
		set_station_properties(k,v)
	end

	return station.name

end

----------------------------------------------------------------------------
--//////////////////////////////////////////////////////////////////////
-- Function:	CompleteStationWithCustomCfg(station)
-- 	check if custom confuguration table is active
-- 	copy parameters from custom confuguration table into station definition
-- 	override existing parameters

--//////////////////////////////////////////////////////////////////////
----------------------------------------------------------------------------

function CompleteStationWithCustomCfg(station)

	if custom_cfg_table == nil then return end

	-- complete station definition with custom parameters using 'station.ip' as key
	-- override existing parameters
	local station_desc = custom_cfg_table[station.ip]
	if station_desc then
		for k,v in pairs(station_desc) do
			station[k] = v
		end
	end

	-- complete station definition with line parameters using 'station.line' as key
	if custom_cfg_line == nil then return end
	if station.line    == nil then return end
	local line_desc = custom_cfg_line[station.line]
	if line_desc       == nil then return end
	-- do not override existing parameters
	for k,v in pairs(line_desc) do
		local overwrite = false
		local param = station[k]
		if param == nil
			then overwrite = true
			else
				if 	type(param) == 'string' and #param == 0
				then overwrite = true end
			end
		if overwrite == true then station[k] = v end
	end

end

----------------------------------------------------------------------
--//////////////////////////////////////////////////////////////////////
--         GetCurveFileName ( called from project core )             ----
--//////////////////////////////////////////////////////////////////////
function GetCurveFileName(
    -- station params		  tightening result			          time stamp
	     Name,IP,		IDCode,Rack,Slot,Prg,Seq,QC,	Year,Month,Day,Hour,Minute,Second,IDSeq)
	if IDSeq == nil then IDSeq = '000' end
	local FileName = string.format('%s\\Ch%02d.%d\\Seq%08d.qrv',IP,Rack,Slot,Seq)
	return FileName
end
--//////////////////////////////////////////////////////////////////////
--         common event handler ( called from project )             ----
--//////////////////////////////////////////////////////////////////////




function add_to_log(str)

end

function __start()

end

function __finish()

end


--///////////////////////////////////////////////////////////////////////////////////////////////////////////////
