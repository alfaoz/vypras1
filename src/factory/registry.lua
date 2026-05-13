local frequency = require("vypras1.frequency")
local constants = require("vypras1.constants")
local util = require("vypras1.util")

local M = {}

function M.new_registry(id)
  return {
    schema_version = 1,
    registry_id = id or "vypraconfig-main",
    vehicles = {},
    stations = {},
    allocations = {},
    credentials = {},
    setup_keys = {},
    released_allocations = {},
  }
end

function M.next_id(prefix, bucket)
  local n = 1
  while bucket[string.format("%s-%04d", prefix, n)] do
    n = n + 1
  end
  return string.format("%s-%04d", prefix, n)
end

function M.allocate(registry, owner_type, owner_id, purpose, physical_label, display_label)
  local used = frequency.build_used_lookup(registry.allocations)
  local pair, err = frequency.random_unused(used)
  if not pair then return nil, err end

  local id = M.next_id("alloc", registry.allocations)
  local allocation = {
    id = id,
    pair = pair,
    owner_type = owner_type,
    owner_id = owner_id,
    purpose = purpose,
    physical_label = physical_label,
    display_label = display_label,
    active = true,
  }
  registry.allocations[id] = allocation
  return allocation
end

function M.create_vehicle(registry, name)
  local id = M.next_id("s1", registry.vehicles)
  local vehicle = {
    id = id,
    name = name or id,
    class = "vypra-s1",
    status = "draft",
    config_version = 1,
    firmware_channel = "stable",
    drive = {
      kind = "vypra_s1_default_treads",
      physical_map = {
        view = "underside",
        diagram = constants.drive_diagram,
      },
      outputs = {},
      profile = constants.default_drive_profile,
    },
    local_inputs = { enabled = false, controls = {} },
    subsystems = {},
    groups = {},
    credential_ids = {},
    secrets = {
      vehicle_key = util.random_id("vehkey"),
    },
  }

  local drive_outputs = {
    { key = "left_forward", purpose = "drive.left_forward", label = "A", display = "Left Tread Forward" },
    { key = "left_reverse", purpose = "drive.left_reverse", label = "B", display = "Left Tread Reverse" },
    { key = "right_forward", purpose = "drive.right_forward", label = "C", display = "Right Tread Forward" },
    { key = "right_reverse", purpose = "drive.right_reverse", label = "D", display = "Right Tread Reverse" },
    { key = "speed", purpose = "drive.speed", label = "E", display = "Speed 0-15" },
  }

  for _, spec in ipairs(drive_outputs) do
    local allocation = assert(M.allocate(registry, "vehicle_output", id, spec.purpose, spec.label, spec.display))
    vehicle.drive.outputs[spec.key] = {
      physical_label = spec.label,
      allocation_id = allocation.id,
      pair = allocation.pair,
      safe = 0,
    }
  end

  registry.vehicles[id] = vehicle
  return vehicle
end

function M.get_vehicle(registry, vehicle_id)
  return registry.vehicles[vehicle_id]
end

function M.create_setup_key(registry, vehicle_id)
  if not registry.vehicles[vehicle_id] then return nil, "unknown vehicle" end

  local key
  repeat
    key = util.random_code(6)
  until not registry.setup_keys[key]

  registry.setup_keys[key] = {
    key = key,
    vehicle_id = vehicle_id,
    status = "unused",
    attempts = 0,
    max_attempts = 8,
  }

  registry.vehicles[vehicle_id].status = "pending_pair"
  return key
end

function M.claim_setup_key(registry, key)
  local record = registry.setup_keys[key]
  if not record then return nil, "setup key not found" end
  if record.status ~= "unused" then return nil, "setup key is " .. tostring(record.status) end

  record.attempts = (record.attempts or 0) + 1
  if record.attempts > (record.max_attempts or 8) then
    record.status = "locked"
    return nil, "setup key locked"
  end

  local vehicle = registry.vehicles[record.vehicle_id]
  if not vehicle then return nil, "vehicle missing" end

  record.status = "used"
  vehicle.status = "active"
  return M.onboard_config(registry, vehicle.id)
end

function M.onboard_config(registry, vehicle_id)
  local vehicle = registry.vehicles[vehicle_id]
  if not vehicle then return nil, "unknown vehicle" end

  local credentials = {}
  for _, credential_id in ipairs(vehicle.credential_ids or {}) do
    local credential = registry.credentials[credential_id]
    if credential and credential.status == "active" then
      credentials[credential_id] = {
        id = credential.id,
        card_type = credential.card_type,
        permissions = credential.permissions,
        secret = credential.secret,
        status = credential.status,
      }
    end
  end

  return {
    schema_version = 1,
    vehicle_id = vehicle.id,
    vehicle_name = vehicle.name,
    config_version = vehicle.config_version,
    registry_id = registry.registry_id,
    secrets = {
      vehicle_key = vehicle.secrets.vehicle_key,
    },
    credentials = credentials,
    network = constants.network,
    drive = vehicle.drive,
    local_inputs = vehicle.local_inputs,
    subsystems = vehicle.subsystems,
    groups = vehicle.groups,
  }
