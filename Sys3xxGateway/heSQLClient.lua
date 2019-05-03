require('sys3xx')

function trim(s)   return s:match "^%s*(.-)%s*$" end

replace_empty_idcode='empty'

event = {}

function LuaDecodeEvent()


	local EventType = 0
	local Station 	= event.station_short
	local User 	= trim(string.sub(event.id,41,59))
	local SParam 	= ''
	local IParam 	= 0
	local FParam 	= 0.0
	local Desc 	= ''

 	if event.type == 'Logon' then
		EventType = 1
	end

	if event.type == 'Leave' then
		EventType = 2
		FParam = event.act   -- takt
		if event.total == 1 then
			IParam = 1   -- OK completed
		else
			IParam = 0   -- NOK or not completed
		end
		
		SParam = trim(string.sub(event.id,1,27)) 

	end

	if (string.find(event.type, 'Barcode:') == 1) then
		EventType = 3
		SParam = string.sub(event.type, 9,-1)
		Desc   = event.id
		if event.total == 1 then
			IParam = 1   -- OK completed
		else
			IParam = 0   -- NOK or not completed
		end
	end
	
	return Desc,FParam,IParam,SParam,User,Station,EventType

end


 --[[

	// line parameters
    Properties["line"]        = LineObj.Name ;
    Properties["line_short"]  = LineObj.Short;
    Properties["line_number"] = LineObj.Num;

	// write station parameter set
    Properties["station"]       = StaObj.Name;
    Properties["station_short"] = StaObj.Short;
    Properties["station_number"]= StaObj.Num;
    Properties["station_ip"]    = BoltObj.IP;

    // write part parameter set
    Properties["part"]   = PartObj.Name;
    Properties["part_short"]  = PartObj.Name;
    Properties["part_number"] = PartObj.Num;
    Properties["model"]   = PartObj.QWXModel;
    Properties["part_type"]   = PartObj.QWXPartType;
    Properties["id"] = BoltObj.Id;
    Properties["type"] = PartObj.Short;  // event type as string

    // write Bolt parameter set
    Properties["bolt"]          = BoltObj.Name;
    Properties["bolt_short"]    = BoltObj.Short;
    Properties["bolt_number"]   = BoltObj.Num;
    Properties["spindle"]       = BoltObj.Spindle;
    Properties["channel"]       = BoltObj.Chn;
    Properties["prg"]           = BoltObj.Prg;
    Properties["total"]         = BoltObj.PTotal;
    TDateTime DateTime 			= FileTimeToDateTime(BoltObj.Td);
    Properties["date"]          = FormatDateTime("yyyy-mm-dd", DateTime);
    Properties["time"]          = FormatDateTime("hh:nn:ss", DateTime);
    Properties["seq"]           = BoltObj.Lz;

    // first step params only

    Properties["step"]          = DocuObj.Name;  // Bosch step name (3A/12A)
    Properties["step_number"]   = DocuObj.Num;
    Properties["category"]      = DocuObj.sk;
    Properties["qc"]            = DocuObj.QC;
    Properties["category"]      = DocuObj.sk;

    // first characteristic only
    Properties["char"]  = CharObj.ID;
    Properties["min"]   = CharObj.Min;
    Properties["max"]   = CharObj.Max;
    Properties["act"]   = CharObj.Act;
    Properties["target"]= CharObj.Target;
    Properties["ref"]   = CharObj.Ref;

]]
