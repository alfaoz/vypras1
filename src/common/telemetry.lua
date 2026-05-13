local M = {}

local function call(module, method)
  if type(module) ~= "table" or type(module[method]) ~= "function" then
    return nil, "missing " .. method
  end
  local ok, value = pcall(module[method])
  if ok then return value end
  return nil, tostring(value)
end

function M.sample()
  local pose, pose_err = call(_G.sublevel, "getLogicalPose")
  local velocity = call(_G.sublevel, "getVelocity")

  local data = {
    pose = { ok = false, err = pose_err or "sublevel unavailable" },
    motion = { speed = 0, vx = 0, vy = 0, vz = 0 },
  }

  if type(pose) == "table" then
    data.pose = {
      ok = true,
      raw = pose,
    }
  end

  if type(velocity) == "table" then
    local vx = tonumber(velocity.x or velocity[1]) or 0
    local vy = tonumber(velocity.y or velocity[2]) or 0
    local vz = tonumber(velocity.z or velocity[3]) or 0
    data.motion = {
      speed = math.sqrt(vx * vx + vy * vy + vz * vz),
      vx = vx,
      vy = vy,
      vz = vz,
      raw = velocity,
    }
  end

  return data
end

return M
