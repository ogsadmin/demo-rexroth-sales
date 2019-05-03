

-------------------------------------------------------------------------------------------------
UserManager = { user = nil, user_level = 0, master = "", master_level = 0, autologon = 0,
                user_id = nil,  master_id = nil,  last_valid_id = nil, timer = os.clock()} -- , id_lenght = 11

function UserManager_UpdateStatus(user, user_level, master, master_level, autologon, user_id, master_id)
	local changed = false;
	local currUser = ""
	if UserManager.user ~= user or UserManager.master ~= master then
		-- logon state changed
		changed = true
		if master ~= nil and #master > 0 then
			currUser = master
		else
			currUser = user
		end
	end


	UserManager.user = user
	UserManager.user_level = user_level
	UserManager.master = master
	UserManager.master_level = master_level
	UserManager.autologon = autologon
	UserManager.user_id = user_id
	UserManager.master_id = master_id

	if changed then
		-- NOTE: SendFTP requires updated UserManager table data!
			XTRACE(16, "RfidLogon: changed")
		if Lua_SendFTP ~= nil then
			XTRACE(16, "RfidLogon: SendFTP")
			local ID
		    if assembly_in_process == 1 then
				ID = GetIDCode()
			else
				local CurrOp = { JobName = "                ", BoltName = "               ", Number = 0, Total = 0, Loosen = 0, ByHandAck = 0 }
				XTRACE(16, "GetOperationID")
				ID = BarCode_GetOperationID(CurrOp, "                            ")
				XTRACE(16, "GetOperationID OK")

			end
			XTRACE(16, "Lua_SendFTP")
			Lua_SendFTP('Logon', param_as_str(ID), 1, param_as_str(currUser))  -- event name, error code, param1
			XTRACE(16, "Lua_SendFTP OK")
		end
	end
end
--------------------------------------------------------------------------------------------
function UserManager_GetCurrentUser()

	if (UserManager.master ~= nil) and  (#UserManager.master ~= 0) then
		return UserManager.master
	end
	return UserManager.user

end
--------------------------------------------------------------------------------------------
function UserManager.RfidLogon(rawCode)

	XTRACE(16, "RfidLogon: "..param_as_str(rawCode))
	local userid = param_as_str(rawCode);
	userid = string.gsub(string.gsub(userid,'\r',''),'\n','')

	local timer = os.clock()
	if   (timer - UserManager.timer <= 2) then
		-- ignore this input
		XTRACE(16, "RfidLogon: ID ignored: "..userid)
		UserManager.timer = timer;
		return
	end
	UserManager.timer = timer;

	local user
	local level
	user,level = GetUserByID(userid)
	if (level == nil) or (user == nil) then
		XTRACE(16, "RfidLogon: user '"..userid.."' not found")
		-- ProcessUserLogin("", 0, 0)
		return
	end

	UserManager.last_valid_id = userid

	XTRACE(16, "RfidLogon: ID='"..userid.."' User='"..user.."' Level="..level.."  Prev. user id="..param_as_str(UserManager.user_id))
--	local timeout = 0 -- in seconds 0 : do not show popup (param is ignored while logoff)
	local timeout = 3 -- in seconds --> show popup for a short time (3 seconds)

	local UserStatus = string.format('RfidLogon: (state before logon) autologon=%d, master=%s(%d), user=%s(%d), current user id=%s, timeout=%d',
					UserManager.autologon, param_as_str(UserManager.master), UserManager.master_level, param_as_str(UserManager.user),
 					UserManager.user_level, param_as_str(UserManager.user_id), timeout)
	XTRACE(16, UserStatus)
	ProcessUserLogin(user, timeout, 0)
end

-- Standard operator rights
user_rights = {
	0x0001,  -- finish assembly processing
	0x0002,  -- clear assembly (clear all tightening results on assembly)
	0x0004,  -- start current Job
	0x0008,  -- finish current Job processing
	0x0010,  -- skip Job (finish current Job processing and start the next)
	0x0020,  -- clear Job (clear all tightening results on current Job)
	0x0040,  -- skip Operation (set current operation to NOK and start the next)
	0x0080,  -- clear Bolt (clear tightening results on current bolt position and define it as NOT_PROCESSED)
	0x0100,  -- start diagnostic Job
	0x0200,  -- select Job / Bolt in view or on image
	0x1000   -- process NOK (continue tightening process after NOK result)
}

----------------------------------------------------
function UserManager_HasRight(right)

	if 	user_rights[1000] == 1000 then  -- temporary rights granted
		user_rights[1000] = nil         -- disable temporary rights
		return true
	end

	for k,v in pairs(user_rights) do
		if v == right then return true end
	end
	return false
end
----------------------------------------------------
-- source: Barcode scanner in "keyboard" mode
function UserManager.GUILogon(rawCode)

	XTRACE(16, "GUILogon: "..param_as_str(rawCode))
	local userid = param_as_str(rawCode);
	userid = string.gsub(string.gsub(userid,'\r',''),'\n','')

	local user
	local level

	user,level = GetUserByID(userid)
	if (level == nil) or (user == nil) or (level < 2 )then
		XTRACE(16, "GUILogon: user '"..userid.."' not found or not enough right")
		return
	end

	XTRACE(16, "GUILogon: user '"..user.."' has checked NOK result")

	user_rights[1000] = 1000  -- grant temporary rights

end
