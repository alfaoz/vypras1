# Implementation Plan

## Build Order

### Phase 1: Shared Core

- Constants and item pool.
- Frequency allocator.
- Drive mixer.
- Basic schema validators.
- Serialization helpers.
- Protocol constructors.

Exit criteria:

- Drive mixer can be tested locally with truth table cases.
- Frequency allocator never returns an allocated pair.
- Example configs validate.

Current status:

- Constants, item pool, allocator, drive mixer, subsystem stepping helpers, protocol constructors, and initial tests exist.
- Security is still a placeholder boundary pending Allay crypto/hash dependencies.

### Phase 2: Onboard Minimal

- Load config from `/etc/vypras1/onboard.lua`.
- Detect modem and redstone link bridge.
- Set all outputs safe on boot.
- Implement drive output writer.
- Implement local input polling.
- Implement LOCAL mode.
- Implement terminal maintenance menu.

Exit criteria:

- A cockpit/local controller can drive through onboard input links.
- Boot/reboot always clears drive outputs first.

Current status:

- Local mode skeleton exists.
- Remote mode and subsystem output execution now exist in v1-test form.
- Setup-key claim and config sync exist through the factory modem server.

### Phase 3: Factory Minimal

- Registry file storage.
- Random frequency allocation.
- Create vehicle.
- Generate setup key.
- Print setup sheet.
- Claim setup key from onboard.
- Serve config sync.

Exit criteria:

- A new vehicle can be created and paired.
- Repair/frequency map can be displayed.

### Phase 4: Station Minimal

- Read disk credential.
- Detect peripherals.
- Create station input profile.
- Test input links.
- Request session.
- Send control frames at 50 Hz.
- Render telemetry text if monitor exists.

Exit criteria:

- Remote station can control a paired S1.
- Onboard remote timeout stops drive.

### Phase 5: Subsystems

- Implement direct, toggle, pulse, analog, directional, accumulator.
- Add subsystem from factory.
- Sync onboard config.
- Bind local/station inputs to subsystem commands.
- Output test flow.

Exit criteria:

- A directional gearshift subsystem works.
- An accumulator analog subsystem works.
- A toggle and pulse subsystem work.

### Phase 6: Security

- Allay crypto dependency.
- HMAC signatures.
- Session key derivation.
- Sequence number replay protection.
- Credential revocation checks.

Exit criteria:

- Invalid session frames are rejected.
- Old sequence frames are rejected.
- Revoked disk cannot start a new remote session when registry is reachable.

### Phase 7: Updates and Polish

- Allay package descriptors.
- Rednet Allay source support from factory.
- Version checks.
- Config migrations.
- Better UI screens.
- Logs/diagnostics.

## Engineering Invariants

- Onboard owns all physical outputs.
- Registry owns allocation truth.
- Local and remote inputs normalize into the same command object.
- Runtime control does not depend on registry availability.
- Every output has a safe value.
- Every config has a schema version.
- Every remote session has one active controller.

## First Tests To Write

Drive mixer truth table:

- W.
- S.
- A.
- D.
- W+A.
- W+D.
- S+A.
- S+D.
- brake.
- throttle shaping.

Frequency allocator:

- Generates only valid allowed items.
- Never returns used pair.
- Pair ordering is preserved.

Subsystem engine:

- Toggle rising edge.
- Pulse duration.
- Directional conflict neutral.
- Accumulator rate and clamp.

Runtime:

- Remote timeout neutral.
- Mode switch neutral.
- Old sequence rejected.
