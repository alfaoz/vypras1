local root = (... or ".")

local function load_as(name, path)
  package.preload[name] = function()
    return assert(loadfile(root .. "/" .. path))()
  end
end

load_as("vypras1.constants", "src/common/constants.lua")
load_as("vypras1.util", "src/common/util.lua")
load_as("vypras1.frequency", "src/common/frequency.lua")
load_as("vypras1.mixer", "src/common/mixer.lua")
load_as("vypras1.protocol", "src/common/protocol.lua")
load_as("vypras1.schema", "src/common/schema.lua")
load_as("vypras1.subsystems", "src/common/subsystems.lua")
load_as("vypras1.secure", "src/common/secure.lua")
load_as("vypras1.commands", "src/common/commands.lua")
load_as("vypras1.fsutil", "src/common/fsutil.lua")
load_as("vypras1.bridge", "src/common/bridge.lua")
load_as("vypras1.factory.registry", "src/factory/registry.lua")

local constants = require("vypras1.constants")
local frequency = require("vypras1.frequency")
local mixer = require("vypras1.mixer")
local registry = require("vypras1.factory.registry")
local secure = require("vypras1.secure")
local subsystems = require("vypras1.subsystems")
local commands = require("vypras1.commands")

local failures = 0

local function check(name, condition)
  if condition then
    print("ok - " .. name)
  else
    failures = failures + 1
    print("FAIL - " .. name)
  end
end

local function same_drive(actual, expected)
  for key, value in pairs(expected) do
    if actual[key] ~= value then
      return false, key .. " expected " .. tostring(value) .. " got " .. tostring(actual[key])
    end
  end
  return true
end

