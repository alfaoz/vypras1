local constants = require("vypras1.constants")
local fsutil = require("vypras1.fsutil")
local bridge_api = require("vypras1.bridge")
local mixer = require("vypras1.mixer")
local schema = require("vypras1.schema")
local net = require("vypras1.net")
local protocol = require("vypras1.protocol")
local secure = require("vypras1.secure")
local util = require("vypras1.util")
local commands = require("vypras1.commands")
local subsystems = require("vypras1.subsystems")
local telemetry = require("vypras1.telemetry")

local CONFIG_PATH = "/etc/vypras1/onboard.lua"

local M = {}

local function write_output(bridge, output, value)
  if not output then return end
  if output.invert then
    if output.signal_type == "analog" then
      value = 15 - util.clamp(value, 0, 15)
    else
      value = value and 0 or 15
    end
  elseif output.signal_type == "boolean" then
    value = value and 15 or 0
  end
  bridge_api.write(bridge, output.pair, value)
end

local function write_drive(bridge, drive_config, output)
  local outputs = drive_config.outputs
  write_output(bridge, outputs.left_forward, output.left_forward)
  write_output(bridge, outputs.left_reverse, output.left_reverse)
  write_output(bridge, outputs.right_forward, output.right_forward)
  write_output(bridge, outputs.right_reverse, output.right_reverse)
  write_output(bridge, outputs.speed, output.speed)
end

local function neutral_drive(bridge, drive_config)
  write_drive(bridge, drive_config, mixer.neutral())
end

local function init_subsystem_state(config)
  local state = {}
  for id, subsystem in pairs(config.subsystems or {}) do
    state[id] = subsystem.state or subsystems.initial_state(subsystem)
  end
  return state
end

local function apply_subsystems(config, bridge, sub_command, state)
  local output_state = {}
  for id, subsystem in pairs(config.subsystems or {}) do
    local outputs, next_state = subsystems.step(subsystem, state[id], sub_command and sub_command[id] or {})
    state[id] = next_state
    output_state[id] = outputs
    for key, value in pairs(outputs or {}) do
      write_output(bridge, subsystem.outputs and subsystem.outputs[key], value)
    end
  end
  return output_state
end

local function safe_all(config, bridge)
  neutral_drive(bridge, config.drive)
  for _, subsystem in pairs(config.subsystems or {}) do
    for _, output in pairs(subsystem.outputs or {}) do
      write_output(bridge, output, output.safe or 0)
    end
  end
end

function M.load_config()
  local config, err = fsutil.read_table(CONFIG_PATH)
  if not config then return nil, err end

  local ok, schema_err = schema.validate_vehicle_config(config)
  if not ok then return nil, schema_err end
  return config
end

local function save_config(config)
  fsutil.write_table(CONFIG_PATH, config)
end

local function claim_setup_key()
  local modem = net.find_modem()
  if not modem then
    printError("No modem found.")
    return
  end

  write("Factory channel [" .. net.factory_channel .. "]: ")
  local channel = tonumber(read()) or net.factory_channel
  local reply = channel + 101
  net.open(modem, reply)

  write("Setup key: ")
  local key = read()
  print("Claiming setup key...")
  net.send(modem, channel, reply, {
    t = "setup_claim",
    key = key,
    computer_id = os.getComputerID(),
  })

  local response = net.receive(reply, 8, function(message)
    return message.t == "setup_claim_result"
  end)

  if not response then
    printError("No response from factory.")
    return
  end

  if not response.ok then
    printError("Setup failed: " .. tostring(response.err))
    return
  end

  save_config(response.config)
  print("Paired vehicle " .. tostring(response.config.vehicle_id))
  print("Config saved to " .. CONFIG_PATH)
end

