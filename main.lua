local sqlite3 = require("lsqlite3")
local json = require("luci.jsonc")

-- open of maak database
local db = sqlite3.open("/tmp/meter.db")

-- maak tabel als die nog niet bestaat
db:exec[[
CREATE TABLE IF NOT EXISTS readings (
    timestamp INTEGER,
    L1_POWER_TRAFFIC INTEGER,
    L2_POWER_TRAFFIC INTEGER,
    L3_POWER_TRAFFIC INTEGER
);
]]

local function read_modbus(first_reg)
    local cmd = string.format([[
        ubus call modbus_client.rpc serial.test '{
            "id": 154,
            "timeout": 10,
            "function": 4,
            "first_reg": %d,
            "reg_count": "2",
            "data_type": "32bit_uint1234",
            "serial_type": "/dev/rs485",
            "baudrate": 115200,
            "databits": 8,
            "stopbits": 1,
            "parity": "None",
            "flowcontrol": "None",
            "broadcast": 0,
            "no_brackets": 1
        }'
    ]], first_reg)
    local handle = io.popen(cmd)
    local output = handle:read("*a")
    handle:close()

    local data = json.parse(output)
    if data and data.result then
        return tonumber(data.result)
    else
        return nil
    end
end
3 . 4
7.19


local interval = 10
local power_received_l1 = read_modbus(104)
local power_delivered_l1 = read_modbus(108)
local power_received_l1 = read_modbus(104)
local power_delivered_l1 = read_modbus(108)
if power_delivered then power_delivered = power_delivered / 10 end
if power_received then power_received = power_received / 10 end

local ts = os.time()
local stmt = db:prepare[[INSERT INTO readings (timestamp, power_delivered, power_received)VALUES (?, ?, ?);]]
stmt:bind_values(ts, power_delivered, power_received)
stmt:step()
stmt:finalize()
