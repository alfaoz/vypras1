# Vypra S1 Schemas

These schemas are written as Lua tables because CC:Tweaked stores native Lua tables cleanly with `textutils.serialize`.

## Registry Root

The factory registry stores one root database:

```lua
registry = {
  schema_version = 1,
  registry_id = "vypraconfig-main",
  created_at = 0,
  updated_at = 0,

  vehicles = {},
  stations = {},
  allocations = {},
  credentials = {},
  setup_keys = {},
  released_allocations = {},
}
```

## Allocation Record

Every physical redstone link channel is an ordered pair from the global 9216-pair pool.

```lua
allocation = {
  id = "alloc-000123",
  pair = {"minecraft:red_wool", "minecraft:blue_candle"},

  owner_type = "vehicle_output", -- vehicle_output | vehicle_local_input | station_input | factory_test
  owner_id = "s1-0007",

  purpose = "drive.left_forward",
  physical_label = "A",
  display_label = "Left Tread Forward",

  active = true,
  created_at = 0,
  released_at = nil,
  notes = "",
}
```

The registry should index allocations by `pair_key = freq1 .. "|" .. freq2`.

## Vehicle Record

The registry-side vehicle record:

```lua
vehicle = {
  id = "s1-0007",
  name = "Vypra S1-007",
  class = "vypra-s1",
  status = "active", -- draft | pending_pair | active | maintenance | retired

  config_version = 1,
  firmware_channel = "stable",
  firmware_min = "0.1.0",

  drive = drive_config,
  local_inputs = local_input_config,
  subsystems = {},
  groups = {},

  credential_ids = {},
  active_station_id = nil,

  created_at = 0,
  updated_at = 0,
  notes = "",
}
```

## Onboard Config

The onboard computer keeps a local copy of the config. It must be enough to drive safely without the registry online.

```lua
onboard_config = {
  schema_version = 1,
  vehicle_id = "s1-0007",
  vehicle_name = "Vypra S1-007",
  config_version = 1,
  registry_id = "vypraconfig-main",

  secrets = {
    vehicle_key = "...long random secret...",
  },

  drive = drive_config,
  local_inputs = local_input_config,
  subsystems = {},
  groups = {},

  network = {
    control_hz = 50,
    telemetry_hz = 25,
    timeout_ms = 250,
  },
}
```

## Drive Config

```lua
drive_config = {
  kind = "vypra_s1_default_treads",

  physical_map = {
    view = "underside",
    diagram = [[
       {R}
     A  E  C
[L]  #--+--#  [R]
     B  v  D
       {F}

LF: A
LR: B
RF: C
RB: D
SP: E
]],
  },

  outputs = {
    left_forward = {
      physical_label = "A",
      allocation_id = "alloc-000001",
      pair = {"...", "..."},
      safe = 0,
    },
    left_reverse = {
      physical_label = "B",
      allocation_id = "alloc-000002",
      pair = {"...", "..."},
      safe = 0,
    },
    right_forward = {
      physical_label = "C",
      allocation_id = "alloc-000003",
      pair = {"...", "..."},
      safe = 0,
    },
    right_reverse = {
      physical_label = "D",
      allocation_id = "alloc-000004",
      pair = {"...", "..."},
      safe = 0,
    },
    speed = {
      physical_label = "E",
      allocation_id = "alloc-000005",
      pair = {"...", "..."},
      safe = 0,
    },
  },

  profile = {
    straight = 1.0,
    moving_turn = 0.75,
    pivot = 0.55,
    reverse = 0.8,
    min_speed = 0,
    max_speed = 15,
  },
}
```

## Local Input Config

Local inputs belong to the vehicle and are read by the onboard computer.

```lua
local_inputs = {
  enabled = true,
  mode_switch = "terminal", -- terminal for v1
  controls = {
    drive_forward = {
      kind = "button",
      allocation_id = "alloc-000020",
      pair = {"...", "..."},
      maps_to = "drive.forward_pos",
    },
    drive_reverse = {
      kind = "button",
      allocation_id = "alloc-000021",
      pair = {"...", "..."},
      maps_to = "drive.forward_neg",
    },
    drive_left = {
      kind = "button",
      allocation_id = "alloc-000022",
      pair = {"...", "..."},
      maps_to = "drive.turn_neg",
    },
    drive_right = {
      kind = "button",
      allocation_id = "alloc-000023",
      pair = {"...", "..."},
      maps_to = "drive.turn_pos",
    },
    throttle = {
      kind = "analog",
      allocation_id = "alloc-000024",
      pair = {"...", "..."},
      maps_to = "drive.throttle",
    },
  },
}
```

## Station Config

