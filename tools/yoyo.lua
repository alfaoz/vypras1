-- Vypra control loop timer
-- Measures actual time spent in each stage of the onboard apply_outputs loop.
-- Run this instead of normal onboard remote mode during a timing investigation.
--
-- Requires: bridge peripheral, modem, valid onboard config at /etc/vypras1/onboard.lua
-- In CC: run the file, it connects like normal remote mode but prints timing stats.

package.path = "/usr/allay/lib/?.lua;/usr/allay/lib/?/init.lua;" .. package.path

local constants = require("vypras1.constants")
local fsutil    = require("vypras1.fsutil")
local bridge_api = require("vypras1.bridge")
local mixer     = require("vypras1.mixer")
local net       = require("vypras1.net")
local protocol  = require("vypras1.protocol")
local secure    = require("vypras1.secure")
local util      = require("vypras1.util")

local CONFIG_PATH = "/etc/vypras1/onboard.lua"

local function now() return os.epoch("utc") end

local function stats(times)
  if #times == 0 then return { avg=0, min=0, max=0, p95=0, n=0 } end
  table.sort(times)
  local sum = 0
  for _, t in ipairs(times) do sum = sum + t end
  return {
    n   = #times,
    avg = sum / #times,
    min = times[1],
    max = times[#times],
    p95 = times[math.ceil(#times * 0.95)],
  }
end

local function fmt(label, s)
  if s.n == 0 then
    print(string.format("  %-22s  no samples", label))
    return
  end
  print(string.format("  %-22s  avg %4.1fms  p95 %dms  max %dms  (n=%d)",
    label, s.avg, s.p95, s.max, s.n))
end

-- ── load config ─────────────────────────────────────────────────────────────

local config = fsutil.read_table(CONFIG_PATH)
if not config then
  printError("No config at " .. CONFIG_PATH)
  return
end

local bridge = bridge_api.find()
if not bridge then
  printError("No bridge peripheral.")
  return
end

local modem = net.find_modem()
if not modem then
  printError("No modem.")
  return
end

-- ── session request ──────────────────────────────────────────────────────────

net.open(modem, net.station_channel)
print("Waiting for session request on channel " .. net.station_channel .. " ...")

local request, reply_channel = net.receive(net.station_channel, 3600, function(m)
  return m.t == "session_request" and m.vehicle_id == config.vehicle_id
end)

if not request then printError("No session request.") return end

local credentials = config.credentials or {}
local credential  = credentials[request.credential_id]
if not credential or credential.secret ~= request.credential then
  net.send(modem, reply_channel, net.station_channel, { t = "session_denied", ok = false, err = "bad credential" })
  printError("Bad credential.")
  return
end

local session_id       = util.random_id("sess")
local control_channel  = net.channel_from_seed(config.vehicle_id .. session_id, 1)
local telemetry_channel = control_channel + 1
net.open(modem, control_channel)

local grant = protocol.session_grant({
  vehicle_id       = config.vehicle_id,
  station_id       = request.station_id,
  session_id       = session_id,
  control_channel  = control_channel,
  telemetry_channel = telemetry_channel,
  event_channel    = control_channel + 2,
  control_hz       = (config.network or constants.network).control_hz,
  telemetry_hz     = (config.network or constants.network).telemetry_hz,
  timeout_ms       = (config.network or constants.network).timeout_ms,
})
secure.sign(credential.secret, grant)
net.send(modem, reply_channel, net.station_channel, grant)
print("Session granted. Running timed loop. Press Ctrl+T to stop and print results.")

-- ── timed loop ───────────────────────────────────────────────────────────────

local latest        = { drive = { forward = 0, turn = 0, throttle = 0 }, sub = {} }
local last_seq      = -1
local control_interval = 1 / grant.control_hz
local last_telemetry   = 0

-- Timing buckets
local t_normalize  = {}
local t_mix        = {}
local t_write      = {}
local t_telemetry  = {}
local t_sleep      = {}
local t_total      = {}
local t_recv_gap   = {}  -- time between received frames
local last_recv_ms = now()
local frames_received = 0

local function receive_controls()
  while true do
    local event = { os.pullEvent("modem_message") }
    if event[3] == control_channel then
      local frame = event[5]
      if type(frame) == "table" and frame.t == "ctrl" and frame.session_id == session_id
        and secure.verify(credential.secret, frame)
        and tonumber(frame.seq or -1) > last_seq then
        local gap = now() - last_recv_ms
        if frames_received > 0 then
          t_recv_gap[#t_recv_gap + 1] = gap
        end
        last_recv_ms = now()
        latest   = { drive = frame.drive or {}, sub = frame.sub or {} }
        last_seq = frame.seq
        frames_received = frames_received + 1
      end
    end
  end
end

local function apply_outputs()
  while true do
    local t0 = now()

    local ta = now()
    local drive_intent = mixer.normalize(latest.drive)
    local tb = now()
    t_normalize[#t_normalize + 1] = tb - ta

    local tc = now()
    local drive_output = mixer.mix(drive_intent, config.drive.profile)
    local td = now()
    t_mix[#t_mix + 1] = td - tc

    local te = now()
    local outputs = config.drive.outputs
    local function wo(out, val)
      if not out then return end
      if out.signal_type == "analog" then
        bridge_api.write(bridge, out.pair, val)
      else
        bridge_api.write(bridge, out.pair, val and 15 or 0)
      end
    end
    wo(outputs.left_forward,  drive_output.left_forward)
    wo(outputs.left_reverse,  drive_output.left_reverse)
    wo(outputs.right_forward, drive_output.right_forward)
    wo(outputs.right_reverse, drive_output.right_reverse)
    wo(outputs.speed,         drive_output.speed)
    local tf = now()
    t_write[#t_write + 1] = tf - te

    local tg = now()
    if tg - last_telemetry >= (1000 / grant.telemetry_hz) then
      local tele = protocol.telemetry_frame({
        vehicle_id   = config.vehicle_id,
        session_id   = session_id,
        seq          = last_seq,
        mode         = constants.modes.remote,
        active_source = request.station_id,
        intent       = drive_intent,
        drive        = drive_output,
      })
      secure.sign(credential.secret, tele)
      net.send(modem, telemetry_channel, control_channel, tele)
      last_telemetry = tg
    end
    local th = now()
    t_telemetry[#t_telemetry + 1] = th - tg

    local ti = now()
    sleep(control_interval)
    local tj = now()
    t_sleep[#t_sleep + 1] = tj - ti

    t_total[#t_total + 1] = tj - t0
  end
end

pcall(parallel.waitForAny, receive_controls, apply_outputs)

-- ── results ──────────────────────────────────────────────────────────────────

term.clear()
term.setCursorPos(1, 1)
print("=== Vypra loop timing results ===")
print("")
print(string.format("Frames received: %d", frames_received))
print("")
print("Onboard apply_outputs breakdown:")
fmt("normalize",     stats(t_normalize))
fmt("mix",           stats(t_mix))
fmt("bridge writes", stats(t_write))
fmt("telemetry send",stats(t_telemetry))
fmt("sleep(actual)", stats(t_sleep))
fmt("total cycle",   stats(t_total))
print("")
print("Incoming frame gap (station→onboard):")
fmt("inter-frame gap", stats(t_recv_gap))
print("")
print("If bridge writes avg > 5ms: bridge peripheral is your bottleneck.")
print("If sleep avg >> 50ms: CC scheduler is throttling this computer.")
print("If inter-frame gap >> 20ms: station is sending slower than expected.")
