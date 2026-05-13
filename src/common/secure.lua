local M = {}

local function serialize(value)
  if textutils and textutils.serialize then return textutils.serialize(value) end
  if type(value) ~= "table" then return tostring(value) end
  local parts = {}
  for k, v in pairs(value) do
    if k ~= "sig" then parts[#parts + 1] = tostring(k) .. "=" .. serialize(v) end
  end
  table.sort(parts)
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
  frame.sig = "dev-" .. weak_hash(tostring(key or "") .. "|" .. serialize(frame))
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
