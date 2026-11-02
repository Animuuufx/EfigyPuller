-- SPDX-License-Identifier: GPL-3.0-only
-- EfigyPuller v0.3.0: event-driven effigy discovery with lightweight player proximity checks.
-- The game is authoritative for pickup rewards and saved collected state.
local config = require("config")
local function finite_positive(v, fallback)
    if type(v) ~= "number" or v ~= v or v == math.huge or v == -math.huge or v <= 0 then
        return fallback
    end
    return v
end
local function bounded(v, fallback, low, high)
    if type(v) ~= "number" or v ~= v then return fallback end
    return math.max(low, math.min(high, v))
end
local radiusMeters = finite_positive(config.RadiusMeters, 200)
local radiusSquared = (radiusMeters * 100) ^ 2
local interval = math.floor(bounded(config.CheckIntervalMs or config.ScanIntervalMs, 1000, 250, 30000))
local retryTicks = math.ceil(bounded(config.RetrySeconds, 5, 1, 120) * 1000 / interval)
local maxRequests = math.floor(bounded(config.MaxRequestsPerCheck or config.MaxRequestsPerScan, 8, 1, 32))
local movementThreshold = math.max(0, bounded(config.MovementThresholdMeters, 1, 0, 1000)) * 100
local movementSquared = movementThreshold * movementThreshold

local tick, pending = 0, false
local cache, actors = {}, {}
local attempts = {}
local session, controller, nextControllerSearch = nil, nil, 0
local gameplay, relicClass, pickupFunction = nil, nil, nil
local dirty, lastPosition, soonestRetry = true, nil, math.huge
local warnings, summary = {}, {discovered=0, requested=0, confirmed=0}
local function log(message)
    print("[EfigyPuller v0.3.0] " .. tostring(message) .. "\n")
end
local function warnOnce(key, message)
    if warnings[key] then return end
    warnings[key] = true
    log(message)
end
local function valid(object)
    if object == nil then return false end
    local ok, is = pcall(function() return object:IsValid() end)
    return ok and is == true
