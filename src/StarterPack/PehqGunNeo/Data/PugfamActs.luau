local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Tool = script.Parent.Parent
local Actions = {}
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local PlayerEvents = ReplicatedStorage.Pugfam12RE.PlayerData[player.UserId].RemoteEvents
local Camera = workspace.CurrentCamera

local PugfamGunData = require(Tool.Data.PugfamData)
local PugfamAnimData = require(Tool.Data.PugfamAnims)

local Equipping = false
local FireRateCoolDown = false
local Reloading = false
local isAiming = false
local AimDownSights = false


local function CheckConditions()
    if Equipping == true or FireRateCoolDown == true or Reloading == true and AimDownSights == true then
        return false
	end
	
    return true
end

local function getMouse3dPos(inputObject: InputObject) --similar to mouse.hit.p but better
    local mousepos = inputObject.Position
	
    local cameraRay = Camera:ScreenPointToRay(mousepos.X, mousepos.Y)
---@diagnostic disable-next-line: redundant-parameter	
		
	
	local RaycastParamsThing = RaycastParams.new()
    local x = {character:GetDescendants(), Camera:GetDescendants()}
    for value in pairs(PugfamGunData.RaycastPartFilter) do
        table.insert(x, value)
    end

    RaycastParamsThing.FilterDescendantsInstances = x
    RaycastParamsThing.FilterType = Enum.RaycastFilterType.Exclude
    RaycastParamsThing.IgnoreWater = PugfamGunData.FilterWater

    local raycastResult:RaycastResult = workspace:Raycast(cameraRay.Origin, cameraRay.Direction * PugfamGunData.RayLength, RaycastParamsThing)

	--raycastResult = raycastResult ~= nil and raycastResult.Position or cameraRay.Origin + cameraRay.Direction * PugfamGunData.RayLength --if there wasn't any instance to hit then it will simply return the destination's position
	if not raycastResult then --if not raycast result then return a value
		raycastResult = {
			["Distance"] = PugfamGunData.RayLength,
			["Instance"] = nil,
			["Material"] = nil,
			["Position"] = cameraRay.Origin + cameraRay.Direction * PugfamGunData.RayLength,
			["Normal"] = ((workspace.Camera.CFrame.LookVector.Unit) - Vector3.new(0.5)):Ceil() * -1, --Returns skybox (don't know why you'll need this...)
		}
	end

	local debugPart = Instance.new("Part")
	debugPart.Size = Vector3.one
	debugPart.Position = raycastResult.Position
	debugPart.Anchored = true
	debugPart.CanCollide = false
	debugPart.CanQuery = false
	debugPart.CanTouch = false
	debugPart.Transparency = 0.5
	debugPart.Color = Color3.new(1, 0, 0)
	debugPart.Material = Enum.Material.Neon
	debugPart.Parent = workspace
	task.delay(0.5, function()
		debugPart:Destroy()
	end)

    return raycastResult
end

