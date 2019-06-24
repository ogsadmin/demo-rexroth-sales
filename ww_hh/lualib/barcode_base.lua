------------------------------------------------------------------------------------------
-- Barcode handling
--
-- Notes:
--  - barcodes now basically allow .len as table, e.g. .len={4,6}.
--    WARNING: this is only partially working at the moment, not all functions 
--             and the OGS backend correctly work yet.
--  - 

barcodes = {}
active_barcodes = {}
barcode_changed = 0
action_barcode = ''
action_barcode_length = 4

function sanitize(val)
	if val ~= nil then return tostring(val) end
	return ''
end
--[[ must be implemented in customer barcode.lua (except Barcode_Init is implemented, see below)
function Barcode_InitTable()
	-- Fields to set for barcodes:
    --   .name      Name as shown in the OGS GUI
    --   .len       Max. length of field (might (later) be a table). Note that this should
    --              be set to the maximum with of the ID if used for variable field lengths
    --   .required  Set to 1 if this is a required field
    --   .desc      Descriptive text, unused so far
    --   .row       Display layout in OGS GUI, set row
    --   .with      Display layout in OGS GUI, set relative with (of all fields in the same row)
	-- 
	barcodes[1] = { name="Materialnummer", len=10, required=1, desc="MNR", row=1, width=10 }
	barcodes[2] = { name="Seriennummer",   len=8,  required=1, desc="SNR", row=1, width=8  }
end
]]--
--[[ might be implemented in customer barcode.lua
function BarCode_Init()
	-- might call back into some configuration to get barocde settings
	-- or simply define what is needed here.
	-- .raw is the actual barcode received from the scanner source
	-- .val is the processed value, i.e. the display value
	-- .width is a relative value to calculate a real width of the field to display:  real_width[i] = real_common_width * ( width[i]) / SUM(width[1...n] )
	barcodes[1] = { name="Part ID", len=7, required=1, desc="Part ID",	row=1, width=7 }

	barcode_changed      = 0
	barcode_first_change = 0
	assembly_in_process  = 0

	return barcodes
end
]]
-- New: instead of BarcodeInit, customer should implement Barcode_InitTable in barcode.lua.
-- As a fallback (for backwards compatibility) Barcode_Init() may still be overridden in 
-- barcode.lua (as this is loaded after this file) - but is not recommended.
function BarCode_Init()

	-- let customer fill the table
	Barcode_InitTable()
	-- fill in the redundant data
	for k, v in pairs(barcodes) do
		if v.tag == nil then
            v.tag = k			-- by default v.tag = array index (key)
        end
		if v.raw ~= "" then		-- if raw does not exist or is non-empty, then reset it
            v.raw = ""			
        end
		if v.val ~= "" then		-- if val does not exist or is non-empty, then reset it
            v.val = ""			
        end
		if v.source ~= "" then	-- if source does not exist or is non-empty, then reset it
            v.source = ""			
        end
		-- create the reverse lookup for length
		v.len_set = {}
		if type(v.len) == "table" then
			for _,l in pairs(v.len) do v.len_set[l] = true end
		else
			v.len_set[v.len] = true
		end
	end
	
	barcode_changed      = 0
	barcode_first_change = 0
	assembly_in_process  = 0
	return barcodes
end


