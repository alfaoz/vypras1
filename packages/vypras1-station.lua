return {
  name = "vypras1-station",
  version = "0.1.0-dev",
  description = "Remote station software for Vypra S1.",
  author = "alfa",
  license = "MIT",

  base_url = "https://raw.githubusercontent.com/alfaoz/vypras1/main",

  dependencies = { "vypras1" },

  files = {
    bin = {
      ["src/station/vypras1_station.lua"] = "vypras1-station",
    },
  },
}
