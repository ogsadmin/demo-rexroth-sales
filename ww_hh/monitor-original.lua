XTRACE(16, "Loading monitor.lua...", "monitor.lua", 1)

-- Global objects
require('lualib/system')			-- lualib/system.lua

-- Customer projects

GleP_project = {
 name 		= 'GleP project',
 require1 	= 'heOpGui-config\\GleP\\barcode',
 require2 	= 'heOpGui-config\\GleP\\user_manager',
-- relative or absolut path to station.ini , station.fdb, ....
-- default: 'tables' 
 base_folder = 'heOpGui-config\\GleP',
}

TRIUMPH_project = {
 name 		= 'Triumph project',
 require1 	= 'heOpGui-config\\Triumph\\barcode',
 require2 	= 'heOpGui-config\\Triumph\\user_manager',
 require3 	= 'heOpGui-config\\Triumph\\SignalR',
-- relative or absolut path to station.ini , station.fdb, ....
-- default: 'tables' 
 base_folder = 'heOpGui-config\\Triumph',
}


LEVC_PT0040 = {
 name 		= 'LEVC PT0040',
 require1 	= 'cfg_LondonTaxi\\barcode',
 require2 	= 'cfg_LondonTaxi\\user_manager',
-- IL:: require3 	= 'cfg_LondonTaxi\\SignalR',
 base_folder = 'cfg_LondonTaxi',
}

LondonTaxi_project = {
 name 		= 'LondonTaxi project',
 require1 	= 'heOpGui-config\\LondonTaxi\\barcode',
 require2 	= 'heOpGui-config\\LondonTaxi\\user_manager',
-- IL:: require3 	= 'heOpGui-config\\LondonTaxi\\SignalR',
-- relative or absolut path to station.ini , station.fdb, ....
-- default: 'tables' 
 base_folder = 'heOpGui-config\\LondonTaxi',
}


DEMO_project = {
 name 		= 'DEMO project',
 require1 	= 'Demo\\barcode',
 require2 	= 'Demo\\user_manager',
-- relative or absolut path to station.ini , station.fdb, ....
-- default: 'tables' 
 base_folder = 'Demo',
 logo_file   = 'LEAN.png',
 billboard	= 'local://index.html',
}

cfg_TK_HN_ST1 = {
 name 		= 'TK HN (ST1-Client)',
 require1 	= 'cfg_TK-HN-ST1\\barcode',
 require2 	= 'cfg_TK-HN-ST1\\user_manager',
-- relative or absolut path to station.ini , station.fdb, ....
-- default: 'tables' 
 base_folder = 'cfg_TK-HN-ST1',
}
cfg_TK_HN_ST2 = {
 name 		= 'TK HN (ST2-Server)',
 require1 	= 'cfg_TK-HN-ST2\\barcode',
 require2 	= 'cfg_TK-HN-ST2\\user_manager',
-- relative or absolut path to station.ini , station.fdb, ....
-- default: 'tables' 
 base_folder = 'cfg_TK-HN-ST2',
}

TRIUMPH_BUG = {
 name 		= 'Triumph bug',
 require1 	= 'bob\\barcode',
 require2 	= 'bob\\user_manager',
 require3 	= 'bob\\SignalR',
 base_folder = 'bob',
}
STUART_DEMO = {
 name 		= 'STUART_DEMO',
 require1 	= 'cfg_Stuart\\MqttDemoFULL\\barcode',
 require2 	= 'cfg_Stuart\\MqttDemoFULL\\user_manager',
 require3 	= 'cfg_Stuart\\MqttDemoFULL\\mqtt',
 base_folder= 'cfg_Stuart\\MqttDemoFULL',
}

STUART_BARCODE = {
 name 		= 'STUART_BARCODE',
 require1 	= 'heOpGui-config\\Stuart\\Barcode_Test\\barcode',
 require2 	= 'heOpGui-config\\Stuart\\Barcode_Test\\user_manager',
-- require3 	= 'heOpGui-config\\Stuart\\Barcode_Test\\SignalR',
 base_folder= 'heOpGui-config\\Stuart\\Barcode_Test',
}

BRC_Glenrothes = {
 name 		= 'BRC-Glenrothes',
 require1 	= 'heOpGui-config\\BRC-Glenrothes\\barcode',
 require2 	= 'heOpGui-config\\BRC-Glenrothes\\user_manager',
 require3 	= 'heOpGui-config\\BRC-Glenrothes\\mqtt',
 base_folder= 'heOpGui-config\\BRC-Glenrothes',
}


LEAN_issue = {
 name 		= 'LEVC issue',
 require1 	= 'LEAN\\barcode',
 require2 	= 'LEAN\\user_manager',
 require3 	= 'LEAN\\mqtt',
-- relative or absolut path to station.ini , station.fdb, ....
-- default: 'tables' 
 base_folder = 'LEAN',
}


LEAN_project = {
 name 		= 'LEAN project',
 require1 	= 'heOpGui-config\\LEAN\\barcode',
 require2 	= 'heOpGui-config\\LEAN\\user_manager',
 require3 	= 'heOpGui-config\\LEAN\\mqtt',
-- relative or absolut path to station.ini , station.fdb, ....
-- default: 'tables' 
 base_folder = 'heOpGui-config\\LEAN',
}


--current_project = LEAN_project


--current_project = cfg_TK_HN_ST2
current_project = DEMO_project
--current_project = TRIUMPH_project
--current_project = LondonTaxi_project
--current_project = BRC_Glenrothes
--current_project = STUART_BARCODE

XTRACE(16, "project: ".. current_project.name, "monitor.lua", 1)

function OnInitComplete()
	for req , lua_file in pairs(current_project) do  -- load all lua files
		if 'require' == string.sub(req,1 ,7)  then
			require(lua_file)
		end
	end
end
	
