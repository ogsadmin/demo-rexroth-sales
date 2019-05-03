------------------------------------------------------------------------------
XTRACE(16, "Loading mqtt.lua...", "mqtt.lua", 1)
require "luamqttclient"		
------------------------------------------------------------------------------
--
-- MQTT Initialization
--
------------------------------------------------------------------------------

-- MQTT configuration parameters:
local MqttClientId = "heOpMon"					-- Local client ID (passed to broker)
local MqttUser = nil							-- Mqtt broker username (nil for no username)
local MqttPass = nil							-- Mqtt broker password (nil for no password)
local MqttLasWillTopic = "/heOpMon/connstate"	-- lastwill topic.
local MqttLasWillData = "disconnected"			-- lastwill data
--current_project.module_config_done(mqtt)

local MqttBroker = "tcp://127.0.0.1:1883"		-- Mqtt broker address and port


-- MQTT initialization
local MQTT = MqttClient()				-- create a new MQTT client
MQTT:Init(MqttBroker, MqttClientId)		-- initialize the client instance
MQTT:set_debug(false)					-- do not be that noisy.


-- MQTT callbacks -------------------------------------------------------------

-- MQTT callback: "onConnect" - do your subscriptions here, so they will 
-- automatically get re-subscribed in case the connection got lost.
MQTT.OnConnect = function(Token, sessionPresent, serverURI)
	-- NOTE: paho or mosquitto seems to have a bug with subscriptions
	--       to non-root topics, so e.g. /he/idcode does not work...
	MQTT:Subscribe("/stuff", 1)
	MQTT:Subscribe("/idcode", 1)
	--MQTT:Subscribe("$SYS/#", 0)	-- put some preassure on it...
	MQTT:Publish(MqttLasWillTopic, 1, "connected");
end

MQTT.OnConnectFailed = function(Token, Code, Message)
	XTRACE(2, "ERROR: MQTT Connect failed, code="..tostring(Code)..", err="..Message, "mqtt.lua", 1)
end

MQTT.OnDisconnect = function(Message)
	XTRACE(2, "ERROR: MQTT Connection lost, err="..tostring(Message), "mqtt.lua", 1)
	--hMqttConn = MQTT:Connect(MqttUser, MqttPass, MqttLasWillTopic, MqttLasWillData)
end

-- MQTT message callback: called after a new data for a subscription was received
MQTT.OnMessage = function(MsgId, QoS, Flags, TopicLen, PayloadLen, TopicName, PayloadData)
	XTRACE(16, "MQTT: New data received: Topic=" .. TopicName .. " Payload=" .. PayloadData)

	-- TODO: Implement something reasonable here.
	--       The following simply sends everything received back to the 
	--       the broker again (under the topic /test)
	MQTT:Publish("/test", 0, TopicName .. ": " .. PayloadData);

	if TopicName == "/idcode" then
		XTRACE(16, "MQTT: New ID code = [" .. PayloadData .."]")
		if #PayloadData == 17 then			-- length of id is as expected?
			-- simulate scanner input
			BarCode_InsertByName('Mqtt', 'VIN', PayloadData)
			--BarCode_AddNew('Scanner', '', string.sub(PayloadData, 1, 8))			
			--BarCode_AddNew('Scanner', '', string.sub(PayloadData, 9, -1))			
		end
	end
	
end

-- Additional callbacks
MQTT.OnSubscribe = function(Token, QoS)
	--XTRACE(16, tostring(Token)..": Subscribe ok, QoS="..tostring(QoS))
end
MQTT.OnSubscribeFailed = function(Token, Code, Message)
	--XTRACE(16, tostring(Token)..": ERROR: Subscribe failed, code="..tostring(Code)..", err="..Message)
end
MQTT.OnDeliveryComplete = function(Token)
	--XTRACE(16, tostring(Token)..": Delivery complete.")
end

-- MQTT queue handler --------------------------------------------------------
MQTT.connected = -1
MQTT.ProcessEvents = function()
	-- get events from the queue and dispatch them accordingly
	repeat
		res,item = MQTT:QueueGet()
		if res ~= 0 then
			--print("---------------------------------------->" .. tostring(res) .. "/" .. tostring(item))
			--tprint(item)
			
			-- dispatch to callbacks
			if item.mc == 0 then 
				if item.flags == 1 then MQTT.OnConnect(item.key, item.i2, item.s1)
				else MQTT.OnConnectFailed(item.key, item.i2, item.s1)
				end
			elseif item.mc == 1 then MQTT.OnMessage(item.key, item.qos, item.flags, item.i1, item.i2, item.s1, item.s2)
			elseif item.mc == 2 then 
				if item.flags == 1 then MQTT.OnSubscribe(item.key, item.qos)
				else MQTT.OnSubscribeFailed(item.key, item.i2, item.s1)
				end
			elseif item.mc == 3 then MQTT.OnDisconnect(item.s1)
			elseif item.mc == 4 then MQTT.OnDeliveryComplete(item.key)
			end
		end
	until (res == 0)
	if MQTT:GetConnState() ~= MQTT.connstate then
		MQTT.connstate = MQTT:GetConnState()
		XTRACE(16, "MQTT: INFO: new connection state = " .. tostring(MQTT.connstate))
		if MQTT.connstate == 1 then
			-- pahoe MQTT auto-reconnect forgets about active subscriptions, so redo them
			MQTT.OnConnect(0, 0, 'reconnect')
		end
	end
