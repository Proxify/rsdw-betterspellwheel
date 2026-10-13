-- Resolve ownership through native progression, never asset naming.
-- GetPerksUnlockedAtLevelForSkill returns hard UObject references; querying
-- the full level range is read-only and does not unlock anything.
return function(model)
    local M = {}
    function M.scan(isUnlocked, component)
        assert(component and component:IsValid(), "skill progression component is unavailable")
        local owners = {}
        for _, skill in ipairs(FindAllOf("SkillData") or {}) do
            if skill:IsValid() then
                local id = model.skillFromType(skill.SkillType)
                if id then
                    for _, value in ipairs(component:GetPerksUnlockedAtLevelForSkill(skill, skill.MaxLevel, 0)) do
                        local perk = value:get()
                        if perk:IsValid() then
                            local key = perk:GetFullName()
                            assert(not owners[key] or owners[key] == id, "ambiguous skill ownership: "..key)
                            owners[key] = id
                        end
                    end
                end
            end
        end
        local records, errors = {}, {}
        for _, data in ipairs(FindAllOf("UtilitySpellData") or {}) do
            local ok, record = pcall(function()
                if not data:IsValid() then return nil end
                local perk = data.OwningPerk
                if not perk:IsValid() then return nil end
                local skill = owners[perk:GetFullName()]
                local name = data.SpellDisplayName:ToString()
                if not skill or name == "" then return nil end
                return { id = data:GetFName():ToString(), name = name, skill = skill,
                    perk = perk:GetFullName(), level = perk.PerkUnlockInfo.RequiredSkillLevel,
                    description = perk.PerkDescription:ToString(), cooldown = data.CooldownDuration,
                    unlocked = isUnlocked ~= nil and isUnlocked(perk, data) == true or false,
                    data = data }
            end)
            if ok then
                if record then records[#records + 1] = record end
            else errors[#errors + 1] = tostring(record) end
        end
        assert(#records > 0, "no spells resolved from current progression")
        return model.catalogue(records), errors
    end
    function M.refresh(groups, isUnlocked)
        for _, group in ipairs(groups or {}) do
            group.available = 0
            for _, record in ipairs(group.spells or {}) do
                record.unlocked = isUnlocked(record) == true
                if record.unlocked then group.available = group.available + 1 end
            end
        end
        return groups
    end
    return M
end
