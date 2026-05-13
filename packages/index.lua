return {
  spec = "allay/v1.0.0",
  format = "allay",
  name = "alfaoz/vypras1",
  description = "Vypra S1 vehicle control system packages.",
  homepage = "https://github.com/alfaoz/vypras1",
  packages = {
    vypras1 = { version = "0.1.1-dev", description = "Shared Vypra S1 libraries" },
    ["vypras1-onboard"] = { version = "0.1.1-dev", description = "Vypra S1 onboard firmware" },
    ["vypras1-factory"] = { version = "0.1.1-dev", description = "Vypra S1 factory registry" },
    ["vypras1-station"] = { version = "0.1.1-dev", description = "Vypra S1 station software" },
  },
}
