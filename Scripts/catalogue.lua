-- Read-only Dragonwilds 1.0 adapter. Verified against the MODTEST dedicated
-- server. Never enumerate soft-pointer arrays or marshal a soft pointer.
return function(model)
    local M = {}
    function M.scan(isUnlocked)
        local records, errors = {}, {}
        for _, data in ipairs(FindAllOf("UtilitySpellData") or {}) do
            local ok, record = pcall(function()
                if not data:IsValid() then return nil end
                local perk = data.OwningPerk
                if not perk:IsValid() then return nil end
                local skill = model.skillFromPerk(perk:GetFullName())
                local name = data.SpellDisplayName:ToString()
                if not skill or name == "" then return nil end
                return { id = data:GetFName():ToString(), name = name, skill = skill,
                    perk = perk:GetFullName(), level = perk.PerkUnlockInfo.RequiredSkillLevel,
                    description = perk.PerkDescription:ToString(), cooldown = data.CooldownDuration,
                    -- Availability is injected by the client adapter only after
                    -- its native unlock query has passed the live probe.
                    unlocked = isUnlocked ~= nil and isUnlocked(perk) == true or false,
                    data = data }
            end)
            if ok then
                if record then records[#records + 1] = record end
            else errors[#errors + 1] = tostring(record) end
        end
        return model.catalogue(records), errors
    end
    return M
end
