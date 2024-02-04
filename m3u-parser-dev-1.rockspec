package = "m3u-parser"
version = "dev-1"
source = {
   url = "https://github.com/pawanpaudel93/lua-m3u-parser"
}
description = {
   summary = "A parser for m3u files.",
   detailed = [[
      A parser for m3u files.
      It parses the contents of the m3u file to a list of streams information which can be saved as a JSON/M3U file.
   ]],
   homepage = "https://github.com/pawanpaudel93/lua-m3u-parser",
   license = "MIT"
}
dependencies = {
   "lua >= 5.1",
   "lua-cjson >= 2.1",
   "http >= 0.4",
   "lusc_luv >= 3.1"
}
build = {
   type = "builtin",
   modules = {
      ["m3u-parser"] = "src/m3u-parser/M3uParser.lua"
   }
}
