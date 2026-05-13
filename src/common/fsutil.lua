local M = {}

function M.ensure_dir(path)
  if fs and not fs.exists(path) then fs.makeDir(path) end
end

function M.read_table(path)
  if not fs or not fs.exists(path) then return nil, "missing" end
  local handle = fs.open(path, "r")
  if not handle then return nil, "open failed" end
  local content = handle.readAll()
  handle.close()
  local fn, err = load("return " .. content, path, "t", {})
  if not fn then return nil, err end
  local ok, value = pcall(fn)
  if not ok then return nil, value end
  return value
end

function M.write_table(path, value)
  local dir = fs.getDir(path)
  if dir and dir ~= "" then M.ensure_dir(dir) end
  local handle = assert(fs.open(path, "w"))
  handle.write(textutils.serialize(value))
  handle.close()
end

function M.read_text(path)
  if not fs or not fs.exists(path) then return nil, "missing" end
  local handle = fs.open(path, "r")
  if not handle then return nil, "open failed" end
  local content = handle.readAll()
  handle.close()
  return content
end

function M.write_text(path, value)
  local dir = fs.getDir(path)
  if dir and dir ~= "" then M.ensure_dir(dir) end
  local handle = assert(fs.open(path, "w"))
  handle.write(value or "")
  handle.close()
end

return M