check("96 frequency items", #frequency.items() == 96)
check("9216 ordered frequency pairs", frequency.all_pair_count() == 9216)
check("ordered pair keys differ", frequency.pair_key({"a", "b"}) ~= frequency.pair_key({"b", "a"}))

local reg = registry.new_registry("test")
local vehicle = registry.create_vehicle(reg, "Test S1")
local used = {}
for _, allocation in pairs(reg.allocations) do
  local key = frequency.pair_key(allocation.pair)
  check("unique allocation " .. allocation.id, not used[key])
  used[key] = true
end
check("default drive created", vehicle.drive.outputs.left_forward ~= nil and vehicle.drive.outputs.speed ~= nil)

local setup_key = registry.create_setup_key(reg, vehicle.id)
check("setup key created", type(setup_key) == "string" and #setup_key == 6)
local onboard_config = registry.claim_setup_key(reg, setup_key)
check("setup key returns onboard config", onboard_config and onboard_config.vehicle_id == vehicle.id)
check("used setup key cannot be reused", registry.claim_setup_key(reg, setup_key) == nil)

registry.add_default_local_drive_inputs(reg, vehicle.id)
check("local throttle allocated", reg.vehicles[vehicle.id].local_inputs.controls.throttle ~= nil)

local subsystem = registry.add_subsystem(reg, vehicle.id, "accumulator", "trim", "Trim", {
  initial = 7,
  min = 0,
  max = 15,
  up_every_ticks = 2,
  down_every_ticks = 2,
})
check("accumulator subsystem allocated", subsystem and subsystem.outputs.value ~= nil)

local credential = registry.create_credential(reg, vehicle.id, "operator")
local station = registry.create_station_profile(reg, vehicle.id, "Test Station")
local card = registry.disk_card(reg, credential.id, 123, station)
check("operator disk card created", card and card.credential_id == credential.id and card.station_profile.id == station.id)
local fake_bridge = {
  values = {
    ["minecraft:red_dye|minecraft:white_wool"] = 15,
    ["minecraft:blue_dye|minecraft:white_wool"] = 9,
  },
}
function fake_bridge.getLinkSignal(a, b)
  return fake_bridge.values[a .. "|" .. b] or 0
end
local mapped_command = commands.from_controls(fake_bridge, {
  custom_forward = {
    maps_to = "station.drive_forward",
    pair = { "minecraft:red_dye", "minecraft:white_wool" },
  },
  lever = {
    kind = "analog",
    maps_to = "station.throttle",
    pair = { "minecraft:blue_dye", "minecraft:white_wool" },
  },
})
check("station semantic control mapping", mapped_command.drive.forward == 1 and mapped_command.drive.throttle == 9)
local ok_serialize = pcall(function()
  if textutils and textutils.serialize then
    return textutils.serialize(reg)
  end
  -- Local Lua has no CC textutils, but this still catches obvious cycles with a simple walker.
  local seen = {}
  local function walk(value)
    if type(value) ~= "table" then return end
    if seen[value] then error("repeated table") end
    seen[value] = true
    for k, v in pairs(value) do
      walk(k)
      walk(v)
    end
    seen[value] = nil
  end
  walk(reg)
end)
check("registry has no repeated table refs for CC serialization", ok_serialize)

local frame = { t = "ctrl", seq = 1, drive = { f = 1 } }
secure.sign(credential.secret, frame)
check("dev signature verifies", secure.verify(credential.secret, frame))
check("dev signature rejects wrong key", not secure.verify("wrong", frame))
local grant_a = { t = "session_grant", vehicle_id = "s1", session_id = "abc", control_channel = 1, telemetry_channel = 2 }
local grant_b = { telemetry_channel = 2, control_channel = 1, session_id = "abc", vehicle_id = "s1", t = "session_grant" }
secure.sign("key", grant_a)
grant_b.sig = grant_a.sig
check("dev signature stable across table key order", secure.verify("key", grant_b))
grant_b.proto = "vypra-s1-v1"
check("dev signature ignores transport proto", secure.verify("key", grant_b))
grant_b.sent_ms = 12345
check("dev signature detects post-sign timestamp mutation", not secure.verify("key", grant_b))
grant_b.sent_ms = nil

local profile = constants.default_drive_profile
local cases = {
  {
    name = "W both forward",
    intent = { forward = 1, turn = 0, throttle = 10 },
    expected = { left_forward = 15, left_reverse = 0, right_forward = 15, right_reverse = 0, speed = 10 },
  },
  {
    name = "S both reverse",
    intent = { forward = -1, turn = 0, throttle = 10 },
    expected = { left_forward = 0, left_reverse = 15, right_forward = 0, right_reverse = 15, speed = 8 },
  },
  {
    name = "A pivot left",
    intent = { forward = 0, turn = -1, throttle = 10 },
    expected = { left_forward = 0, left_reverse = 15, right_forward = 15, right_reverse = 0, speed = 6 },
  },
  {
    name = "D pivot right",
    intent = { forward = 0, turn = 1, throttle = 10 },
    expected = { left_forward = 15, left_reverse = 0, right_forward = 0, right_reverse = 15, speed = 6 },
  },
  {
    name = "W+A moving left",
    intent = { forward = 1, turn = -1, throttle = 10 },
    expected = { left_forward = 0, left_reverse = 0, right_forward = 15, right_reverse = 0, speed = 8 },
  },
  {
    name = "W+D moving right",
    intent = { forward = 1, turn = 1, throttle = 10 },
    expected = { left_forward = 15, left_reverse = 0, right_forward = 0, right_reverse = 0, speed = 8 },
  },
  {
    name = "brake neutral",
    intent = { forward = 1, turn = 0, throttle = 10, brake = true },
    expected = { left_forward = 0, left_reverse = 0, right_forward = 0, right_reverse = 0, speed = 0 },
  },
}

for _, case in ipairs(cases) do
  local actual = mixer.mix(case.intent, profile)
  local ok, detail = same_drive(actual, case.expected)
  check(case.name .. (detail and (" (" .. detail .. ")") or ""), ok)
end

local acc = {
  kind = "accumulator",
  config = { initial = 7, min = 0, max = 15, up_every_ticks = 2, down_every_ticks = 2 },
}
local state = subsystems.initial_state(acc)
local outputs
outputs, state = subsystems.step(acc, state, { up = true })
outputs, state = subsystems.step(acc, state, { up = true })
check("accumulator increments on configured ticks", outputs.value == 8)
outputs, state = subsystems.step(acc, state, { up = true, down = true })
check("accumulator conflict holds", outputs.value == 8)

if failures > 0 then
  error(tostring(failures) .. " test(s) failed")
end

print("all tests passed")
