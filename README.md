# Vypra S1 Control System

This workspace contains the working design and first implementation skeleton for the Vypra S1 platform.

Vypra S1 is a ComputerCraft-controlled vehicle base for Create/Create Aeronautics style builds. The onboard computer owns the vehicle outputs. Inputs can come from a local cockpit or from a remote control station over ender modem.

## Software Roles

- `vypras1-onboard`: runs on every Vypra S1.
- `vypras1-factory`: registry, configurator, setup keys, frequency allocation, disks, updates.
- `vypras1-station`: home/control/maintenance station.
- `vypras1`: shared Lua library package used by all roles.

## Docs

- [Architecture](docs/ARCHITECTURE.md)
- [Schemas](docs/SCHEMAS.md)
- [Runtime Protocol](docs/PROTOCOL.md)
- [Lifecycle Flows](docs/LIFECYCLES.md)
- [CC Test Guide](docs/CC_TEST_GUIDE.md)
- [Implementation Plan](docs/IMPLEMENTATION_PLAN.md)

## Current Status

This is not complete production software yet. It is the design baseline plus a Lua skeleton so implementation can proceed without re-litigating the platform shape.

Working pieces now present:

- Random ordered-pair frequency pool model.
- Default S1 drive map and mixer.
- Registry allocator skeleton.
- Onboard local-mode skeleton.
- Factory/station role skeletons.
- Allay package descriptors.
- Basic Lua tests for allocator and drive mixer.
- CC-testable factory/onboard/station v1 flow.

The package descriptors currently assume a future source URL of `alfaoz/vypras1`. They can also be served from a factory computer later through Allay's rednet source mechanism.

The modem benchmark lives separately in `vypra-netbench/`.