--[[
    Each action should fire to the server using PlayerEvents.Action in this format: ActionName, ActionProperties
      ActionName --> The string that is the Action Name
      ActionProperties --> The table that houses each actions' properties

    Any action that gets it's data updated would have to fire to PlayerEvents.Update in this format: ActionName, PropertyToUpdate
        ActionName --> A string. Referencing which property to replace.
        PropertiesToUpdate --> a table with the updated properties. It will only replace the properties that were listed rather than all properties.

        (Note that tool isn't referenced here since tool is already referenced in the PlayerEvents.Action event)
]]

--functions called by the framework, they are called by name
local ConnectionsToDisconnectOnUnequip = {}

local idleAnim

function Actions.Equip()
    Equipping = true
    task.wait(PugfamAnimData.EquipTime)
	Equipping = false
	
	idleAnim = PugfamAnimData.AnimationFile.CharIdle(character)
end

function Actions.UnEquip()
	idleAnim:Stop()
    for _, v in pairs(ConnectionsToDisconnectOnUnequip) do
        v:Disconnect()
    end
end

--Additional functions that will run after contextactionservice finishes setting up keybinds, could be used for PlayerEvents
Actions.AdditionalFunctions = {}

function Actions.AdditionalFunctions.Onsit()
    local sitConnection
    sitConnection = character.Humanoid.Seated:Connect(function(active, currentSeatPart)

    end)

    table.insert(ConnectionsToDisconnectOnUnequip, sitConnection)
end

--Functions binded by keybinds using ContextActionService. These functions will be called through another script.
local function Shoot(actionName, inputState, inputObject)
	if actionName ~= "Shoot" or inputState == Enum.UserInputState.Cancel then
        return
	end
	
	print(inputState == Enum.UserInputState.Begin)

    --Single (shoot once then let go)
    if PugfamGunData.FireType == "Single" and inputState == Enum.UserInputState.Begin and CheckConditions() then
		FireRateCoolDown = true
		
		local res = getMouse3dPos(inputObject)
		
		PlayerEvents.Action:FireServer(actionName, {["StartPos"] = script.Parent.Parent[PugfamGunData.BulletBase].Position , ["TargetPos"] = res.Position}) --use remote function to yield?

        task.spawn(function()
            task.wait(PugfamGunData.Firerate)
            FireRateCoolDown = false
        end)
    end
	--[[
    --Constant (continous shooting)
    if PugfamGunData.FireType == "Constant" and inputState == Enum.UserInputState.Begin and CheckConditions() then
		print("Started")
		
		local res = getMouse3dPos(inputObject)
		
		PlayerEvents.Action:FireServer(actionName, {["FireType"] = "Constant", ["ShootType"] = "Step", ["TargetPos"] = res.Position, ["RaycastResult"] = res, ["isHeld"] = true})
    elseif inputState == Enum.UserInputState.End then
		
		print("Ended")

        PlayerEvents.Action:FireServer(actionName, {"Constant", getMouse3dPos(inputObject).Position, ["isHeld"] = false})

        FireRateCoolDown = true
        task.spawn(function()
            task.wait(PugfamGunData.Firerate)
            FireRateCoolDown = false
        end)
    end

	
    --Multi (number of shots per trigger pulled)
	if PugfamGunData.FireType == "Multi" and inputState == Enum.UserInputState.Begin and CheckConditions() then
        FireRateCoolDown = true
		PlayerEvents.Action:FireServer(actionName, {["FireType"] = "Multi", ["ShootType"] = "Step", ["TargetPos"] = getMouse3dPos(inputObject).Position, ["RaycastResult"] = getMouse3dPos(inputObject)}) --use remote function to yield?
        task.spawn(function()
            task.wait(PugfamGunData.Firerate)
            FireRateCoolDown = false
        end)
    end
	]]
	return
end

local function UpdateMousePos(actionName, inputState, inputObject)
    if actionName ~= "UpdateMousePos" or inputState == Enum.UserInputState.Cancel then
        return
    end

	PlayerEvents.Update:FireServer({"TargetPos", getMouse3dPos(inputObject).Position})
end

local function Reload(actionName, inputState, inputObject)
	if actionName ~= "Reload" or inputState == Enum.UserInputState.Cancel or inputState ~= Enum.UserInputState.Begin then
        return
	end

    local unequippedgun = false
    Reloading = true
    --Play anim

    local UnequipToolConnection
    UnequipToolConnection = Tool.Unequipped:Connect(
        function()
            unequippedgun = true
    end)

    task.wait(PugfamGunData.ReloadTime)

    UnequipToolConnection:Disconnect()

    if PugfamGunData.OffHandReloading ~= true or unequippedgun then --check if gun was unequipped
        return
    end

    --reload function
end

local function Aim(actionName, inputState, inputObject)
	if actionName ~= "Aim" or inputState == Enum.UserInputState.Cancel then
        return
    end


	return Enum.ContextActionResult.Pass --Mouse right click
end

local function Emote(actionName, inputState, inputObject)
	if actionName ~= "Emote" or inputState == Enum.UserInputState.Cancel then
        return
    end

end


--Actions are done from the client
Actions.ContextActions = {
    {
        ["actionName"] = "Shoot",
        ["functionToBind"] = Shoot,
        ["inputTypes"] = { --Multiple keybinds, you can add controller support here
            Enum.UserInputType.MouseButton1,
            Enum.KeyCode.ButtonR2,
        },
        ["priorityLevel"] = 2000,
        ["MobileButtons"] = { --Mobile support, you can set this to nil if you don't want to implement mobile support
            ["createTouchButton"] = true,
            ["stackOrder"] = 1,
            ["description"] = "Shoot the gun", --literally does nothing Rofl
            ["title"] = "Shoot",
            ["image"] = "", --rbxassetid//00000000
			["position"] = {0, 0, 0, 0}, --shoot button position. Stored as Udim2.new(position) Set it to nil for the default position (idk what position, im scripting from vscode).
        },
    },
    {
        ["actionName"] = "UpdateMousePos",
        ["functionToBind"] = UpdateMousePos,
        ["inputTypes"] = {
            Enum.UserInputType.MouseMovement,
            Enum.KeyCode.Thumbstick2,
            --Enum.UserInputType.Touch --idk how to implement this atm
        },
        ["priorityLevel"] = 2000,
        ["MobileButtons"] = nil
    },
    {
        ["actionName"] = "Reload",
        ["functionToBind"] = Reload,
        ["inputTypes"] = {
            Enum.KeyCode.R,
            Enum.KeyCode.ButtonX,
        },
        ["priorityLevel"] = 2000,
        ["MobileButtons"] = {
            ["createTouchButton"] = true,
            ["stackOrder"] = 1,
            ["description"] = "Reload the gun",
            ["title"] = "Reload",
            ["image"] = "",
			["position"] = {0.2, 0, 0, 0},
        }
    },
    {
        ["actionName"] = "Aim",
        ["functionToBind"] = Aim,
        ["inputTypes"] = {
            Enum.UserInputType.MouseButton2,
            Enum.KeyCode.ButtonL2,
        },
        ["priorityLevel"] = 2000,
        ["MobileButtons"] = {
            ["createTouchButton"] = true,
            ["stackOrder"] = 1,
            ["description"] = "Aim the gun",
            ["title"] = "Aim",
            ["image"] = "",
			["position"] = {0.4, 0, 0, 0},
        }
    },
    {
        ["actionName"] = "Emote",
        ["functionToBind"] = Emote,
        ["inputTypes"] = {
            Enum.KeyCode.G,
            Enum.KeyCode.ButtonR3,
        },
        ["priorityLevel"] = 2000,
        ["MobileButtons"] = {
            ["createTouchButton"] = true,
            ["stackOrder"] = 1,
            ["description"] = "Shoot the gun",
            ["title"] = "Emote",
            ["image"] = "",
			["position"] = {0.6, 0, 0, 0},
        }
    },
}

return Actions