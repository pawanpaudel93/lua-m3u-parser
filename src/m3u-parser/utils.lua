local utils = {}

function utils.split(inputstr, delimiter)
    -- Escape all magic characters in delimiter
    delimiter = delimiter:gsub("([%W])", "%%%1")
    local result = {}
    local pattern = "(.-)" .. delimiter .. "()"
    local lastPos
    for part, pos in inputstr:gmatch(pattern) do
        table.insert(result, part)
        lastPos = pos
    end
    -- Add the last part
    if lastPos then
        table.insert(result, inputstr:sub(lastPos))
    else
        -- In case no delimiter is found, return the whole string
        table.insert(result, inputstr)
    end
    return result
end

function utils.includes(tbl, element)
    for _, elem in ipairs(tbl) do
        if elem == element then return true end
    end
    return false
end

function utils.any(tbl, condition)
    for _, value in ipairs(tbl) do
        if condition(value) then
            return true
        end
    end
    return false
end

function utils.all(tbl, condition)
    for _, value in ipairs(tbl) do
        if not condition(value) then
            return false
        end
    end
    return true
end

function utils.shuffle(tbl)
    for i = #tbl, 2, -1 do
        local j = math.random(i)
        tbl[i], tbl[j] = tbl[j], tbl[i]
    end
end

return utils
