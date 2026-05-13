local M = {}

local function clamp(value, min_value, max_value)
  value = tonumber(value) or 0
  if value < min_value then return min_value end
  if value > max_value then return max_value end
  return value
end

local function bool(value)
  return value and true or false
end

local function rising(current, previous)
  return bool(current) and not bool(previous)
end

function M.initial_state(subsystem)
  local kind = subsystem.kind
  local config = subsystem.config or {}

  if kind == "toggle" then
    return { value = bool(config.initial), last_input = false }
  elseif kind == "pulse" then
    return { remaining_ticks = 0, last_input = false }
  elseif kind == "accumulator" then
    return {
      value = clamp(config.initial or config.min or 0, config.min or 0, config.max or 15),
      up_counter = 0,
      down_counter = 0,
    }
  end

  return {}
end

function M.step(subsystem, state, command)
  state = state or M.initial_state(subsystem)
  command = command or {}

  local kind = subsystem.kind
  local config = subsystem.config or {}
  local outputs = {}

  if kind == "direct" then
    outputs.main = bool(command.value)
  elseif kind == "toggle" then
    local current = bool(command.value)
    if rising(current, state.last_input) then
      state.value = not bool(state.value)
    end
    state.last_input = current
    outputs.main = bool(state.value)
  elseif kind == "pulse" then
    local current = bool(command.value)
    if rising(current, state.last_input) and (config.retrigger or (state.remaining_ticks or 0) <= 0) then
      state.remaining_ticks = config.pulse_ticks or 4
    end
    state.last_input = current
    outputs.main = (state.remaining_ticks or 0) > 0
    if state.remaining_ticks and state.remaining_ticks > 0 then
      state.remaining_ticks = state.remaining_ticks - 1
    end
  elseif kind == "analog" then
    outputs.value = clamp(command.value or 0, config.min or 0, config.max or 15)
  elseif kind == "directional" then
    local positive = bool(command.positive)
    local negative = bool(command.negative)
    if positive and negative then
      positive, negative = false, false
    end
    outputs.positive = positive
    outputs.negative = negative
  elseif kind == "accumulator" then
    local up = bool(command.up)
    local down = bool(command.down)
    if up and down then
      up, down = false, false
    end

    if up then
      state.up_counter = (state.up_counter or 0) + 1
      if state.up_counter >= (config.up_every_ticks or 10) then
        state.value = clamp((state.value or 0) + 1, config.min or 0, config.max or 15)
        state.up_counter = 0
      end
    else
      state.up_counter = 0
    end

    if down then
      state.down_counter = (state.down_counter or 0) + 1
      if state.down_counter >= (config.down_every_ticks or 10) then
        state.value = clamp((state.value or 0) - 1, config.min or 0, config.max or 15)
        state.down_counter = 0
      end
    else
      state.down_counter = 0
    end

    outputs.value = clamp(state.value or 0, config.min or 0, config.max or 15)
  end

  return outputs, state
end

return M