end

-- Start the initial connection to the MQTT broker
MQTT:Connect(MqttUser, MqttPass, MqttLasWillTopic, MqttLasWillData)
MQTT:Publish(MqttLasWillTopic, 1, "connected");

------------------------------------------------------------------------------
--
-- State handlers - publish MQTT data
--
------------------------------------------------------------------------------
local ticker = os.clock()

-- StatePoll is cyclically called every 100-200ms
function Mqtt_StatePoll(info)

	MQTT.ProcessEvents()				-- drain pending events

	if os.clock() - ticker > 2 then		-- every 2 seconds...
		-- Publish workflow timing changes
		UpdateWorkflow(info.Workflow)		-- check for workflow state changes

		-- Publish tool information over MQTT
		for idx = 1, table.getn(Tools) do
			local tool = Tools[idx]		-- get the tool info
			local state = tool.Status	-- get the tools current status
			-- format status as json sting
			if state.ToolCycles == nil then state.ToolCycles = 0 end
			local msg = string.format("{ \"ConnState\":%d, \"BatteryState\":%d, \"BatteryLevel\":%d, \"SignalLevel\":%d, \"ToolSN\":\"%s\", \"ToolCalibDate\":\"%s\", \"ControllerSN\":\"%s\", \"ToolCycles\":%d }", 
				state.ConnState, state.BatteryState, state.BatteryLevel, param_as_str(state.SignalLevel), 
				param_as_str(state.ToolSerialNumber), param_as_str(state.LastCalibrationTime), param_as_str(state.ControllerSerialNumber), state.ToolCycles)
			local topic = "/heOpMon/tool" .. idx	
			MQTT:Publish(topic, 1, msg);
		end
		
		--MQTT:Publish("/heOpMon/ticker", 1, ticker);
		ticker = os.clock()
	end

end

-- StateChanged is called each time the workflow state, tool state or 
-- job/operation state changes.
function Mqtt_StateChanged(info)

	MQTT.ProcessEvents()				-- drain pending events
	
	UpdateWorkflow(info.Workflow)		-- check for workflow state changes

	-- dump the whole info block to the ETWTraceViewer (level 16 = debug)
	--tprint(info, 8)
	--tprint(debug.getinfo(1, "nSl"))
end

function Mqtt_Shutdown()
	XTRACE(16, "MQTT: Shutdown...")
	MQTT:Shutdown()
end


-- Handle workflow state changes
--		0 = Idle,			// Idle, no (total)part or job selected, waiting for user to scan barcodes
--		1 = WaitJobStart,   // Totalpart known, job selected but currently locked by: user | barcode | another station | and so on
--		2 = JobActive,      // Job is currently active.
--		3 = JobCompleted,   // Job was completed/aborted.
--		4 = Done,           // Totalpart/Workflow completely done
--		5 = DoneWaitUser,   // Assembly is done, but not marked in DB as archived and is still available for operations like:
--							// delete all results | select Job | delete Job results | Start Job
--		6 = JobAborted,     // current job aborted to execute some User request like: done, skip, delete results, loosen, change curren Job/Operation
oldstate = -1
wfactive = 0
wftagtime = 0
lastid = ''
lastname = ''
function UpdateWorkflow(Workflow)
	--XTRACE(16, "MQTT: Workflow State="..Workflow.State.." tt="..wftagtime)
	if Workflow.State ~= oldState then
		-- send a state change notifivation over MQTT
		oldState = Workflow.State
		XTRACE(16, "MQTT: Workflow state change: "..tostring(Workflow.State))

		if Workflow.State == 2 then
			-- job is active, so start timer
			wfactive = os.clock()
			wftagtime = 0
                  --tprint(Workflow)
                  lastid = Workflow.PartSerial
                  lastname = Workflow.PartName
		end
		if Workflow.State == 0 then
			-- job is back to idle, so stop
			wfactive = 0
		end
		
		-- set the workflow state, so the PLC can see what state we are currently in
		if Workflow.State ~= 0 then
			-- update the part numbers/code
			--MB:SetStr(40100, Workflow.PartSerial, 40)
			--MB:SetStr(40140, Workflow.JobName, 40)
		end
	end
	
	if wfactive ~= 0 then
		wftagtime = os.clock() - wfactive
	end
    local msg = string.format("{ \"State\":%d, \"Tagtime\": \"%.2f\", \"Part\":\"%s\", \"ID\":\"%s\" }", Workflow.State, wftagtime, lastname, lastid)
	MQTT:Publish("/heOpMon/workflowstate", 1, msg);
end

function MQTT_RelayBarcode(rawCode)
	MQTT:Publish("/heOpMon/IDCode", 1, rawCode);
end

-- register the callbacks with core.
if StatePollFunctions ~= nil then
	StatePollFunctions.add(Mqtt_StatePoll)
end	
if StateChangedFunctions ~= nil then
	StateChangedFunctions.add(Mqtt_StateChanged)
end
if StateShutdownFunctions ~= nil then
	StateShutdownFunctions.add(Mqtt_Shutdown)
end
