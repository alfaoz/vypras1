local frequency = require("vypras1.frequency")

local M = {}

local function fail(message)
  return false, message
end

local function require_string(tbl, key, label)
  if type(tbl[key]) ~= "string" or tbl[key] == "" then
    return fail((label or key) .. " must be a non-empty string")
  end
  return true
end

function M.validate_allocation(allocation)
  if type(allocation) ~= "table" then return fail("allocation must be a table") end
  local ok, err = require_string(allocation, "id")
  if not ok then return ok, err end
  ok, err = require_string(allocation, "owner_type")
  if not ok then return ok, err end
  ok, err = require_string(allocation, "owner_id")
  if not ok then return ok, err end
  ok, err = require_string(allocation, "purpose")
  if not ok then return ok, err end
  if not frequency.valid_pair(allocation.pair) then
    return fail("allocation.pair is not in the allowed item pool")
  end
  return true
end

function M.validate_drive_config(drive)
  if type(drive) ~= "table" then return fail("drive must be a table") end
  if type(drive.outputs) ~= "table" then return fail("drive.outputs must be a table") end

  local required = {
    "left_forward",
    "left_reverse",
    "right_forward",
    "right_reverse",
    "speed",
  }

  for _, key in ipairs(required) do
    local output = drive.outputs[key]
    if type(output) ~= "table" then return fail("drive output missing: " .. key) end
    if not frequency.valid_pair(output.pair) then
      return fail("drive output pair invalid: " .. key)
    end
  end

  return true
end

function M.validate_vehicle_config(config)
  if type(config) ~= "table" then return fail("config must be a table") end
  local ok, err = require_string(config, "vehicle_id")
  if not ok then return ok, err end
  if type(config.config_version) ~= "number" then return fail("config_version must be a number") end
  return M.validate_drive_config(config.drive)
end

return M
