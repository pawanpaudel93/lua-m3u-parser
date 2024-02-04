local http = require('http.request');
local lusc = require("lusc");
local uv = require("luv");
local json = require("cjson");

json.encode_escape_forward_slash(false)


function M3uParser(useragent, timeout)
    useragent = useragent or "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36"
    timeout = timeout or 5

    return {
        streamsInfo = {},
        streamsInfoBackup = {},
        lines = {},
        statusChecker = {},
        schemes = {'http', 'https'},
        timeout = timeout,
        enforceSchema = true,
        headers = {["User-Agent"] = useragent},
        checkLive = false,
        regexes = {
            tvgName = 'tvg%-name="([^"]*)"',
            tvgId = 'tvg%-id="([^"]*)"',
            logo = 'tvg%-logo="([^"]*)"',
            tvgChno = 'tvg%-chno="([^"]*)"',
            category = 'group%-title="([^"]*)"',
            title = ',([^"]*)$',
            country = 'tvg%-country="([^"]*)"',
            language = 'tvg%-language="([^"]*)"',
            tvgUrl = 'tvg%-url="([^"]*)"'
        },
        isValidUrl =  function (path)
            return string.match(path, '^[a-z]*://[^ >,;]*$') ~= nil
        end,
        isValidPath = function (path)
            return string.match(path, "^(.-)([/\\])(.-)[/\\](.-)$") ~= nil
        end,
        readContent = function (self, path, type)
            type = type or "m3u"
            local content = ""
            if self.isValidUrl(path) then
                local response = http.new_from_uri(path)
                local _, stream = response:go()
                content = stream:get_body_as_string()
            else
                local file = io.open(path, "r")
                if not file then
                    error("File not found or not accessible.")
                end
                content = file:read("a")
                file:close()
            end
            return content
        end,
        parseLines = function (self)
            self.streamsInfo = {}
            local tasks = function ()
                lusc.open_nursery(function(nursery)
                    for index, line in ipairs(self.lines) do
                        if line:find("#EXTINF") then
                            nursery:start_soon(function()
                                self:parseLine(index)
                            end)
                        end
                    end
                end)
            end
            
            lusc.start()
            lusc.schedule(tasks)
            lusc.stop()
            uv.run()
            
            self.streamsInfoBackup = self.streamsInfo
        end,
        getStatus = function (streamLink, timeout)
            local status, request = pcall(http.new_from_uri, streamLink)
            if not status then
                return false
            end
            local headers, _ = request:go(timeout)
            if headers ~= nil and headers:get(":status") == "200" then
                return true
            else
                return false
            end
        end,
        parseLine = function (self, lineNum)
            local lineInfo = self.lines[lineNum]
            local streamLink = ""
            local streamsLink = {}
            local status = "BAD"

            for i, _ in ipairs({1,2}) do
                local line = self.lines[lineNum + i]
                if line and self.isValidUrl(line) then
                    table.insert(streamsLink, line)
                    break
                elseif line and self.isValidPath(line) then
                    status = "GOOD"
                    table.insert(streamsLink, line)
                    break
                end
            end
            streamLink = streamsLink[1]

            if lineInfo and streamLink then
                local info = { url = streamLink }
                
                local title = self.getByRegex(self.regexes.title, lineInfo)
                if title ~= nil or self.enforceSchema then
                    info.name = title
                end

                local logo = self.getByRegex(self.regexes.logo, lineInfo)
                if title ~= nil or self.enforceSchema then
                    info.logo = logo
                end

                local category = self.getByRegex(self.regexes.category, lineInfo)
                if category ~= nil or self.enforceSchema then
                    info.category = category
                end

                local tvgId = self.getByRegex(self.regexes.tvgId, lineInfo)
                local tvgName = self.getByRegex(self.regexes.tvgName, lineInfo)
                local tvgUrl = self.getByRegex(self.regexes.tvgUrl, lineInfo)
                local tvgChno = self.getByRegex(self.regexes.tvgChno, lineInfo)

                if tvgId ~= nil or tvgName ~= nil or tvgUrl ~= nil or tvgChno ~= nil or self.enforceSchema then
                    info.tvg = {}
                    if tvgId ~= nil or self.enforceSchema then
                        info.tvg.id = tvgId
                    end
                    if tvgName ~= nil or self.enforceSchema then
                        info.tvg.name = tvgName
                    end
                    if tvgUrl ~= nil or self.enforceSchema then
                        info.tvg.url = tvgUrl
                    end
                    if tvgChno ~= nil or self.enforceSche then
                        info.tvg.chno = tvgChno
                    end
                end

                local country = self.getByRegex(self.regexes.country, lineInfo)
                if country ~= nil or self.enforceSchema then
                    info.country = {
                        code = country,
                        name = ""
                    }
                end

                local language = self.getByRegex(self.regexes.language, lineInfo)
                if language ~= nil or self.enforceSchema then
                    info.language = {
                        code = "",
                        name = language
                    }
                end

                if self.checkLive and status == "BAD" then
                    local scheme = string.match(streamLink, "^(.-)://")
                    scheme = scheme ~= nil and scheme:lower() or nil
                    local statusFn = self.statusChecker[scheme]
                    if not statusFn then
                        statusFn = self.getStatus
                    end
                    if statusFn(streamLink, self.timeout) == true then
                        status = "GOOD"
                    else
                        status = "BAD"
                    end
                end

                if self.checkLive then
                    info.status = status
                    info.live = status == "GOOD"
                end
                table.insert(self.streamsInfo, info)
            end
        end,
        getByRegex = function (regex, content)
            return string.match(content, regex)
        end,
        parseM3u = function (self, dataSource, schemes, statusChecker, checkLive, enforceSchema)
            if checkLive ~= nil then self.checkLive = checkLive end
            if enforceSchema ~= nil then self.enforceSchema = enforceSchema end
            if statusChecker ~= nil then self.statusChecker = statusChecker end
            if schemes ~= nil then self.schemes = schemes end

            local content = self:readContent(dataSource, "m3u")
            
            self.lines = {}
            for line in content:gmatch("[^\r\n]+") do
                if line:match("%S") then
                    table.insert(self.lines, line)
                end
            end

            if #self.lines == 0 then
                error("No content to parse.")
            else
                self:parseLines()
            end
        end,
        getM3uContent = function(streamsInfo)
            if #streamsInfo == 0 then
                return ""
            end
            local content = { "#EXTM3U" }
            for index, streamInfo in ipairs(streamsInfo) do
                local line = "#EXTINF:-1"
                if streamInfo.tvg ~= nil then
                    for key, value in pairs(streamInfo.tvg) do
                        if value ~= nil then
                            line = line .. string.format(' tvg-%s="%s"', key, value)
                        end
                    end
                end
                if streamInfo.logo ~= nil then
                    line =  line .. string.format(' tvg-logo="%s"', streamInfo.logo)
                end
                if streamInfo.country ~= nil and streamInfo.country.code ~= nil then
                    line = line .. string.format(' tvg-country="%s"', streamInfo.country.code)
                end
                if streamInfo.language ~= nil and streamInfo.language.name ~= nil then
                    line = line .. string.format(' tvg-language="%s"', streamInfo.language.name)
                end
                if streamInfo.category ~= nil then
                    line = line .. string.format(' group-title="%s"', streamInfo.category)
                end
                if streamInfo.name ~= nil then
                    line = line .. ',' .. streamInfo.name
                end
                table.insert(content, line)
                table.insert(content, streamInfo.url)
            end
            return table.concat(content, "\n")
        end,
        toFile = function (self, filename, format)
            local getFormat = function (path, defaultFormat)
                local fmt = path:match(".+%.(.*)")
                if fmt then
                    return fmt
                else
                    return defaultFormat
                end
            end

            format = format or getFormat(filename, "json")

            local withExtension = function(path, defaultFormat)
                local fmt = getFormat(path, defaultFormat)
                if fmt == defaultFormat then
                    return path
                else
                    return path .. "." .. fmt
                end
            end

            filename = withExtension(filename, format)

            if #self.streamsInfo == 0 then
                error("Either parsing is not done or no stream info was found after parsing.")
            end

            if format == "json" then
                local content = json.encode(self.streamsInfo)
                local file = io.open(filename, "w")
                file:write(content)
                file:close()
            elseif format == "m3u" then
                local content = self.getM3uContent(self.streamsInfo)
                local file = io.open(filename, "w")
                file:write(content)
                file:close()
            else
                error("Unrecognised format.")
            end

            return filename
        end
    }
end

return M3uParser
