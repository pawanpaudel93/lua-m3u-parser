package.path = './src/m3u-parser/?.lua;' .. package.path

local http = require('http.request');
local lusc = require("lusc");
local uv = require("luv");
local json = require("cjson");
local utils = require("utils");

json.encode_escape_forward_slash(false)

function M3uParser(options)
    options = options or {}
    local useragent = options.useragent or
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36"
    local timeout = options.timeout or 5

    local regexes = {
        tvgName = 'tvg%-name="([^"]*)"',
        tvgId = 'tvg%-id="([^"]*)"',
        logo = 'tvg%-logo="([^"]*)"',
        tvgChno = 'tvg%-chno="([^"]*)"',
        category = 'group%-title="([^"]*)"',
        title = ',([^"]*)$',
        country = 'tvg%-country="([^"]*)"',
        language = 'tvg%-language="([^"]*)"',
        tvgUrl = 'tvg%-url="([^"]*)"'
    }

    local state = {
        streamsInfo = {},
        streamsInfoBackup = {},
        lines = {},
        statusChecker = {},
        schemes = { 'http', 'https' },
        timeout = timeout,
        enforceSchema = true,
        headers = { ["User-Agent"] = useragent },
        checkLive = false
    }

    local function isValidUrl(path, schemes)
        schemes = schemes or { "http", "https" }
        local scheme = path:match("^(.-)://")
        scheme = scheme ~= nil and scheme:lower() or nil
        return path:match("^[a-zA-Z]+://.+") ~= nil and utils.includes(schemes, scheme)
    end

    local function isValidPath(path)
        -- Normalize path by replacing backslashes with slashes
        local normalizedPath = path:gsub("\\", "/")

        -- Check if it looks like a URL
        if normalizedPath:match("^[a-zA-Z]+://") then
            return false
        end

        -- Check for invalid characters. This is a basic check, focusing on characters
        -- invalid in Windows and Unix-like paths. Adjust the pattern as needed.
        if normalizedPath:match("[%*%?\"<>|%c]+") then
            return false
        end

        return string.match(path, "^(.-)([/\\])(.-)[/\\](.-)$") ~= nil
    end

    local function readContent(path, type)
        type = type or "m3u"
        local content = ""
        if isValidUrl(path, state.schemes) then
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
    end

    local function getStatus(streamLink, timeout)
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
    end

    local function getByRegex(regex, content)
        return string.match(content, regex)
    end

    local function getM3uContent(streamsInfo)
        if #streamsInfo == 0 then
            return ""
        end
        local content = { "#EXTM3U" }
        for _, streamInfo in ipairs(streamsInfo) do
            local line = "#EXTINF:-1"
            if streamInfo.tvg ~= nil then
                for key, value in pairs(streamInfo.tvg) do
                    if value ~= nil then
                        line = line .. string.format(' tvg-%s="%s"', key, value)
                    end
                end
            end
            if streamInfo.logo ~= nil then
                line = line .. string.format(' tvg-logo="%s"', streamInfo.logo)
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
    end

    local function parseLine(lineNum)
        local lineInfo = state.lines[lineNum]
        local streamLink = nil
        local status = "BAD"

        for i, _ in ipairs({ 1, 2 }) do
            local line = state.lines[lineNum + i]
            if line and isValidUrl(line, state.schemes) then
                streamLink = line
                break
            elseif line and isValidPath(line) then
                status = "GOOD"
                streamLink = line
                break
            end
        end

        if lineInfo and streamLink then
            local info = { url = streamLink }

            local title = getByRegex(regexes.title, lineInfo)
            if title ~= nil or state.enforceSchema then
                info.name = title
            end

            local logo = getByRegex(regexes.logo, lineInfo)
            if title ~= nil or state.enforceSchema then
                info.logo = logo
            end

            local category = getByRegex(regexes.category, lineInfo)
            if category ~= nil or state.enforceSchema then
                info.category = category
            end

            local tvgId = getByRegex(regexes.tvgId, lineInfo)
            local tvgName = getByRegex(regexes.tvgName, lineInfo)
            local tvgUrl = getByRegex(regexes.tvgUrl, lineInfo)
            local tvgChno = getByRegex(regexes.tvgChno, lineInfo)

            if tvgId ~= nil or tvgName ~= nil or tvgUrl ~= nil or tvgChno ~= nil or state.enforceSchema then
                info.tvg = {}
                if tvgId ~= nil or state.enforceSchema then
                    info.tvg.id = tvgId
                end
                if tvgName ~= nil or state.enforceSchema then
                    info.tvg.name = tvgName
                end
                if tvgUrl ~= nil or state.enforceSchema then
                    info.tvg.url = tvgUrl
                end
                if tvgChno ~= nil or state.enforceSche then
                    info.tvg.chno = tvgChno
                end
            end

            local country = getByRegex(regexes.country, lineInfo)
            if country ~= nil or state.enforceSchema then
                info.country = {
                    code = country,
                    name = ""
                }
            end

            local language = getByRegex(regexes.language, lineInfo)
            if language ~= nil or state.enforceSchema then
                info.language = {
                    code = "",
                    name = language
                }
            end

            if state.checkLive and status == "BAD" then
                local scheme = string.match(streamLink, "^(.-)://")
                scheme = scheme ~= nil and scheme:lower() or nil
                local statusFn = state.statusChecker[scheme]
                if not statusFn then
                    statusFn = getStatus
                end
                if statusFn(streamLink, state.timeout) == true then
                    status = "GOOD"
                else
                    status = "BAD"
                end
            end

            if state.checkLive then
                info.status = status
                info.live = status == "GOOD"
            end
            table.insert(state.streamsInfo, info)
        end
    end

    local function parseLines()
        state.streamsInfo = {}
        local tasks = function()
            lusc.open_nursery(function(nursery)
                for index, line in ipairs(state.lines) do
                    if line:find("#EXTINF") then
                        nursery:start_soon(function() parseLine(index) end)
                    end
                end
            end)
        end

        lusc.start()
        lusc.schedule(tasks)
        lusc.stop()
        uv.run()

        state.streamsInfoBackup = state.streamsInfo
    end

    local function checkStatus(index)
        local streamInfo = state.streamsInfo[index]
        local streamUrl = streamInfo.url

        local scheme = string.match(streamUrl, "^(.-)://")
        scheme = scheme ~= nil and scheme:lower() or nil
        local statusFn = state.statusChecker[scheme]
        if not statusFn then
            statusFn = getStatus
        end
        if statusFn(streamUrl, state.timeout) == true then
            streamInfo.status = "GOOD"
        else
            streamInfo.status = "BAD"
        end
        streamInfo.live = streamInfo.status == "GOOD"
        state.streamsInfo[index] = streamInfo
    end

    local function checkStreamsStatus()
        if state.checkLive and #state.streamsInfo > 0 then
            local tasks = function()
                lusc.open_nursery(function(nursery)
                    for index, _ in ipairs(state.streamsInfo) do
                        nursery:start_soon(function() checkStatus(index) end)
                    end
                end)
            end

            lusc.start()
            lusc.schedule(tasks)
            lusc.stop()
            uv.run()

            state.streamsInfoBackup = state.streamsInfo
        end
    end

    return {
        parseM3u = function(self, dataSource, options)
            options = options or {}
            state.checkLive = options.checkLive == nil and true or options.checkLive
            state.enforceSchema = options.enforceSchema == nil and true or options.enforceSchema
            state.statusChecker = options.statusChecker or {}
            state.schemes = options.schemes or { "https", "http" }

            local content = readContent(dataSource, "m3u")

            state.lines = {}
            for line in content:gmatch("[^\r\n]+") do
                if line:match("%S") then
                    table.insert(state.lines, line)
                end
            end

            if #state.lines == 0 then
                error("No content to parse.")
            else
                parseLines()
            end

            return self
        end,
        parseJson = function(self, dataSource, options)
            options = options or {}
            state.checkLive = options.checkLive == nil and true or options.checkLive
            state.enforceSchema = options.enforceSchema == nil and true or options.enforceSchema
            state.statusChecker = options.statusChecker or {}
            state.schemes = options.schemes or { "https", "http" }

            local content = readContent(dataSource, "json")

            local streamsInfo = json.decode(content)

            state.streamsInfo = {}

            if streamsInfo and type(streamsInfo) == "table" and #streamsInfo > 0 then
                for _, streamInfo in ipairs(streamsInfo) do
                    if type(streamInfo) == "table" and streamInfo.url then
                        table.insert(state.streamsInfo, {
                            name = streamInfo.name,
                            logo = streamInfo.logo,
                            url = streamInfo.url,
                            category = streamInfo.category,
                            tvg = {
                                id = streamInfo.tvg and streamInfo.tvg.id or nil,
                                name = streamInfo.tvg and streamInfo.tvg.name or nil,
                                url = streamInfo.tvg and streamInfo.tvg.url or nil,
                                chno = streamInfo.tvg and streamInfo.tvg.chno or nil
                            },
                            country = {
                                code = streamInfo.country and streamInfo.country.code or nil,
                                name = streamInfo.country and streamInfo.country.name or nil,
                            },
                            language = {
                                code = streamInfo.language and streamInfo.language.code or nil,
                                name = streamInfo.language and streamInfo.language.name or nil,
                            },
                            status = streamInfo.status or "BAD",
                            live = streamInfo.status == "GOOD"
                        })
                    end
                end
            end
            checkStreamsStatus()
            return self
        end,
        filterBy = function(self, key, filters, options)
            options = options or {}
            local keySplitter = options.keySplitter or "-"
            local retrieve = options.retrieve == nil and true or options.retrieve
            local nestedKey = options.nestedKey ~= nil and options.nestedKey or false

            local key0, key1 = key, ""
            if nestedKey then
                local splits = utils.split(key, keySplitter)
                key0, key1 = splits[1], splits[2]
                if #state.streamsInfo >= 1 and (state.streamsInfo[1][key0] == nil or state.streamsInfo[1][key0][key1] == nil) then
                    error(string.format("Nested key '%s' is not present in the streams.", key))
                end
            elseif #state.streamsInfo >= 1 and state.streamsInfo[1][key] == nil then
                error(string.format("Key '%s' is not present in the streams.", key))
            end

            if type(filters) ~= "table" then
                filters = { filters }
            end

            local anyOrAll

            if retrieve then
                anyOrAll = utils.any
            else
                anyOrAll = utils.all
            end

            local notOperator = function(x)
                if retrieve then
                    return x
                else
                    return not x
                end
            end

            local function checkFilter(streamInfo, fltr)
                local value

                if nestedKey then
                    value = streamInfo[key0] and streamInfo[key0][key1] or nil
                else
                    value = streamInfo[key]
                end

                -- Case 1: Both filter and value are None, return True
                if fltr == nil and value == nil then
                    return true
                end

                --  Case 2: Filter is None, but value is not None, return False
                if fltr == nil and value ~= nil then
                    return false
                end

                -- Case 3: Filter is not None, but value is None, return False
                if fltr ~= nil and value == nil then
                    return false
                end

                -- Case 4: Both filter and value are not None, apply the filter condition
                if type(fltr) == "boolean" then
                    return value == fltr
                end

                if type(fltr) == "string" and type(value) == "string" then
                    return string.find(string.lower(value), string.lower(fltr)) ~= nil
                end

                -- Case 5: Invalid filter type, return False
                return false
            end

            local function filterStreams()
                local filteredStreams = {}

                for _, streamInfo in ipairs(state.streamsInfo) do
                    local passesFilter = anyOrAll(filters, function(fltr)
                        return notOperator(checkFilter(streamInfo, fltr))
                    end)

                    if passesFilter then
                        table.insert(filteredStreams, streamInfo)
                    end
                end

                return filteredStreams
            end

            state.streamsInfo = filterStreams()
            return self
        end,
        resetOperations = function(self)
            state.streamsInfo = state.streamsInfoBackup
            return self
        end,
        removeByextension = function(self, extensions)
            return self:filterBy("url", extensions, { retrieve = false })
        end,
        retrieveByExtension = function(self, extensions)
            return self:filterBy("url", extensions)
        end,
        removeByCategory = function(self, categories)
            return self:filterBy("category", categories, { retrieve = false })
        end,
        retrieveByCategory = function(self, categories)
            return self:filterBy("category", categories)
        end,
        sortBy = function(self, key, options)
            options = options or {}
            local keySplitter = options.keySplitter or "-"
            local asc = options.asc == nil and true or options.asc
            local nestedKey = options.nestedKey ~= nil and options.nestedKey or false

            local key0, key1 = key, ""
            if nestedKey then
                local splits = utils.split(key, keySplitter)
                key0, key1 = splits[1], splits[2]
                if #state.streamsInfo >= 1 and (state.streamsInfo[1][key0] == nil or state.streamsInfo[1][key0][key1] == nil) then
                    error(string.format("Nested key '%s' is not present in the streams.", key))
                end
            elseif #state.streamsInfo >= 1 and state.streamsInfo[1][key] == nil then
                error(string.format("Key '%s' is not present in the streams.", key))
            end

            local function compare(streamInfoA, streamInfoB)
                local function getValue(streamInfo)
                    if nestedKey then
                        if streamInfo[key0] and streamInfo[key0][key1] ~= nil then
                            return streamInfo[key0][key1], true
                        end
                    else
                        if streamInfo[key] ~= nil then
                            return streamInfo[key], true
                        end
                    end
                    return nil, false -- Return nil and false if value doesn't exist
                end

                local aVal, aExists = getValue(streamInfoA)
                local bVal, bExists = getValue(streamInfoB)

                if not aExists and not bExists then
                    return false -- Keep original order if both values don't exist
                elseif not aExists then
                    return false -- Treat non-existent a as less
                elseif not bExists then
                    return true  -- Treat non-existent b as less
                else
                    if asc then
                        return aVal < bVal
                    else
                        return aVal > bVal
                    end
                end
            end

            table.sort(state.streamsInfo, compare)

            return self
        end,
        removeDuplicates = function(self, name, url)
            if name == nil and url ~= nil then
                error("Param name is not passed.")
            end

            if name ~= nil and url == nil then
                error("Param url is not passed.")
            end

            local filteredStreams = {}
            local seenEntries = {}

            local namePattern = name and name:lower() or nil

            for _, streamInfo in ipairs(state.streamsInfo) do
                local streamName = streamInfo.name and streamInfo.name:lower() or nil
                local streamUrl = streamInfo.url and streamInfo.url:lower() or nil

                local bothNone = name == nil and url == nil
                local matchName = streamName and namePattern and string.find(streamName, namePattern)
                local matchUrl = url and streamUrl and streamUrl == url:lower()

                if ((matchName or matchUrl) or bothNone) then
                    local isFound = false
                    local uniqueKey = streamName .. streamUrl

                    if bothNone then
                        isFound = seenEntries[uniqueKey] ~= nil
                    else
                        if seenEntries[uniqueKey] then
                            isFound = true
                        end
                    end

                    if not isFound then
                        seenEntries[uniqueKey] = true
                        table.insert(filteredStreams, streamInfo)
                    end
                else
                    table.insert(filteredStreams, streamInfo)
                end
            end

            state.streamsInfo = filteredStreams

            return self
        end,
        getJson = function(self)
            return json.encode(state.streamsInfo)
        end,
        getList = function(self)
            return state.streamsInfo
        end,
        getRandomStream = function(self, randomShuffle)
            if randomShuffle == nil then randomShuffle = true end
            if #state.streamsInfo == 0 then
                error("No streams information so could not get any random stream.")
            end
            if randomShuffle then
                utils.shuffle(state.streamsInfo)
            end
            local randomIndex = math.random(#state.streamsInfo)
            return state.streamsInfo[randomIndex]
        end,
        toFile = function(self, filename, format)
            local getFormat = function(path, defaultFormat)
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

            if #state.streamsInfo == 0 then
                error("Either parsing is not done or no stream info was found after parsing.")
            end

            if format == "json" then
                local content = json.encode(state.streamsInfo)
                local file = io.open(filename, "w")
                file:write(content)
                file:close()
            elseif format == "m3u" then
                local content = getM3uContent(state.streamsInfo)
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
