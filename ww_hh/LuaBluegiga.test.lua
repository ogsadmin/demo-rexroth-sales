
local SYLVAC_BLE_ADDR = 'DC:53:6A:1D:86:99' --{0xDC,0x53,0x6A,0x1D,0x86,0x99}
local SYLVAC_DONGLE_COMPORT = 'COM17'

function XTRACE(lvl, msg)
    print(msg)
end

local bluegiga = require("luabluegiga")
print(bluegiga.version())

local ble = bluegiga.new(SYLVAC_DONGLE_COMPORT)
print(tostring(ble))

local state = 0
local conn_handle = -1

--- callbacks ----------------------------------------------------------
function on_ble_version(major, minor, patch, build, ll_version, proto_version, hw)
    XTRACE(16, string.format("BLE version = %d.%d.%d.%d, ll = %d, proto = %d, hw = %d", major, minor, patch, build, ll_version, proto_version, hw))
    state = state + 1
end
--function on_ble_scan_response()
--end    
function on_ble_conn_status(connection, flags, bd_addr, addr_type, conn_interval, timeout, latency, bonding)
    if flags % (2*0x01) >= 0x01 then  -- test if bit 0 is set (0x01)
        conn_handle = connection
        XTRACE(16, string.format("BLE connected, handle = %d", connection))
        -- NOTE: this is a shortcut, we already know the service/characteristic handles, so
        --       we don't need to go through reading the handles
        --       Here handle 12 is the value configuration
        --[[
            // Handle for Temperature Measurement configuration already known
            if (thermometer_handle_configuration) {
                change_state(state_listening_measurements);
                enable_indications(msg->connection, thermometer_handle_configuration);
            }
            // Find primary services
            else {
                change_state(state_finding_services);
                ble_cmd_attclient_read_by_group_type(msg->connection, FIRST_HANDLE, LAST_HANDLE, 2, primary_service_uuid);
            }
        ]]--
        -- enable indications (0x0002) on the handle
        XTRACE(16, string.format("conn_handle = %d", conn_handle))
        ble:attclient_attribute_write(conn_handle, 12, {0x02, 0x00});
    end
end    
function on_ble_attr_group_found()
end    
function on_ble_attr_procedure_done()
end    
function on_ble_attr_info_found()
end    
function on_ble_attr_value(connection, attr_handle, value_type, value)
    local n = tonumber(value)
    XTRACE(16, string.format('H=%d, vt=%d, value = %s', attr_handle, value_type, tostring(n)))
end    
function on_ble_conn_disconnect(connection, reason)
    XTRACE(16, string.format("DISCONNECTED: reason = %d", reason))
    ble:gap_connect_direct(SYLVAC_BLE_ADDR, bluegiga.GAP_ADDRESS_TYPE_RANDOM, 0x60, 0x70, 100, 0)
end    


-- initialize the callbacks
ble:register_callback('ble_rsp_system_get_info', on_ble_version)
--ble:register_callback('ble_evt_gap_scan_response', on_ble_scan_response)   -- not yet implemented 
ble:register_callback('ble_evt_connection_status', on_ble_conn_status)
ble:register_callback('ble_evt_attclient_group_found', on_ble_attr_group_found)
ble:register_callback('ble_evt_attclient_procedure_completed', on_ble_attr_procedure_done)
ble:register_callback('ble_evt_attclient_find_information_found', on_ble_attr_info_found)
ble:register_callback('ble_evt_attclient_attribute_value', on_ble_attr_value)
ble:register_callback('ble_evt_connection_disconnected', on_ble_conn_disconnect)


-- start the state machine
local oldstate = 0
local ok, err
while true do
    
    -- TODO: could/should check poll response
    ble:poll(100)
    
    if state == 0 then      -- open port
        ok, err = ble:open()
        if not ok then
            print("open: error: " .. err)
            exit()
        end
        state = state + 1
        
    elseif state == 1 then  -- reset system
        ble:system_reset(0)
        state = state + 1
        
    elseif state == 2 then  -- reopen port
        ok, err = ble:open()
        if ok then
            state = state + 1
        end
        
    elseif state == 3 then  -- query version
        ble:system_get_info()
        state = state + 1
        
    elseif state == 4 then  -- wait for response
        
    elseif state == 5 then  -- set bonding
        ble:set_bondable_mode(1)
        state = state + 1
        
    elseif state == 6 then  -- connect
        ble:gap_connect_direct(SYLVAC_BLE_ADDR, bluegiga.GAP_ADDRESS_TYPE_RANDOM, 0x60, 0x70, 100, 0)
        state = state + 1
    end
    
    
    
    if oldstate ~= state then
        print(string.format("State changed %d -> %d", oldstate, state))
        oldstate = state
    end
end







