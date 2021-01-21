local SOUND = {
    STATUS_LOADING = 0,
    STATUS_LOADED = 1,
    STATUS_ERROR = 2,
    Sounds = {}
}

function SOUND:LoadFromURL(url, key, callback)
    if not IsValid(ENTITY) then return end

    if self.Sounds[key] then
        if self.Sounds[key].status == self.STATUS_LOADED and callback then
            callback(self.Sounds[key].sound)
        end
        return
    end

    self.Sounds[key] = {
        status = self.STATUS_LOADING
    }

    sound.PlayURL(url, "3d noplay noblock", function(snd, err, errstr)
        if not IsValid(ENTITY) then return end

        if not IsValid(snd) then
            self.Sounds[key].status = self.STATUS_ERROR
            self.Sounds[key].err = errstr
            return
        end

        snd:SetPos(ENTITY:GetPos())
        ENTITY.LoadedSounds[key] = snd

        self.Sounds[key].status = self.STATUS_LOADED
        self.Sounds[key].sound = snd

        if callback then callback(snd) end
    end)
end

function SOUND:Play(name, level, pitch, volume)
    if not IsValid(ENTITY) then return end
    sound.Play(name, ENTITY:GetPos(), level, pitch, volume)
end

function SOUND:EmitSound(...)
    if not IsValid(ENTITY) then return end
    ENTITY:EmitSound(...)
end

function SOUND:StopSound(...)
    if not IsValid(ENTITY) then return end
    ENTITY:StopSound(...)
end

return SOUND