-- Engine-independent catalogue and radial interaction. Angles start at twelve
-- o'clock and increase clockwise. No spell is selected by hovering alone.
local M = {}
local TAU = math.pi * 2
M.geometry = { dead = 112, inner = 132, outer = 264, branchInner = 282,
    branchOuter = 408, skillRadius = 202, spellRadius = 344, dwell = 0.055,
    hysteresis = math.rad(3), maxBranch = 6 }

-- Stable positions: a level-up must never rearrange a player's muscle memory.
M.skills = {
    { id = "Woodcutting", label = "Woodcutting", tint = {0.56, 0.77, 0.38} },
    { id = "Mining", label = "Mining", tint = {0.57, 0.73, 0.84} },
    { id = "Artisan", label = "Artisan", tint = {0.89, 0.64, 0.37} },
    { id = "Construction", label = "Construction", tint = {0.81, 0.73, 0.53} },
    { id = "Farming", label = "Farming", tint = {0.65, 0.81, 0.36} },
    { id = "Cooking", label = "Cooking", tint = {0.91, 0.53, 0.37} },
    { id = "Fishing", label = "Fishing", tint = {0.36, 0.77, 0.81} },
    { id = "Runecrafting", label = "Runecrafting", tint = {0.66, 0.66, 0.94} },
    { id = "Magic", label = "Magic", tint = {0.45, 0.70, 0.95} },
    { id = "Attack", label = "Attack", tint = {0.91, 0.43, 0.35} },
    { id = "Ranged", label = "Ranged", tint = {0.60, 0.78, 0.53} },
    { id = "Agility", label = "Agility", tint = {0.72, 0.80, 0.83} },
}
local skillById = {}
for i, skill in ipairs(M.skills) do skillById[skill.id] = i end

function M.angle(x, y) return math.atan(x, -y) % TAU end
function M.delta(a, b) return (a - b + math.pi) % TAU - math.pi end
function M.point(angle, radius) return math.sin(angle)*radius, -math.cos(angle)*radius end
function M.skillAngle(index, count) return (index - 1) * TAU / count end

-- OwningPerk names were read from the live 1.0 server. No soft pointer
-- marshalling: that crashes this UE4SS build. Match whole tokens, including
-- the Fishing and Agility plugin assets and the game's "Runecraftng" typo.
function M.skillFromPerk(path)
    if type(path) ~= "string" then return nil end
    local name = path:match("%.([^%.]+)$") or path:match("([^/]+)$") or path
    local id = name:match("^PerkV2_([^_]+)_") or name:match("^Perk_([^_]+)_")
    if id == "Runecraftng" then id = "Runecrafting" end
    return skillById[id] and id or nil
end

-- Records contain only plain Lua values, apart from an opaque engine data
-- handle stored by the caller. Read unlock state afresh on each open.
function M.catalogue(records)
    local groups, lookup, seen = {}, {}, {}
    for i, skill in ipairs(M.skills) do
        groups[i] = { id = skill.id, label = skill.label, tint = skill.tint,
            spells = {}, available = 0 }
        lookup[skill.id] = groups[i]
    end
    for _, record in ipairs(records) do
        local id = record.skill or M.skillFromPerk(record.perk)
        local group = lookup[id]
        if group and type(record.id) == "string" and record.id ~= ""
            and type(record.name) == "string" and record.name ~= ""
            and not seen[record.id] then
            seen[record.id] = true
            group.spells[#group.spells + 1] = record
            if record.unlocked == true then group.available = group.available + 1 end
        end
    end
    for _, group in ipairs(groups) do
        table.sort(group.spells, function(a, b)
            local al, bl = a.level or math.huge, b.level or math.huge
            if al ~= bl then return al < bl end
            -- IDs, not translated names or availability: ordering is stable.
            return a.id < b.id
        end)
    end
    return groups
end

function M.new(groups)
    return { groups = groups, group = nil, spell = nil, candidate = nil,
        candidateSince = 0, page = 1, zone = "center", opened = true }
end

function M.pages(state)
    local group = state.groups[state.group]
    return group and math.max(1, math.ceil(#group.spells / M.geometry.maxBranch)) or 1
end

function M.branch(state)
    if not state.group then return nil end
    local group = state.groups[state.group]
    local first = (state.page - 1) * M.geometry.maxBranch + 1
    local count = math.max(0, math.min(M.geometry.maxBranch, #group.spells - first + 1))
    local step = math.rad(20)
    return { center = M.skillAngle(state.group, #state.groups), first = first,
        count = count, step = step, span = step * count }
end

function M.setGroup(state, index)
    if not state.groups[index] then return false end
    if state.group ~= index then state.group, state.page = index, 1 end
    state.spell, state.candidate = nil, nil
    return true
end

function M.turnPage(state, direction)
    if not state.group then return end
    state.page = (state.page - 1 + direction) % M.pages(state) + 1
    state.spell, state.candidate = nil, nil
end

function M.update(state, x, y, now)
    if not state.opened then return end
    local g, r, angle = M.geometry, math.sqrt(x*x+y*y), M.angle(x,y)
    state.spell = nil -- outside the actual target can never cast a stale spell
    if r < g.inner then
        state.zone, state.candidate = "center", nil
        return
    end
    if r <= g.outer or not state.group then
        local count = #state.groups
        if count == 0 then state.zone = "center"; return end
        local step = TAU/count
        local index = math.floor((angle + step/2) % TAU / step) + 1
        if state.group and math.abs(M.delta(angle, M.skillAngle(state.group,count))) < step/2 + g.hysteresis then
            index = state.group
        end
        state.zone = "skill"
        if index ~= state.group then
            if state.candidate ~= index then state.candidate, state.candidateSince = index, now end
            if now - state.candidateSince >= g.dwell then M.setGroup(state, index) end
        else state.candidate = nil end
        return
    end
    -- The selected skill stays latched throughout the bridge and outer fan.
    -- Return to the inner ring to switch skills; no diagonal branch hopping.
    state.candidate = nil
    state.zone = "bridge"
    if r < g.branchInner or r > g.branchOuter then return end
    local branch = M.branch(state)
    if not branch or branch.count == 0 then return end
    local d = M.delta(angle, branch.center)
    if math.abs(d) >= branch.span/2 then return end
    local index = math.floor((d + branch.span/2) / branch.step)
    state.spell = branch.first + index
    state.zone = "spell"
end

function M.selection(state)
    if not state.opened or state.zone ~= "spell" or not state.group or not state.spell then return nil end
    local spell = state.groups[state.group].spells[state.spell]
    if not spell then return nil end
    if spell.unlocked ~= true then return nil, "locked" end
    return spell
end

function M.close(state)
    state.opened, state.group, state.spell, state.candidate = false, nil, nil, nil
end
return M
