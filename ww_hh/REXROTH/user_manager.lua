--------------------------------------------------------------------------------------------
function UserManager_GetCurrentUserID()

	if (UserManager.master ~= nil) and  (#UserManager.master ~= 0) then
		return UserManager.user_id
	end
	return UserManager.user_id

end
--------------------------------------------------------------------------------------------
