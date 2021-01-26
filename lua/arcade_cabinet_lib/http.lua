local HTTP = {}

function HTTP:urlhash(str)
    local strlen = #str
    local blocks = 4
    local hash = ""
    local memblock = {}

    if strlen < blocks then
        blocks = 1
    end

    local lastInc = 0

    for i = 1, blocks do
        local pos = math.floor((i / blocks) * strlen)
        memblock[i] = util.CRC(string.sub(str, lastInc + 1, pos))
        lastInc = pos
    end

    for _, v in ipairs(memblock) do
        hash = hash .. string.format("%x", v)
    end

    hash = string.upper(hash)
    return hash
end

function HTTP:GetExtension(path)
    return string.GetExtensionFromFilename(path:gsub("?(.*)", ""))
end

function HTTP:Fetch(url, success, fail)
    http.Fetch(
        url,
        function(body, size, headers, code)
            if code >= 400 then
                if fail then
                    fail(code, body)
                end
                return
            end

            success(body, size, headers, code)
        end,
        fail
    )
end

return HTTP