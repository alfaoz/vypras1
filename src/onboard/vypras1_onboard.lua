package.path = "/usr/allay/lib/?.lua;/usr/allay/lib/?/init.lua;" .. package.path

local onboard = require("vypras1.onboard")
onboard.run()
