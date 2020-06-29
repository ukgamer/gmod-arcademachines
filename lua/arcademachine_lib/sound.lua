local SOUND = {
    STATUS_QUEUED = 0,
    STATUS_LOADING = 1,
    STATUS_LOADED = 2,
    STATUS_ERROR = 3,
    Sounds = {}
}

function SOUND:LoadFromURL(url, key, callback)
    if self.Sounds[key] and IsValid(self.Sounds[key].sound) then return end

    self.Sounds[key] = {
        status = self.STATUS_QUEUED
    }

    table.insert(QUEUE, {
        url = url,
        key = key,
        callback = callback,
        context = self
    })
end

function SOUND:LoadQueued(tbl)
    self.Sounds[tbl.key].status = self.STATUS_LOADING

    sound.PlayURL(tbl.url, "3d noplay noblock", function(snd, err, errstr)
        if not IsValid(snd) then
            self.Sounds[tbl.key].status = self.STATUS_ERROR
            self.Sounds[tbl.key].err = errstr
            return
        end
        
        snd:SetPos(MACHINE.Entity:GetPos())
        MACHINE.LoadedSounds[tbl.key] = snd

        self.Sounds[tbl.key].status = self.STATUS_LOADED
        self.Sounds[tbl.key].sound = snd

        if tbl.callback then tbl.callback(snd) end
    end)
end

return SOUND