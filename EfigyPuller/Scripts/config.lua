-- EfigyPuller v0.3.0
-- Change these values while Palworld is closed, then restart the game.
return {
    Enabled = true,

    -- Any positive radius in METERS; no hardcoded upper limit.
    -- Examples: 25, 200, 750, 1500, 5000.
    -- Only effigies already loaded by the game can be collected.
    RadiusMeters = 200,

    -- Lightweight check of the cached effigy list; NOT a world scan.
    CheckIntervalMs = 1000,

    -- Skip checks while the player is stationary (unless an effigy loads or a retry is due).
    -- Set to 0 for exact movement checks, including tiny movements.
    MovementThresholdMeters = 1,

    -- Avoid retrying rejected pickups continuously.
    RetrySeconds = 5,

    -- Prevent a large radius from flooding the server in one frame.
    MaxRequestsPerCheck = 8,

    -- Diagnostic messages for nearby effigies and individual requests.
    Debug = false,
}
