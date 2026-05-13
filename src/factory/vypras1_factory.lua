package.path = "/usr/allay/lib/?.lua;/usr/allay/lib/?/init.lua;" .. package.path

local factory = require("vypras1.factory")
factory.run()
