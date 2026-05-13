local util = require("vypras1.util")

local M = {}

M.factory_channel = 47001
M.discovery_channel = 47000
M.station_channel = 47002
M.protocol = "vypra-s1-v1"

function M.find_modem()
  local modem = peripheral.find("modem")
  return modem
end

function M.open(modem, channel)
  if modem and not modem.isOpen(channel) then modem.open(channel) end
end

function M.close(modem, channel)
  if modem and modem.isOpen(channel) then modem.close(channel) end
end

function M.send(modem, channel, reply_channel, message)
  message.proto = message.proto or M.protocol
  message.sent_ms = message.sent_ms or util.now_ms()
  modem.transmit(channel, reply_channel or channel, message)
end

function M.receive(channel, timeout, predicate)
  local deadline = util.now_ms() + ((timeout or 1) * 1000)
  while true do
    local remaining_ms = deadline - util.now_ms()
    if remaining_ms <= 0 then return nil, "timeout" end
    local timer = os.startTimer(remaining_ms / 1000)
    while true do
      local event = { os.pullEvent() }
      if event[1] == "timer" and event[2] == timer then
        return nil, "timeout"
      elseif event[1] == "modem_message" then
        local recv_channel = event[3]
        local reply_channel = event[4]
        local message = event[5]
        local distance = event[6]
        if recv_channel == channel and type(message) == "table" and message.proto == M.protocol then
          if not predicate or predicate(message, reply_channel, distance) then
            os.cancelTimer(timer)
            return message, reply_channel, distance
          end
        end
      end
    end
  end
end

function M.channel_from_seed(seed, offset)
  local hash = 2166136261
  local text = tostring(seed or "vypra")
  for i = 1, #text do
    hash = (hash + string.byte(text, i) * i) % 4294967296
    hash = (hash * 16777619) % 4294967296
  end
  return 20000 + ((hash + (offset or 0)) % 30000)
end

return M
