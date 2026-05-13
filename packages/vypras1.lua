return {
  name = "vypras1",
  version = "0.1.3-dev",
  description = "Shared libraries for the Vypra S1 control system.",
  author = "alfa",
  license = "MIT",

  base_url = "https://raw.githubusercontent.com/alfaoz/vypras1/main",

  files = {
    lib = {
      ["src/common/constants.lua"] = "constants.lua",
      ["src/common/frequency.lua"] = "frequency.lua",
      ["src/common/mixer.lua"] = "mixer.lua",
      ["src/common/protocol.lua"] = "protocol.lua",
      ["src/common/schema.lua"] = "schema.lua",
      ["src/common/subsystems.lua"] = "subsystems.lua",
      ["src/common/secure.lua"] = "secure.lua",
      ["src/common/fsutil.lua"] = "fsutil.lua",
      ["src/common/bridge.lua"] = "bridge.lua",
      ["src/common/util.lua"] = "util.lua",
      ["src/common/net.lua"] = "net.lua",
      ["src/common/commands.lua"] = "commands.lua",
      ["src/common/telemetry.lua"] = "telemetry.lua",

      ["src/onboard/main.lua"] = "onboard/init.lua",
      ["src/factory/main.lua"] = "factory/init.lua",
      ["src/factory/registry.lua"] = "factory/registry.lua",
      ["src/station/main.lua"] = "station/init.lua",
    },
  },
}