end

function M.add_default_local_drive_inputs(registry, vehicle_id)
  local vehicle = registry.vehicles[vehicle_id]
  if not vehicle then return nil, "unknown vehicle" end

  local specs = {
    { key = "drive_forward", purpose = "local.drive_forward", display = "Local Forward / W" },
    { key = "drive_reverse", purpose = "local.drive_reverse", display = "Local Reverse / S" },
    { key = "drive_left", purpose = "local.drive_left", display = "Local Left / A" },
    { key = "drive_right", purpose = "local.drive_right", display = "Local Right / D" },
    { key = "throttle", purpose = "local.throttle", display = "Local Throttle 0-15", kind = "analog" },
    { key = "boost", purpose = "local.boost", display = "Local Boost / Shift" },
    { key = "brake", purpose = "local.brake", display = "Local Brake / Space" },
    { key = "estop", purpose = "local.estop", display = "Local Emergency Stop" },
  }

  vehicle.local_inputs.enabled = true
  vehicle.local_inputs.controls = vehicle.local_inputs.controls or {}

  for _, spec in ipairs(specs) do
    if not vehicle.local_inputs.controls[spec.key] then
      local allocation = assert(M.allocate(registry, "vehicle_local_input", vehicle_id, spec.purpose, spec.key, spec.display))
      vehicle.local_inputs.controls[spec.key] = {
        kind = spec.kind or "button",
        allocation_id = allocation.id,
        pair = allocation.pair,
        maps_to = spec.purpose,
        invert = false,
      }
    end
  end

  vehicle.config_version = vehicle.config_version + 1
  return vehicle.local_inputs
end

local subsystem_output_specs = {
  direct = {
    { key = "main", signal_type = "boolean", label = "OUT" },
  },
  toggle = {
    { key = "main", signal_type = "boolean", label = "OUT" },
  },
  pulse = {
    { key = "main", signal_type = "boolean", label = "PULSE" },
  },
  analog = {
    { key = "value", signal_type = "analog", label = "VAL" },
  },
  directional = {
    { key = "positive", signal_type = "boolean", label = "POS" },
    { key = "negative", signal_type = "boolean", label = "NEG" },
  },
  accumulator = {
    { key = "value", signal_type = "analog", label = "VAL" },
  },
}

function M.add_subsystem(registry, vehicle_id, kind, id, label, config)
  local vehicle = registry.vehicles[vehicle_id]
  if not vehicle then return nil, "unknown vehicle" end
  if vehicle.subsystems[id] then return nil, "subsystem already exists" end

  local specs = subsystem_output_specs[kind]
  if not specs then return nil, "unknown subsystem kind: " .. tostring(kind) end

  local subsystem = {
    id = id,
    label = label or id,
    kind = kind,
    status = "pending_install",
    outputs = {},
    config = config or {},
    state = {},
    safe_behavior = (config and config.safe_behavior) or "off",
    safe_value = (config and config.safe_value) or 0,
  }

  for _, spec in ipairs(specs) do
    local purpose = "subsystem." .. id .. "." .. spec.key
    local allocation = assert(M.allocate(registry, "vehicle_output", vehicle_id, purpose, id .. "." .. spec.label, subsystem.label .. " " .. spec.key))
    subsystem.outputs[spec.key] = {
      signal_type = spec.signal_type,
      allocation_id = allocation.id,
      pair = allocation.pair,
      physical_label = id .. "." .. spec.label,
      invert = false,
      safe = 0,
      min = 0,
      max = 15,
    }
  end

  vehicle.subsystems[id] = subsystem
  vehicle.config_version = vehicle.config_version + 1
  return subsystem
end

