local M = {}

M.version = "0.1.1-dev"

M.colors = {
  "white",
  "orange",
  "magenta",
  "light_blue",
  "yellow",
  "lime",
  "pink",
  "gray",
  "light_gray",
  "cyan",
  "purple",
  "blue",
  "brown",
  "green",
  "red",
  "black",
}

M.item_groups = {
  { suffix = "dye", pattern = "minecraft:%s_dye" },
  { suffix = "wool", pattern = "minecraft:%s_wool" },
  { suffix = "candle", pattern = "minecraft:%s_candle" },
  { suffix = "stained_glass", pattern = "minecraft:%s_stained_glass" },
  { suffix = "concrete", pattern = "minecraft:%s_concrete" },
  { suffix = "concrete_powder", pattern = "minecraft:%s_concrete_powder" },
}

M.network = {
  control_hz = 50,
  telemetry_hz = 25,
  timeout_ms = 250,
  control_hz_max = 80,
  telemetry_hz_max = 40,
}

M.modes = {
  off = "OFF",
  local_control = "LOCAL",
  remote = "REMOTE",
  factory = "FACTORY",
  maintenance = "MAINTENANCE",
}

M.drive_diagram = [[
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
]]

M.default_drive_profile = {
  straight = 1.0,
  moving_turn = 0.75,
  pivot = 0.55,
  reverse = 0.8,
  min_speed = 0,
  max_speed = 15,
}

return M
