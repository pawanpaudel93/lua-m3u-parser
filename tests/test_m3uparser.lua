local lu = require("luaunit")
local M3uParser = require("src.m3u-parser.M3uParser")

-- Sample M3U content for testing
local SAMPLE_M3U_CONTENT = [[
#EXTM3U
#EXTINF:-1 tvg-id="Channel 1" tvg-chno="1" tvg-logo="https://i.imgur.com/AvCQYgu.png" tvg-country="NP" tvg-language="Newari" group-title="News",Channel 1
http://example.com/stream1
#EXTINF:-1 tvg-id="Channel 2" tvg-chno="2" tvg-logo="https://i.imgur.com/AvCQYgu.png" tvg-country="IN" tvg-language="Hindi" group-title="News",Channel 2
http://example.com/stream2
#EXTINF:-1 tvg-id="Channel 3" tvg-logo="https://i.imgur.com/AvCQYgu.png" tvg-country="CN" tvg-language="Chinesee" group-title="News",Channel 3
http://example.com/stream3
#EXTINF:0,Dlf
#EXTVLCOPT:network-caching=1000
rtsp://10.0.0.1:554/?avm=1&freq=514&bw=8&msys=dvbc&mtype=256qam&sr=6900&specinv=0&pids=0,16,17,18,20,800,810,850
]]

local DUPLICATE_M3U_CONTENT = [[
#EXTM3U
#EXTINF:-1 tvg-id="Channel 1" tvg-logo="https://i.imgur.com/AvCQYgu.png" tvg-country="NP" tvg-language="Newari" group-title="News",Channel 1
http://example.com/stream1
#EXTINF:-1 tvg-id="Channel 1" tvg-logo="https://i.imgur.com/AvCQYgu.png" tvg-country="NP" tvg-language="Newari" group-title="News",Channel 1
http://example.com/stream1
#EXTINF:-1 tvg-id="Channel 2" tvg-logo="https://i.imgur.com/AvCQYgu.png" tvg-country="CN" tvg-language="Chinesee" group-title="News",Channel 2
http://example.com/stream2
]]

local SAMPLE_JSON_CONTENT = [[
[
    {
        "name": "Channel 1",
        "logo": "https://i.imgur.com/AvCQYgu.png",
        "url": "http://example.com/stream1",
        "category": "News",
        "tvg": {"id": "Channel 1", "name": null, "url": null, "chno": "1"},
        "country": {"code": "NP", "name": "Nepal"},
        "language": {"code": "new", "name": "Newari"}
    },
    {
        "name": "Channel 2",
        "logo": "https://i.imgur.com/AvCQYgu.png",
        "url": "http://example.com/stream2",
        "category": "News",
        "tvg": {"id": "Channel 2", "name": null, "url": null},
        "country": {"code": "IN", "name": "India"},
        "language": {"code": "hin", "name": "Hindi"}
    },
    {
        "name": "Channel 3",
        "logo": "https://i.imgur.com/AvCQYgu.png",
        "url": "http://example.com/stream3",
        "category": "News",
        "tvg": {"id": "Channel 3", "name": null, "url": null},
        "country": {"code": "CN", "name": "China"},
        "language": {"code": null, "name": "Chinesee"}
    }
]
]]

function rtspChecker(url)
    return true
end

function fileExists(name)
    local f = io.open(name, "r")
    return f ~= nil and io.close(f)
end

function tempM3uFile(options)
    options = options or {}
    options.filename = options.filename or "test.m3u"
    local file = io.open(options.filename, "w")
    file:write(options.content or SAMPLE_M3U_CONTENT)
    file:close()
    return options.filename
end

function tempDuplicateM3uFile()
    local file = io.open("duplicate.m3u", "w")
    file:write(DUPLICATE_M3U_CONTENT)
    file:close()
    return "duplicate.m3u"
end

function tempJsonFile()
    local file = io.open("test.json", "w")
    file:write(SAMPLE_JSON_CONTENT)
    file:close()
    return "test.json"
end

