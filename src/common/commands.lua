local bridge_api = require("vypras1.bridge")

local M = {}

local function read_signal(bridge, controls, name)
  local binding = controls and controls[name]
  if not binding then return 0 end
  return bridge_api.read(bridge, binding.pair)
end

local function set_sub_command(command, path, value)
  local id, field = string.match(path or "", "^sub%.([%w_%-]+)%.([%w_%-]+)$")
  if not id then id, field = string.match(path or "", "^subsystem%.([%w_%-]+)%.([%w_%-]+)$") end
  if not id then return end
  command.sub[id] = command.sub[id] or {}
  command.sub[id][field] = value
end

function M.from_controls(bridge, controls)
  local command = {
    drive = {
      forward = 0,
      turn = 0,
      throttle = 0,
      boost = false,
      brake = false,
      estop = false,
    },
    sub = {},
  }

  local forward_pos = read_signal(bridge, controls, "drive_forward") > 0
  local forward_neg = read_signal(bridge, controls, "drive_reverse") > 0
  if forward_pos ~= forward_neg then command.drive.forward = forward_pos and 1 or -1 end

  local turn_neg = read_signal(bridge, controls, "drive_left") > 0
  local turn_pos = read_signal(bridge, controls, "drive_right") > 0
  if turn_pos ~= turn_neg then command.drive.turn = turn_pos and 1 or -1 end

  command.drive.throttle = read_signal(bridge, controls, "throttle")
  command.drive.boost = read_signal(bridge, controls, "boost") > 0
  command.drive.brake = read_signal(bridge, controls, "brake") > 0
  command.drive.estop = read_signal(bridge, controls, "estop") > 0

  for key, binding in pairs(controls or {}) do
    local maps_to = binding.maps_to or ""
    if string.sub(maps_to, 1, 4) == "sub." or string.sub(maps_to, 1, 10) == "subsystem." then
      local signal = bridge_api.read(bridge, binding.pair)
      if binding.kind == "analog" then
        set_sub_command(command, maps_to, signal)
      else
        set_sub_command(command, maps_to, signal > (binding.threshold or 0))
      end
    elseif string.sub(key, 1, 4) == "sub_" then
      local id, field = string.match(key, "^sub_([%w_%-]+)_([%w_%-]+)$")
      if id and field then
        command.sub[id] = command.sub[id] or {}
        local signal = bridge_api.read(bridge, binding.pair)
        command.sub[id][field] = binding.kind == "analog" and signal or signal > 0
      end
    end
  end

  return command
end

return M
