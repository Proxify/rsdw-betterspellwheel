-- Spell cooldowns for the custom wheel: DISPLAY ONLY. The game decides whether
-- a spell can be cast; these timers never block a cast. Synced from the game's
-- last cast times while the wheel is open and from the server's cooldown
-- notices; casts seen through the wheel start a timer straight away.
-- A spell is "waived" when the game accepted a cast while its timer was still
-- running (e.g. a no-cooldown mod): no local timer is started for it until the
-- game refuses it with a cooldown notice again.
local M = {}

function M.new()
    return setmetatable({ untilById = {}, waived = {} }, { __index = M })
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
    if not id or self.waived[id] then return end
    if duration <= 0 then self.untilById[id] = nil; return end
    local untilAt = (tonumber(now) or 0) + duration
    self.untilById[id] = math.max(self.untilById[id] or 0, untilAt)
end

-- Replace the estimate with the game's own timing (last cast time read from
-- PlayerUtilityMagicComponent, or the server's "on cooldown" notice).
function M:sync(spell, now, remaining)
    local id = key(spell)
    if not id then return end
    remaining = tonumber(remaining) or 0
    if remaining <= 0 then self.untilById[id] = nil; return end
    self.untilById[id] = (tonumber(now) or 0) + remaining
end

function M:clear(spell)
    local id = key(spell)
    if id then self.untilById[id] = nil end
end

function M:reset()
    self.untilById = {}
end

-- The game accepted a cast the timer said was on cooldown: drop the estimate.
function M:waive(spell)
    local id = key(spell)
    if not id then return end
    self.untilById[id] = nil
    self.waived[id] = true
end

-- The game refused the spell with a cooldown notice: estimates apply again.
function M:trust(spell)
    local id = key(spell)
    if id then self.waived[id] = nil end
end

function M:isWaived(spell)
    local id = key(spell)
    return id ~= nil and self.waived[id] == true
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
