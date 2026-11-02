# Validation — EfigyPuller v0.3.0

- Auto pickup radius default 200m, configuration permits any positive finite meter value.
- Event-driven discovery through `NotifyOnNewObject("/Script/Pal.PalLevelObjectRelic", ...)`.
- One initial `GameplayStatics:GetAllActorsOfClass` query per world session.
- Cached proximity checks use player movement threshold and retry timing.
- GameThread used for object handling and pickup RPCs, and network requests rate-limited in batches.
- Live-game behavior, server acceptance of long-range requests, and persistence require in-game testing.
