-- Vypra bridge peripheral latency benchmark
-- Measures getLinkSignal and sendLinkSignal call overhead to isolate
-- whether the bridge is causing control loop delay.
--
-- Run on any computer with a bridge peripheral attached.
-- Usage:  lua vypra_bridge_bench.lua
-- In CC:  just run the file

local function now()
  return os.epoch("utc")
end

local function find_bridge()
  local b = peripheral.find("redstoneLinkBridge")
    or peripheral.find("Create_Redstone_Link_Bridge")
    or peripheral.find("redstone_link_bridge")
  if b then return b end
  for _, name in ipairs(peripheral.getNames()) do
    local w = peripheral.wrap(name)
    if type(w) == "table" and w.getLinkSignal and w.sendLinkSignal then
      return w, name
    end
  end
  return nil
end

local function stats(times)
  table.sort(times)
  local sum = 0
  for _, t in ipairs(times) do sum = sum + t end
  return {
    n    = #times,
    avg  = sum / #times,
    min  = times[1],
    max  = times[#times],
    p50  = times[math.ceil(#times * 0.50)],
    p95  = times[math.ceil(#times * 0.95)],
  }
end

local function fmt(s)
  return string.format(
    "avg %4.1fms  p50 %dms  p95 %dms  min %dms  max %dms  (n=%d)",
    s.avg, s.p50, s.p95, s.min, s.max, s.n)
end

local function bench_reads(bridge, pair, n)
  local times = {}
  for i = 1, n do
    local t0 = now()
    bridge.getLinkSignal(pair[1], pair[2])
    times[i] = now() - t0
  end
  return stats(times)
end

local function bench_writes(bridge, pair, n)
  local times = {}
  for i = 1, n do
    local t0 = now()
    bridge.sendLinkSignal(pair[1], pair[2], i % 2 == 0 and 15 or 0)
    times[i] = now() - t0
  end
  bridge.sendLinkSignal(pair[1], pair[2], 0)
  return stats(times)
end

local function bench_cycle(bridge, pair, n, reads, writes)
  -- Simulates one control loop iteration: N reads then N writes
  local times = {}
  for c = 1, n do
    local t0 = now()
    for _ = 1, reads  do bridge.getLinkSignal(pair[1], pair[2])     end
    for _ = 1, writes do bridge.sendLinkSignal(pair[1], pair[2], 0) end
    times[c] = now() - t0
  end
  return stats(times)
end

-- ── main ────────────────────────────────────────────────────────────────────

term.clear()
term.setCursorPos(1, 1)
print("Vypra bridge bench")
print("==================")
print("")

local bridge, bridge_name = find_bridge()
if not bridge then
  printError("No bridge peripheral found.")
  printError("Needs redstoneLinkBridge (CC:C Bridge or compatible).")
  return
end
print("Bridge: " .. tostring(bridge_name or "found"))
print("")

write("Test freq 1 (e.g. minecraft:red_wool):  ")
local f1 = read()
write("Test freq 2 (e.g. minecraft:blue_dye):  ")
local f2 = read()
local pair = { f1, f2 }

write("Samples per test [200]: ")
local n = tonumber(read()) or 200

print("")
print("Running " .. n .. " samples per test...")
print("")

-- Individual call cost
write("read  ... ")
local r = bench_reads(bridge, pair, n)
print(fmt(r))

write("write ... ")
local w = bench_writes(bridge, pair, n)
print(fmt(w))

print("")

-- Station sender simulation: reads all controls, then sends via modem
-- In real code: commands.from_controls reads 8 signals per cycle
write("station cycle  (8r+0w)  ... ")
local sc = bench_cycle(bridge, pair, n, 8, 0)
print(fmt(sc))

-- Onboard apply_outputs simulation: writes 5 drive outputs per cycle
write("onboard cycle  (0r+5w)  ... ")
local oc = bench_cycle(bridge, pair, n, 0, 5)
print(fmt(oc))

-- Full round cycle: station read + onboard write combined budget
write("combined       (8r+5w)  ... ")
local fc = bench_cycle(bridge, pair, n, 8, 5)
print(fmt(fc))

print("")
print("────────────────────────────────────────────")

-- Estimate where the 1-second delay comes from
local station_ms  = sc.avg
local onboard_ms  = oc.avg
local sleep_ms    = 50   -- CC min sleep = 1 tick
local modem_ms    = 1    -- effectively instant

local theoretical = station_ms + sleep_ms + modem_ms + onboard_ms + sleep_ms
print(string.format("Estimated round-trip:"))
print(string.format("  station bridge reads : %.1f ms", station_ms))
print(string.format("  station sleep        : %.0f ms  (1 CC tick)", sleep_ms))
print(string.format("  modem transit        : ~%.0f ms", modem_ms))
print(string.format("  onboard bridge writes: %.1f ms", onboard_ms))
print(string.format("  onboard sleep        : %.0f ms  (1 CC tick)", sleep_ms))
print(string.format("  ─────────────────────────────"))
print(string.format("  theoretical total    : %.0f ms", theoretical))
print(string.format("  (worst-case 3-tick   : %.0f ms)", theoretical + sleep_ms))
print("")
print("If theoretical << your observed delay, the bottleneck is")
print("elsewhere: server CC CPU limits, signal propagation, or")
print("the bridge peripheral itself is queuing calls.")
