-----------------------------------------------------------------------------------------------
--  Company:    		"Haller + Erne GmbH"
--  Project: 			Sys3xxGateway service
--  File description:   Project-specific data structures and function
--  WARNING !!!         Do not edit this file.
-----------------------------------------------------------------------------------------------

-----------------------------------------------------------------------------------------------
--  parameters for Sys3xxGateway service with QWX output driver
-----------------------------------------------------------------------------------------------

service_name  = 'Sys3xxGateway'
--[[ 
 Data consumer have to be defined in custom.lua
 currently supported:
 data_consumer = 'heSQLClient'
 data_consumer = 'ToolsNetClient'
	data_consumer = 'Sciemetric Quality WorkX'  -- default
]]
data_consumer = 'heSQLClient'  --'heSQLClient'

heIPMDLL_settings = {

	-- IPM settings

	ipm_bind_port   = 22222,   --  -- port to bind to (default: '22222' = IPM)
	ipm_buffer_size = 32768,   -- 0x8000
	ipm_free_sockets= 500,     -- default: 500
	ipm_free_buffers= 500,     -- default: 500

}----------------------------------------------------------------------
heFTPDLL_settings = {

	-- FTP settings

	ftp_bind_addr   = '0.0.0.0',	--  interface to bind to (default = '0.0.0.0')
	ftp_bind_port   = 21,	--  port to bind to (default: '21' = FTP)
	ftp_buffer_size = 6553600,   		-- 0x640000
	ftp_timeout     = 10000,   		-- 10 seconds

}
----------------------------------------------------------------------
heQWXDLL_settings = {

	base_directory = [[C:\Sys3xx]], -- [[C:\Sys3xx]]  --

	--  QWX API: Warnings and errors
    -- 		tracing level: 0/1/2/3 � no/low/medium/high verbosity

	trace_level    = 0,
	trace_location = [[C:\QWX\LOG]],
	fifo_max_size  = 10000,
	AdvancedFolderSpecfication = 1,
	
}
heCRSDLL_settings = {
	job_timeout = 30	-- in sec --
}
----------------------------------------------------------------------

-- list of input drivers (nil - inactive / {}- active)

InputDrivers ['heIPM.dll'] = heIPMDLL_settings
InputDrivers ['heFTP.dll'] = heFTPDLL_settings
----------------------------------------------------------------------

-- list of output drivers (nil - inactive / {} - active)

OutputDrivers ['heQWX.dll'] = heQWXDLL_settings
----------------------------------------------------------------------

   -- QWX parameters and functions

---------------- db = database[name] ------------------------------------
database = {}
-------------------------------------------------------------------------
function param_as_str(param) if tostring(param) ~= 'nil' then return tostring(param) end return '' end

function create_database(dbserver, dbname, dbpass, dbuser)
	local a = {}
	a.dbserver = dbserver
	a.dbname   = dbname
	a.dbpass   = dbpass
	a.dbuser   = dbuser
    return a
end
-------------------------------------------------------------------------
--[[

	Default ID mask configuration rule in the Sys3xxGateway is as following:

	Part  serial        is 16 bytes( 1-16byte)
	Model/Part selector is 15 bytes(17-31byte)
	Bolt position       is  2 bytes(33-34byte)
	Operation counter   is  2 bytes(35-36byte)

]]

function qwx_id_parser(station_name, IDCode)

    local sernum 	= nil
    local model   	= nil
    local part	 	= nil

	local station = stations[station_name];

    if valid_str(IDCode) then
		sernum = string.sub(IDCode,1,16)
		if #IDCode >= 17 then
			model = string.sub(IDCode,17,31)
			part  =	model
		end
	end
	return sernum,model,part
end
-------------------------------------------------------------------------
function qwx_bolt_definition(station_name, IDCode)

    local bolt_pos = nil
    local op_count = "-1"

	local station = stations[station_name];

    if valid_str(IDCode) then
		if #IDCode >= 33 then bolt_pos = string.sub(IDCode,33,34) end
		if #IDCode >= 35 then op_count = string.sub(IDCode,35,36) end
	end

	return bolt_pos,op_count
end
-------------------------------------------------------------------------
function GetPartName(station_name, ID, ApplName)
    local sernum 	= nil
    local model   	= nil
    local part	 	= nil

	sernum,model,part = qwx_id_parser(station_name, ID)
	return part
end
-------------------------------------------------------------------------
ChannelNames = {}
ProgramNames = {}


function process_channel_name(ip, channel_name, rack,slot)

	local qwx_station = channel_name
	if valid_str(channel_name) then
		local len = #channel_name
		local n = string.find(channel_name, "|")
		if n and n > 0 then
			qwx_station  = string.sub(channel_name,1,n-1)
		    channel_name = string.sub(channel_name,n+1,-1)
		end
	end

	RegisterChannelName(ip, channel_name, rack,slot)
	return qwx_station
