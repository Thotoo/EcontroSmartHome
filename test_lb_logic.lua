local lu = require("luaunit")
local logic = require("lb_logic")

local mockHistory = {
    _et = {
        {received=100}, {received=120}, {received=150}
    },
    last = function(self, n)
        -- return only last n entries
        n = math.min(n, #self._et)
        local res = {}
        for i = #self._et-n+1, #self._et do
            table.insert(res, self._et[i])
        end
        return res
    end
}

TestBatteryLogic = {}

-- Test compareAndClamp
function TestBatteryLogic:testCompareAndClamp()
    local tests = {
        {cur=0, new=0, min=0, max=0, want=0},
        {cur=100, new=200, min=500, max=1000, want=100},
        {cur=100, new=2000, min=500, max=1000, want=1100},
        {cur=-100, new=101, min=100, max=500, want=101},
        {cur=100, new=-101, min=100, max=200, want=-100},
    }

    for idx, test in pairs(tests) do
        local got = logic.compareAndClamp(test.cur, test.new, test.min, test.max)
        lu.assertEquals(got, test.want, string.format("Test %d failed", idx))
    end
end

-- Test SmoothIn
function TestBatteryLogic:testSmoothIn()
    lu.assertEquals(logic.SmoothIn(10, 20, 1), 15)
    lu.assertEquals(math.floor(logic.SmoothIn(10, 20)), 16)
    lu.assertEquals(logic.SmoothIn(0, 100), 66.66666666666667)
end

-- Test compute_discharge
function TestBatteryLogic:testComputeDischarge()
    local result1 = logic.compute_discharge(5000, 4000, 2500)
    lu.assertTrue(result1 > 0)

    local result2 = logic.compute_discharge(3000, 4000, 2500)
    lu.assertEquals(result2, 0)
end

-- Test predicted_usage
function TestBatteryLogic:testPredictedUsage()
    lu.assertEquals(logic.predicted_usage(100, 10, 5), 150)
end

-- Test determine_mode
function TestBatteryLogic:testDetermineMode()
    local DISCHARGE = 2
    local CHARGE_STOP = 0
    local CHARGE = 1

    lu.assertEquals(logic.determine_mode(50, CHARGE, 500), DISCHARGE)
    lu.assertEquals(logic.determine_mode(100, CHARGE, 0), CHARGE_STOP)
    lu.assertEquals(logic.determine_mode(90, 0, 0), CHARGE)
    lu.assertEquals(logic.determine_mode(90, CHARGE, 0), CHARGE_STOP)
end

function TestBatteryLogic:testComputeSlope()
    local slope = logic.compute_slope(mockHistory, 10, 5)
    lu.assertEquals(slope, 6)
end


-- Run all tests
os.exit(lu.LuaUnit.run())
