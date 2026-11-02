return {
    Enabled = true,
    -- Default 200 m. Set to ANY positive number (e.g., 50, 200, 1000, 5000).
    -- No artificial maximum. Only already-loaded effigies are discoverable.
    RadiusMeters = 200,
    ScanIntervalMs = 500,
    DiscoveryIntervalMs = 2000,
    RetrySeconds = 5,
    MaxRequestsPerScan = 8,
    Debug = false,
}
