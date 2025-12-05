package.path = "/etc/scripts/?.lua;" .. package.path

local Stack = require("stack")
local json = require("luci.jsonc")
local CHANGE_TIME = 60 
-- Thresholds
local POWER_RECEIVED_MAX = 10000      -- Waarschuwing bij onrealistische waarden
local MAIN_NET_THRESHOLD = 4000         -- Drempel om accu te laden of ontladen

-- Modbus IDs
local ID_POWER_RECEIVED = 2.5
local ID_POWER_DELIVERED = 2.6
local ID_GET_CHARGE_MODE = 7.9       -- 0: stop, 1: charge, 2: discharge
local ID_SOC = 7.8                    -- State of Charge in %
local ID_SET_CHARGE_MODE = 7.10       -- 0: stop, 1: charge, 2: discharge

-- Charge modes
local CHARGE_STOP = 0
local CHARGE = 1
local DISCHARGE = 2

-- Charge power
local ID_GET_CHARGE_POWER = 7.13
local ID_GET_DISCHARGE_POWER = 7.14

-- History stacknew_charge_power
local HISTORY_LIMIT = 60
local history = Stack:Create()

-- Battery Stats
local MAX_DISCHARGE_POWER = 2500
local MAX_CHARGE_POWER = 2500

-- Update interval from script argument, default 5 seconds
local UPDATE_INTERVAL = tonumber(arg[1]) or 5

-- Function to read a Modbus tag
local function read_modbus(id)
    local cmd = string.format([[
        ubus call modbus_client.rpc get_tag_value '{"id":"%g", "index":0, "count":1}'
    ]], id)

    local handle = io.popen(cmd)
    local output = handle:read("*a")
    handle:close()

    local data = json.parse(output)
    if data and data.values and data.values[1] then
        return tonumber(data.values[1])
    else
        return nil
    end
end

-- Function to write a Modbus tag
local function set_modbus(id, value)
    local cmd = string.format([[
        ubus call modbus_client.rpc set_tag_value '{"id":"%s","values":["%s"],"index":0}'
    ]], id, value)

    local handle = io.popen(cmd)
    handle:read("*a")
    handle:close()
end

-- SmoothIn: weighted smoothing function
function SmoothIn(previous, new, weight_new)
    weight_new = weight_new or 2
    return (previous + new * weight_new) / (1 + weight_new)
end

local function compareAndClamp(cur, new, min, max)
    local difference = new - cur
    local abs = math.abs(difference)

    if abs < min then
        do return cur end
    end

    if abs > max then
        do return difference < -max and cur - max or cur + max end
    end

    return new
 end

 local function compute_slope(history, steps)
    local entries = history:last(steps)
    if #entries < steps then return 0 end

    local first_value = entries[1].received
    local last_value = entries[#entries].received
    local slope = (last_value - first_value) / ((#entries - 1) * UPDATE_INTERVAL)
    return slope
end

-- Measure Modbus values and update history
local function measure_and_update()
    local raw_power_received = read_modbus(ID_POWER_RECEIVED)
    local raw_power_delivered = read_modbus(ID_POWER_DELIVERED)
    local accu_state = read_modbus(ID_GET_CHARGE_MODE)
    local soc = read_modbus(ID_SOC)

    if raw_power_received and raw_power_received >= POWER_RECEIVED_MAX then
        print("Waarschuwing: onrealistische waarden gedetecteerd. Gegevens niet verwerkt.")
        return
    end

    -- Initialize smoothed values with raw values
    local Smooth_power_received = raw_power_received or 0
    local Smooth_power_delivered = raw_power_delivered or 0

    local prev_entry = history._et[#history._et]
    if prev_entry then
        Smooth_power_received = SmoothIn(prev_entry.received, raw_power_received, 2)
        Smooth_power_delivered = SmoothIn(prev_entry.delivered, raw_power_delivered, 2)
    end

    -- Push raw values to history
    history:push({
        timestamp = os.time(),
        received = Smooth_power_received,
        delivered = Smooth_power_delivered,
        soc = soc
    })

    -- Keep history within limit
    if history:getn() > HISTORY_LIMIT then
        history:pop_bottom()
    end
    local slope5s = compute_slope(history, 2)
    local slope30s = compute_slope(history, 6)
    local predicted_usage5s = slope5s * 5
    local predicted_usage30s = slope30s * 30
    local new_charge_power = compareAndClamp(read_modbus(ID_GET_CHARGE_POWER),Smooth_power_received,0,2500)
    print(string.format("Raw usage: %g  Smooth usage: %g   5 s slope: %g  30s slope: %g", raw_power_received, Smooth_power_received, predicted_usage5s, predicted_usage30s))
end

-- Main loop
while true do
    measure_and_update()
    os.execute(string.format("sleep %d", UPDATE_INTERVAL))
end

if power_received and power_received > SWITCH_THRESHOLD then
    set_modbus(ID_SET_CHARGE_MODE, tostring(DISCHARGE))
else
    if soc and soc >= 100 then
        set_modbus(ID_SET_CHARGE_MODE, tostring(CHARGE_STOP))
    elseif accu_state and accu_state ~= CHARGE then
        set_modbus(ID_SET_CHARGE_MODE, tostring(CHARGE))
    end
end
local formatted = string.format("Power received: %d W | Power delivered: %d W",power_received or 0, power_delivered or 0)
print(formatted)

-- get all tags: 
-- ubus call modbus_client.rpc get_tags 
-- 7.9 read charge mode 
-- 7.10 write charge mode (0: stop 1: charge 2: discharge) 
-- heartbeat 
-- validation 
-- comments 
-- consistentie