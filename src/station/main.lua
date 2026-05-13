local constants = require("vypras1.constants")
local fsutil = require("vypras1.fsutil")
local bridge_api = require("vypras1.bridge")
local commands = require("vypras1.commands")
local net = require("vypras1.net")
local protocol = require("vypras1.protocol")
local secure = require("vypras1.secure")
local util = require("vypras1.util")

local M = {}

local function detect()
  return {
    modem = peripheral.find("modem"),
    drive = peripheral.find("drive"),
    monitor = peripheral.find("monitor"),
    bridge = bridge_api.find(),
  }
end

local function read_card()
  local drive = peripheral.find("drive")
  if not drive then return nil, "no disk drive" end
  if drive.isDiskPresent and not drive.isDiskPresent() then return nil, "no disk inserted" end
  local mount = drive.getMountPath and drive.getMountPath()
  if not mount then return nil, "disk has no mount path" end
  local path = fs.combine(mount, "vypra_card.lua")
  return fsutil.read_table(path)
end

local function print_station_sheet(card)
  local station = card.station_profile
  if not station then
    print("Disk has no station profile.")
    return
  end

  print("Station: " .. tostring(station.name or station.id))
  print("Vehicle: " .. tostring(card.vehicle_id))
  for key, binding in pairs((station.input_profile or {}).controls or {}) do
    print("")
    print(key)
    print("  Freq 1: " .. binding.pair[1])
    print("  Freq 2: " .. binding.pair[2])
  end
end

local function test_inputs(bridge, controls)
  print("Input test. Press/move each configured control.")
  for key, binding in pairs(controls or {}) do
    print("")
    print("Waiting for " .. key .. "...")
    print("Freq 1: " .. binding.pair[1])
    print("Freq 2: " .. binding.pair[2])
    local ok = false
    local deadline = util.now_ms() + 8000
    while util.now_ms() < deadline do
      local value = bridge_api.read(bridge, binding.pair)
      if value > 0 then
        print("Got signal: " .. value)
        ok = true
        break
      end
      sleep(0.1)
    end
    if not ok then print("No signal detected.") end
  end
end

local function request_session(card, modem)
  local reply = net.station_channel + 101
  net.open(modem, reply)

  local station_id = card.station_profile and card.station_profile.id or ("station-" .. os.getComputerID())
  net.send(modem, net.station_channel, reply, {
    t = "session_request",
    vehicle_id = card.vehicle_id,
    station_id = station_id,
    credential_id = card.credential_id,
    credential = card.credential,
    card_type = card.card_type,
  })

  local response = net.receive(reply, 8, function(message)
    return message.t == "session_grant" or message.t == "session_denied"
  end)

  if not response then return nil, "no response from onboard" end
  if response.t == "session_denied" then return nil, response.err or "denied" end
  if not secure.verify(card.credential, response) then return nil, "bad session signature" end
  return response
end

local function render_telemetry(target, frame)
  target.clear()
  target.setCursorPos(1, 1)
  target.write("Vypra telemetry")
  target.setCursorPos(1, 2)
  target.write("Vehicle: " .. tostring(frame.vehicle_id))
  target.setCursorPos(1, 3)
  target.write("Mode: " .. tostring(frame.mode))
  target.setCursorPos(1, 4)
  target.write("Seq: " .. tostring(frame.seq))
  target.setCursorPos(1, 5)
  local motion = frame.motion or {}
  target.write(string.format("Speed: %.3f", tonumber(motion.speed) or 0))
  target.setCursorPos(1, 6)
  local drive = frame.drive or {}
  target.write(string.format("LF %s LR %s RF %s RR %s SP %s",
    tostring(drive.left_forward or 0),
    tostring(drive.left_reverse or 0),
    tostring(drive.right_forward or 0),
    tostring(drive.right_reverse or 0),
    tostring(drive.speed or 0)))
end

local function run_control(card, grant, bridge, modem, monitor)
  local controls = ((card.station_profile or {}).input_profile or {}).controls or {}
  local seq = 0
  local running = true
  local last_telemetry = nil

  net.open(modem, grant.telemetry_channel)

  local function sender()
    local interval = 1 / (grant.control_hz or constants.network.control_hz)
    while running do
      seq = seq + 1
      local command = commands.from_controls(bridge, controls)
      local frame = protocol.control_frame({
        vehicle_id = card.vehicle_id,
        station_id = card.station_profile and card.station_profile.id,
        session_id = grant.session_id,
        seq = seq,
        drive = {
          f = command.drive.forward,
          turn = command.drive.turn,
          thr = command.drive.throttle,
          boost = command.drive.boost,
          brake = command.drive.brake,
          estop = command.drive.estop,
        },
        sub = command.sub,
      })
      secure.sign(card.credential, frame)
      net.send(modem, grant.control_channel, grant.telemetry_channel, frame)
      sleep(interval)
    end
  end

  local function receiver()
    while running do
      local event = { os.pullEvent() }
      if event[1] == "key" and event[2] == keys.q then
        running = false
      elseif event[1] == "modem_message" and event[3] == grant.telemetry_channel then
        local frame = event[5]
        if type(frame) == "table" and frame.t == "tele" and frame.session_id == grant.session_id
          and secure.verify(card.credential, frame) then
          last_telemetry = frame
          if monitor then
            render_telemetry(monitor, frame)
          else
            term.setCursorPos(1, 10)
            term.clearLine()
            write("Tele seq " .. tostring(frame.seq) .. " speed " .. tostring((frame.motion or {}).speed or 0))
          end
        end
      end
    end
  end

  term.clear()
  term.setCursorPos(1, 1)
  print("Connected to " .. tostring(card.vehicle_id))
  print("Control: " .. tostring(grant.control_hz) .. " Hz")
  print("Telemetry: " .. tostring(grant.telemetry_hz) .. " Hz")
  print("Press q to stop station control.")
  parallel.waitForAny(sender, receiver)
  running = false
  print("")
  print("Control stopped.")
  if last_telemetry then print("Last telemetry seq " .. tostring(last_telemetry.seq)) end
end

function M.run()
  term.clear()
  term.setCursorPos(1, 1)
  print("Vypra S1 station " .. constants.version)

  local peripherals = detect()
  print("Modem:                " .. tostring(peripherals.modem ~= nil))
  print("Disk drive:           " .. tostring(peripherals.drive ~= nil))
  print("Redstone link bridge: " .. tostring(peripherals.bridge ~= nil))
  print("Monitor:              " .. tostring(peripherals.monitor ~= nil))

  while true do
    print("")
    print("1) Read disk/card")
    print("2) Print station setup")
    print("3) Test inputs")
    print("4) Connect/control")
    print("q) Quit")
    write("> ")
    local choice = read()

    local card, err = read_card()
    if choice ~= "q" and not card then
      printError("Card error: " .. tostring(err))
    elseif choice == "1" then
      print(textutils.serialize(card))
    elseif choice == "2" then
      print_station_sheet(card)
    elseif choice == "3" then
      if not peripherals.bridge then
        printError("No redstone link bridge.")
      else
        test_inputs(peripherals.bridge, ((card.station_profile or {}).input_profile or {}).controls)
      end
    elseif choice == "4" then
      if not peripherals.modem then
        printError("No modem.")
      elseif not peripherals.bridge then
        printError("No redstone link bridge.")
      else
        local grant, grant_err = request_session(card, peripherals.modem)
        if not grant then
          printError("Connect failed: " .. tostring(grant_err))
        else
          run_control(card, grant, peripherals.bridge, peripherals.modem, peripherals.monitor)
        end
      end
    elseif choice == "q" then
      return
    end
  end
end

return M
