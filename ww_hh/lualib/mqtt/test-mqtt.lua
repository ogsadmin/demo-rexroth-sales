------------------------------------------------------------------------------
--
-- MQTT Initialization
--
------------------------------------------------------------------------------
-- MQTT configuration parameters:
local MqttBroker = "tcp://127.0.0.1:1883" --"tcp://172.23.56.110:1883"		-- Mqtt broker address and port
local MqttClientId = "heOpMon"					-- Local client ID (passed to broker)
local MqttUser = nil							-- Mqtt broker username (nil for no username)
local MqttPass = nil							-- Mqtt broker password (nil for no password)
local MqttLasWillTopic = "/heOpMon/connstate"	-- lastwill topic.
local MqttLasWillData = "disconnected"			-- lastwill data

print("start...")

-- Add additional LUA paths
if AddDllDirectory ~= nil then
	AddDllDirectory(path)
end	

package.cpath = package.cpath .. ";./win32/debug/?.dll"

require "luamqttclient"		-- note, this is case sensitive!

-- print a table (for debugging)
function tprint (tbl, indent)
  if not indent then indent = 0 end
  for k, v in pairs(tbl) do
    formatting = string.rep("  ", indent) .. k .. ": "
    if type(v) == "table" then
      print(formatting)
      tprint(v, indent+4)
    elseif type(v) == 'boolean' then
      print(formatting .. tostring(v))      
    else
      print(formatting .. v)
    end
  end
end


-- MQTT initialization
local MQTT = MqttClient()				-- create a new MQTT client
MQTT:Init(MqttBroker, MqttClientId)		-- initialize the client instance
MQTT:set_debug(true)					-- enable library debug output


MQTT.OnConnect = function(Token, sessionPresent, serverURI)
	print(tostring(Token)..": Connected to "..serverURI)
	-- do whatever is needed after getting connected...
	MQTT:Subscribe("/stuff", 1)
	MQTT:Subscribe("/idcode", 1)
	MQTT:Subscribe("$SYS/#", 0)	-- put some preassure on it...
	MQTT:Publish(MqttLasWillTopic, 1, "connected");
end

MQTT.OnConnectFailed = function(Token, Code, Message)
	print(tostring(Token)..": ERROR: Connect failed, code="..tostring(Code)..", err="..Message)
end

MQTT.OnDisconnect = function(Message)
	print("ERROR: Connection lost, err="..tostring(Message))
end

MQTT.OnMessage = function(MsgId, QoS, Flags, TopicLen, PayloadLen, TopicName, PayloadData)
	print("New data: MsgId="..tostring(MsgId)..", QoS="..tostring(QoS)..", Flags="..tostring(Flags))
	print("    Topic: Len="..tostring(TopicLen)..", Name="..TopicName)
	print("    Data:  Len="..tostring(PayloadLen)..", Data="..PayloadData)
end
MQTT.OnSubscribe = function(Token, QoS)
	print(tostring(Token)..": Subscribe ok, QoS="..tostring(QoS))
end
MQTT.OnSubscribeFailed = function(Token, Code, Message)
	print(tostring(Token)..": ERROR: Subscribe failed, code="..tostring(Code)..", err="..Message)
end
MQTT.OnDeliveryComplete = function(Token)
	print(tostring(Token)..": Delivery complete.")
end







-- MQTT callback: called "onConnect" - do your subscriptions here, so they will 
-- automatically get re-subscribed in case the connection got lost.
function Mqtt_OnConnect(hInst)
	-- NOTE: paho or mosquitto seems to have a bug with subscriptions
	--       to non-root topics, so e.g. /he/idcode does not work...
	MQTT:Subscribe("/stuff", 0)
	MQTT:Subscribe("/idcode", 0)
	MQTT:Publish(MqttLasWillTopic, 1, "connected");
end
---- MQTT callback: called "onPublishAcknowledge"
--function Mqtt_OnPubAck(hConn, msgid)
--	XTRACE(16, "MQTT: OnPubAck")
--end
---- MQTT callback: called "onSubscribeAcknowledge"
--function Mqtt_OnSubAck(hConn, msgid)
--	XTRACE(16, "MQTT: OnSubAck")
--end

-- MQTT callback: called after a new data for a subscription was received
function Mqtt_OnPublish(hConn, topiclen, topic, payloadlen, payload)
	XTRACE(16, "MQTT: OnPublish: Topic=" .. topic .. " payload=" .. payload)
	
	-- TODO: Implement something reasonable here.
	--       The following simply sends everything received back to the 
	--       the broker again (under the topic /test)
	MQTT:Publish("/test", 0, topic .. ": " .. payload);

	if topic == "/idcode" then
		XTRACE(16, "MQTT: New ID code = [" .. payload .."]")
		if #payload == 17 then			-- length of id is as expected?
			-- simulate scanner input
			BarCode_InsertByName('Mqtt', 'VIN', payload)
			--BarCode_AddNew('Scanner', '', string.sub(payload, 1, 8))			
			--BarCode_AddNew('Scanner', '', string.sub(payload, 9, -1))			
		end
	end
	
end
-- MQTT callback: called whenever the connection is closed. 
-- NOTE: to stay connected, call connect again here!
function Mqtt_OnClose(hConn, sReason)
	XTRACE(16, "MQTT: OnClose")
	hMqttConn = MQTT:Connect(MqttUser, MqttPass, MqttLasWillTopic, MqttLasWillData)
end

-- Start the initial connection to the MQTT broker
MQTT:Connect(MqttUser, MqttPass, MqttLasWillTopic, MqttLasWillData)
MQTT:Publish(MqttLasWillTopic, 1, "connected");



print ("Hello World!")
local ticker = os.clock()
while (1) do

	--MQTT:Poll()
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
	
	if os.clock() - ticker > 1 then		-- every now and then...
		local msg = string.format("{ \"ConnState\":%d, \"BatteryState\":%d, \"BatteryLevel\":%d, \"SignalLevel\":%d }", 
			1, 2, 3, 4)
		local topic = "/heOpMon/tool"	
		print("Sending message...")
		MQTT:Publish(topic, 1, msg);
	
		ticker = os.clock()
	end
	
end

io.read ()


