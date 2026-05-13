local M = {}

function M.find()
  local bridge = peripheral.find("redstoneLinkBridge")
    or peripheral.find("Create_Redstone_Link_Bridge")
    or peripheral.find("redstone_link_bridge")

  if not bridge then
    for _, name in ipairs(peripheral.getNames()) do
      local wrapped = peripheral.wrap(name)
      if type(wrapped) == "table" and wrapped.getLinkSignal and wrapped.sendLinkSignal then
        return wrapped, name
      end
    end
  end

  return bridge
end

function M.read(bridge, pair)
  if not bridge or not pair then return 0 end
  local ok, value = pcall(function()
    return bridge.getLinkSignal(pair[1], pair[2])
  end)
  if ok and tonumber(value) then return tonumber(value) end
  return 0
end

function M.write(bridge, pair, value)
  if not bridge or not pair then return false end
  value = math.max(0, math.min(15, math.floor((tonumber(value) or 0) + 0.5)))
  local ok = pcall(function()
    bridge.sendLinkSignal(pair[1], pair[2], value)
  end)
  return ok
end

return M
