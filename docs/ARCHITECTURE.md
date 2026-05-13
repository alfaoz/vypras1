# Vypra S1 Architecture

## Goal

Vypra S1 is a standard vehicle base system. It should be easy to build in a factory, easy to repair later, remote-controllable, locally controllable, and expandable with user-defined subsystems.

The core rule:

```text
The onboard computer owns all real vehicle outputs.
```

Everything else is an input source, configuration source, or display.

## Computer Roles

### Onboard Computer

Installed on every Vypra S1.

Responsibilities:

- Read local cockpit inputs when local mode is enabled.
- Receive remote control frames when remote mode is enabled.
- Mix drive intent into tread output links.
- Execute subsystem logic.
- Own toggle state, accumulator state, active mode, and active remote session.
- Write all drive/subsystem redstone link outputs.
- Publish telemetry from CC:Sable when available.
- Enter local maintenance from the onboard terminal without a disk.

The onboard computer has:

- Ender modem.
- Redstone link bridge/hub.
- Optional CC:Sable APIs when assembled into a sub-level.

It does not require a disk drive.

### Factory Registry / Configurator

Lives at the factory and is the source of truth.

Responsibilities:

- Store vehicle records.
- Allocate random unused ordered frequency pairs from the global pool.
- Generate setup keys.
- Generate setup/repair sheets.
- Write/reissue/revoke operator and maintenance disks.
- Store subsystem definitions.
- Serve Allay updates and package sources.
- Store config history and released frequencies.

### Home / Station Computer

Used by the owner/operator.

Responsibilities:

- Remote-control an S1 when a valid operator disk is inserted.
- Enter remote maintenance when a valid maintenance disk is inserted.
- Read physical control inputs through its own redstone link bridge.
- Display telemetry when a monitor exists.
- Set up/test station input bindings.

The station computer has:

- Ender modem.
- Disk drive.
- Redstone link bridge/hub.
- Optional monitor.

## Local vs Remote Control

Local mode collapses the control station into the onboard computer:

```text
local cockpit controls
  -> redstone links
  -> onboard redstone link bridge
  -> onboard computer
  -> onboard redstone link bridge
  -> output redstone links
  -> drive/subsystems
```

Remote mode uses a separate station:

```text
control room controls
  -> redstone links
  -> station redstone link bridge
  -> station computer
  -> ender modem fast path
  -> onboard computer
  -> onboard redstone link bridge
  -> output redstone links
  -> drive/subsystems
```

Both paths normalize into the same internal command shape. The drive mixer and subsystem engine should not care where the command came from.

## Frequency Model

Allowed frequency items:

- 16 dyes.
- 16 wool.
- 16 candles.
- 16 stained glass.
- 16 concrete.
- 16 concrete powder.

Total:

```text
96 items
ordered pair = freq1 + freq2
96 * 96 = 9216 redstone link channels
```

There are no semantic color groups and no fixed blocks per vehicle. The factory registry treats all 9216 ordered pairs as one global pool.

Allocation rule:

```text
When any physical redstone input/output needs a channel, pick a random pair.
If it is already allocated, pick again.
Store owner, purpose, and physical label.
```

Release rule:

```text
When a subsystem, station, local input, or vehicle is removed, release its owned pairs.
Keep historical records for repair/logging.
```

Frequency owner categories:

- `vehicle_output`: actual hardware outputs controlled by onboard firmware.
- `vehicle_local_input`: cockpit/local input links read by onboard firmware.
- `station_input`: remote station physical controls read by station software.
- `factory_test`: temporary factory/calibration channels.

Heartbeat, telemetry, auth, setup keys, config sync, and updates do not use redstone link frequencies. They are network/control-plane concepts.

## Default Drive Module

Factory worker underside view:

```text
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
```

Meaning:

- `A`: left tread forward.
- `B`: left tread reverse.
- `C`: right tread forward.
- `D`: right tread reverse.
- `E`: shared speed 0-15.

The setup sheet should print this diagram and list the random pair assigned to each physical label.

## Drive Mixer

The control contract is intent, not raw link states:

```lua
drive = {
  forward = -1, -- -1 reverse, 0 neutral, 1 forward
  turn = -1,    -- -1 left, 0 straight, 1 right
  throttle = 12,
  boost = false,
  brake = false,
}
```

Default behavior:

| Intent | Output |
| --- | --- |
| W | left forward + right forward |
| S | left reverse + right reverse |
| A | left reverse + right forward |
| D | left forward + right reverse |
| W + A | right forward only |
| W + D | left forward only |
| S + A | right reverse only |
| S + D | left reverse only |

Speed is shared, so maneuver speed is adjusted globally using a drive profile:

```lua
profile = {
  straight = 1.0,
  moving_turn = 0.75,
  pivot = 0.55,
  reverse = 0.8,
  min_speed = 0,
  max_speed = 15,
}
```

## Modes

Onboard modes:

- `OFF`: all drive outputs safe.
- `LOCAL`: read local cockpit links.
- `REMOTE`: accept one authenticated station session.
- `FACTORY`: setup/config/test/update operations.
- `MAINTENANCE`: local onboard maintenance from terminal.

Local maintenance from the onboard terminal does not require a disk because the onboard computer has no disk drive. Remote/station maintenance requires a maintenance disk.

Mode transition rule:

```text
Any mode transition forces drive neutral first.
```

## Safety Rules

- Boot sets outputs to safe defaults.
- Remote timeout sets drive neutral.
- Emergency stop, when configured, overrides drive and dangerous outputs.
- Forward plus reverse resolves to neutral.
- Left plus right resolves to neutral.
- Directional positive plus negative resolves to neutral.
- Accumulator up plus down means no change.
- Pulse/fire outputs default off.
- Harmless toggles may hold if configured.

## Runtime Rates

Benchmarked ender modem throughput is far beyond the control workload. Runtime defaults:

- Control: 50 Hz.
- Telemetry: 25 Hz.
- Remote timeout: 250 ms.

Configurable ranges:

- Control normal: 50 Hz.
- Control high: 60 Hz.
- Control max: 80 Hz.
- Telemetry normal: 25 Hz.
- Telemetry high: 30 Hz.
- Telemetry max: 40 Hz.

The expected control packet is tiny. The bottleneck is more likely CC scheduling, redstone link read/write timing, or vehicle physics than modem bandwidth.
