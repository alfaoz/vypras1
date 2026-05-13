return {
  name = "vypras1-factory",
  version = "0.1.5-dev",
  description = "Factory registry and configurator for Vypra S1.",
  author = "alfa",
  license = "MIT",

  base_url = "https://raw.githubusercontent.com/alfaoz/vypras1/main",

  dependencies = { "vypras1" },

  files = {
    bin = {
      ["src/factory/vypras1_factory.lua"] = "vypras1-factory",
    },
  },
}
