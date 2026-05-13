local M = {}

local function stable(value)
  local kind = type(value)
  if kind == "nil" then return "nil" end
  if kind == "boolean" or kind == "number" then return tostring(value) end
  if kind == "string" then return string.format("%q", value) end
  if kind ~= "table" then return kind .. ":" .. tostring(value) end

  local keys = {}
  for key in pairs(value) do
    if key ~= "sig" then keys[#keys + 1] = key end
  end
  table.sort(keys, function(a, b)
    return tostring(a) < tostring(b)
  end)

  local parts = {}
  for i, key in ipairs(keys) do
    parts[i] = stable(key) .. "=" .. stable(value[key])
  end
  return "{" .. table.concat(parts, ",") .. "}"
end

local function weak_hash(text)
  local hash = 5381
  for i = 1, #text do
    hash = (hash * 33 + string.byte(text, i) * i) % 4294967296
  end
  return string.format("%08x", hash)
end

function M.sign(key, frame)
  -- Dev signature for v1 test builds. Replace with HMAC-SHA256 via Allay deps.
  frame.sig = nil
  frame.sig = "dev-" .. weak_hash(tostring(key or "") .. "|" .. stable(frame))
  return frame
end

function M.verify(key, frame)
  if type(frame) ~= "table" or type(frame.sig) ~= "string" then return false end
  local sig = frame.sig
  local copy = {}
  for k, v in pairs(frame) do if k ~= "sig" then copy[k] = v end end
  M.sign(key, copy)
  return copy.sig == sig
end

return M
