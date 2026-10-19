--!strict
-- NotifyService
-- Shows a short message on one player's screen ("You need more Bolts", "You bought ...").
-- The client side is NotificationController, which listens on ReplicatedStorage/Remotes/Notify.
-- Container: ServerScriptService/Services

----- Services -----
local ReplicatedStorage = game:GetService("ReplicatedStorage")

----- Variables -----
-- Made here rather than by hand in Studio, so the folder always exists once any service loads
local remotes = ReplicatedStorage:FindFirstChild("Remotes")
if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name = "Remotes"
	remotes.Parent = ReplicatedStorage
end
local notifyRemote = remotes:FindFirstChild("Notify") :: RemoteEvent?
if not notifyRemote then
	local remote = Instance.new("RemoteEvent")
	remote.Name = "Notify"
	remote.Parent = remotes
	notifyRemote = remote
end

local NotifyService = {}

----- Public Functions -----
function NotifyService.Send(player: Player, text: string)
	(notifyRemote :: RemoteEvent):FireClient(player, text)
end

function NotifyService.Init()
	-- Nothing to start: the remote is created when this module is first required
end

return NotifyService
