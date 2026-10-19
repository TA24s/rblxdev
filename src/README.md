# Gizmo Grab scripts

Copies of the scripts in the Roblox Studio place, saved after each build stage. Studio is the
working copy; these files are the history and the backup.

Paths mirror the Studio Explorer. `.server.luau` is a Script, `.client.luau` a LocalScript and
plain `.luau` a ModuleScript (the naming Rojo uses, so the folder can be synced later if wanted).

| Stage | Scripts |
|---|---|
| 2. Lab assignment | `ServerScriptService/Init.server.luau`, `ServerScriptService/Services/LabService.luau` |
| 3. Bolts and saving | `ServerScriptService/Services/DataService.luau`, `StarterPlayer/StarterPlayerScripts/HudController.client.luau` |
| 4. Gadgets | `ReplicatedStorage/Shared/Config/Rarities.luau`, `ReplicatedStorage/Shared/Config/Gadgets.luau`, `StarterPlayer/StarterPlayerScripts/GadgetAnimator.client.luau`. The 8 models in `ServerStorage/GadgetModels` were built once with `tools/build-gadget-models.luau` (run in the Studio command bar). |
| 5. Conveyor and buying | `ServerScriptService/Services/ConveyorService.luau`, `ServerScriptService/Services/NotifyService.luau`, `StarterPlayer/StarterPlayerScripts/NotificationController.client.luau` |
| Map makeover | `StarterPlayer/StarterPlayerScripts/GadgetAnimator.client.luau` now also animates models tagged `AnimatedDecor`, and Spin can turn around a pivot. The decorations, lab signs, colours and lighting were built once with `tools/build-decor.luau`. |
| 6. Benches, income and saving | `ServerScriptService/Services/BenchService.luau` (new); `DataService.luau` (saves benches, data version 2, waits for saves on shutdown); `ConveyorService.luau` (buys go through BenchService) |
| 7. Upgrades and selling | `ReplicatedStorage/Shared/Config/Upgrades.luau` (new); `BenchService.luau` (unlock benches 5-8, sell for half price plus piled-up Bolts); `DataService.luau` (saves `ExtraBenches`, data version 3). Bench5-8 were added to every lab with `tools/build-extra-benches.luau`. |
