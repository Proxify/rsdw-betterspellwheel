-- Session cooldowns for spells selected through BetterSpellWheel.
-- The game remains authoritative: this only gives the custom wheel a fast
-- local view and avoids sending an obviously unavailable selection back to
-- the native spellcasting UI.
local M = {}

function M.new()
    return setmetatable({ untilById = {} }, { __index = M })
end

local function key(spell)
    return spell and spell.id
end

function M:duration(spell)
    local value = spell and spell.cooldown
    if type(value) == 'number' then return value end
    local ok, result = pcall(function() return value + 0 end)
    return ok and tonumber(result) or tonumber(value) or 0
end

function M:remaining(spell, now)
    local id = key(spell)
    if not id then return 0 end
    local untilAt = self.untilById[id]
    if not untilAt then return 0 end
    local remaining = untilAt - (tonumber(now) or 0)
    if remaining <= 0 then
        self.untilById[id] = nil
        return 0
    end
    return remaining
end

function M:start(spell, now)
    local id = key(spell)
    local duration = self:duration(spell)
    if not id or duration <= 0 then return end
    local untilAt = (tonumber(now) or 0) + duration
    self.untilById[id] = math.max(self.untilById[id] or 0, untilAt)
end

function M:clear(spell)
    local id = key(spell)
    if id then self.untilById[id] = nil end
end

function M:format(seconds)
    local value = math.max(0, math.ceil(tonumber(seconds) or 0))
    if value >= 3600 then
        return string.format('%dh %02dm', math.floor(value / 3600), math.floor(value % 3600 / 60))
    end
    if value >= 60 then
        return string.format('%dm %02ds', math.floor(value / 60), value % 60)
    end
    return string.format('%ds', value)
end

return M
