# Vypra S1 Runtime Protocol

## Network Strategy

Use two layers:

```text
Control plane:
  rednet-style discovery, registry sync, setup, auth, config, update checks

Fast path:
  raw modem channels for active remote control and telemetry
```

The active driving loop must never depend on the registry. Once a station session is granted, the station and onboard computer exchange frames directly.

## Runtime Rates

Defaults:

```lua
network = {
  control_hz = 50,
  telemetry_hz = 25,
  timeout_ms = 250,
}
```

Control frames are sent:

- Immediately on input change.
- Repeated at `control_hz` while the session is active.

Telemetry frames are sent at `telemetry_hz`.

## Session Channels

After auth, the onboard computer grants a session:

```lua
session_grant = {
  t = "session_grant",
  vehicle_id = "s1-0007",
  station_id = "station-0003",
  session_id = "sess-...",
  control_channel = 43120,
  telemetry_channel = 43121,
  event_channel = 43122,
  control_hz = 50,
  telemetry_hz = 25,
  timeout_ms = 250,
}
```

Only one remote session is active per vehicle in v1.

## Message Security

For v1 implementation:

- Setup keys are one-time pairing codes.
- Long-term vehicle and card secrets are random, not human-sized.
- Remote control frames include `session_id`, `seq`, and a signature.
- The onboard computer rejects old sequence numbers.
- The onboard computer rejects frames for inactive sessions.

Signature placeholder:

```lua
sig = hmac_sha256(session_key, canonical_body)
```

Allay can provide the crypto/hash libraries later. The initial skeleton keeps the API boundary but does not hardcode a crypto implementation.

## Auth Flow

Station with disk:

```text
station -> registry/onboard: request session with disk credential
registry/onboard -> station: challenge
station -> registry/onboard: signed challenge
onboard -> station: session_grant
```

If the registry is reachable, revocation should be checked. If the registry is unreachable, an onboard cached trust decision can be allowed only for non-expired credentials.

## Control Frame

Readable form:

```lua
control_frame = {
  t = "ctrl",
  v = 1,
  vehicle_id = "s1-0007",
  station_id = "station-0003",
  session_id = "sess-...",
  seq = 18422,
  sent_ms = 123456789,

  drive = {
    f = 1,      -- -1 reverse, 0 neutral, 1 forward
    turn = -1, -- -1 left, 0 straight, 1 right
    thr = 12,  -- 0-15
    boost = false,
    brake = false,
    estop = false,
  },

  sub = {
    lights = true,
    turret_yaw_up = true,
    turret_yaw_down = false,
    cannon_fire = false,
  },

  sig = "...",
}
```

Implementation note:

Start with readable tables. If measured CPU overhead is too high, add a compact encoder later. The modem tests showed bandwidth is not the problem.

## Telemetry Frame

```lua
telemetry_frame = {
  t = "tele",
  v = 1,
  vehicle_id = "s1-0007",
  session_id = "sess-...",
  seq = 9001,
  sent_ms = 123456900,

  mode = "REMOTE",
  active_source = "station-0003",

  pose = {
    ok = true,
    x = 0,
    y = 0,
    z = 0,
    heading = 0,
    pitch = 0,
    roll = 0,
  },

  motion = {
    speed = 0,
    vx = 0,
    vy = 0,
    vz = 0,
  },

  drive = {
    left_forward = 0,
    left_reverse = 0,
    right_forward = 0,
    right_reverse = 0,
    speed = 0,
  },

  subsystems = {
    lights = true,
    turret_yaw = 7,
  },

  warnings = {},
  sig = "...",
}
```

Telemetry should degrade gracefully if CC:Sable is unavailable:

```lua
pose = { ok = false, err = "sublevel unavailable" }
```

## Event Frame

Low-rate events:

```lua
event_frame = {
  t = "event",
  v = 1,
  vehicle_id = "s1-0007",
  session_id = "sess-...",
  seq = 12,
  level = "warn", -- info | warn | error
  code = "REMOTE_TIMEOUT",
  message = "Remote control timed out; drive set neutral.",
  sig = "...",
}
```

## Timeout Behavior

Onboard remote mode:

```text
If no valid control frame arrives for timeout_ms:
  set drive neutral
  keep harmless subsystem states according to safe_behavior
  keep session open for a short grace window
```

Recommended:

- `timeout_ms = 250`.
- Reconnect grace window: 5 seconds.

## Local Mode

Local mode does not use the network protocol. The onboard computer reads vehicle-owned local input frequencies and produces the same normalized command object internally.

## Message Types

Control plane:

- `discover_registry`
- `registry_announce`
- `setup_claim`
- `setup_claim_result`
- `config_sync_request`
- `config_sync_result`
- `update_check`
- `update_result`
- `auth_request`
- `auth_challenge`
- `auth_response`
- `session_grant`
- `session_denied`

Fast path:

- `ctrl`
- `tele`
- `event`
- `release_control`
- `ping`
- `pong`
