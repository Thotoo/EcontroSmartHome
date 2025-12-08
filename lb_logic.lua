local M = {}

--------------------------------------------------------------------------------
-- SmoothIn
-- Weighted smoothing of a value. Combines a previous value with a new value
-- giving more weight to the new value if specified.
--
-- Parameters:
--  previous (number): the previous value
--  new (number): the new measurement
--  weight_new (number, optional): weight factor for the new value (default=2)
--
-- Returns:
--  number: the smoothed value
--------------------------------------------------------------------------------
function M.SmoothIn(previous, new, weight_new)
    weight_new = weight_new or 2
    return (previous + new * weight_new) / (1 + weight_new)
end

--------------------------------------------------------------------------------
-- compareAndClamp
-- Clamps the change between a current value and a new value within a min and max.
--
-- Parameters:
--  cur (number): current value
--  new (number): new target value
--  min (number): minimum allowed change
--  max (number): maximum allowed change
--
-- Returns:
--  number: adjusted value clamped within the min/max constraints
--------------------------------------------------------------------------------
function M.compareAndClamp(cur, new, min, max)
    local difference = new - cur
    local abs = math.abs(difference)
    if abs < min then return cur end
    if abs > max then
        return difference < -max and cur - max or cur + max
    end
    return new
end

--------------------------------------------------------------------------------
-- compute_slope
-- Computes the slope (rate of change per second) from historical entries.
--
-- Parameters:
--  history (table): table containing past values with a :last(n) method
--                   each entry must have a 'received' field
--  desired_seconds (number): duration over which to compute the slope
--  interval (number, optional): interval between entries in seconds (default=5)
--
-- Returns:
--  number: slope in units per second
--------------------------------------------------------------------------------
function M.compute_slope(history, desired_seconds, interval)
    interval = interval or 5
    local steps = math.max(2, math.floor(desired_seconds / interval))
    local entries = history:last(steps)
    if #entries < steps then return 0 end
    local first_value = entries[1].received
    local last_value = entries[#entries].received
    return (last_value - first_value) / ((#entries - 1) * interval)
end

--------------------------------------------------------------------------------
-- predicted_usage
-- Predicts a future value based on the current value, slope, and time period.
--
-- Parameters:
--  current (number): current value
--  slope (number): rate of change per second
--  period (number): period into the future to predict
--
-- Returns:
--  number: predicted value
--------------------------------------------------------------------------------
function M.predicted_usage(current, slope, period)
    return current + slope * period
end

--------------------------------------------------------------------------------
-- compute_discharge
-- Calculates a gradual discharge power based on predicted overshoot and maximum allowed.
--
-- Parameters:
--  predicted (number): predicted value (e.g., predicted consumption)
--  threshold (number): threshold above which discharge is required
--  max_discharge (number): maximum discharge power
--
-- Returns:
--  number: calculated discharge power (clamped between 0 and max_discharge)
--------------------------------------------------------------------------------
function M.compute_discharge(predicted, threshold, max_discharge)
    local overshoot = predicted - threshold
    local new_power = 0
    if overshoot > 0 then
        local proportion = math.min(overshoot / threshold, 1)
        new_power = proportion * max_discharge
    end
    return math.max(0, math.min(new_power, max_discharge))
end

--------------------------------------------------------------------------------
-- determine_mode
-- Determines the battery charge mode based on SOC, current state, and discharge power.
--
-- Parameters:
--  soc (number): state of charge (0-100)
--  accu_state (number): current battery mode (0=STOP, 1=CHARGE, 2=DISCHARGE)
--  new_power (number): new discharge/charge power requested
--
-- Returns:
--  number: new mode (0=CHARGE_STOP, 1=CHARGE, 2=DISCHARGE)
--------------------------------------------------------------------------------
function M.determine_mode(soc, accu_state, new_power)
    local CHARGE_STOP = 0
    local CHARGE = 1
    local DISCHARGE = 2

    if new_power > 0 then
        return DISCHARGE
    elseif soc and soc >= 100 then
        return CHARGE_STOP
    elseif accu_state and accu_state ~= CHARGE then
        return CHARGE
    else
        return CHARGE_STOP
    end
end

return M
