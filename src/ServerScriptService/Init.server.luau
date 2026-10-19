--!strict
-- Init
-- Server entry point: starts every service in ServerScriptService/Services.
-- Container: ServerScriptService

local ServerScriptService = game:GetService("ServerScriptService")

local Services = ServerScriptService:WaitForChild("Services")

for _, module in Services:GetChildren() do
	if module:IsA("ModuleScript") then
		local ok, err = pcall(function()
			local service = require(module) :: { Init: (() -> ())? }
			if service.Init then
				service.Init()
			end
		end)
		if ok then
			print(`[Init] Started {module.Name}`)
		else
			warn(`[Init] {module.Name} failed to start: {err}`)
		end
	end
end