function Barcode_SetFirstIfTblEmpty()

	barcode_changed = 1
	for k, v in pairs(barcodes) do
		local val = param_as_str(#v.val)
		if (#val > 0 ) then
			barcode_first_change = 0
			return
		end
	end
	barcode_first_change = 1
	barcode_changed = 1

end
----------------------------------------------------------
function BarCode_CheckTag(tag, value)
	local val = sanitize(value)
	if barcodes[tag].len_set ~= nil then
		if barcodes[tag].len_set[#val] ~= nil then
			return 1	-- the length is in the set
		end
	elseif type(barcodes[tag].len) == "table" then
		for k,v in pairs(barcodes[tag].len) do 
			if #val == v then
				return 1	-- found length  in the array
			end
		end
	else
		if #val == barcodes[tag].len then
			return 1
		end
	end
	return nil
end
----------------------------------------------------------
function BarCode_AddNew(source, name, rawCode)
	-- return the "tag" value if a valid barcode was given
	-- else return an error code (value < 0)
	-- if successful, update the global barcodes table val element
	-- NOTE: the "source" parameter indicates the driver issuing the
	--       AddNew command , e.g. "SignalR", "Scanner", "Keyboard"
	rawCode = sanitize(rawCode)
	if source == 'Scanner' then
		-- by default map scanned barcodes by length of the configured fields
		for k, v in pairs(barcodes) do
			if BarCode_CheckTag(v.tag, rawCode) ~= nil then
				Barcode_SetFirstIfTblEmpty()
				v.raw = rawCode
				v.val = rawCode
				v.source = source
				return v.tag
			end
		end
		-- not found:
		return 0
	elseif source == 'SignalR' then
		-- SignalR
		if name == "ITEM" and #rawCode == 7 then
			rawCode = rawCode .. ' '
		end
		return BarCode_InsertByName(source, name, rawCode)
	elseif source == 'Rfid' then
		-- forward to user logon
		UserManager.RfidLogon(rawCode)
		return 0
	elseif source == 'GUI' then
		name = param_as_str(name)
		if name == '' then
			-- barcode scanner in "keyboard" mode to accept master account for temporary privilege operation (Thailand Triumph)
			UserManager.GUILogon(rawCode)
			return 0
		end
		return BarCode_InsertByName(source, name, rawCode)
	else
		-- unknown source
		return 0
	end
end

function BarCode_InsertByName(source, name, rawCode)
	rawCode = sanitize(rawCode)

	if name == 'action_barcode' then
		-- Tool of type BARCODE_READER
		local s = param_as_str(rawCode)
		action_barcode = s
		Barcode_LastCode = s
		return 1
	end

	for k, v in pairs(barcodes) do
		if v.name==name then
			v.raw    = rawCode
			v.val    = rawCode
			v.source = source
			barcode_changed = 1
			return k
		end
	end
	return 0
end


function match_mask(mask,str)

	mask = param_as_str(mask)
	str = param_as_str(str)

	if #mask ~= #str then return false end
	if #mask == 0 then return false end

	local ignor1 = string.byte("?")
	local ignor2 = string.byte("_")

	for idx = 1, #str do
		local b = mask:byte(idx)
		if  (b~= ignor1) and b ~= ignor2 and b ~= str:byte(idx) then
		return false end
	end
	return true
end

local lastMask = ""
function BarCode_GetLastMask()
	return lastMask
end

function BarCode_GetActionBarcode(mask)

-- return values:  status (-1 - NOK, 0 - no result, 1 - OK), current bar code

	local barcode = param_as_str(action_barcode)
	action_barcode = ''   -- clear after each function call
	if #barcode == 0 then return 0, '' end  -- barcode is not available
	mask = param_as_str(mask)
	if #mask == 0 and #barcode == action_barcode_length then
		return 1, barcode -- return barcode that matches length (without mask)
	end

	if (match_mask(mask, barcode)) then
		return 1, barcode  -- valid barcode
	end

	return -1, barcode    -- invalid barcode

end

function BarCode_CheckByName(source, name)

local value  = ''
	for k, v in pairs(barcodes) do
		if (not valid_str(source)) or (v.source == source)  then
			local val = param_as_str(v.val)
			if (v.name==name) and valid_str(v.val) and (#val == v.len) then
				source   = v.source
				if v.raw == '$cancel$' then
					    value = v.raw
				else 	value = v.val end
				v.val    = ''
				v.source = ''
				v.raw    = ''
				return k, source, value
			end
		end
	end
	return 0, source, value
end


function BarCode_Check(tag, code)
	-- return true, if the "code" given for the specific "tag" is an allowed value
	-- if successful, update the global barcodes table val element

	-- TODO: process the "raw" code into a value
	local rawCode = sanitize(code)
	local val = rawCode
	local ret = 0
	for k, v in pairs(barcodes) do
		if (tag == v.tag) then
			if  (#rawCode==v.len)  then
				Barcode_SetFirstIfTblEmpty()
				v.raw = rawCode
				v.val = val
				ret = 1
			else
				-- clear barcode in internal cache on error
				barcodes[tag].raw = ""
				barcodes[tag].val = ""
			end
			break; -- tag found and processed
		end
	end
	return ret

end

function BarCode_GetChangeflag()
	return barcode_changed
end

function BarCode_ResetChangeflag()
	barcode_changed = 0
	barcode_first_change = 0
end

function BarCode_GetMerged()
	-- return the merged string
	-- add padding for missing parts of the code such that the resulting
	--     string is always fixed length

	local str = '['

	for k, v in pairs(barcodes) do
		str = str .. TrimOrFill(v.val, v.len, '_') .. '#'
	end

	return str .. ']'


end

function BarCode_GetPartID()
	return BarCode_CheckPartID(barcodes)
end

function BarCode_CheckPartID(barcode_tbl)

	-- return the relevant portion of the ID-code for Part ID matching/lookup
	-- Also indicates whether *all* barcodes as expected are available...

	-- require the 'ITEM', 'FON' and one of either VIN or EIN
	local some_of_not_required_exists = 0
	local number_of_not_required      = 0


	local str = ''

	for k, v in pairs(barcode_tbl) do
		local val = param_as_str(v.val)
		XTRACE(16, "   barcode["..k.."] name='"..param_as_str(v.name).."' val='"..val.."' raw='"..param_as_str(v.raw).."'")

		if v.required == 0  then
			number_of_not_required = number_of_not_required + 1
			if  BarCode_CheckTag(v.tag, val) ~= nil then
				some_of_not_required_exists = 1
			end
		end

		if BarCode_CheckTag(v.tag, val) ~= nil then
			str = str .. v.val
		elseif v.required == 1 then
			return ''  -- error
		else
			str = str .. TrimOrFill(val, v.len, '_')
		end
	end

	if (number_of_not_required == 0) or (some_of_not_required_exists == 1) then
		return str
	else
		return ''  -- error
	end

end

function BarCode_Reset()
	-- Reset all values to empty
	for k, v in pairs(barcodes) do
		v.raw=""
		v.val=""
	end
	barcode_changed = 1
	barcode_first_change = 0
end

function BarCode_GetTable()
	-- return the barcode table
	return barcodes
end

function Barcode_StartAssembly()

	assembly_in_process = 1
	active_barcodes = CloneTable(barcodes)
end

function Barcode_StopAssembly()

	assembly_in_process = 0
	active_barcodes = {}

end
----------------------------------------------------------------------
function BarCode_GetOperationID(CurrOp, CurrPartID)

-- now ID code is limited to 40 sings:
-- CurrOp 																		[1-5]
	local JobName  = TrimOrFill( CurrOp.JobName, 20, '-') 					--	[6-25]
	local BoltOp															--	[26-32]
	local Username = TrimOrFillLeft( UserManager_GetCurrentUser(), 8, ' ') 	--	[33_40]
    if  CurrOp.Loosen == 0 then
		BoltOp = string.format('%s_%02d%02d', TrimOrFillLeft(CurrOp.BoltName,2,'0'), CurrOp.Number, CurrOp.Total)
	else
		BoltOp = string.format('%s_%02d%02d', TrimOrFillLeft(CurrOp.BoltName,2,'0'), CurrOp.Number, 0)
	end
	return string.format('%s%s%s%s', CurrPartID, JobName, BoltOp, Username)

end
------------------------------------------------------------------------------------------

