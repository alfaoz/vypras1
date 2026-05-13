local constants = require("vypras1.constants")
local fsutil = require("vypras1.fsutil")
local registry_api = require("vypras1.factory.registry")
local net = require("vypras1.net")
local util = require("vypras1.util")

local REGISTRY_PATH = "/etc/vypras1/registry.lua"

local M = {}

local function load_or_create()
  local registry = fsutil.read_table(REGISTRY_PATH)
  if registry then return registry end
  return registry_api.new_registry("vypraconfig-main")
end

local function save(registry)
  fsutil.write_table(REGISTRY_PATH, registry)
end

local function pause()
  print("Press enter.")
  read()
end

local function select_vehicle(registry)
  print("Vehicles:")
  for id, vehicle in pairs(registry.vehicles) do
    print("  " .. id .. "  " .. vehicle.name)
  end
  write("Vehicle ID: ")
  local id = read()
  if not registry.vehicles[id] then
    printError("Unknown vehicle.")
    return nil
  end
  return id, registry.vehicles[id]
end

local function write_disk_card(card)
  local drive = peripheral.find("drive")
  if not drive then return nil, "no disk drive peripheral" end
  if drive.isDiskPresent and not drive.isDiskPresent() then return nil, "no disk inserted" end
  local mount = drive.getMountPath and drive.getMountPath()
  if not mount then return nil, "disk has no mount path" end
  if drive.getDiskID then card.disk_id = drive.getDiskID() end
  local path = fs.combine(mount, "vypra_card.lua")
  fsutil.write_table(path, card)
  return path
end

local function add_subsystem_flow(registry)
  local vehicle_id = select_vehicle(registry)
  if not vehicle_id then return end

  print("Kinds: direct, toggle, pulse, analog, directional, accumulator")
  write("Kind: ")
  local kind = read()
  write("Subsystem id (no spaces): ")
  local id = read()
  write("Label: ")
  local label = read()

  local config = {}
  if kind == "pulse" then
    write("Pulse ticks [4]: ")
    config.pulse_ticks = tonumber(read()) or 4
  elseif kind == "accumulator" then
    write("Initial value [7]: ")
    config.initial = tonumber(read()) or 7
    write("Ticks per increment [10]: ")
    config.up_every_ticks = tonumber(read()) or 10
    config.down_every_ticks = config.up_every_ticks
    config.min = 0
    config.max = 15
  elseif kind == "analog" then
    config.min = 0
    config.max = 15
  end

  local subsystem, err = registry_api.add_subsystem(registry, vehicle_id, kind, id, label, config)
  if not subsystem then
    printError(err)
  else
    save(registry)
    print("Added subsystem " .. subsystem.id)
  end
  pause()
end

local function list_credentials(registry, vehicle_id)
  local vehicle = registry.vehicles[vehicle_id]
  if not vehicle then return end
  print("Credentials for " .. vehicle_id)
  for _, credential_id in ipairs(vehicle.credential_ids or {}) do
    local credential = registry.credentials[credential_id]
    if credential then
      print(string.format("  %s  %s  %s", credential.id, credential.card_type, credential.status))
    end
  end
end

local function reissue_disk_flow(registry)
  local vehicle_id = select_vehicle(registry)
  if not vehicle_id then return end
  list_credentials(registry, vehicle_id)
  write("Revoke credential id (blank to skip): ")
  local revoke_id = read()
  if revoke_id and revoke_id ~= "" then
    local _, err = registry_api.revoke_credential(registry, revoke_id)
    if err then printError(err) else print("Revoked " .. revoke_id) end
  end

  write("New card type [operator/maintenance]: ")
  local card_type = read()
  if card_type ~= "maintenance" then card_type = "operator" end
  write("Station name: ")
  local station_name = read()

  local credential = registry_api.create_credential(registry, vehicle_id, card_type)
  local station = registry_api.create_station_profile(registry, vehicle_id, station_name)
  local card = registry_api.disk_card(registry, credential.id, nil, station)
  local path, err = write_disk_card(card)
  save(registry)

  if path then
    print("Wrote " .. path)
  else
    printError("Could not write disk: " .. tostring(err))
    print(textutils.serialize(card))
  end
  print(registry_api.station_setup_sheet(station))
end

