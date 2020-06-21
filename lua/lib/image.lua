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

function IMAGE:ClearCache()
	self.Images = {}

	for _, v in ipairs(file.Find(path .. "/*", "DATA")) do
		file.Delete(path .. "/" .. v)
	end
end

function IMAGE:LoadFromURL(url, name, noCache)
	if self.Images[name] and not noCache then return end
	
	local filename = path .. "/" .. urlhash(url) .. "." .. string.GetExtensionFromFilename(url)
	
	if not noCache then
		if file.Exists(filename, "DATA") then
			self.Images[name] = {
				status = self.STATUS_LOADED,
				mat = Material("../data/" .. filename)
			}
			return
		end
	end
	
	self.Images[name] = {
		status = self.STATUS_LOADING,
		mat = Material("error")
	}
	
	http.Fetch(
		url,
		function(body, size, headers, code)
			file.Write(filename, body)
			self.Images[name].status = self.STATUS_LOADED
			self.Images[name].mat = Material("../data/" .. filename)
		end,
		function(err)
			self.Images[name].status = self.STATUS_ERROR
			Error("Failed to load image:" .. err)
		end
	)
end

return IMAGE