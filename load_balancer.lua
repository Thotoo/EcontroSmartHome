local json = require("luci.jsonc")
local switch_threshold = 4000

local function read_modbus(id)
    local cmd = string.format([[
        ubus call modbus_client.rpc get_tag_value '{"id":"%g", "index":0, "count":1}'
    ]], id)

    local handle = io.popen(cmd)
    local output = handle:read("*a")
    handle:close()
    local data = json.parse(output)
    if data and data.values[1] then
        return tonumber(data.values[1])
    else
        return nil
    end
end

local function set_modbus(id, value)
    local cmd = string.format([[
        ubus call modbus_client.rpc set_tag_value '{"id":"%s","values":["%s"],"index":0}'
    ]], id, value)
    local handle = io.popen(cmd)    
    local output = handle:read("*a")
    handle:close()
end

power_received = read_modbus(2.5)
accu_state = read_modbus(7.9)
soc = read_modbus(7.8)

if power_received >= 10000 then
    print("Waarschuwing: onrealistische waarden gedetecteerd. Gegevens niet verwerkt.")
    os.exit(1)
end

if power_received > 4000 then -- als de threshold overschreden wordt
    set_tag_value("7.10", "2")
else
    if accu_state ~= 1 then -- als de accu niet al aan laden is
        set_modbus("7.10", "1")
    end

    if soc >= 100 then -- als de accu vol is
        set_modbus("7.10", "0")
    end
end

-- get all tags:
-- ubus call modbus_client.rpc get_tags

-- 7.9 read charge mode
-- 7.10 write charge mode (0: stop 1: charge 2: discharge)