local HTTP = include("http.lua")

local IMAGE = {}

IMAGE.STATUS_LOADING = 0
IMAGE.STATUS_LOADED = 1
IMAGE.STATUS_ERROR = 2

IMAGE.Images = {}

local path = "arcade/cache/images"
file.CreateDir(path)

function IMAGE:ClearImages()
    self.Images = {}
end

function IMAGE:LoadFromURL(url, key, callback, noCache, materialParams)
    if self.Images[key] and not noCache then
        if self.Images[key].status == self.STATUS_LOADED and callback then
            callback(self.Images[key])
        end
        return
    end

    local filename = path .. "/" .. HTTP:urlhash(url) .. "." .. HTTP:GetExtension(url)

    if not noCache and file.Exists(filename, "DATA") then
        self.Images[key] = {
            status = self.STATUS_LOADED,
            mat = Material("../data/" .. filename, materialParams)
        }
        if callback then
            callback(self.Images[key])
        end
        return
    end

    self.Images[key] = {
        status = self.STATUS_LOADING,
        mat = Material("error")
    }

    HTTP:Fetch(
        url,
        function(body, size, headers, code)
            file.Write(filename, body)
            self.Images[key].status = self.STATUS_LOADED
            self.Images[key].mat = Material("../data/" .. filename, materialParams)

            if callback then
                callback(self.Images[key])
            end
        end,
        function(err, body)
            self.Images[key].status = self.STATUS_ERROR
            self.Images[key].err = body and err .. ":" .. body or err
        end
    )
end

function IMAGE:LoadFromMaterial(name, key)
    if self.Images[key] then return end

    self.Images[key] = {
        status = self.STATUS_LOADED,
        mat = CreateMaterial(
            "arcadecabinets_" .. key .. "_" .. math.random(9999),
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