end
local function addRelic(actor)
    if not valid(actor) then return end
    local ok, address = pcall(function() return tostring(actor:GetAddress()) end)
    if not ok or not address then return end
    if valid(cache[address]) then return end
    cache[address] = actor
    actors[#actors + 1] = {actor=actor, address=address}
    dirty = true
    summary.discovered = summary.discovered + 1
end

-- Newly streamed effigies are discovered via event, not by polling the entire world.
-- Defer to the game thread because an actor can be mid-initialization at construction.
local eventReady = false
local eventOk, eventError = pcall(function()
    NotifyOnNewObject("/Script/Pal.PalLevelObjectRelic", function(actor)
        ExecuteInGameThread(function()
            local ok, err = pcall(addRelic, actor)
            if not ok then warnOnce("new_object", "Effigy creation event failed: " .. tostring(err)) end
        end)
    end)
end)
if eventOk then
    eventReady = true
else
    warnOnce("event_registration", "New-object event unavailable: " .. tostring(eventError))
end

local function localPlayer()
    if not valid(controller) or not controller:IsLocalPlayerController() then
        controller = nil
        if tick < nextControllerSearch then return end
        nextControllerSearch = tick + math.max(1, math.ceil(2000 / interval))
        for _, candidate in ipairs(FindAllOf("PalPlayerController") or {}) do
            if valid(candidate) and candidate:IsLocalPlayerController() then
                controller = candidate
                break
            end
        end
    end
    if not valid(controller) then return end
    local pawn, state = controller.Pawn, controller.PlayerState
    if not valid(pawn) or not valid(state) or not pawn:IsA("/Script/Pal.PalPlayerCharacter") then return end
    local transmitter = controller.Transmitter
    if not valid(transmitter) or not valid(transmitter.Player) then return end
    return pawn, state, transmitter.Player
end

local function clearWorld()
    cache, actors, attempts = {}, {}, {}
    lastPosition, soonestRetry, session = nil, math.huge, nil
    dirty = true
end

local function readyAPI()
    if valid(gameplay) and valid(relicClass) and valid(pickupFunction) then return true end
    gameplay = StaticFindObject("/Script/Engine.Default__GameplayStatics")
    relicClass = StaticFindObject("/Script/Pal.PalLevelObjectRelic")
    pickupFunction = StaticFindObject("/Script/Pal.PalNetworkPlayerComponent:RequestObtainLevelObject_ToServer")
    if not (valid(gameplay) and valid(relicClass) and valid(pickupFunction)) then
        warnOnce("api", "Required game API unavailable; requests paused.")
        return false
    end
    return true
end

-- One-time reconciliation on joining a world; no recurring GetAllActorsOfClass.
-- Newly loaded effigies thereafter arrive from NotifyOnNewObject.
local function seedWorld(pawn)
    local output = {}
    gameplay:GetAllActorsOfClass(pawn, relicClass, output)
    for _, wrapped in ipairs(output) do
        local ok, actor = pcall(function() return wrapped:get() end)
        if ok then addRelic(actor) end
    end
    log("One-time world initialization: " .. tostring(#actors) ..
        " effigy actors. New effigies use creation events.")
end

local function check()
    tick = tick + 1
    local pawn, state, networkPlayer = localPlayer()
    if not pawn then
        if session then clearWorld() end
        return
    end
    local world = pawn:GetWorld()
    if not valid(world) then return end
    local key = tostring(world:GetAddress()) .. ":" .. tostring(state:GetAddress())
    if key ~= session then
        clearWorld()
        session = key
        if not readyAPI() then return end
        local ok, err = pcall(seedWorld, pawn)
        if not ok then warnOnce("seed", "Initial effigy discovery failed: " .. tostring(err)) end
        log("World active; configured radius " .. radiusMeters .. " m.")
    end
    if not readyAPI() then return end

    -- A failed NotifyOnNewObject registration enables a slow fallback.
    -- Normally this branch never runs.
    if not eventReady and tick % math.max(1, math.ceil(30000 / interval)) == 0 then
        local ok, err = pcall(seedWorld, pawn)
        if not ok then warnOnce("fallback", "Fallback effigy lookup failed: " .. tostring(err)) end
    end

    local position = pawn:K2_GetActorLocation()
    if lastPosition and not dirty and tick < soonestRetry then
        local dx,dy,dz = position.X-lastPosition.X, position.Y-lastPosition.Y, position.Z-lastPosition.Z
        if dx*dx+dy*dy+dz*dz < movementSquared then return end
    end
    lastPosition = {X=position.X,Y=position.Y,Z=position.Z}
    dirty = false
    soonestRetry = math.huge
    local candidates, survivors = {}, {}
    for _, entry in ipairs(actors) do
        local actor = entry.actor
        local ok, err = pcall(function()
            if not valid(actor) then
                if cache[entry.address] == actor then cache[entry.address] = nil end
                attempts[entry.address] = nil
                return
            end
            local actorWorld = actor:GetWorld()
            if not valid(actorWorld) or actorWorld:GetAddress() ~= world:GetAddress() then return end
            if actor.bPickedInClient == true then
                if attempts[entry.address] then
                    summary.confirmed = summary.confirmed + 1
                    if config.Debug then log("Pickup confirmed: " .. entry.address) end
                    attempts[entry.address] = nil
                end
                cache[entry.address] = nil
                return
            end
            survivors[#survivors+1] = entry
            if actor.bPickedInClient ~= false then return end
            local loc = actor:K2_GetActorLocation()
            local dx,dy,dz = loc.X-position.X,loc.Y-position.Y,loc.Z-position.Z
            local distanceSquared = dx*dx+dy*dy+dz*dz
            if distanceSquared > radiusSquared then return end
            local retry = attempts[entry.address]
            if retry and tick < retry then
                soonestRetry = math.min(soonestRetry, retry)
                return
            end
            candidates[#candidates+1] = {actor=actor, address=entry.address, distance=distanceSquared}
        end)
        if not ok then
            warnOnce("relic", "Error reading an effigy: " .. tostring(err))
            if valid(actor) then survivors[#survivors+1] = entry end
        end
    end
    actors = survivors
    table.sort(candidates, function(a,b) return a.distance < b.distance end)
    for i=1,math.min(#candidates,maxRequests) do
        local candidate=candidates[i]
        attempts[candidate.address] = tick + retryTicks
        soonestRetry = math.min(soonestRetry, attempts[candidate.address])
        local ok, err = pcall(function()
            if valid(candidate.actor) and candidate.actor.bPickedInClient == false then
                networkPlayer:RequestObtainLevelObject_ToServer(candidate.actor)
                summary.requested = summary.requested + 1
                if config.Debug then log("Pickup requested: " .. candidate.address) end
            end
        end)
        if not ok then warnOnce("request", "Pickup request failed: " .. tostring(err)) end
    end
    if config.Debug and #candidates > 0 then
        log(string.format("Nearby=%d requests this check=%d, cached=%d", #candidates, math.min(#candidates,maxRequests), #actors))
    end
end

if config.Enabled == false then
    log("Disabled in config.lua.")
    return
end
log(string.format("Loaded: radius=%g m; proximity checks=%d ms; new-effigy event=%s",
    radiusMeters, interval, tostring(eventReady)))
LoopAsync(interval, function()
    if pending then return false end
    pending = true
    local ok, err = pcall(function()
        ExecuteInGameThread(function()
            local success, scanError = pcall(check)
            pending = false
            if not success then warnOnce("check", "Proximity check failed: " .. tostring(scanError)) end
        end)
    end)
    if not ok then
        pending = false
        warnOnce("queue", "Could not schedule game-thread check: " .. tostring(err))
    end
    return false
end)
