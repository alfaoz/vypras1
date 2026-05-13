local constants = require("vypras1.constants")

local M = {}

local function clamp(value, min_value, max_value)
  value = tonumber(value) or 0
  if value < min_value then return min_value end
  if value > max_value then return max_value end
  return value
end

local function sign_axis(value)
  value = tonumber(value) or 0
  if value > 0 then return 1 end
  if value < 0 then return -1 end
  return 0
end

local function rounded(value)
  return math.floor(value + 0.5)
end

local function bool_value(value)
  if value == true then return true end
  if value == false or value == nil then return false end
  if type(value) == "number" then return value > 0 end
  if type(value) == "string" then
    local lower = string.lower(value)
    return lower == "true" or lower == "yes" or lower == "on" or tonumber(value) ~= nil and tonumber(value) > 0
  end
  return false
end

local function profile_value(profile, key)
  profile = profile or constants.default_drive_profile
  if profile[key] ~= nil then return profile[key] end
  return constants.default_drive_profile[key]
end

function M.neutral()
  return {
    left_forward = 0,
    left_reverse = 0,
    right_forward = 0,
    right_reverse = 0,
    speed = 0,
  }
end

function M.normalize(intent)
  intent = intent or {}

  return {
    forward = sign_axis(intent.forward or intent.f),
    turn = sign_axis(intent.turn),
    throttle = clamp(intent.throttle or intent.thr or 0, 0, 15),
    boost = bool_value(intent.boost),
    brake = bool_value(intent.brake),
    estop = bool_value(intent.estop),
  }
end

function M.mix(intent, profile)
  intent = M.normalize(intent)
  profile = profile or constants.default_drive_profile

  local out = M.neutral()
  if intent.estop or intent.brake then
    return out
  end

  local forward = intent.forward
  local turn = intent.turn
  local throttle = intent.throttle

  if forward == 0 and turn == 0 then return out end
  if throttle <= 0 then throttle = profile_value(profile, "max_speed") end

  local multiplier = profile_value(profile, "straight")

  if forward == 1 and turn == 0 then
    out.left_forward = 15
    out.right_forward = 15
    multiplier = profile_value(profile, "straight")
  elseif forward == -1 and turn == 0 then
    out.left_reverse = 15
    out.right_reverse = 15
    multiplier = profile_value(profile, "straight") * profile_value(profile, "reverse")
  elseif forward == 0 and turn == -1 then
    out.left_reverse = 15
    out.right_forward = 15
    multiplier = profile_value(profile, "pivot")
  elseif forward == 0 and turn == 1 then
    out.left_forward = 15
    out.right_reverse = 15
    multiplier = profile_value(profile, "pivot")
  elseif forward == 1 and turn == -1 then
    out.right_forward = 15
    multiplier = profile_value(profile, "moving_turn")
  elseif forward == 1 and turn == 1 then
    out.left_forward = 15
    multiplier = profile_value(profile, "moving_turn")
  elseif forward == -1 and turn == -1 then
    out.right_reverse = 15
    multiplier = profile_value(profile, "moving_turn") * profile_value(profile, "reverse")
  elseif forward == -1 and turn == 1 then
    out.left_reverse = 15
    multiplier = profile_value(profile, "moving_turn") * profile_value(profile, "reverse")
  end

  local min_speed = profile_value(profile, "min_speed")
  local max_speed = profile_value(profile, "max_speed")
  out.speed = clamp(rounded(throttle * multiplier), min_speed, max_speed)
  return out
end

return M
