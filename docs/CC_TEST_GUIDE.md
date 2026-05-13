# CC Test Guide

This is the v1 field-test flow.

## Install Allay

On each ComputerCraft computer:

```lua
wget run https://raw.githubusercontent.com/allaycc/allay/main/install.lua
```

Then add the Vypra package source:

```lua
allay source add https://raw.githubusercontent.com/alfaoz/vypras1/main/packages
```

## Factory Computer

Required peripherals:

- Ender/wireless modem for setup server.
- Disk drive for writing station auth disks.

Install:

```lua
allay install vypras1-factory
```

Run:

```lua
vypras1-factory
```

Suggested first flow:

1. `Create default S1`.
2. Optional: `Add local cockpit inputs`.
3. `Generate setup key`.
4. `Write operator/maintenance station disk`.
5. `Serve setup/config over modem`.

Keep the factory setup server running while pairing the onboard computer.

## Onboard Computer

Required peripherals:

- Ender/wireless modem.
- Redstone link bridge/hub.

Install:

```lua
allay install vypras1-onboard
```

Run:

```lua
vypras1-onboard
```

First boot:

1. Choose `Claim factory setup key`.
2. Enter the setup key from the factory.
3. Restart/run `vypras1-onboard`.
4. Choose `Test drive outputs`.
5. For local cockpit, choose `Local mode`.
6. For remote control, choose `Remote mode`.

Onboard has no disk drive requirement. Local/onboard maintenance is physical-access based.

## Station Computer

Required peripherals:

- Ender/wireless modem.
- Redstone link bridge/hub.
- Disk drive with the factory-written `vypra_card.lua`.

Optional:

- Monitor for telemetry.

Install:

```lua
allay install vypras1-station
```

Run:

```lua
vypras1-station
```

Flow:

1. Insert the auth disk.
2. `Print station setup`.
3. Tune physical station controls to the shown frequency pairs.
4. `Test inputs`.
5. Put onboard computer into `Remote mode`.
6. Choose `Connect/control` on the station.

The station sends control frames at the granted rate, currently 50 Hz by default. Telemetry is displayed at 25 Hz.

## Runtime Channels

Known fixed setup/control-plane channels:

- Factory setup/config: `47001`.
- Remote session request: `47002`.

Per-session fast-path channels are generated from the vehicle/session id and returned in the session grant.

## Notes

- v1 uses a development signature function. The API boundary exists, but it is not real HMAC yet.
- Registry/factory must be online for initial setup, config sync, and disk reissue.
- Driving itself does not depend on the registry after setup.
- Remote mode accepts one active station session.
