package.path = "/usr/allay/lib/?.lua;/usr/allay/lib/?/init.lua;" .. package.path

local station = require("vypras1.station")
station.run()
