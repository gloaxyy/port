-- ============================================================
-- JungleGoblinBuilder
-- Constructs a stylized low-poly Jungle Goblin enemy model
-- and registers it in ReplicatedStorage/BalloonModels/JungleGoblin
-- Features articulated Motor6D joints for full realistic walk & turning animation
-- ============================================================

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BalloonModels = ReplicatedStorage:WaitForChild("BalloonModels")

local function buildJungleGoblin()
	local existing = BalloonModels:FindFirstChild("JungleGoblin")
	if existing then
		existing:Destroy()
	end

	local model = Instance.new("Model")
	model.Name = "JungleGoblin"

	-- Materials & Colors Palette (Darker richer jungle goblin green)
	local SKIN_COLOR = Color3.fromRGB(45, 95, 32) -- deep dark forest goblin green
	local DARK_SKIN = Color3.fromRGB(30, 68, 22) -- darker shadow/accent green
	local LEATHER_COLOR = Color3.fromRGB(90, 52, 28) -- tribal leather brown
	local DARK_LEATHER = Color3.fromRGB(60, 32, 16)
	local LEAF_COLOR = Color3.fromRGB(28, 88, 32) -- tropical dark leaf green
	local BONE_COLOR = Color3.fromRGB(230, 225, 205) -- tooth / bone ivory
	local WOOD_COLOR = Color3.fromRGB(95, 60, 30) -- primitive club wood
	local HAIR_COLOR = Color3.fromRGB(24, 20, 20) -- messy dark hair
	local EYE_GLOW = Color3.fromRGB(255, 170, 30) -- glowing amber eyes
	local MOUTH_COLOR = Color3.fromRGB(55, 15, 15)

	-- Scale factor to make goblin smaller and more compact
	local S = 0.65

	-- Root Part
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2 * S, 2 * S, 1 * S)
	root.Transparency = 1
	root.CanCollide = false
	root.Anchored = true
	root.CFrame = CFrame.new(0, 2.3, 0)
	root.Parent = model
	model.PrimaryPart = root

	-- Configure Humanoid to hide display name / health text (standard healthbar will render via HealthBarManager)
	local humanoid = Instance.new("Humanoid")
	humanoid.Name = "Humanoid"
	humanoid.MaxHealth = 40
	humanoid.Health = 40
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.Parent = model

	local function weldParts(part0, part1, c0)
		local weld = Instance.new("Weld")
		weld.Part0 = part0
		weld.Part1 = part1
		weld.C0 = c0 or CFrame.new()
		weld.C1 = CFrame.new()
		weld.Parent = part0
		part1.CFrame = part0.CFrame * (c0 or CFrame.new())
		part1.Anchored = false
		part1.CanCollide = false
		return weld
	end

	local function makeJoint(part0, part1, jointName, c0, c1)
		local m6d = Instance.new("Motor6D")
		m6d.Name = jointName
		m6d.Part0 = part0
		m6d.Part1 = part1
		m6d.C0 = c0 or CFrame.new()
		m6d.C1 = c1 or CFrame.new()
		m6d.Parent = part0
		part1.CFrame = part0.CFrame * (c0 or CFrame.new()) * (c1 and c1:Inverse() or CFrame.new())
		part1.Anchored = false
		part1.CanCollide = false
		return m6d
	end

	-- ¦¦ Torso (Lower & Upper with Tribal Wraps) ¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦
	local torso = Instance.new("Part")
	torso.Name = "UpperTorso"
	torso.Size = Vector3.new(1.8 * S, 1.6 * S, 1.2 * S)
	torso.Color = SKIN_COLOR
	torso.Material = Enum.Material.SmoothPlastic
	torso.Anchored = false
	torso.CanCollide = false
	torso.Parent = model
	makeJoint(root, torso, "RootJoint", CFrame.new(0, 0.2 * S, 0))

	-- Chest Tribal Harness (Leather straps crossing chest)
	local strap1 = Instance.new("Part")
	strap1.Name = "ChestStrap1"
	strap1.Size = Vector3.new(0.3 * S, 1.8 * S, 1.26 * S)
	strap1.Color = LEATHER_COLOR
	strap1.Material = Enum.Material.Fabric
	strap1.Anchored = false
	strap1.CanCollide = false
	strap1.Parent = model
	weldParts(torso, strap1, CFrame.Angles(0, 0, math.rad(35)))

	local strap2 = Instance.new("Part")
	strap2.Name = "ChestStrap2"
	strap2.Size = Vector3.new(0.3 * S, 1.8 * S, 1.26 * S)
	strap2.Color = LEATHER_COLOR
	strap2.Material = Enum.Material.Fabric
	strap2.Anchored = false
	strap2.CanCollide = false
	strap2.Parent = model
	weldParts(torso, strap2, CFrame.Angles(0, 0, math.rad(-35)))

	-- Bone/Tooth Amulet in center of chest
	local amulet = Instance.new("Part")
	amulet.Name = "BoneAmulet"
	amulet.Size = Vector3.new(0.35 * S, 0.6 * S, 0.3 * S)
	amulet.Color = BONE_COLOR
	amulet.Material = Enum.Material.SmoothPlastic
	amulet.Anchored = false
	amulet.CanCollide = false
	amulet.Parent = model
	weldParts(torso, amulet, CFrame.new(0, 0.1 * S, -0.68 * S) * CFrame.Angles(math.rad(180), 0, 0))
	local amuletMesh = Instance.new("SpecialMesh")
	amuletMesh.MeshType = Enum.MeshType.Wedge
	amuletMesh.Parent = amulet

	-- Lower Torso / Waist with Leather Belt
	local lowerTorso = Instance.new("Part")
	lowerTorso.Name = "LowerTorso"
	lowerTorso.Size = Vector3.new(1.6 * S, 0.8 * S, 1.1 * S)
	lowerTorso.Color = DARK_LEATHER
	lowerTorso.Material = Enum.Material.SmoothPlastic
	lowerTorso.Anchored = false
	lowerTorso.CanCollide = false
	lowerTorso.Parent = model
	makeJoint(torso, lowerTorso, "WaistJoint", CFrame.new(0, -1.0 * S, 0))

	-- Tribal Leaf Skirt / Loincloth hanging from belt
	local leafAngles = {-45, -20, 0, 20, 45}
	for i, ang in ipairs(leafAngles) do
		local leaf = Instance.new("Part")
		leaf.Name = "LeafSkirt_" .. i
		leaf.Size = Vector3.new(0.5 * S, 0.9 * S, 0.15 * S)
		leaf.Color = (i % 2 == 0) and LEAF_COLOR or Color3.fromRGB(38, 110, 42)
		leaf.Material = Enum.Material.SmoothPlastic
		leaf.Anchored = false
		leaf.CanCollide = false
		leaf.Parent = model
		local leafMesh = Instance.new("SpecialMesh")
		leafMesh.MeshType = Enum.MeshType.Wedge
		leafMesh.Scale = Vector3.new(1, 1, 0.6)
		leafMesh.Parent = leaf

		local rad = math.rad(ang)
		local xOffset = math.sin(rad) * 0.7 * S
		weldParts(lowerTorso, leaf, CFrame.new(xOffset, -0.6 * S, -0.6 * S) * CFrame.Angles(math.rad(15), 0, math.rad(ang * 0.4)))
	end

	-- Back Leaf Skirt
	for i, ang in ipairs({-30, 0, 30}) do
		local leafBack = Instance.new("Part")
		leafBack.Name = "LeafSkirtBack_" .. i
		leafBack.Size = Vector3.new(0.55 * S, 0.85 * S, 0.15 * S)
		leafBack.Color = LEAF_COLOR
		leafBack.Material = Enum.Material.SmoothPlastic
		leafBack.Anchored = false
		leafBack.CanCollide = false
		leafBack.Parent = model
		local leafMesh = Instance.new("SpecialMesh")
		leafMesh.MeshType = Enum.MeshType.Wedge
		leafMesh.Parent = leafBack

		local rad = math.rad(ang)
		local xOffset = math.sin(rad) * 0.6 * S
		weldParts(lowerTorso, leafBack, CFrame.new(xOffset, -0.55 * S, 0.6 * S) * CFrame.Angles(math.rad(-165), math.rad(180), math.rad(ang * 0.3)))
	end

	-- ¦¦ Oversized Stylized Head ¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦
	local head = Instance.new("Part")
	head.Name = "Head"
	head.Size = Vector3.new(1.9 * S, 1.6 * S, 1.7 * S)
	head.Color = SKIN_COLOR
	head.Material = Enum.Material.SmoothPlastic
	head.Anchored = false
	head.CanCollide = false
	head.Parent = model
	makeJoint(torso, head, "NeckJoint", CFrame.new(0, 1.45 * S, -0.1 * S))

	-- Goblin Brow Ridge (Aggressive expression)
	local brow = Instance.new("Part")
	brow.Name = "BrowRidge"
	brow.Size = Vector3.new(1.7 * S, 0.35 * S, 0.5 * S)
	brow.Color = DARK_SKIN
	brow.Material = Enum.Material.SmoothPlastic
	brow.Anchored = false
	brow.CanCollide = false
	brow.Parent = model
	weldParts(head, brow, CFrame.new(0, 0.45 * S, -0.8 * S) * CFrame.Angles(math.rad(-15), 0, 0))

	-- Glowing Mischievous Eyes
	for _, side in ipairs({-1, 1}) do
		local eyeSocket = Instance.new("Part")
		eyeSocket.Name = "EyeSocket_" .. (side == -1 and "L" or "R")
		eyeSocket.Size = Vector3.new(0.42 * S, 0.32 * S, 0.2 * S)
		eyeSocket.Color = DARK_SKIN
		eyeSocket.Material = Enum.Material.SmoothPlastic
		eyeSocket.Anchored = false
		eyeSocket.CanCollide = false
		eyeSocket.Parent = model
		weldParts(head, eyeSocket, CFrame.new(side * 0.45 * S, 0.2 * S, -0.85 * S) * CFrame.Angles(0, 0, math.rad(-side * 18)))

		local eye = Instance.new("Part")
		eye.Name = "Eye_" .. (side == -1 and "L" or "R")
		eye.Size = Vector3.new(0.28 * S, 0.22 * S, 0.15 * S)
		eye.Color = EYE_GLOW
		eye.Material = Enum.Material.Neon
		eye.Anchored = false
		eye.CanCollide = false
		eye.Parent = model
		weldParts(eyeSocket, eye, CFrame.new(0, 0, -0.08 * S))

		local pupil = Instance.new("Part")
		pupil.Name = "Pupil_" .. (side == -1 and "L" or "R")
		pupil.Size = Vector3.new(0.1 * S, 0.18 * S, 0.1 * S)
		pupil.Color = Color3.fromRGB(20, 10, 10)
		pupil.Material = Enum.Material.SmoothPlastic
		pupil.Anchored = false
		pupil.CanCollide = false
		pupil.Parent = model
		weldParts(eye, pupil, CFrame.new(side * 0.04 * S, 0, -0.05 * S))
	end

	-- Goblin Large Pointed Nose
	local nose = Instance.new("Part")
	nose.Name = "GoblinNose"
	nose.Size = Vector3.new(0.45 * S, 0.55 * S, 0.65 * S)
	nose.Color = DARK_SKIN
	nose.Material = Enum.Material.SmoothPlastic
	nose.Anchored = false
	nose.CanCollide = false
	nose.Parent = model
	local noseMesh = Instance.new("SpecialMesh")
	noseMesh.MeshType = Enum.MeshType.Wedge
	noseMesh.Parent = nose
	weldParts(head, nose, CFrame.new(0, -0.05 * S, -0.95 * S) * CFrame.Angles(math.rad(15), 0, 0))

	-- Mouth & Sharp Teeth / Fangs
	local mouth = Instance.new("Part")
	mouth.Name = "Mouth"
	mouth.Size = Vector3.new(1.1 * S, 0.35 * S, 0.2 * S)
	mouth.Color = MOUTH_COLOR
	mouth.Material = Enum.Material.SmoothPlastic
	mouth.Anchored = false
	mouth.CanCollide = false
	mouth.Parent = model
	weldParts(head, mouth, CFrame.new(0, -0.45 * S, -0.82 * S))

	-- Prominent Lower Fangs (Orc/Goblin style)
	for _, side in ipairs({-1, 1}) do
		local fang = Instance.new("Part")
		fang.Name = "Fang_" .. (side == -1 and "L" or "R")
		fang.Size = Vector3.new(0.16 * S, 0.32 * S, 0.16 * S)
		fang.Color = BONE_COLOR
		fang.Material = Enum.Material.SmoothPlastic
		fang.Anchored = false
		fang.CanCollide = false
		fang.Parent = model
		local fangMesh = Instance.new("SpecialMesh")
		fangMesh.MeshType = Enum.MeshType.Wedge
		fangMesh.Parent = fang
		weldParts(mouth, fang, CFrame.new(side * 0.32 * S, 0.22 * S, -0.08 * S) * CFrame.Angles(math.rad(-15), math.rad(side * 15), 0))
	end

	-- Top Sharp Teeth
	for _, xPos in ipairs({-0.2, 0, 0.2}) do
		local tooth = Instance.new("Part")
		tooth.Name = "ToothTop"
		tooth.Size = Vector3.new(0.12 * S, 0.18 * S, 0.12 * S)
		tooth.Color = BONE_COLOR
		tooth.Material = Enum.Material.SmoothPlastic
		tooth.Anchored = false
		tooth.CanCollide = false
		tooth.Parent = model
		local toothMesh = Instance.new("SpecialMesh")
		toothMesh.MeshType = Enum.MeshType.Wedge
		toothMesh.Parent = tooth
		weldParts(mouth, tooth, CFrame.new(xPos * S, -0.1 * S, -0.06 * S) * CFrame.Angles(math.rad(180), 0, 0))
	end

	-- ¦¦ Big Pointed Goblin Ears ¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦
	for _, side in ipairs({-1, 1}) do
		local earBase = Instance.new("Part")
		earBase.Name = "EarBase_" .. (side == -1 and "L" or "R")
		earBase.Size = Vector3.new(0.4 * S, 0.6 * S, 0.4 * S)
		earBase.Color = SKIN_COLOR
		earBase.Material = Enum.Material.SmoothPlastic
		earBase.Anchored = false
		earBase.CanCollide = false
		earBase.Parent = model
		weldParts(head, earBase, CFrame.new(side * 1.05 * S, 0.2 * S, 0) * CFrame.Angles(0, 0, math.rad(-side * 25)))

		local earTip = Instance.new("Part")
		earTip.Name = "EarTip_" .. (side == -1 and "L" or "R")
		earTip.Size = Vector3.new(0.35 * S, 1.4 * S, 0.5 * S)
		earTip.Color = SKIN_COLOR
		earTip.Material = Enum.Material.SmoothPlastic
		earTip.Anchored = false
		earTip.CanCollide = false
		earTip.Parent = model
		local earMesh = Instance.new("SpecialMesh")
		earMesh.MeshType = Enum.MeshType.Wedge
		earMesh.Parent = earTip
		weldParts(earBase, earTip, CFrame.new(side * 0.55 * S, 0.4 * S, 0) * CFrame.Angles(math.rad(15), math.rad(side == -1 and 90 or -90), math.rad(-side * 40)))

		if side == -1 then
			local earring = Instance.new("Part")
			earring.Name = "TribalEarring"
			earring.Size = Vector3.new(0.2 * S, 0.2 * S, 0.08 * S)
			earring.Color = Color3.fromRGB(220, 180, 50)
			earring.Material = Enum.Material.Metal
			earring.Anchored = false
			earring.CanCollide = false
			earring.Parent = model
			local ringMesh = Instance.new("SpecialMesh")
			ringMesh.MeshType = Enum.MeshType.Sphere
			ringMesh.Scale = Vector3.new(1, 1, 0.5)
			ringMesh.Parent = earring
			weldParts(earTip, earring, CFrame.new(-0.2 * S, 0.1 * S, 0))
		end
	end

	-- ¦¦ Messy Dark Hair / Spikes ¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦
	local hairTufts = {
		{ pos = Vector3.new(0, 0.95 * S, -0.1 * S), size = Vector3.new(1.3 * S, 0.7 * S, 1.4 * S), rot = Vector3.new(-10, 0, 0) },
		{ pos = Vector3.new(0, 1.3 * S, 0.1 * S), size = Vector3.new(0.6 * S, 0.9 * S, 0.6 * S), rot = Vector3.new(-25, 0, 0) },
		{ pos = Vector3.new(-0.4 * S, 1.2 * S, 0.2 * S), size = Vector3.new(0.5 * S, 0.8 * S, 0.5 * S), rot = Vector3.new(-20, -15, -15) },
		{ pos = Vector3.new(0.4 * S, 1.2 * S, 0.2 * S), size = Vector3.new(0.5 * S, 0.8 * S, 0.5 * S), rot = Vector3.new(-20, 15, 15) },
		{ pos = Vector3.new(0, 0.8 * S, 0.85 * S), size = Vector3.new(1.1 * S, 0.9 * S, 0.5 * S), rot = Vector3.new(15, 0, 0) },
	}
	for i, h in ipairs(hairTufts) do
		local hair = Instance.new("Part")
		hair.Name = "HairTuft_" .. i
		hair.Size = h.size
		hair.Color = HAIR_COLOR
		hair.Material = Enum.Material.SmoothPlastic
		hair.Anchored = false
		hair.CanCollide = false
		hair.Parent = model
		if i > 1 then
			local hMesh = Instance.new("SpecialMesh")
			hMesh.MeshType = Enum.MeshType.Wedge
			hMesh.Parent = hair
		end
		weldParts(head, hair, CFrame.new(h.pos) * CFrame.Angles(math.rad(h.rot.X), math.rad(h.rot.Y), math.rad(h.rot.Z)))
	end

	-- ¦¦ Arms & Hands (Animated via Shoulder & Elbow Motor6Ds) ¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦
	-- Left Arm
	local leftUpperArm = Instance.new("Part")
	leftUpperArm.Name = "LeftUpperArm"
	leftUpperArm.Size = Vector3.new(0.65 * S, 1.1 * S, 0.65 * S)
	leftUpperArm.Color = SKIN_COLOR
	leftUpperArm.Material = Enum.Material.SmoothPlastic
	leftUpperArm.Anchored = false
	leftUpperArm.CanCollide = false
	leftUpperArm.Parent = model
	makeJoint(torso, leftUpperArm, "LeftShoulder", CFrame.new(-1.25 * S, 0.2 * S, 0) * CFrame.Angles(0, 0, math.rad(-15)))

	local leftBand = Instance.new("Part")
	leftBand.Name = "LeftArmBand"
	leftBand.Size = Vector3.new(0.72 * S, 0.3 * S, 0.72 * S)
	leftBand.Color = LEATHER_COLOR
	leftBand.Material = Enum.Material.Fabric
	leftBand.Anchored = false
	leftBand.CanCollide = false
	leftBand.Parent = model
	weldParts(leftUpperArm, leftBand, CFrame.new(0, 0.1 * S, 0))

	local leftLowerArm = Instance.new("Part")
	leftLowerArm.Name = "LeftLowerArm"
	leftLowerArm.Size = Vector3.new(0.6 * S, 1.0 * S, 0.6 * S)
	leftLowerArm.Color = SKIN_COLOR
	leftLowerArm.Material = Enum.Material.SmoothPlastic
	leftLowerArm.Anchored = false
	leftLowerArm.CanCollide = false
	leftLowerArm.Parent = model
	makeJoint(leftUpperArm, leftLowerArm, "LeftElbow", CFrame.new(0, -0.95 * S, 0) * CFrame.Angles(math.rad(25), 0, 0))

	local leftHand = Instance.new("Part")
	leftHand.Name = "LeftHand"
	leftHand.Size = Vector3.new(0.6 * S, 0.5 * S, 0.6 * S)
	leftHand.Color = SKIN_COLOR
	leftHand.Material = Enum.Material.SmoothPlastic
	leftHand.Anchored = false
	leftHand.CanCollide = false
	leftHand.Parent = model
	weldParts(leftLowerArm, leftHand, CFrame.new(0, -0.7 * S, 0))

	-- Right Arm (Holding Primitive Club)
	local rightUpperArm = Instance.new("Part")
	rightUpperArm.Name = "RightUpperArm"
	rightUpperArm.Size = Vector3.new(0.65 * S, 1.1 * S, 0.65 * S)
	rightUpperArm.Color = SKIN_COLOR
	rightUpperArm.Material = Enum.Material.SmoothPlastic
	rightUpperArm.Anchored = false
	rightUpperArm.CanCollide = false
	rightUpperArm.Parent = model
	makeJoint(torso, rightUpperArm, "RightShoulder", CFrame.new(1.25 * S, 0.2 * S, 0) * CFrame.Angles(0, 0, math.rad(15)))

	local rightBand = Instance.new("Part")
	rightBand.Name = "RightArmBand"
	rightBand.Size = Vector3.new(0.72 * S, 0.3 * S, 0.72 * S)
	rightBand.Color = LEAF_COLOR
	rightBand.Material = Enum.Material.SmoothPlastic
	rightBand.Anchored = false
	rightBand.CanCollide = false
	rightBand.Parent = model
	weldParts(rightUpperArm, rightBand, CFrame.new(0, 0.1 * S, 0))

	local rightLowerArm = Instance.new("Part")
	rightLowerArm.Name = "RightLowerArm"
	rightLowerArm.Size = Vector3.new(0.6 * S, 1.0 * S, 0.6 * S)
	rightLowerArm.Color = SKIN_COLOR
	rightLowerArm.Material = Enum.Material.SmoothPlastic
	rightLowerArm.Anchored = false
	rightLowerArm.CanCollide = false
	rightLowerArm.Parent = model
	makeJoint(rightUpperArm, rightLowerArm, "RightElbow", CFrame.new(0, -0.95 * S, 0) * CFrame.Angles(math.rad(40), 0, 0))

	local rightHand = Instance.new("Part")
	rightHand.Name = "RightHand"
	rightHand.Size = Vector3.new(0.6 * S, 0.5 * S, 0.6 * S)
	rightHand.Color = SKIN_COLOR
	rightHand.Material = Enum.Material.SmoothPlastic
	rightHand.Anchored = false
	rightHand.CanCollide = false
	rightHand.Parent = model
	weldParts(rightLowerArm, rightHand, CFrame.new(0, -0.7 * S, 0))

	-- ¦¦ Primitive Wooden Jungle Club ¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦
	local clubHandle = Instance.new("Part")
	clubHandle.Name = "ClubHandle"
	clubHandle.Size = Vector3.new(0.3 * S, 1.8 * S, 0.3 * S)
	clubHandle.Color = WOOD_COLOR
	clubHandle.Material = Enum.Material.Wood
	clubHandle.Anchored = false
	clubHandle.CanCollide = false
	clubHandle.Parent = model
	weldParts(rightHand, clubHandle, CFrame.new(0.1 * S, -0.2 * S, -0.3 * S) * CFrame.Angles(math.rad(-65), math.rad(15), 0))

	local clubHead = Instance.new("Part")
	clubHead.Name = "ClubHead"
	clubHead.Size = Vector3.new(0.7 * S, 1.2 * S, 0.7 * S)
	clubHead.Color = Color3.fromRGB(75, 45, 22)
	clubHead.Material = Enum.Material.Wood
	clubHead.Anchored = false
	clubHead.CanCollide = false
	clubHead.Parent = model
	local clubMesh = Instance.new("SpecialMesh")
	clubMesh.MeshType = Enum.MeshType.Head
	clubMesh.Parent = clubHead
	weldParts(clubHandle, clubHead, CFrame.new(0, 1.1 * S, 0))

	-- Stone Spike on Club
	local clubSpike = Instance.new("Part")
	clubSpike.Name = "ClubSpike"
	clubSpike.Size = Vector3.new(0.35 * S, 0.6 * S, 0.35 * S)
	clubSpike.Color = Color3.fromRGB(100, 105, 110)
	clubSpike.Material = Enum.Material.Slate
	clubSpike.Anchored = false
	clubSpike.CanCollide = false
	clubSpike.Parent = model
	local spikeMesh = Instance.new("SpecialMesh")
	spikeMesh.MeshType = Enum.MeshType.Wedge
	spikeMesh.Parent = clubSpike
	weldParts(clubHead, clubSpike, CFrame.new(0.35 * S, 0.2 * S, 0) * CFrame.Angles(0, 0, math.rad(-90)))

	-- Vine Wraps around club
	local clubVine = Instance.new("Part")
	clubVine.Name = "ClubVine"
	clubVine.Size = Vector3.new(0.4 * S, 0.35 * S, 0.4 * S)
	clubVine.Color = LEAF_COLOR
	clubVine.Material = Enum.Material.SmoothPlastic
	clubVine.Anchored = false
	clubVine.CanCollide = false
	clubVine.Parent = model
	weldParts(clubHandle, clubVine, CFrame.new(0, 0.4 * S, 0))

	-- ¦¦ Legs & Feet (Hip & Knee Motor6Ds) ¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦
	for _, side in ipairs({-1, 1}) do
		local sideName = (side == -1 and "Left" or "Right")

		local upperLeg = Instance.new("Part")
		upperLeg.Name = sideName .. "UpperLeg"
		upperLeg.Size = Vector3.new(0.7 * S, 1.2 * S, 0.7 * S)
		upperLeg.Color = SKIN_COLOR
		upperLeg.Material = Enum.Material.SmoothPlastic
		upperLeg.Anchored = false
		upperLeg.CanCollide = false
		upperLeg.Parent = model
		makeJoint(lowerTorso, upperLeg, sideName .. "Hip", CFrame.new(side * 0.5 * S, -0.9 * S, 0) * CFrame.Angles(0, 0, math.rad(-side * 4)))

		-- Shin leather wrap
		local legWrap = Instance.new("Part")
		legWrap.Name = sideName .. "LegWrap"
		legWrap.Size = Vector3.new(0.76 * S, 0.4 * S, 0.76 * S)
		legWrap.Color = DARK_LEATHER
		legWrap.Material = Enum.Material.Fabric
		legWrap.Anchored = false
		legWrap.CanCollide = false
		legWrap.Parent = model
		weldParts(upperLeg, legWrap, CFrame.new(0, -0.3 * S, 0))

		local lowerLeg = Instance.new("Part")
		lowerLeg.Name = sideName .. "LowerLeg"
		lowerLeg.Size = Vector3.new(0.65 * S, 1.1 * S, 0.65 * S)
		lowerLeg.Color = SKIN_COLOR
		lowerLeg.Material = Enum.Material.SmoothPlastic
		lowerLeg.Anchored = false
		lowerLeg.CanCollide = false
		lowerLeg.Parent = model
		makeJoint(upperLeg, lowerLeg, sideName .. "Knee", CFrame.new(0, -1.05 * S, 0))

		local foot = Instance.new("Part")
		foot.Name = sideName .. "Foot"
		foot.Size = Vector3.new(0.7 * S, 0.45 * S, 1.1 * S)
		foot.Color = SKIN_COLOR
		foot.Material = Enum.Material.SmoothPlastic
		foot.Anchored = false
		foot.CanCollide = false
		foot.Parent = model
		weldParts(lowerLeg, foot, CFrame.new(0, -0.7 * S, -0.2 * S))

		-- Claws / Toenails
		for _, clawX in ipairs({-0.2, 0, 0.2}) do
			local claw = Instance.new("Part")
			claw.Name = sideName .. "Claw"
			claw.Size = Vector3.new(0.12 * S, 0.15 * S, 0.25 * S)
			claw.Color = BONE_COLOR
			claw.Material = Enum.Material.SmoothPlastic
			claw.Anchored = false
			claw.CanCollide = false
			claw.Parent = model
			local clawMesh = Instance.new("SpecialMesh")
			clawMesh.MeshType = Enum.MeshType.Wedge
			clawMesh.Parent = claw
			weldParts(foot, claw, CFrame.new(clawX * S, -0.15 * S, -0.6 * S))
		end
	end

	-- Configure anchoring: ONLY HumanoidRootPart is anchored, all limbs are unanchored so Motor6D transforms articulate them!
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			if part.Name == "HumanoidRootPart" then
				part.Anchored = true
			else
				part.Anchored = false
			end
			part.CanCollide = false
			part.CastShadow = true
		end
	end

	-- Embed procedural walk animation script inside model by cloning template
	local templateScript = ReplicatedStorage:FindFirstChild("GoblinWalkAnimatorTemplate")
	if templateScript then
		local animScript = templateScript:Clone()
		animScript.Name = "GoblinWalkAnimator"
		animScript.Parent = model
	end

	model.Parent = BalloonModels
	print("[JungleGoblinBuilder] Successfully built and saved animated JungleGoblin model to ReplicatedStorage/BalloonModels/JungleGoblin")
	return model
end

-- Run once on startup
buildJungleGoblin()

return {
	Build = buildJungleGoblin,
}
