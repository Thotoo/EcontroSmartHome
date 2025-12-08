package.path = "/etc/scripts/?.lua;" .. package.path

-- Import pure logic module (your testable functions)
local logic = require("lb_logic")

-- Still using your dependencies
local Stack = require("stack")
local json = require("luci.jsonc")

-- ===============================
-- CONFIG
-- ===============================
local CHANGE_TIME = 60
local POWER_RECEIVED_MAX = 10000
local MAIN_NET_THRESHOLD = tonumber(arg[2]) or 4000
local MAX_DISCHARGE_POWER = 2500
local MAX_CHARGE_POWER = 2500
local HISTORY_LIMIT = 60
local UPDATE_INTERVAL = tonumber(arg[1]) or 5

-- Logging config
local LOG_FILE = "/etc/scripts/battery_log.txt"
local LOG_WIDTH = 32  -- each value occupies 10 characters (bytes)
local LOG_INTERVAL = 60  -- seconds between logging
local last_log_time = 0

-- Modbus IDs
local ID_POWER_RECEIVED = 2.5
local ID_POWER_DELIVERED = 2.6
local ID_GET_CHARGE_MODE = 7.9
local ID_SOC = 7.8
local ID_SET_CHARGE_MODE = 7.10
local ID_GET_CHARGE_POWER = 7.13
local ID_GET_DISCHARGE_POWER = 7.14
local ID_SET_DISCHARGE_POWER = 7.19

-- Charge modes
local CHARGE_STOP = 0
local CHARGE = 1
local DISCHARGE = 2

-- History storage
local history = Stack:Create()

-- ===============================
-- MODBUS FUNCTIONS
-- ===============================

local function read_modbus(id)
    local cmd = string.format(
        [[ubus call modbus_client.rpc get_tag_value '{"id":"%g","index":0,"count":1}']], 
        id
    )
    local handle = io.popen(cmd)
    local output = handle:read("*a")
    handle:close()

    local data = json.parse(output)
    if data and data.values and data.values[1] then
        return tonumber(data.values[1])
    end
    return nil
end

local function set_modbus(id, value)
    local cmd = string.format(
        [[ubus call modbus_client.rpc set_tag_value '{"id":"%s","values":["%s"],"index":0}']], 
        tostring(id or ""), tostring(value or 0)
    )
    local handle = io.popen(cmd)
    handle:read("*a")
    handle:close()
end

-- ===============================
-- HISTORY MANAGEMENT
-- ===============================

local function push_history(received, delivered, soc)
    history:push({
        timestamp = os.time(),
        received = received,
        delivered = delivered,
        soc = soc
    })
    if history:getn() > HISTORY_LIMIT then
        history:pop_bottom()
    end
end

-- ===============================
-- MEASUREMENT + LOGIC PIPELINE
-- ===============================

local function format_value(val)
    -- Convert to string, pad or truncate to LOG_WIDTH bytes
    local str = string.format("%.2f", val or 0)  -- 2 decimals
    if #str > LOG_WIDTH then
        return str:sub(1, LOG_WIDTH)
    else
        return str .. string.rep(" ", LOG_WIDTH - #str)
    end
end

local function log_measurement(received, delivered, soc, mode, charge_power)
    local file = io.open(LOG_FILE, "w")  -- append mode
    if not file then return end

    -- Each value on its own line, fixed width
    file:write(format_value(received) .. "\n")
    file:write(format_value(delivered) .. "\n")
    file:write(format_value(soc) .. "\n")
    file:write(format_value(mode) .. "\n")
    file:write(format_value(charge_power) .. "\n")
    file:close()
end

local function measure_and_update()
    local raw_received = read_modbus(ID_POWER_RECEIVED)
    local raw_delivered = read_modbus(ID_POWER_DELIVERED)
    local accu_state   = tonumber(read_modbus(ID_GET_CHARGE_MODE)) or 4
    local soc          = read_modbus(ID_SOC)

    if not raw_received or raw_received >= POWER_RECEIVED_MAX then
        print("⚠️ Waarschuwing: onrealistische waarden gedetecteerd.")
        return
    end

    -- Smooth input
    local prev = history._et[#history._et]
    local smooth_received = prev and logic.SmoothIn(prev.received, raw_received, 2) or raw_received
    local smooth_delivered = prev and logic.SmoothIn(prev.delivered, raw_delivered, 2) or raw_delivered

    -- Update history
    push_history(smooth_received, smooth_delivered, soc)

    -- Compute slopes (pure logic module)
    local slope5s  = logic.compute_slope(history, 5, UPDATE_INTERVAL)
    local slope30s = logic.compute_slope(history, 30, UPDATE_INTERVAL)

    -- Prediction
    local pred5s  = logic.predicted_usage(smooth_received, slope5s, 5)
    local pred30s = logic.predicted_usage(smooth_received, slope30s, 30)

    -- Compute discharge power (pure logic module)
    local new_charge_power = logic.compute_discharge(pred30s, MAIN_NET_THRESHOLD, MAX_DISCHARGE_POWER)

    -- If we need to discharge, push settings via Modbus
    if new_charge_power > 0 then
        set_modbus(ID_SET_CHARGE_POWER, tostring(new_charge_power))

        local new_mode = logic.determine_mode(soc, accu_state, new_charge_power)
        set_modbus(ID_SET_CHARGE_MODE, tostring(new_mode))
    end
    if now - last_log_time >= LOG_INTERVAL then
        log_measurement(smooth_received, smooth_delivered, soc, accu_state, new_charge_power)
        last_log_time = now
    end
    -- Debug print
    print(string.format(
        "[%s] Raw: %g W  Smooth: %g W  Pred5s: %g W  Pred30s: %g W  Slope5s: %g W/s  Slope30s: %g W/s  Mode: %d  ChargePower: %g W",
        os.date("%H:%M:%S"),
        raw_received, smooth_received,
        pred5s, pred30s,
        slope5s, slope30s,
        accu_state, new_charge_power
    ))
end

-- ===============================
-- MAIN LOOP (only runs on device)
-- ===============================

while true do
    measure_and_update()
    os.execute("sleep " .. UPDATE_INTERVAL)
end
