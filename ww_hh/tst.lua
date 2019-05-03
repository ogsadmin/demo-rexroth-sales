
function TrimOrFill(str, max, pad_char)

	if (str == nil) or (#str == 0) then
		return string.rep(pad_char, max)
	end

	local len = #str
	if len > max then
		str = string.sub(str,1 ,max)
		len = max
	end
	if len == 0 then str = '' end

	if len < max then
		str = str .. string.rep(pad_char, max - len)
	end

	return str

end

-------------------------------------------------------------------------------------------------
UserManager = { user = nil, user_level = 0, master = "", master_level = 0, autologon = 0 }

function UserManager_UpdateStatus(user, user_level, master, master_level, autologon)

		UserManager.user = user
		UserManager.user_level = user_level
		UserManager.master = master
		UserManager.master_level = master_level
		UserManager.autologon = autologon
end
--------------------------------------------------------------------------------------------

--UserManager_UpdateStatus("mumu", 1, "kuku12345678901234567890", 3, 1)
UserManager_UpdateStatus("mumu", 1, "kuku1234567890", 3, 1)


print (TrimOrFill(UserManager.user, 20, ' ') ..'$' ..
       UserManager.user_level .. '$' ..
	   TrimOrFill(UserManager.master,20, ' ') .. '$' ..
	   UserManager.master_level .. '$' ..
	   UserManager.autologon)