local function serve_setup(registry)
  local modem = net.find_modem()
  if not modem then
    printError("No modem found.")
    pause()
    return
  end
  net.open(modem, net.factory_channel)
  print("Factory setup server on channel " .. net.factory_channel)
  print("Ctrl+T to stop.")

  while true do
    local message, reply_channel = net.receive(net.factory_channel, 3600)
    if message then
      if message.t == "setup_claim" then
        local config, err = registry_api.claim_setup_key(registry, message.key)
        if config then
          save(registry)
          net.send(modem, reply_channel, net.factory_channel, {
            t = "setup_claim_result",
            ok = true,
            config = config,
          })
          print("Setup claimed for " .. config.vehicle_id)
        else
          net.send(modem, reply_channel, net.factory_channel, {
            t = "setup_claim_result",
            ok = false,
            err = err,
          })
        end
      elseif message.t == "config_sync" then
        local vehicle = registry.vehicles[message.vehicle_id]
        if vehicle and vehicle.secrets.vehicle_key == message.vehicle_key then
          net.send(modem, reply_channel, net.factory_channel, {
            t = "config_sync_result",
            ok = true,
            config = registry_api.onboard_config(registry, vehicle.id),
          })
        else
          net.send(modem, reply_channel, net.factory_channel, {
            t = "config_sync_result",
            ok = false,
            err = "bad vehicle id/key",
          })
        end
      end
    end
  end
end

function M.run()
  math.randomseed(util.now_ms() % 2147483647)
  local registry = load_or_create()

  while true do
    term.clear()
    term.setCursorPos(1, 1)
    print("Vypra S1 factory " .. constants.version)
    local count = 0
    for _ in pairs(registry.vehicles) do count = count + 1 end
    print("Vehicles: " .. tostring(count))
    print("")
    print("1) Create default S1")
    print("2) List vehicles")
    print("3) Print setup sheet")
    print("4) Add local cockpit inputs")
    print("5) Add subsystem")
    print("6) Generate setup key")
    print("7) Write operator/maintenance station disk")
    print("8) Serve setup/config over modem")
    print("9) Save")
    print("10) Reissue lost auth disk")
    print("q) Quit")
    write("> ")
    local choice = read()

    if choice == "1" then
      write("Vehicle name: ")
      local name = read()
      local vehicle = registry_api.create_vehicle(registry, name)
      save(registry)
      print(registry_api.vehicle_setup_sheet(vehicle))
      pause()
    elseif choice == "2" then
      for id, vehicle in pairs(registry.vehicles) do
        print(id .. " " .. vehicle.name)
      end
      pause()
    elseif choice == "3" then
      local _, vehicle = select_vehicle(registry)
      if vehicle then print(registry_api.vehicle_setup_sheet(vehicle)) end
      pause()
    elseif choice == "4" then
      local vehicle_id = select_vehicle(registry)
      if vehicle_id then
        registry_api.add_default_local_drive_inputs(registry, vehicle_id)
        save(registry)
        print("Local cockpit inputs allocated.")
      end
      pause()
    elseif choice == "5" then
      add_subsystem_flow(registry)
    elseif choice == "6" then
      local vehicle_id = select_vehicle(registry)
      if vehicle_id then
        local key = registry_api.create_setup_key(registry, vehicle_id)
        save(registry)
        print("Setup key: " .. key)
        print("Run setup server, then enter this key on onboard computer.")
      end
      pause()
    elseif choice == "7" then
      local vehicle_id = select_vehicle(registry)
      if vehicle_id then
        write("Card type [operator/maintenance]: ")
        local card_type = read()
        if card_type ~= "maintenance" then card_type = "operator" end
        write("Station name: ")
        local station_name = read()
        local credential = registry_api.create_credential(registry, vehicle_id, card_type)
        local station = registry_api.create_station_profile(registry, vehicle_id, station_name)
        local card = registry_api.disk_card(registry, credential.id, nil, station)
        local path, err = write_disk_card(card)
        save(registry)
        if path then
          print("Wrote " .. path)
        else
          printError("Could not write disk: " .. tostring(err))
          print("Card contents:")
          print(textutils.serialize(card))
        end
        print(registry_api.station_setup_sheet(station))
      end
      pause()
    elseif choice == "8" then
      serve_setup(registry)
    elseif choice == "9" then
      save(registry)
      print("Saved.")
      sleep(1)
    elseif choice == "10" then
      reissue_disk_flow(registry)
      pause()
    elseif choice == "q" then
      save(registry)
      return
    end
  end
end

return M
