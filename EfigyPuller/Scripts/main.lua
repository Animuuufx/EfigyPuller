-- SPDX-License-Identifier: GPL-3.0-only
-- EfigyPuller: request ordinary effigy pickups for the local player.
local config = require("config")
local function bounded(value, fallback, low, high)
    if type(value) ~= "number" or value ~= value then return fallback end
    return math.max(low, math.min(high, value))
end
local radius = bounded(config.RadiusMeters, 50, 1, 500) * 100
local interval = math.floor(bounded(config.ScanIntervalMs, 500, 100, 10000))
local retryTicks = math.ceil(bounded(config.RetrySeconds, 5, 1, 60) * 1000 / interval)
local limit = math.floor(bounded(config.MaxRequestsPerScan, 8, 1, 32))
local tick, pending = 0, false
local attempts, session = {}, nil
local warned = {}

local function log(message)
    print("[EfigyPuller] " .. message .. "\n")
end
local function warnOnce(key, message)
    if not warned[key] then warned[key] = true; log(message) end
end
local function valid(object)
    return object ~= nil and object:IsValid()
end
local function localPlayer()
    for _, controller in ipairs(FindAllOf("PalPlayerController") or {}) do
        if valid(controller) and controller:IsLocalPlayerController() then
            local pawn, state = controller.Pawn, controller.PlayerState
            if valid(pawn) and valid(state) and pawn:IsA("/Script/Pal.PalPlayerCharacter") then
                return pawn, state
            end
        end
    end
end
local function scan()
    tick = tick + 1
    local pawn, state = localPlayer()
    if not pawn then attempts = {}; session = nil; return end
    local world = pawn:GetWorld()
    if not valid(world) then return end
    local sessionKey = tostring(world:GetAddress()) .. ":" .. tostring(state:GetAddress())
    if sessionKey ~= session then attempts = {}; session = sessionKey end

    -- Verify reflection before making any pickup request; never fabricate rewards.
    local pickup = StaticFindObject("/Script/Pal.PalPlayerState:RequestObtainLevelObject_ToServer")
    if not valid(pickup) then
        warnOnce("api", "Pickup function unavailable; collection paused. Check game/UE4SS compatibility.")
        return
    end
    local position = pawn:K2_GetActorLocation()
    local candidates, live = {}, {}
    for _, relic in ipairs(FindAllOf("PalLevelObjectRelic") or {}) do
        local ok, err = pcall(function()
            if not valid(relic) or relic.bPickedInClient ~= false then return end
            local relicWorld = relic:GetWorld()
            if not valid(relicWorld) or relicWorld:GetAddress() ~= world:GetAddress() then return end
            local location = relic:K2_GetActorLocation()
            local dx, dy, dz = location.X - position.X, location.Y - position.Y, location.Z - position.Z
            local distanceSquared = dx * dx + dy * dy + dz * dz
            if distanceSquared > radius * radius then return end
            local key = relic:GetFullName()
            live[key] = true
            if not attempts[key] or tick >= attempts[key] then
                candidates[#candidates + 1] = { actor = relic, key = key, distance = distanceSquared }
            end
        end)
        if not ok then warnOnce("relic", "Could not inspect an effigy: " .. tostring(err)) end
    end
    for key in pairs(attempts) do
        if not live[key] then attempts[key] = nil end
    end
    table.sort(candidates, function(a, b) return a.distance < b.distance end)
    for i = 1, math.min(limit, #candidates) do
        local candidate = candidates[i]
        attempts[candidate.key] = tick + retryTicks
        local ok, err = pcall(function()
            if valid(candidate.actor) and candidate.actor.bPickedInClient == false then
                state:RequestObtainLevelObject_ToServer(candidate.actor)
                if config.Debug then log("Pickup requested: " .. candidate.key) end
            end
        end)
        if not ok then warnOnce("request", "Pickup request failed: " .. tostring(err)) end
    end
end

if config.Enabled == false then
    log("Disabled in config.lua.")
    return
end
log(string.format("Loaded v0.1.0: auto-collect within %.1f meters, scanning every %d ms.", radius / 100, interval))
LoopAsync(interval, function()
    -- Do not enqueue more work while a paused/loading game has a scan outstanding.
    if pending then return false end
    pending = true
    local queued, queueError = pcall(function()
        ExecuteInGameThread(function()
            local ok, err = pcall(scan)
            pending = false
            if not ok then warnOnce("scan", "Scan failed: " .. tostring(err)) end
        end)
    end)
    if not queued then
        pending = false
        warnOnce("queue", "Could not schedule scan: " .. tostring(queueError))
    end
    return false
end)