local function sync_config(config)
  local modem = net.find_modem()
  if not modem then
    printError("No modem found.")
    return config
  end

  write("Factory channel [" .. net.factory_channel .. "]: ")
  local channel = tonumber(read()) or net.factory_channel
  local reply = channel + 102
  net.open(modem, reply)

  print("Requesting config sync...")
  net.send(modem, channel, reply, {
    t = "config_sync",
    vehicle_id = config.vehicle_id,
    vehicle_key = config.secrets and config.secrets.vehicle_key,
  })

  local response = net.receive(reply, 8, function(message)
    return message.t == "config_sync_result"
  end)

  if not response then
    printError("No response from factory.")
    return config
  end
  if not response.ok then
    printError("Sync failed: " .. tostring(response.err))
    return config
  end

  save_config(response.config)
  print("Synced config version " .. tostring(response.config.config_version))
  return response.config
end

function M.run_local(config, bridge)
  local subsystem_state = init_subsystem_state(config)
  print("Vypra S1 onboard LOCAL mode")
  print("Vehicle: " .. tostring(config.vehicle_name or config.vehicle_id))
  print("Ctrl+T to stop.")
  neutral_drive(bridge, config.drive)

  while true do
    local command = commands.from_controls(bridge, (config.local_inputs or {}).controls)
    local output = mixer.mix(command.drive, config.drive.profile)
    write_drive(bridge, config.drive, output)
    apply_subsystems(config, bridge, command.sub, subsystem_state)
    sleep(1 / (config.network and config.network.control_hz or constants.network.control_hz))
  end
end

local function credential_for(config, request)
  local credentials = config.credentials or {}
  local credential = credentials[request.credential_id]
  if not credential then return nil, "unknown credential" end
  if credential.status ~= "active" then return nil, "credential is " .. tostring(credential.status) end
  if credential.secret ~= request.credential then return nil, "bad credential secret" end
  if not credential.permissions or not credential.permissions.remote_control then
    return nil, "credential cannot remote-control"
  end
  return credential
end

function M.run_remote(config, bridge)
  local modem = net.find_modem()
  if not modem then
    printError("No modem found.")
    return
  end

  local subsystem_state = init_subsystem_state(config)
  local station_channel = net.station_channel
  net.open(modem, station_channel)
  print("REMOTE standby on channel " .. station_channel)
  print("Waiting for station session request. Ctrl+T to stop.")
  safe_all(config, bridge)

  while true do
    local request, reply_channel = net.receive(station_channel, 3600, function(message)
      return message.t == "session_request" and message.vehicle_id == config.vehicle_id
    end)

    local credential, err = credential_for(config, request)
    if not credential then
      net.send(modem, reply_channel, station_channel, { t = "session_denied", ok = false, err = err })
    else
      local session_id = util.random_id("sess")
      local control_channel = net.channel_from_seed(config.vehicle_id .. session_id, 1)
      local telemetry_channel = control_channel + 1
      local event_channel = control_channel + 2
      net.open(modem, control_channel)

      local grant = protocol.session_grant({
        vehicle_id = config.vehicle_id,
        station_id = request.station_id,
        session_id = session_id,
        control_channel = control_channel,
        telemetry_channel = telemetry_channel,
        event_channel = event_channel,
        control_hz = (config.network or constants.network).control_hz,
        telemetry_hz = (config.network or constants.network).telemetry_hz,
        timeout_ms = (config.network or constants.network).timeout_ms,
      })
      secure.sign(credential.secret, grant)
      net.send(modem, reply_channel, station_channel, grant)

      print("Remote session granted to " .. tostring(request.station_id))

      local latest = { drive = { forward = 0, turn = 0, throttle = 0 }, sub = {} }
      local last_seq = -1
      local last_frame_ms = util.now_ms()
      local control_interval = 1 / grant.control_hz
      local telemetry_interval = 1 / grant.telemetry_hz
      local last_telemetry = 0
      local drive_output = mixer.neutral()

      while true do
        local timer = os.startTimer(control_interval)
        local event = { os.pullEvent() }

        if event[1] == "timer" and event[2] == timer then
          -- apply latest below
        elseif event[1] == "modem_message" and event[3] == control_channel then
          os.cancelTimer(timer)
          local frame = event[5]
          if type(frame) == "table" and frame.t == "ctrl" and frame.session_id == session_id
            and secure.verify(credential.secret, frame)
            and tonumber(frame.seq or -1) > last_seq then
            latest = { drive = frame.drive or {}, sub = frame.sub or {} }
            last_seq = frame.seq
            last_frame_ms = util.now_ms()
          end
        end

        if util.now_ms() - last_frame_ms > grant.timeout_ms then
          latest = { drive = { forward = 0, turn = 0, throttle = 0, brake = true }, sub = {} }
        end

        drive_output = mixer.mix(latest.drive, config.drive.profile)
        write_drive(bridge, config.drive, drive_output)
        local subsystem_outputs = apply_subsystems(config, bridge, latest.sub, subsystem_state)

        if util.now_ms() - last_telemetry >= (1000 / grant.telemetry_hz) then
          local sample = telemetry.sample()
          local tele = protocol.telemetry_frame({
            vehicle_id = config.vehicle_id,
            session_id = session_id,
            seq = last_seq,
            mode = constants.modes.remote,
            active_source = request.station_id,
            pose = sample.pose,
            motion = sample.motion,
            drive = drive_output,
            subsystems = subsystem_outputs,
          })
          secure.sign(credential.secret, tele)
          net.send(modem, telemetry_channel, control_channel, tele)
          last_telemetry = util.now_ms()
        end
      end
    end
  end
