local IMAGE = {}

IMAGE.STATUS_LOADING = 0
IMAGE.STATUS_LOADED = 1
IMAGE.STATUS_ERROR = 2

IMAGE.Images = {}

local path = "arcademachines/cache/images"
file.CreateDir(path)

local function urlhash(str)
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

function IMAGE:LoadFromURL(url, key, noCache)
    if self.Images[key] and not noCache then return end
    
    local filename = path .. "/" .. urlhash(url) .. "." .. string.GetExtensionFromFilename(url)
    
    if not noCache then
        if file.Exists(filename, "DATA") then
            self.Images[key] = {
                status = self.STATUS_LOADED,
                mat = Material("../data/" .. filename)
            }
            return
        end
    end
    
    self.Images[key] = {
        status = self.STATUS_LOADING,
        mat = Material("error")
    }

    local function err(err, body)
        self.Images[key].status = self.STATUS_ERROR
        self.Images[key].err = body and err .. ":" .. body or err
    end
    
    http.Fetch(
        url,
        function(body, size, headers, code)
            if code >= 400 then
                err(code, body)
                return
            end

            file.Write(filename, body)
            self.Images[key].status = self.STATUS_LOADED
            self.Images[key].mat = Material("../data/" .. filename)
        end,
        err
    )
end

function IMAGE:LoadFromMaterial(name, key)
    if self.Images[key] then return end

    self.Images[key] = {
        status = self.STATUS_LOADED,
        mat = CreateMaterial(
            "arcademachines_" .. key .. "_" .. math.random(9999),
            "UnlitGeneric",
            {
                ["$basetexture"] = name,
                ["$vertexcolor"] = 1,
                ["$vertexalpha"] = 1,
                ["$additive"] = 1,
                ["$ignorez"] = 1,
                ["$nolod"] = 1
            }
        )
    }
end

return IMAGE