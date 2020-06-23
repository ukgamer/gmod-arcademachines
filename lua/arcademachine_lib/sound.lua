local SOUND = {
    STATUS_LOADING = 0,
    STATUS_LOADED = 1,
    STATUS_ERROR = 2,
    Sounds = {}
}

function SOUND:LoadFromURL(url, key, callback)
    if self.Sounds[key] and IsValid(self.Sounds[key].sound) then return end

    self.Sounds[key] = {
        status = self.STATUS_LOADING
    }

    sound.PlayURL(url, "3d noplay noblock", function(snd, err, errstr)
        if not IsValid(snd) then
            self.Sounds[key].status = self.STATUS_ERROR
            self.Sounds[key].err = errstr
            return
        end

        snd:SetPos(MACHINE.Entity:GetPos())
        self.Sounds[key].sound = snd
        MACHINE.LoadedSounds[key] = snd

        if callback then callback(snd) end
    end)
end

return SOUND