return {
  name = "vypras1-onboard",
  version = "0.1.5-dev",
  description = "Onboard firmware for Vypra S1 vehicles.",
  author = "alfa",
  license = "MIT",

  base_url = "https://raw.githubusercontent.com/alfaoz/vypras1/main",

  dependencies = { "vypras1" },

  files = {
    bin = {
      ["src/onboard/vypras1_onboard.lua"] = "vypras1-onboard",
    },
    startup = {
      ["src/onboard/vypras1_onboard.lua"] = "onboard",
    },
  },

  post_install_message = "Run vypras1-onboard or reboot. Config lives at /etc/vypras1/onboard.lua.",
}
