-- show the lua path(s)
local function printpath()
	print("LUA MODULES:\n",(package.path:gsub("%;","\n\t")),"\n\nC MODULES:\n",(package.cpath:gsub("%;","\n\t")))
end

-- add the lua libs path to our environment
package.cpath = package.cpath .. ";./lualib/signalr/?.dll"

require "luasignalr"


-- print a table (for debugging)
function tprint (tbl, indent)
  if not indent then indent = 0 end
  for k, v in pairs(tbl) do
    formatting = string.rep("  ", indent) .. tostring(k) .. ": "
    if type(v) == "table" then
      print(formatting)
      tprint(v, indent+4)
    elseif type(v) == 'boolean' then
      print(formatting .. tostring(v))      
    elseif type(v) == 'function' then
      print(formatting .. tostring(v))      
    else
      print(formatting .. v)
    end
  end
end

Config = {}
Config.SignalR = {
	StationID = "StaX01",
	URL = "http://localhost:8080",
	HUB = "MyHub"
}

StatePollFunctions = {
	list = {},
	add = function(fn)
		StatePollFunctions.list[fn] = fn
	end,
	exec = function(arg)
		for k, v in pairs(StatePollFunctions.list) do
			v(arg)
		end
	end
}

s1 = function() 
	print("s1")
end	
s2 = function() 
	print("s2")
end	
StatePollFunctions.add(s1)
StatePollFunctions.add(s2)
tprint(StatePollFunctions)

StatePollFunctions.exec(123)

print ("test 1234!")

local myHub = SignalR ()

-- create callback functions
myHub.OnTrace = function(mc, msg, src)
	print("Trace: ["..tostring(mc).."]: "..tostring(msg).." ("..tostring(src)..")")
end
myHub.OnState = function(oldState, newState)
	print("State: "..tostring(oldState).." --> "..tostring(newState))
	if newState == 1 then
		myHub:Subscribe("stationUpdate")
		myHub:Invoke("JoinStation", "[ '".. Config.SignalR.StationID .."' ]")
	end
end
myHub.OnEvent = function(eventName, eventParams)
	print("Event: " .. eventName)
end

print ("inst created\n")

myHub:set_debug(1)
myHub:Init(Config.SignalR.URL, Config.SignalR.HUB, 31)
myHub:Connect()


print ("Hello World!")
while (1) do

	res,item = myHub:QueueGet()
	if res ~= 0 then
		-- dispatch to callbacks
		if item.mc == 1 then myHub.OnTrace(item.i1, item.s1, item.s2)
		elseif item.mc == 2 then myHub.OnState(item.i1, item.i2)
		elseif item.mc == 3 then myHub.OnEvent(item.s1, item.s2)
		end
		--print("-->" .. tostring(res) .. "/" .. tostring(item))
		--tprint(item)
	end
end

io.read ()


