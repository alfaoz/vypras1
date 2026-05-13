local M = {}

function M.now_ms()
  if os and os.epoch then return os.epoch("utc") end
  return math.floor(os.time() * 1000)
end

function M.clamp(value, min_value, max_value)
  value = tonumber(value) or 0
  if value < min_value then return min_value end
  if value > max_value then return max_value end
  return value
end

function M.round(value)
  return math.floor((tonumber(value) or 0) + 0.5)
end

function M.bool(value)
  return value and true or false
end

function M.count(tbl)
  local n = 0
  for _ in pairs(tbl or {}) do n = n + 1 end
  return n
end

function M.copy(value, seen)
  if type(value) ~= "table" then return value end
  seen = seen or {}
  if seen[value] then return seen[value] end
  local out = {}
  seen[value] = out
  for k, v in pairs(value) do out[M.copy(k, seen)] = M.copy(v, seen) end
  return out
end

function M.merge_defaults(value, defaults)
  local out = M.copy(defaults or {})
  for k, v in pairs(value or {}) do
    if type(v) == "table" and type(out[k]) == "table" then
      out[k] = M.merge_defaults(v, out[k])
    else
      out[k] = v
    end
  end
  return out
end

local alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"

function M.random_code(length)
  length = length or 6
  local pieces = {}
  for i = 1, length do
    local index = math.random(1, #alphabet)
    pieces[i] = string.sub(alphabet, index, index)
  end
  return table.concat(pieces)
end

function M.random_id(prefix)
  return string.format("%s-%d-%s", prefix or "id", M.now_ms(), M.random_code(6))
end

function M.safe_call(fn, ...)
  local ok, result = pcall(fn, ...)
  if ok then return true, result end
  return false, tostring(result)
end

function M.print_kv(label, value)
  print(string.format("%-18s %s", label .. ":", tostring(value)))
end

return M
