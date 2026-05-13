local constants = require("vypras1.constants")

local M = {}

M.version = 1
M.fast_proto = "vypra-s1-fast"
M.control_proto = "vypra-s1-control"

local function now_ms()
  if os.epoch then return os.epoch("utc") end
  return os.time() * 1000
end

function M.control_frame(fields)
  fields = fields or {}
  return {
    t = "ctrl",
    v = M.version,
    vehicle_id = fields.vehicle_id,
    station_id = fields.station_id,
    session_id = fields.session_id,
    seq = fields.seq,
    sent_ms = fields.sent_ms or now_ms(),
    drive = fields.drive or {
      f = 0,
      turn = 0,
      thr = 0,
      boost = false,
      brake = false,
      estop = false,
    },
    sub = fields.sub or {},
    sig = fields.sig,
  }
end

function M.telemetry_frame(fields)
  fields = fields or {}
  return {
    t = "tele",
    v = M.version,
    vehicle_id = fields.vehicle_id,
    session_id = fields.session_id,
    seq = fields.seq,
    sent_ms = fields.sent_ms or now_ms(),
    mode = fields.mode or constants.modes.off,
    active_source = fields.active_source,
    pose = fields.pose or { ok = false, err = "not sampled" },
    motion = fields.motion or { speed = 0, vx = 0, vy = 0, vz = 0 },
    drive = fields.drive or {},
    subsystems = fields.subsystems or {},
    warnings = fields.warnings or {},
    sig = fields.sig,
  }
end

function M.event_frame(fields)
  fields = fields or {}
  return {
    t = "event",
    v = M.version,
    vehicle_id = fields.vehicle_id,
    session_id = fields.session_id,
    seq = fields.seq,
    sent_ms = fields.sent_ms or now_ms(),
    level = fields.level or "info",
    code = fields.code or "INFO",
    message = fields.message or "",
    sig = fields.sig,
  }
end

function M.session_grant(fields)
  fields = fields or {}
  return {
    t = "session_grant",
    v = M.version,
    vehicle_id = fields.vehicle_id,
    station_id = fields.station_id,
    session_id = fields.session_id,
    control_channel = fields.control_channel,
    telemetry_channel = fields.telemetry_channel,
    event_channel = fields.event_channel,
    control_hz = fields.control_hz or constants.network.control_hz,
    telemetry_hz = fields.telemetry_hz or constants.network.telemetry_hz,
    timeout_ms = fields.timeout_ms or constants.network.timeout_ms,
  }
end

return M
