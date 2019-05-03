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


reg = require("lualib/registry")

--[[
 str = ''

 a =  TrimOrFillLeft(str, 3, '0')aaa.

 b = tonumber(a)

pr

local tbl = reg.getkey('HKEY_LOCAL_MACHINE\\SOFTWARE\\WOW6432Node\\Haller + Erne GmbH\\Worker guidance')

local values
if tbl ~= nil then
	values = tbl.values
end

if values ~= nil then
	for name , aaa in pairs(values) do
		print( 	aaa.value .. '  ' .. aaa.type .. ' ' .. aaa.name)
	end

end

]]



----------------------------------------------------------------------
function BarCode_GetOperationID(CurrOp, CurrPartID)

	local JobName  = TrimOrFillLeft( CurrOp.JobName, 12, ' ')				--	[6-25]
	local UserID = '' --TrimOrFillLeft( UserManager_GetCurrentUserID(), 8, ' ') 	--	[33_40]
	local BoltOp = string.format('%s%02d', TrimOrFillLeft(CurrOp.BoltName,3,'0'), CurrOp.Number)
	return string.format('%s%s%s%s', CurrPartID, UserID, JobName, BoltOp)

end
------------------------------------------------------------------------------------------

				local CurrOp = { JobName = "                ", BoltName = "               ", Number = 0, Total = 0, Loosen = 0, ByHandAck = 0 }
				ID = BarCode_GetOperationID(CurrOp, "                            ")


print (ID)