end
-------------------------------------------------------------------------
function RegisterChannelName(ip, channel_name, rack,slot)	
	
	if not valid_str(channel_name) then
		channel_name = string.format('Ch%02d.%d', rack,slot)
	end
	local Channels = ChannelNames[ip]
	if Channels == nil then
		ChannelNames[ip] = {}
		Channels = ChannelNames[ip]
	end
	local chn = rack * 8 + slot
	Channels[chn] = channel_name

--	LUA_XTRACE(XP.DEBUG, 'Channel name: [' .. (chn * 1000 ) ..'] ' .. channel_name,debug.getinfo(1))

end
-------------------------------------------------------------------------
function RegisterProgramName(ip, program_name, rack,slot, prg)

	if not valid_str(program_name) then return end
	local Programs = ProgramNames[ip]
	if Programs == nil then
		ProgramNames[ip] = {}
		Programs = ProgramNames[ip]
	end
	local chn = rack * 8 + slot
	Programs[chn * 1000 + prg] = program_name
--	LUA_XTRACE(XP.DEBUG, 'Program name: [' .. (chn *  1000 + prg) ..'] ' .. program_name,debug.getinfo(1))


end
-------------------------------------------------------------------------
function GetChannelAndProgramNames(ip, chn, prg)

--	LUA_XTRACE(XP.DEBUG, 'requested Channel/Program names: [' .. (chn *  1000 + prg) ..'] ',debug.getinfo(1))

	local channel_name
	local program_name
	local Channels = ChannelNames[ip]
	if Channels ~= nil then channel_name = Channels[chn] end
	local Programs = ProgramNames[ip]
	if Programs ~= nil then program_name = Programs[chn * 1000 + prg] end
	
--	LUA_XTRACE(XP.DEBUG, 'found Channel/Program names: [' .. (chn *  1000 + prg) ..'] ' .. channel_name .. ' | ' ..program_name,debug.getinfo(1))

	return channel_name,program_name

end
-------------------------------------------------------------------------
function GetBoltNameEx (ip, id, channel_name, program_name, bol_name, app, chn, prg)

	local n = 0
	if valid_str(channel_name) then
		n = string.find(channel_name, "|")
	end
	-- register channel name only if this is not NEXO (combination of Station|Channel names)
	if n == nil or n == 0 then RegisterChannelName(ip, channel_name, math.floor(chn/8),chn%8)	end
	RegisterProgramName(ip, program_name, math.floor(chn/8),chn%8, prg)

	return nil

end
-------------------------------------------------------------------------
function GetStation (	ip,idcode,
						channel_name,appl_name,
						location_name1,
						location_name2,
						location_name3,
						location_name4,
						location_name5,
						location_name6,
						location_name7,
						location_name8,
						rack,slot )


	-- define station name and short name

	local qwx_station = process_channel_name(ip,channel_name, rack,slot)
	if valid_str(location_name3) then qwx_station = location_name3 end
	
	local station_name
	if valid_str(qwx_station)
		then station_name = string.format('%s:%s',qwx_station,ip)
		else station_name = ip end

	local qwx_part_type = location_name1
	local section       = location_name2
	local dbconnection  = location_name4;

--	create new station

	local station = {}

	-- define mandatory station parameters: ip,name,line
	
	station.ip   = ip
 	station.name = station_name
	if valid_str(section)
		then station.line = section
	    else station.line = 'undefined' end -- default value, it can be overridden later

    -- here define station parameters, that can be overridden from custom configuration

	station.qwx_station = qwx_station
	station.part_type   = qwx_part_type
	station.dbconnection= dbconnection
	station.application = 'QWXApplication'
--	station.part_leave_timeout_sec = 15   -- in seconds
	station.part_leave_timeout = 1 -- in minutes
	
	if station.line == 'undefined' and not valid_str(station.dbconnection) then
		station.dbconnection = 'default'
	end

	-- end

	-- complete missing station parameters from custom confuguration table
	-- existing parameters can be overridden

	CompleteStationWithCustomCfg(station)

	-- Check whether the station with given name exists already

	if stations[station.name] ~= nil then return station.name end

	-- here define station parameters, that cannot be overridden from custom configuration
	--
	-- end

	-- check database connection

	if not valid_str(station.dbconnection) then  -- invalid db connection!
		LUA_XTRACE(XP.ERROR, 'Invalid database connection name',debug.getinfo(1))
		return nil
	end
	if database[station.dbconnection] == nil then   -- unknown db connection!
		LUA_XTRACE(XP.ERROR, string.format('Database connection name "%s" not found', station.dbconnection),debug.getinfo(1))
		return nil
	end

--	register new station

	stations[station.name] = station

	-- report parameters of new station to C++ Core

	for k,v in pairs(station) do
		set_station_properties(k,v)
	end

	return station.name

end
-------------------------------------------------------------------


