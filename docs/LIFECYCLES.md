# Vypra S1 Lifecycle Flows

## New Vehicle Build

1. Factory opens `vypras1-factory`.
2. Factory creates a new vehicle record.
3. Factory selects default Vypra S1 drive module.
4. Registry allocates five vehicle output pairs:
   - A left forward.
   - B left reverse.
   - C right forward.
   - D right reverse.
   - E speed.
5. Factory optionally adds initial subsystems and local cockpit inputs.
6. Registry prints/shows setup sheet with drive underside diagram and all assigned pairs.
7. Factory generates a one-time setup key.
8. Worker builds/tunes all physical redstone links from the setup sheet.
9. Worker installs onboard firmware with Allay.
10. Worker runs onboard setup and enters setup key.
11. Onboard claims setup key from registry and downloads config.
12. Onboard saves config under `/etc/vypras1/onboard.lua`.
13. Onboard runs output tests.
14. Registry marks vehicle active.

## Factory Setup Sheet

The sheet must be useful for a worker without software context.

Example:

```text
Vehicle: Vypra S1-007
Config version: 1

Drive underside view:

       {R}
     A  E  C
[L]  #--+--#  [R]
     B  v  D
       {F}

A Left Tread Forward
  Freq 1: minecraft:red_concrete
  Freq 2: minecraft:blue_candle

B Left Tread Reverse
  Freq 1: ...
  Freq 2: ...
```

## Add Subsystem Later

1. Factory opens existing vehicle record.
2. Factory chooses `Add subsystem`.
3. User selects subsystem type:
   - direct
   - toggle
   - pulse
   - analog
   - directional
   - accumulator
4. Factory asks only the questions needed for that type.
5. Registry allocates output frequency pairs.
6. Registry increments vehicle `config_version`.
7. Registry marks subsystem `pending_install`.
8. Registry prints/shows install sheet.
9. Worker wires/tunes subsystem links.
10. Onboard enters maintenance from local terminal, no disk required.
11. Onboard syncs latest config from registry.
12. Onboard tests new outputs.
13. If test passes, subsystem status becomes `active`.
14. Station software sees the new subsystem on next sync/connect and offers binding setup.

Subsystems can exist without controls bound yet. Hardware availability and operator bindings are separate concerns.

## Remove Subsystem

1. Factory selects subsystem.
2. Registry marks subsystem `disabled`.
3. Onboard syncs config and sets outputs safe.
4. Factory confirms physical removal.
5. Registry releases owned allocation pairs.
6. Registry keeps historical allocation entries for repair logs.
7. Station/local bindings pointing to the subsystem are disabled.

## Local Cockpit Setup

Local cockpit controls are part of the vehicle, not a separate station.

1. Factory marks vehicle as having local controls.
2. Registry allocates `vehicle_local_input` pairs.
3. Setup sheet lists each cockpit control:
   - W / forward
   - S / reverse
   - A / left
   - D / right
   - shift / boost if present
   - space / brake or estop if configured
   - throttle lever 0-15
   - subsystem controls
4. Worker tunes local control outputs to those pairs.
5. Onboard enters local maintenance.
6. Onboard runs input test:
   - "Press W"
   - "Move throttle to 15"
   - "Press turret right"
7. Onboard saves input test status.
8. LOCAL mode becomes available.

No disk is needed for local/onboard maintenance.

## Remote Station Setup

1. User installs `vypras1-station` with Allay.
2. Station detects peripherals:
   - ender modem required
   - disk drive required
   - redstone link bridge required for physical controls
   - monitor optional
3. User inserts operator or maintenance disk.
4. Station reads vehicle/card identity.
5. Station authenticates with registry/onboard.
6. Registry creates or updates station record.
7. Registry allocates `station_input` pairs for this station's physical controls.
8. Station displays setup/test instructions.
9. User tunes physical controls.
10. Station tests every input.
11. Station saves local station profile.

Daily use:

1. Insert disk.
2. Run station software.
3. Press connect.
4. Station requests remote control session.
5. Onboard grants one active session if allowed.
6. Station starts 50 Hz control and 25 Hz telemetry.

## Lost Auth Disk

1. Factory opens vehicle record.
2. Factory selects credential.
3. Factory revokes old credential.
4. Factory writes replacement disk with new credential.
5. Registry records replacement event.
6. Station uses new disk.

If the onboard computer can reach the registry, revoked disks are rejected. If the registry is offline, onboard can only enforce cached expiration/revocation state.

## Replacing Broken Onboard Computer

1. Factory selects vehicle.
2. Factory issues a new setup key for existing vehicle config.
3. Worker installs replacement computer and firmware.
4. Worker enters setup key.
5. Replacement onboard downloads existing config and vehicle secret.
6. Physical redstone links do not need to change.
7. Old onboard identity is revoked if applicable.

## Update Flow

Allay is the install/update mechanism.

Factory:

1. Hosts package source with Allay server/rednet transport or GitHub source.
2. Publishes package versions.
3. Marks firmware channels:
   - stable
   - beta
   - factory

Onboard:

1. Local maintenance menu has `Check updates`.
2. Onboard asks registry for allowed update channel.
3. Onboard runs Allay update.
4. Config under `/etc/vypras1/` is preserved.
5. On reboot, migration checks run before driving.

Station:

1. Station can check updates from its menu.
2. Maintenance disks may permit forced update.

## Config Migration

Every config has:

```lua
schema_version = 1
config_version = N
```

On startup:

1. Load config.
2. If schema is older, run migrations.
3. If migration fails, enter safe maintenance mode.
4. Never drive with partially migrated config.

## Offline Behavior

Driving:

- Local mode works without registry.
- Remote mode can work with cached trusted credentials if allowed.

Maintenance:

- Local diagnostic/test menus work without registry.
- Config changes need registry.
- Updates need registry/package source.

Registry offline should not make a working vehicle undrivable, but it should block permanent reconfiguration.
