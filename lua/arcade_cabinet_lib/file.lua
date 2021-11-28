local HTTP = include("http.lua")

local FILE = {}

FILE.STATUS_LOADING = 0
FILE.STATUS_LOADED = 1
FILE.STATUS_ERROR = 2

FILE.Files = {}

local path = "arcade/cache/files"
file.CreateDir(path)

function FILE:LoadFromURL(url, key, callback, noCache)
    if self.Files[key] and not noCache then
        if self.Files[key].status == self.STATUS_LOADED and callback then
            callback(self.Files[key])
        end
        return
    end

    local filename = path .. "/" .. HTTP:urlhash(url) .. "." .. HTTP:GetExtension(url) .. ".dat"

    if not noCache and file.Exists(filename, "DATA") then
        self.Files[key] = {
            status = self.STATUS_LOADED,
            path = filename
        }
        if callback then
            callback(self.Files[key])
        end
        return
    end

    self.Files[key] = {
        status = self.STATUS_LOADING
    }

    HTTP:Fetch(
        url,
        function(body, size, headers, code)
            file.Write(filename, body)
            self.Files[key].status = self.STATUS_LOADED
            self.Files[key].path = filename

            if callback then
                callback(self.Files[key])
            end
        end,
        function(err, body)
            self.Files[key].status = self.STATUS_ERROR
            self.Files[key].err = body and err .. ":" .. body or err
        end
    )
end

return FILE