function M.create_credential(registry, vehicle_id, card_type)
  local vehicle = registry.vehicles[vehicle_id]
  if not vehicle then return nil, "unknown vehicle" end

  local id = M.next_id("cred", registry.credentials)
  local permissions = {
    remote_control = true,
    remote_maintenance = card_type == "maintenance",
    reconfigure_station = true,
  }

  local credential = {
    id = id,
    vehicle_id = vehicle_id,
    card_type = card_type or "operator",
    status = "active",
    permissions = permissions,
    secret = util.random_id("cardkey"),
  }

  registry.credentials[id] = credential
  vehicle.credential_ids[#vehicle.credential_ids + 1] = id
  vehicle.config_version = vehicle.config_version + 1
  return credential
end

function M.create_station_profile(registry, vehicle_id, name)
  if not registry.vehicles[vehicle_id] then return nil, "unknown vehicle" end

  local id = M.next_id("station", registry.stations)
  local station = {
    id = id,
    name = name or id,
    vehicle_id = vehicle_id,
    status = "active",
    input_profile = {
      controls = {},
    },
  }

  local specs = {
    { key = "drive_forward", purpose = "station.drive_forward", display = "Station Forward / W" },
    { key = "drive_reverse", purpose = "station.drive_reverse", display = "Station Reverse / S" },
    { key = "drive_left", purpose = "station.drive_left", display = "Station Left / A" },
    { key = "drive_right", purpose = "station.drive_right", display = "Station Right / D" },
    { key = "throttle", purpose = "station.throttle", display = "Station Throttle 0-15", kind = "analog" },
    { key = "boost", purpose = "station.boost", display = "Station Boost / Shift" },
    { key = "brake", purpose = "station.brake", display = "Station Brake / Space" },
    { key = "estop", purpose = "station.estop", display = "Station Emergency Stop" },
  }

  for _, spec in ipairs(specs) do
    local allocation = assert(M.allocate(registry, "station_input", id, spec.purpose, spec.key, spec.display))
    station.input_profile.controls[spec.key] = {
      kind = spec.kind or "button",
      allocation_id = allocation.id,
      pair = allocation.pair,
      maps_to = spec.purpose,
      invert = false,
    }
  end

  registry.stations[id] = station
  return station
end

function M.revoke_credential(registry, credential_id)
  local credential = registry.credentials[credential_id]
  if not credential then return nil, "unknown credential" end
  credential.status = "revoked"
  credential.revoked_at = util.now_ms()
  local vehicle = registry.vehicles[credential.vehicle_id]
  if vehicle then vehicle.config_version = vehicle.config_version + 1 end
  return credential
end

function M.disk_card(registry, credential_id, disk_id, station_profile)
  local credential = registry.credentials[credential_id]
  if not credential then return nil, "unknown credential" end
  return {
    schema_version = 1,
    registry_id = registry.registry_id,
    vehicle_id = credential.vehicle_id,
    credential_id = credential.id,
    card_type = credential.card_type,
    disk_id = disk_id,
    credential = credential.secret,
    station_profile = station_profile,
  }
end

function M.station_setup_sheet(station)
  local lines = {}
  lines[#lines + 1] = "Station: " .. station.name .. " (" .. station.id .. ")"
  lines[#lines + 1] = "Vehicle: " .. station.vehicle_id
  lines[#lines + 1] = ""
  lines[#lines + 1] = "Tune station physical controls to:"
  for key, binding in pairs(station.input_profile.controls or {}) do
    lines[#lines + 1] = key
    lines[#lines + 1] = "  Freq 1: " .. binding.pair[1]
    lines[#lines + 1] = "  Freq 2: " .. binding.pair[2]
    lines[#lines + 1] = ""
  end
  return table.concat(lines, "\n")
end

function M.vehicle_setup_sheet(vehicle)
  local lines = {}
  lines[#lines + 1] = "Vehicle: " .. vehicle.name .. " (" .. vehicle.id .. ")"
  lines[#lines + 1] = "Config version: " .. tostring(vehicle.config_version)
  lines[#lines + 1] = ""
  lines[#lines + 1] = vehicle.drive.physical_map.diagram

  local order = {
    "left_forward",
    "left_reverse",
    "right_forward",
    "right_reverse",
    "speed",
  }

  for _, key in ipairs(order) do
    local output = vehicle.drive.outputs[key]
    lines[#lines + 1] = string.format("%s %s", output.physical_label, key)
    lines[#lines + 1] = "  Freq 1: " .. output.pair[1]
    lines[#lines + 1] = "  Freq 2: " .. output.pair[2]
    lines[#lines + 1] = ""
  end

  if vehicle.local_inputs and vehicle.local_inputs.enabled then
    lines[#lines + 1] = "Local cockpit inputs"
    for key, binding in pairs(vehicle.local_inputs.controls or {}) do
      lines[#lines + 1] = key
      lines[#lines + 1] = "  Freq 1: " .. binding.pair[1]
      lines[#lines + 1] = "  Freq 2: " .. binding.pair[2]
      lines[#lines + 1] = ""
    end
  end

  if vehicle.subsystems then
    lines[#lines + 1] = "Subsystem outputs"
    for _, subsystem in pairs(vehicle.subsystems) do
      lines[#lines + 1] = subsystem.label .. " (" .. subsystem.kind .. ")"
      for key, output in pairs(subsystem.outputs or {}) do
        lines[#lines + 1] = "  " .. key .. " [" .. tostring(output.physical_label) .. "]"
        lines[#lines + 1] = "    Freq 1: " .. output.pair[1]
        lines[#lines + 1] = "    Freq 2: " .. output.pair[2]
      end
      lines[#lines + 1] = ""
    end
  end

  return table.concat(lines, "\n")
end

return M
