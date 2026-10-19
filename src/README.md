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