Station inputs belong to an external station and are read by station software.

```lua
station = {
  id = "station-0003",
  name = "Home Control Room",
  status = "active",

  input_profile = {
    controls = {
      drive_forward = input_binding,
      drive_reverse = input_binding,
      drive_left = input_binding,
      drive_right = input_binding,
      throttle = input_binding,
      estop = input_binding,
    },
  },

  created_at = 0,
  updated_at = 0,
}
```

## Input Binding

```lua
input_binding = {
  kind = "button", -- button | analog | switch
  allocation_id = "alloc-001001",
  pair = {"...", "..."},
  maps_to = "drive.forward_pos",
  invert = false,
  threshold = 1,
}
```

## Subsystem Record

Subsystem hardware belongs to a vehicle. Controls can be bound later by local input or station input profiles.

```lua
subsystem = {
  id = "turret_yaw",
  label = "Turret Yaw",
  kind = "directional", -- direct | toggle | pulse | analog | directional | accumulator
  status = "active",   -- draft | pending_install | active | disabled

  outputs = {},
  config = {},
  state = {},

  safe_behavior = "neutral", -- off | neutral | hold | value
  safe_value = 0,

  created_at = 0,
  updated_at = 0,
}
```

### Direct

One boolean command directly drives one boolean output.

```lua
config = {
  invert = false,
}

outputs = {
  main = output_binding_boolean,
}
```

### Toggle

Rising edge flips stored onboard state.

```lua
config = {
  initial = false,
  invert_output = false,
  safe_behavior = "hold",
}

state = {
  value = false,
  last_input = false,
}
```

### Pulse

Rising edge sends high for a configured tick duration.

```lua
config = {
  pulse_ticks = 4,
  retrigger = false,
}

state = {
  remaining_ticks = 0,
  last_input = false,
}
```

### Analog

0-15 input maps to 0-15 output.

```lua
config = {
  min = 0,
  max = 15,
  invert = false,
  safe_behavior = "hold",
}
```

### Directional

Two boolean outputs. Both on is never allowed.

```lua
outputs = {
  positive = output_binding_boolean,
  negative = output_binding_boolean,
}

config = {
  positive_label = "Right",
  negative_label = "Left",
  invert_positive = false,
  invert_negative = false,
}
```

### Accumulator

Stored 0-15 value. Holding up/down changes value every configured number of ticks.

```lua
outputs = {
  value = output_binding_analog,
}

config = {
  min = 0,
  max = 15,
  initial = 7,
  up_every_ticks = 10,
  down_every_ticks = 10,
  safe_behavior = "hold",
}

state = {
  value = 7,
  up_counter = 0,
  down_counter = 0,
}
```

## Output Binding

```lua
output_binding_boolean = {
  signal_type = "boolean",
  allocation_id = "alloc-000300",
  pair = {"...", "..."},
  physical_label = "TY+",
  invert = false,
  safe = 0,
}

output_binding_analog = {
  signal_type = "analog",
  allocation_id = "alloc-000301",
  pair = {"...", "..."},
  physical_label = "TRIM",
  min = 0,
  max = 15,
  invert = false,
  safe = 0,
}
```

## Group Record

Groups are virtual and do not allocate frequencies directly.

```lua
group = {
  id = "combat_lights",
  label = "Combat Lights",
  members = {
    { subsystem_id = "front_lights", command = "set", value = true },
    { subsystem_id = "rear_lights", command = "set", value = true },
  },
}
```

## Setup Key

Short human-entered setup key. This is not the long-term secret.

```lua
setup_key = {
  key = "K7Q9DA",
  vehicle_id = "s1-0007",
  status = "unused", -- unused | used | expired | revoked
  expires_at = 0,
  attempts = 0,
  max_attempts = 8,
}
```

## Credential / Disk Record

Remote disks are used by stations. Onboard local maintenance does not use a disk.

```lua
credential = {
  id = "cred-00044",
  vehicle_id = "s1-0007",
  card_type = "operator", -- operator | maintenance
  status = "active",     -- active | revoked | expired
  disk_id = 12345,

  permissions = {
    remote_control = true,
    remote_maintenance = false,
    reconfigure_station = true,
  },

  secret = "...long random card secret...",
  issued_at = 0,
  expires_at = nil,
  revoked_at = nil,
}
```

Disk file:

```lua
disk_card = {
  schema_version = 1,
  registry_id = "vypraconfig-main",
  vehicle_id = "s1-0007",
  credential_id = "cred-00044",
  card_type = "operator",
  credential = "...signed or shared credential material...",
}
```

Lost disk flow revokes the old credential and writes a new credential. If the lost disk is later found, it should fail the next registry-backed auth check.