end

local function test_outputs(config, bridge)
  local outputs = {
    { name = "A left_forward", output = config.drive.outputs.left_forward, value = 15 },
    { name = "B left_reverse", output = config.drive.outputs.left_reverse, value = 15 },
    { name = "C right_forward", output = config.drive.outputs.right_forward, value = 15 },
    { name = "D right_reverse", output = config.drive.outputs.right_reverse, value = 15 },
    { name = "E speed", output = config.drive.outputs.speed, value = 15 },
  }

  safe_all(config, bridge)
  for _, item in ipairs(outputs) do
    print("Testing " .. item.name)
    write_output(bridge, item.output, item.value)
    sleep(0.5)
    write_output(bridge, item.output, 0)
    sleep(0.2)
  end
  safe_all(config, bridge)
  print("Output test done.")
end

function M.run()
  term.clear()
  term.setCursorPos(1, 1)
  print("Vypra S1 onboard " .. constants.version)

  local config = M.load_config()
  if not config then
    print("No onboard config found.")
    print("1) Claim factory setup key")
    print("q) Quit")
    write("> ")
    local choice = read()
    if choice == "1" then claim_setup_key() end
    return
  end

  local bridge = bridge_api.find()
  if not bridge then
    printError("No redstone link bridge found.")
    return
  end

  safe_all(config, bridge)

  while true do
    print("")
    print("Vehicle: " .. tostring(config.vehicle_name or config.vehicle_id))
    print("1) Local mode")
    print("2) Remote mode")
    print("3) Safe/off")
    print("4) Test drive outputs")
    print("5) Print drive map")
    print("6) Reload config")
    print("7) Sync config from factory")
    print("q) Quit")
    write("> ")
    local choice = read()

    if choice == "1" then
      M.run_local(config, bridge)
    elseif choice == "2" then
      M.run_remote(config, bridge)
    elseif choice == "3" then
      safe_all(config, bridge)
      print("Outputs safe.")
    elseif choice == "4" then
      test_outputs(config, bridge)
    elseif choice == "5" then
      print(constants.drive_diagram)
    elseif choice == "6" then
      config = assert(M.load_config())
      print("Reloaded.")
    elseif choice == "7" then
      config = sync_config(config)
    elseif choice == "q" then
      safe_all(config, bridge)
      return
    end
  end
end

return M
