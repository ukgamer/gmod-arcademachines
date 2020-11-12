local SOUND = {
    STATUS_QUEUED = 0,
    STATUS_LOADING = 1,
    STATUS_LOADED = 2,
    STATUS_ERROR = 3,
    Sounds = {}
}

function SOUND:LoadFromURL(url, key, callback)
    if not IsValid(MACHINE) then return end

    if self.Sounds[key] then
        if self.Sounds[key].status == self.STATUS_LOADED and callback then
            callback(self.Sounds[key].sound)
        end
        return
    end

    self.Sounds[key] = {
        status = self.STATUS_QUEUED
    }

    if not QUEUE[MACHINE:EntIndex()] then
        QUEUE[MACHINE:EntIndex()] = {}
    end

    table.insert(QUEUE[MACHINE:EntIndex()], {
        url = url,
        key = key,
        callback = callback,
        context = self
    })
end

function SOUND:LoadQueued(tbl)
    self.Sounds[tbl.key].status = self.STATUS_LOADING

    sound.PlayURL(tbl.url, "3d noplay noblock", function(snd, err, errstr)
        if not IsValid(MACHINE) then return end

        if not IsValid(snd) then
            self.Sounds[tbl.key].status = self.STATUS_ERROR
            self.Sounds[tbl.key].err = errstr
            return
        end

        snd:SetPos(MACHINE:GetPos())
        MACHINE.LoadedSounds[tbl.key] = snd

        self.Sounds[tbl.key].status = self.STATUS_LOADED
        self.Sounds[tbl.key].sound = snd

        if tbl.callback then tbl.callback(snd) end
    end)
end

function SOUND:Play(name, level, pitch, volume)
    if not IsValid(MACHINE) then return end
    sound.Play(name, MACHINE:GetPos(), level, pitch, volume)
end

function SOUND:EmitSound(...)
    if not IsValid(MACHINE) then return end
    MACHINE:EmitSound(...)
end

function SOUND:StopSound(...)
    if not IsValid(MACHINE) then return end
    MACHINE:StopSound(...)
end

return SOUND