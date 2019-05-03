XTRACE(16, "Loading barcode.lua...", "barcode.lua", 1)
------------------------------------------------------------------------------------------
--[[
They will scan in two barcodes:

•	Motor Part number (MPN)
o	142U3B205BARAA165240 (14 to 28 characters)
•	Motor Serial Number (MSN)
o	190812345 or 190812345-1 (9 or 11 characters)
These two fields should be concatenated and passed on to the family selection in OGS.

]]

function sanitize(val)
	if val ~= nil then return tostring(val) end
	return ''
end

function BarCode_Init()

	barcodes[1] = { tag=1, name="Part Type",   raw="", val="", source="", len=28, required=1, desc="MPN", row=1, width=28 }
	barcodes[2] = { tag=2, name="Serial Number", raw="", val="", source="", len=11, required=1, desc="MSN", row=1, width=11}

	barcode_changed      = 0
	barcode_first_change = 0
	assembly_in_process  = 0

	return barcodes
end
--------------------------------------------------------------
function BarCode_CheckTag(tag, value)
	local val = sanitize(value)
	if tag == 1 then
		if #val >= 14 and #val <= 28 then return 1 end
	end
	if tag == 2 then
		if #val == 9 or #val == 11 then return 1 end
	end
	return nil
end
-------------------------------------------------------------
function BarCode_AddNew(source, name, rawCode)
	-- return the "tag" value if a valid barcode was given
	-- else return an error code (value < 0)
	-- if successful, update the global barcodes table val element
	-- NOTE: the "source" parameter indicates the driver issuing the
	--       AddNew command , e.g. "SignalR", "Scanner", "Keyboard"
	rawCode = sanitize(rawCode)
	if source == 'Scanner' then

		val = rawCode
		if  BarCode_CheckTag(1, val) then
			Barcode_SetFirstIfTblEmpty()
			barcodes[1].raw = val
			barcodes[1].val = val
			barcodes[1].source = source
			return 1
		end
		if  BarCode_CheckTag(2, val) then
			Barcode_SetFirstIfTblEmpty()
			barcodes[2].raw = val
			barcodes[2].val = val
			barcodes[2].source = source
			return 2
		end

	elseif source == 'Rfid' then
		-- forward to user logon
		UserManager.RfidLogon(rawCode)
	elseif source == 'GUI' then
		return BarCode_InsertByName(source, name, rawCode)
	end
	-- unknown source
	return 0
end

-------------------------------------------------------

function BarCode_Check(tag, code)
	-- return true, if the "code" given for the specific "tag" is an allowed value
	-- if successful, update the global barcodes table val element

	rawCode = sanitize(code)
	val = rawCode
	if  BarCode_CheckTag(tag, val) then
			Barcode_SetFirstIfTblEmpty()
			barcodes[tag].raw = val
			barcodes[tag].val = val
			barcodes[tag].source = ''
			return tag
		end
	return 0

end
-------------------------------------------------------------------------
--These function concatenates two fields 'MPN'+'MSN' and passes they to the family selection in OGS.
function BarCode_GetPartID()
	local str = ''
	local v1 = param_as_str(barcodes[1].val)  -- 'MPN'
	local v2 = param_as_str(barcodes[2].val)  -- 'MSN'

	if  BarCode_CheckTag(1, v1)  and
		BarCode_CheckTag(2, v2)  then
		str = TrimOrFill( v1, 28, ' ')  .. TrimOrFill( v2, 11, ' ')
	end
	return str

end
----------------------------------------------------------------------
function BarCode_GetCSVFilename()
	local v1 = param_as_str(active_barcodes[1].val)  -- 'MPN'
	return v1 .. '.csv'
end

--[[
The 64 byte ID string needs to be constructed as follows:

AAAAAAAAAAAAAAAAAAAAAAAAAAAABBBBBBBBBBBCCCCCCCCDDDDDDDDDDDDEEEFF

A – 28 characters for MPN
B – 11 characters for MSN
C – 8 characters for OPERATOR. This is the 8 characters scanned in on RFID, or the one detailed in the station.ini if the user logs on with their name and password.
D – 12 characters for the JOB NAME
E – 3 characters for the BOLT NAME
F – 2 characters for the OPERATION NUMBER

The script needs to either pad out short strings or cut long strings to fit the map.
For example a JOBNAME of ILIE-IS-A-TERRIBLE-CODER should be ILIE-IS-A-TERRIBLE-C
If the scanned MSN is “123ABC789“ it should be “   123ABC789”

]]

--These function returns combined Motor Part number (MPN) and
-- Motor Serial Number (MSN) for result ID Code (Database ID)
function BarCode_CheckPartID(barcode_tbl)

	local str = ''
	local v1 = param_as_str(barcode_tbl[1].val)  -- 'MPN'
	local v2 = param_as_str(barcode_tbl[2].val)  -- 'MSN'

	if  BarCode_CheckTag(1, v1)  and
		BarCode_CheckTag(2, v2)  then
		str = TrimOrFill( v1, 28, ' ')  .. TrimOrFill( v2, 11, ' ')
	end
	return str

end
----------------------------------------------------------------------
function BarCode_GetOperationID(CurrOp, CurrPartID)

	local JobName  = TrimOrFill( CurrOp.JobName, 12, ' ')				--	[6-25]
	local UserID = TrimOrFill( UserManager_GetCurrentUserID(), 8, ' ') 	--	[33_40]
	local BoltOp = string.format('%s%02d', TrimOrFill(CurrOp.BoltName,3,'_'), CurrOp.Number)
	return string.format('%s%s%s%s', CurrPartID, UserID, JobName, BoltOp)

end
------------------------------------------------------------------------------------------