function testParseM3u()
    local m3uPath = tempM3uFile()
    local parser = M3uParser()
    parser:parseM3u(m3uPath, { checkLive = false })
    local streams = parser:getList()
    lu.assertEquals(#streams, 3)
end

function testParseM3uWithSchemes()
    local m3uPath = tempM3uFile()
    local parser = M3uParser()
    parser:parseM3u(
        m3uPath,
        { checkLive = true, schemes = { "http", "https", "rtsp" }, statusChecker = { rtsp = rtspChecker } }
    )
    local streams = parser:getList()
    lu.assertEquals(#streams, 4)
end

function testParseJson()
    local jsonPath = tempJsonFile()
    local parser = M3uParser()
    parser:parseJson(jsonPath, { check_live = false })
    local streams = parser:getList()
    lu.assertEquals(#streams, 3)
end

-- Test filtering by extension
function testFilterByExtension()
    local m3uPath = tempM3uFile()
    local parser = M3uParser()
    parser:parseM3u(m3uPath, { checkLive = false })
    parser:retrieveByExtension('mp4')
    local streams = parser.getList()
    lu.assertEquals(#streams, 0)
end

-- Test filtering by nested key
function testFilterByNestedKey()
    local m3uPath = tempM3uFile()
    local parser = M3uParser()
    parser:parseM3u(m3uPath)
    parser:filterBy('language.name', nil, { keySplitter = ".", retrieve = false, nestedKey = true })
    local streams = parser:getList()
    lu.assertEquals(#streams, 3)
end

-- Test filtering by invalid category
function testFilterByInvalidCategory()
    local m3uPath = tempM3uFile()
    local parser = M3uParser()
    parser:parseM3u(m3uPath, { check_live = false })
    parser:filterBy('category', 'Invalid')
    local streams = parser:getList()
    lu.assertEquals(#streams, 0)
end

-- Test filtering by invalid category
function testFilterByInvalidKey()
    local m3uPath = tempM3uFile()
    local parser = M3uParser()
    parser:parseM3u(m3uPath, { check_live = false })
    local success, _ = pcall(function() parser:filterBy('invalid', 'Invalid') end)
    lu.assertEquals(success, false)
end

-- Test filtering by live
function testFilterByLive()
    local m3uPath = tempM3uFile()
    local parser = M3uParser()
    parser:parseM3u(m3uPath, { checkLive = true, schemes = { "http", "https", "rtsp" } })
    parser:filterBy("live", false)
    local streams = parser:getList()
    lu.assertEquals(#streams, 4)
end

-- Test filtering by live when check_live is False
function testFilterByLiveWhenCheckLiveFalse()
    local m3uPath = tempM3uFile()
    local parser = M3uParser()
    parser:parseM3u(m3uPath, { checkLive = false, schemes = { "http", "https", "rtsp" } })
    local success, _ = pcall(function() parser:filterBy("live", false) end)
    lu.assertEquals(success, false)
end

-- Test sorting by stream name in ascending order
function testSortByNameAsc()
    local m3uPath = tempM3uFile()
    local parser = M3uParser()
    parser:parseM3u(m3uPath, { checkLive = false })
    parser:sortBy('name')
    local streams = parser:getList()
    lu.assertEquals(streams[1]['name'], 'Channel 1')
    lu.assertEquals(streams[2]['name'], 'Channel 2')
    lu.assertEquals(streams[3]['name'], 'Channel 3')
end

-- Test sorting by stream name in descending order
function testSortByNameDesc()
    local m3uPath = tempM3uFile()
    local parser = M3uParser()
    parser:parseM3u(m3uPath, { checkLive = false })
    parser:sortBy('name', { asc = false })
    local streams = parser:getList()
    lu.assertEquals(streams[1]['name'], 'Channel 3')
    lu.assertEquals(streams[2]['name'], 'Channel 2')
    lu.assertEquals(streams[3]['name'], 'Channel 1')
end

-- Test resetting operations
function testResetOperations()
    local m3uPath = tempM3uFile()
    local parser = M3uParser()
    parser:parseM3u(m3uPath, { checkLive = false })
    parser:retrieveByExtension('mp4')
    parser:resetOperations()
    local streams = parser:getList()
    lu.assertEquals(#streams, 3)
end

-- Test saving to JSON file
function testSaveToJson()
    local m3uPath = tempM3uFile()
    local parser = M3uParser()
    local outputPath = "output.json"
    parser:parseM3u(m3uPath, { checkLive = false })
    parser:toFile(outputPath, "json")
    lu.assertEquals(fileExists(outputPath), true)
    os.remove(outputPath)
end

-- Test filtering by category
function testFilterByCategory()
    local m3uPath = tempM3uFile()
    local parser = M3uParser()
    parser:parseM3u(m3uPath, { checkLive = false })
    parser:removeByCategory('News')
    local streams = parser.getList()
    lu.assertEquals(#streams, 0)
end

-- Test retrieving by category
function testRetrieveByCategory()
    local m3uPath = tempM3uFile()
    local parser = M3uParser()
    parser:parseM3u(m3uPath, { checkLive = false })
    parser:retrieveByCategory('News')
    local streams = parser:getList()
    lu.assertEquals(#streams, 3)
end

-- Test parsing invalid M3U content
function testInvalidM3uContent()
    local m3uPath = tempM3uFile({ filename = "invalid.m3u", content = "Invalid M3U Content" })
    local parser = M3uParser()
    local success, _ = pcall(function()
        parser:parseM3u(m3uPath)
        parser:getRandomStream()
    end)
    lu.assertEquals(success, false)
end

function testRemoveSpecificDuplicates()
    local m3uPath = tempDuplicateM3uFile()
    local parser = M3uParser()
    parser:parseM3u(m3uPath, { checkLive = false })
    parser:removeDuplicates("Channel 1", "http://example.com/stream1")
    local streams = parser:getList()
    lu.assertEquals(#streams, 2)
end

function testRemoveAllDuplicates()
    local m3uPath = tempDuplicateM3uFile()
    local parser = M3uParser()
    parser:parseM3u(m3uPath, { checkLive = false })
    parser:removeDuplicates()
    local streams = parser:getList()
    lu.assertEquals(#streams, 2)
end

function testRemoveDuplicatesNameParamOnly()
    local m3uPath = tempDuplicateM3uFile()
    local parser = M3uParser()
    parser:parseM3u(m3uPath, { checkLive = false })
    local success, _ = pcall(function() parser:removeDuplicates("Channel 1") end)
    lu.assertEquals(success, false)
end

function testRemoveDuplicatesUrlParamOnly()
    local m3uPath = tempDuplicateM3uFile()
    local parser = M3uParser()
    parser:parseM3u(m3uPath, { checkLive = false })
    local success, _ = pcall(function() parser:removeDuplicates(nil, "http://example.com/stream1") end)
    lu.assertEquals(success, false)
end

os.exit(lu.LuaUnit.run())
