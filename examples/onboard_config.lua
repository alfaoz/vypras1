return {
  schema_version = 1,
  vehicle_id = "s1-example",
  vehicle_name = "Example Vypra",
  config_version = 1,
  registry_id = "vypraconfig-main",
  secrets = {
    vehicle_key = "dev-only",
  },
  network = {
    control_hz = 50,
    telemetry_hz = 25,
    timeout_ms = 250,
  },
  drive = {
    kind = "vypra_s1_default_treads",
    outputs = {
      left_forward = { physical_label = "A", pair = {"minecraft:red_wool", "minecraft:red_dye"}, safe = 0 },
      left_reverse = { physical_label = "B", pair = {"minecraft:red_wool", "minecraft:orange_dye"}, safe = 0 },
      right_forward = { physical_label = "C", pair = {"minecraft:red_wool", "minecraft:yellow_dye"}, safe = 0 },
      right_reverse = { physical_label = "D", pair = {"minecraft:red_wool", "minecraft:lime_dye"}, safe = 0 },
      speed = { physical_label = "E", pair = {"minecraft:red_wool", "minecraft:green_dye"}, safe = 0 },
    },
    profile = {
      straight = 1.0,
      moving_turn = 0.75,
      pivot = 0.55,
      reverse = 0.8,
      min_speed = 0,
      max_speed = 15,
    },
  },
  local_inputs = {
    enabled = true,
    controls = {
      drive_forward = { kind = "button", pair = {"minecraft:blue_wool", "minecraft:white_dye"} },
      drive_reverse = { kind = "button", pair = {"minecraft:blue_wool", "minecraft:orange_dye"} },
      drive_left = { kind = "button", pair = {"minecraft:blue_wool", "minecraft:magenta_dye"} },
      drive_right = { kind = "button", pair = {"minecraft:blue_wool", "minecraft:light_blue_dye"} },
      throttle = { kind = "analog", pair = {"minecraft:blue_wool", "minecraft:yellow_dye"} },
    },
  },
  subsystems = {},
  groups = {},
}
