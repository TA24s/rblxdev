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
| Mountains and caves | No script changes. The terrain mountains, cave crystals and the invisible arena wall were built once with `tools/build-mountains.luau`. |
| Purple dusk sky | No script changes. Lighting, Atmosphere, Sky and the `ScienceTint` colour effect were set once with `tools/set-sky.luau`. |
| 8. Gate lock | `ServerScriptService/Services/GateService.luau` (new: lock button, recharge, upgrades); `StarterPlayer/StarterPlayerScripts/GateController.client.luau` (new: locked gate is solid for everyone but the owner); `Upgrades.luau` (lock times and prices); `DataService.luau` (saves `GateLevel`, data version 4). The buttons were built once with `tools/build-gate-buttons.luau`. |
| 9. Stealing | `ServerScriptService/Services/StealService.luau` (new: grab, carry over your head for 60s, deliver at your Receiving Dock, or it goes back); `ReplicatedStorage/Shared/Config/Stealing.luau` (new: hold times by rarity, carry time, carry speed); `BenchService.luau` (Steal prompt on every bench except the Vault, hides a gadget while it's carried, hands it over when delivered); `StarterPlayer/StarterPlayerScripts/LabPromptController.client.luau` (new: you only see Steal in other labs and Sell/Unlock/lock in yours); `GateController.client.luau` (someone inside a lab when it locks can walk out). |
| Saving with ProfileStore | `DataService.luau` now saves through ProfileStore (session locking, so a quick rejoin to another server can't copy or bring back stolen gadgets). Store `PlayerProfiles_v1`, data version 5; old `PlayerData_v1` saves are copied in once and never written again. **ProfileStore itself is not in this repo:** it's loleris's free module from the Creator Store (asset 109379033046155), inserted as `ServerStorage.ProfileStore`. |
| 10. Protection and Boing Glove | `ServerScriptService/Services/ProtectionService.luau` (new: 10-minute new-player shield, 90s protection after a theft, 5-minute repeat-theft cooldown, no stealing from players earning under 20% of you, 25% insurance, label above the gate); `ServerScriptService/Services/GloveService.luau` (new: everyone gets a Boing Glove; hitting a thief who carries your gadget sends it home); `StarterPlayer/StarterPlayerScripts/KnockbackController.client.luau` (new: the bounce); `Config/Stealing.luau` (protection and glove numbers); `StealService.luau` (checks the rules, no glove while carrying); `DataService.luau` (saves `ShieldSeconds`, data version 6). |
