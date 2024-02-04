local M3uParser = require("../src/m3u-parser/M3uParser")


local parser = M3uParser()
parser:parseM3u("https://iptv-org.github.io/iptv/countries/np.m3u", { "http", "https" }, {}, false, true)
parser:toFile("nepal.json")
parser:toFile("nepal.m3u")
