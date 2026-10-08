-- ============================================================
-- MonkeyWarriorBuilder
-- Constructs a stylized 3D Monkey Warrior model matching the reference:
--   • Muscular monkey humanoid with rich brown fur & peach/tan chest & muzzle
--   • Confident smirk expression, thick dark eyebrows, monkey tuft hair & round ears
--   • Wooden curved shoulder armor pads (pauldrons) with feather accents
--   • Leather cross-chest straps, rope-wrapped waist belt, tribal loincloth & green leaves
--   • Arm bands with bone & colored feather charms (orange/blue)
--   • Big two-handed tribal stone/wood blade with wrapped guard resting in right hand
--   • Long curved monkey tail
--   • Sandals / foot wraps with visible toes
--   • Fully rigged with Motor6D joints for walk & combat animation
-- ============================================================

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BalloonModels = ReplicatedStorage:WaitForChild("BalloonModels")

local function buildMonkeyWarrior()
	local existing = BalloonModels:FindFirstChild("MonkeyWarrior")
	if existing then
		existing:Destroy()
	end

	local model = Instance.new("Model")
	model.Name = "MonkeyWarrior"

	-- ¦¦ Color Palette (Matching Reference Art) ¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦
	local FUR_BROWN       = Color3.fromRGB(138, 78, 46)   -- Rich warm monkey fur
	local DARK_FUR        = Color3.fromRGB(105, 56, 32)   -- Deeper fur / hair shadow
	local TAN_SKIN        = Color3.fromRGB(224, 172, 134)  -- Peach/tan muzzle, chest, palms, toes
	local CHEST_TAN       = Color3.fromRGB(218, 162, 122)  -- Defined pectoral tan
	local WOOD_PLANK      = Color3.fromRGB(168, 114, 68)   -- Shoulder armor wooden slats
	local DARK_WOOD       = Color3.fromRGB(118, 76, 42)    -- Wood trim & sword spine
	local LEATHER_BROWN   = Color3.fromRGB(108, 62, 38)    -- Harness & gauntlets
	local ROPE_COLOR      = Color3.fromRGB(205, 185, 142)  -- Waist & wrist rope wraps
	local LEAF_GREEN      = Color3.fromRGB(122, 168, 48)   -- Bright jungle leaves on hips
	local STONE_BLADE     = Color3.fromRGB(165, 170, 175)  -- Chiseled grey stone sword edge
	local FEATHER_ORANGE  = Color3.fromRGB(235, 88, 35)    -- Tribal orange feather
	local FEATHER_BLUE    = Color3.fromRGB(45, 125, 220)   -- Tribal blue feather
	local BONE_WHITE      = Color3.fromRGB(240, 238, 225)  -- Tribal small bone charms
	local DARK_LEATHER    = Color3.fromRGB(80, 42, 24)     -- Dark leather accents
	local EYE_WHITE       = Color3.fromRGB(245, 245, 245)
	local EYE_PUPIL       = Color3.fromRGB(35, 20, 15)     -- Dark brown eyes
	local EYEBROW_DARK    = Color3.fromRGB(55, 30, 18)

	-- Scale factor: slightly taller/wider than goblin for a heroic monkey warrior build
	local S = 0.85

	-- ¦¦ HumanoidRootPart ¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2 * S, 2 * S, 1 * S)
	root.Transparency = 1
	root.CanCollide = false
	root.Anchored = true
	root.CFrame = CFrame.new(0, 3.0, 0)
	root.Parent = model
	model.PrimaryPart = root

	local humanoid = Instance.new("Humanoid")
	humanoid.Name = "Humanoid"
	humanoid.MaxHealth = 85
	humanoid.Health = 85
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

	-- ¦¦ Upper Torso (Muscular Chest & Back) ¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦
	local torso = Instance.new("Part")
	torso.Name = "UpperTorso"
	torso.Size = Vector3.new(2.2 * S, 1.8 * S, 1.4 * S)
	torso.Color = FUR_BROWN
	torso.Material = Enum.Material.SmoothPlastic
	torso.Anchored = false
	torso.CanCollide = false
	torso.Parent = model
	makeJoint(root, torso, "RootJoint", CFrame.new(0, 0.4 * S, 0))

	-- Muscular Peach/Tan Pectoral Plates (Left & Right chest muscles)
	for _, side in ipairs({ -1, 1 }) do
		local pec = Instance.new("Part")
		pec.Name = "ChestPec_" .. (side == -1 and "L" or "R")
		pec.Size = Vector3.new(0.85 * S, 0.75 * S, 0.25 * S)
		pec.Color = CHEST_TAN
		pec.Material = Enum.Material.SmoothPlastic
		pec.Anchored = false
		pec.CanCollide = false
		pec.Parent = model
		local pecMesh = Instance.new("SpecialMesh")
		pecMesh.MeshType = Enum.MeshType.Head
		pecMesh.Scale = Vector3.new(1, 0.9, 0.6)
		pecMesh.Parent = pec
		weldParts(torso, pec, CFrame.new(side * 0.45 * S, 0.25 * S, -0.65 * S) * CFrame.Angles(0, 0, math.rad(-side * 8)))

		-- Ab muscle block
		local ab = Instance.new("Part")
		ab.Name = "ChestAb_" .. (side == -1 and "L" or "R")
		ab.Size = Vector3.new(0.65 * S, 0.5 * S, 0.2 * S)
		ab.Color = CHEST_TAN
		ab.Material = Enum.Material.SmoothPlastic
		ab.Anchored = false
		ab.CanCollide = false
		ab.Parent = model
		local abMesh = Instance.new("SpecialMesh")
		abMesh.MeshType = Enum.MeshType.Head
		abMesh.Scale = Vector3.new(1, 0.8, 0.5)
		abMesh.Parent = ab
		weldParts(torso, ab, CFrame.new(side * 0.35 * S, -0.35 * S, -0.62 * S))
	end

	-- Leather Harness Straps crossing the chest (X pattern from reference)
	local strap1 = Instance.new("Part")
	strap1.Name = "HarnessStrap1"
	strap1.Size = Vector3.new(0.32 * S, 2.3 * S, 1.46 * S)
	strap1.Color = LEATHER_BROWN
	strap1.Material = Enum.Material.Fabric
	strap1.Anchored = false
	strap1.CanCollide = false
	strap1.Parent = model
	weldParts(torso, strap1, CFrame.Angles(0, 0, math.rad(42)))

	local strap2 = Instance.new("Part")
	strap2.Name = "HarnessStrap2"
	strap2.Size = Vector3.new(0.32 * S, 2.3 * S, 1.46 * S)
	strap2.Color = LEATHER_BROWN
	strap2.Material = Enum.Material.Fabric
	strap2.Anchored = false
	strap2.CanCollide = false
	strap2.Parent = model
	weldParts(torso, strap2, CFrame.Angles(0, 0, math.rad(-42)))

	-- Leaf badge near collar strap
	local collarLeaf = Instance.new("Part")
	collarLeaf.Name = "CollarLeaf"
	collarLeaf.Size = Vector3.new(0.4 * S, 0.6 * S, 0.15 * S)
	collarLeaf.Color = LEAF_GREEN
	collarLeaf.Material = Enum.Material.SmoothPlastic
	collarLeaf.Anchored = false
	collarLeaf.CanCollide = false
	collarLeaf.Parent = model
	local clMesh = Instance.new("SpecialMesh")
	clMesh.MeshType = Enum.MeshType.Wedge
	clMesh.Parent = collarLeaf
	weldParts(torso, collarLeaf, CFrame.new(-0.6 * S, 0.65 * S, -0.7 * S) * CFrame.Angles(math.rad(25), 0, math.rad(30)))

	-- ¦¦ Lower Torso & Belt System ¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦
	local lowerTorso = Instance.new("Part")
	lowerTorso.Name = "LowerTorso"
	lowerTorso.Size = Vector3.new(1.8 * S, 0.9 * S, 1.25 * S)
	lowerTorso.Color = FUR_BROWN
	lowerTorso.Material = Enum.Material.SmoothPlastic
	lowerTorso.Anchored = false
	lowerTorso.CanCollide = false
	lowerTorso.Parent = model
	makeJoint(torso, lowerTorso, "WaistJoint", CFrame.new(0, -1.15 * S, 0))

	-- Thick Leather Belt
	local belt = Instance.new("Part")
	belt.Name = "LeatherBelt"
	belt.Size = Vector3.new(1.95 * S, 0.5 * S, 1.35 * S)
	belt.Color = LEATHER_BROWN
	belt.Material = Enum.Material.Fabric
	belt.Anchored = false
	belt.CanCollide = false
	belt.Parent = model
	weldParts(lowerTorso, belt, CFrame.new(0, 0.2 * S, 0))

	-- Rope Belt Tied Over Leather Belt
	local ropeBelt = Instance.new("Part")
	ropeBelt.Name = "RopeBelt"
	ropeBelt.Size = Vector3.new(2.05 * S, 0.22 * S, 1.45 * S)
	ropeBelt.Color = ROPE_COLOR
	ropeBelt.Material = Enum.Material.SmoothPlastic
	ropeBelt.Anchored = false
	ropeBelt.CanCollide = false
	ropeBelt.Parent = model
	weldParts(lowerTorso, ropeBelt, CFrame.new(0, 0.15 * S, 0))

	-- Hanging Rope Knot on Right Hip with Hanging Feathers & Bone Charm
	local knot = Instance.new("Part")
	knot.Name = "RopeKnot"
	knot.Size = Vector3.new(0.3 * S, 0.3 * S, 0.3 * S)
	knot.Color = ROPE_COLOR
	knot.Material = Enum.Material.SmoothPlastic
	knot.Anchored = false
	knot.CanCollide = false
	knot.Parent = model
	local knotMesh = Instance.new("SpecialMesh")
	knotMesh.MeshType = Enum.MeshType.Sphere
	knotMesh.Parent = knot
	weldParts(belt, knot, CFrame.new(0.6 * S, -0.15 * S, -0.7 * S))

	-- Hanging Feathers on Belt (Orange & Blue like reference)
	local beltFeather1 = Instance.new("Part")
	beltFeather1.Name = "BeltFeather_Orange"
	beltFeather1.Size = Vector3.new(0.25 * S, 0.65 * S, 0.08 * S)
	beltFeather1.Color = FEATHER_ORANGE
	beltFeather1.Material = Enum.Material.SmoothPlastic
	beltFeather1.Anchored = false
	beltFeather1.CanCollide = false
	beltFeather1.Parent = model
	local bf1Mesh = Instance.new("SpecialMesh")
	bf1Mesh.MeshType = Enum.MeshType.Wedge
	bf1Mesh.Parent = beltFeather1
	weldParts(knot, beltFeather1, CFrame.new(-0.05 * S, -0.4 * S, 0) * CFrame.Angles(math.rad(180), 0, math.rad(-10)))

	local beltFeather2 = Instance.new("Part")
	beltFeather2.Name = "BeltFeather_Blue"
	beltFeather2.Size = Vector3.new(0.25 * S, 0.65 * S, 0.08 * S)
	beltFeather2.Color = FEATHER_BLUE
	beltFeather2.Material = Enum.Material.SmoothPlastic
	beltFeather2.Anchored = false
	beltFeather2.CanCollide = false
	beltFeather2.Parent = model
	local bf2Mesh = Instance.new("SpecialMesh")
	bf2Mesh.MeshType = Enum.MeshType.Wedge
	bf2Mesh.Parent = beltFeather2
	weldParts(knot, beltFeather2, CFrame.new(0.12 * S, -0.38 * S, 0) * CFrame.Angles(math.rad(180), 0, math.rad(12)))

	-- Hanging Bone Bead on Belt Knot
	local beltBone = Instance.new("Part")
	beltBone.Name = "BeltBone"
	beltBone.Size = Vector3.new(0.16 * S, 0.3 * S, 0.16 * S)
	beltBone.Color = BONE_WHITE
	beltBone.Material = Enum.Material.SmoothPlastic
	beltBone.Anchored = false
	beltBone.CanCollide = false
	beltBone.Parent = model
	local bbMesh = Instance.new("SpecialMesh")
	bbMesh.MeshType = Enum.MeshType.Sphere
	bbMesh.Scale = Vector3.new(0.8, 1.2, 0.8)
	bbMesh.Parent = beltBone
	weldParts(knot, beltBone, CFrame.new(0.04 * S, -0.2 * S, -0.08 * S))

	-- Center Jagged Leather Loincloth / Apron
	local loincloth = Instance.new("Part")
	loincloth.Name = "CenterLoincloth"
	loincloth.Size = Vector3.new(0.9 * S, 1.3 * S, 0.15 * S)
	loincloth.Color = LEATHER_BROWN
	loincloth.Material = Enum.Material.Fabric
	loincloth.Anchored = false
	loincloth.CanCollide = false
	loincloth.Parent = model
	local lcMesh = Instance.new("SpecialMesh")
	lcMesh.MeshType = Enum.MeshType.Wedge
	lcMesh.Scale = Vector3.new(1, 1, 0.8)
	lcMesh.Parent = loincloth
	weldParts(lowerTorso, loincloth, CFrame.new(0, -0.6 * S, -0.65 * S) * CFrame.Angles(math.rad(12), 0, 0))

	-- Side Jungle Leaves on Hips (Bright green fan leaves)
	for _, side in ipairs({ -1, 1 }) do
		for idx, ang in ipairs({ -25, 0, 25 }) do
			local hipLeaf = Instance.new("Part")
			hipLeaf.Name = "HipLeaf_" .. (side == -1 and "L" or "R") .. "_" .. idx
			hipLeaf.Size = Vector3.new(0.55 * S, 0.95 * S, 0.12 * S)
			hipLeaf.Color = LEAF_GREEN
			hipLeaf.Material = Enum.Material.SmoothPlastic
			hipLeaf.Anchored = false
			hipLeaf.CanCollide = false
			hipLeaf.Parent = model
			local hlMesh = Instance.new("SpecialMesh")
			hlMesh.MeshType = Enum.MeshType.Wedge
			hlMesh.Parent = hipLeaf
			weldParts(lowerTorso, hipLeaf, CFrame.new(side * (0.85 + (idx - 2) * 0.1) * S, -0.55 * S, (idx - 2) * 0.2 * S) * CFrame.Angles(math.rad(15), math.rad(side * (75 + ang)), math.rad(-side * 20)))
		end
	end

	-- ¦¦ Articulated Monkey Tail ¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦
	local tailBase = Instance.new("Part")
	tailBase.Name = "TailBase"
	tailBase.Size = Vector3.new(0.35 * S, 0.35 * S, 0.8 * S)
	tailBase.Color = FUR_BROWN
	tailBase.Material = Enum.Material.SmoothPlastic
	tailBase.Anchored = false
	tailBase.CanCollide = false
	tailBase.Parent = model
	makeJoint(lowerTorso, tailBase, "TailJoint", CFrame.new(0, -0.1 * S, 0.65 * S) * CFrame.Angles(math.rad(-25), 0, 0))

	local tailCurve1 = Instance.new("Part")
	tailCurve1.Name = "TailSegment1"
	tailCurve1.Size = Vector3.new(0.32 * S, 0.32 * S, 1.0 * S)
	tailCurve1.Color = FUR_BROWN
	tailCurve1.Material = Enum.Material.SmoothPlastic
	tailCurve1.Anchored = false
	tailCurve1.CanCollide = false
	tailCurve1.Parent = model
	weldParts(tailBase, tailCurve1, CFrame.new(0.2 * S, 0.1 * S, 0.75 * S) * CFrame.Angles(math.rad(30), math.rad(25), 0))

	local tailTip = Instance.new("Part")
	tailTip.Name = "TailTipCurl"
	tailTip.Size = Vector3.new(0.35 * S, 0.35 * S, 0.9 * S)
	tailTip.Color = FUR_BROWN
	tailTip.Material = Enum.Material.SmoothPlastic
	tailTip.Anchored = false
	tailTip.CanCollide = false
	tailTip.Parent = model
	local ttMesh = Instance.new("SpecialMesh")
	ttMesh.MeshType = Enum.MeshType.Sphere
	ttMesh.Scale = Vector3.new(1, 1.4, 2)
	ttMesh.Parent = tailTip
	weldParts(tailCurve1, tailTip, CFrame.new(0.4 * S, 0.45 * S, 0.65 * S) * CFrame.Angles(math.rad(85), math.rad(45), 0))

	-- ¦¦ Expressive Monkey Head ¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦
	local head = Instance.new("Part")
	head.Name = "Head"
	head.Size = Vector3.new(1.8 * S, 1.7 * S, 1.7 * S)
	head.Color = FUR_BROWN
	head.Material = Enum.Material.SmoothPlastic
	head.Anchored = false
	head.CanCollide = false
	head.Parent = model
	makeJoint(torso, head, "NeckJoint", CFrame.new(0, 1.45 * S, 0))

	-- Peach/Tan Monkey Muzzle & Face Plate
	local muzzle = Instance.new("Part")
	muzzle.Name = "MuzzleFace"
	muzzle.Size = Vector3.new(1.3 * S, 1.0 * S, 0.65 * S)
	muzzle.Color = TAN_SKIN
	muzzle.Material = Enum.Material.SmoothPlastic
	muzzle.Anchored = false
	muzzle.CanCollide = false
	muzzle.Parent = model
	local muzzleMesh = Instance.new("SpecialMesh")
	muzzleMesh.MeshType = Enum.MeshType.Head
	muzzleMesh.Scale = Vector3.new(1.05, 0.95, 0.9)
	muzzleMesh.Parent = muzzle
	weldParts(head, muzzle, CFrame.new(0, -0.2 * S, -0.7 * S))

	-- Small dark nose nostrils
	local nose = Instance.new("Part")
	nose.Name = "MonkeyNose"
	nose.Size = Vector3.new(0.35 * S, 0.22 * S, 0.2 * S)
	nose.Color = DARK_FUR
	nose.Material = Enum.Material.SmoothPlastic
	nose.Anchored = false
	nose.CanCollide = false
	nose.Parent = model
	local nm = Instance.new("SpecialMesh")
	nm.MeshType = Enum.MeshType.Head
	nm.Scale = Vector3.new(1, 0.6, 0.8)
	nm.Parent = nose
	weldParts(muzzle, nose, CFrame.new(0, 0.12 * S, -0.3 * S))

	-- Confident Smirking Mouth (Curved upward on right side)
	local mouth = Instance.new("Part")
	mouth.Name = "SmirkMouth"
	mouth.Size = Vector3.new(0.7 * S, 0.12 * S, 0.15 * S)
	mouth.Color = Color3.fromRGB(60, 25, 20)
	mouth.Material = Enum.Material.SmoothPlastic
	mouth.Anchored = false
	mouth.CanCollide = false
	mouth.Parent = model
	weldParts(muzzle, mouth, CFrame.new(0.08 * S, -0.22 * S, -0.28 * S) * CFrame.Angles(0, 0, math.rad(12)))

	-- Monkey Brow Ridge & Confident Heavy Eyebrows
	local browRidge = Instance.new("Part")
	browRidge.Name = "BrowRidge"
	browRidge.Size = Vector3.new(1.5 * S, 0.35 * S, 0.45 * S)
	browRidge.Color = FUR_BROWN
	browRidge.Material = Enum.Material.SmoothPlastic
	browRidge.Anchored = false
	browRidge.CanCollide = false
	browRidge.Parent = model
	weldParts(head, browRidge, CFrame.new(0, 0.4 * S, -0.75 * S) * CFrame.Angles(math.rad(-10), 0, 0))

	for _, side in ipairs({ -1, 1 }) do
		local eyebrow = Instance.new("Part")
		eyebrow.Name = "Eyebrow_" .. (side == -1 and "L" or "R")
		eyebrow.Size = Vector3.new(0.55 * S, 0.18 * S, 0.15 * S)
		eyebrow.Color = EYEBROW_DARK
		eyebrow.Material = Enum.Material.SmoothPlastic
		eyebrow.Anchored = false
		eyebrow.CanCollide = false
		eyebrow.Parent = model
		-- Confident raised eyebrow on right, focused on left
		local browRot = (side == -1 and -16 or 24)
		weldParts(browRidge, eyebrow, CFrame.new(side * 0.4 * S, 0.05 * S, -0.2 * S) * CFrame.Angles(0, 0, math.rad(browRot)))

		-- Big Stylized Cartoon Eyes
		local eyeWhite = Instance.new("Part")
		eyeWhite.Name = "EyeWhite_" .. (side == -1 and "L" or "R")
		eyeWhite.Size = Vector3.new(0.38 * S, 0.35 * S, 0.15 * S)
		eyeWhite.Color = EYE_WHITE
		eyeWhite.Material = Enum.Material.SmoothPlastic
		eyeWhite.Anchored = false
		eyeWhite.CanCollide = false
		eyeWhite.Parent = model
		local ewMesh = Instance.new("SpecialMesh")
		ewMesh.MeshType = Enum.MeshType.Sphere
		ewMesh.Scale = Vector3.new(1, 1.2, 0.5)
		ewMesh.Parent = eyeWhite
		weldParts(head, eyeWhite, CFrame.new(side * 0.4 * S, 0.15 * S, -0.85 * S))

		local pupil = Instance.new("Part")
		pupil.Name = "Pupil_" .. (side == -1 and "L" or "R")
		pupil.Size = Vector3.new(0.2 * S, 0.24 * S, 0.1 * S)
		pupil.Color = EYE_PUPIL
		pupil.Material = Enum.Material.SmoothPlastic
		pupil.Anchored = false
		pupil.CanCollide = false
		pupil.Parent = model
		local pMesh = Instance.new("SpecialMesh")
		pMesh.MeshType = Enum.MeshType.Sphere
		pMesh.Parent = pupil
		weldParts(eyeWhite, pupil, CFrame.new(side * 0.04 * S, -0.02 * S, -0.06 * S))
	end

	-- Large Round Monkey Ears (Inner peach, outer fur)
	for _, side in ipairs({ -1, 1 }) do
		local earOuter = Instance.new("Part")
		earOuter.Name = "EarOuter_" .. (side == -1 and "L" or "R")
		earOuter.Size = Vector3.new(0.25 * S, 0.75 * S, 0.75 * S)
		earOuter.Color = FUR_BROWN
		earOuter.Material = Enum.Material.SmoothPlastic
		earOuter.Anchored = false
		earOuter.CanCollide = false
		earOuter.Parent = model
		local eoMesh = Instance.new("SpecialMesh")
		eoMesh.MeshType = Enum.MeshType.Sphere
		eoMesh.Scale = Vector3.new(0.6, 1.1, 1.1)
		eoMesh.Parent = earOuter
		weldParts(head, earOuter, CFrame.new(side * 1.05 * S, 0.2 * S, 0.05 * S) * CFrame.Angles(0, math.rad(side * 15), 0))

		local earInner = Instance.new("Part")
		earInner.Name = "EarInner_" .. (side == -1 and "L" or "R")
		earInner.Size = Vector3.new(0.18 * S, 0.52 * S, 0.52 * S)
		earInner.Color = TAN_SKIN
		earInner.Material = Enum.Material.SmoothPlastic
		earInner.Anchored = false
		earInner.CanCollide = false
		earInner.Parent = model
		local eiMesh = Instance.new("SpecialMesh")
		eiMesh.MeshType = Enum.MeshType.Sphere
		eiMesh.Scale = Vector3.new(0.5, 1, 1)
		eiMesh.Parent = earInner
		weldParts(earOuter, earInner, CFrame.new(side * 0.05 * S, 0, -0.08 * S))
	end

	-- Monkey Head Hair Tuft / Crest (Characteristic triangular top tuft)
	local hairTufts = {
		{ pos = Vector3.new(0, 1.15 * S, -0.15 * S),  size = Vector3.new(0.6 * S, 0.85 * S, 0.7 * S),  rot = Vector3.new(-20, 0, 0) },
		{ pos = Vector3.new(0, 0.95 * S, 0.5 * S),    size = Vector3.new(1.1 * S, 0.9 * S, 0.8 * S),   rot = Vector3.new(15, 0, 0) },
		{ pos = Vector3.new(-0.4 * S, 0.8 * S, 0.4 * S), size = Vector3.new(0.6 * S, 0.7 * S, 0.6 * S), rot = Vector3.new(10, -20, -15) },
		{ pos = Vector3.new(0.4 * S, 0.8 * S, 0.4 * S),  size = Vector3.new(0.6 * S, 0.7 * S, 0.6 * S), rot = Vector3.new(10, 20, 15) },
	}
	for i, h in ipairs(hairTufts) do
		local hair = Instance.new("Part")
		hair.Name = "HairTuft_" .. i
		hair.Size = h.size
		hair.Color = DARK_FUR
		hair.Material = Enum.Material.SmoothPlastic
		hair.Anchored = false
		hair.CanCollide = false
		hair.Parent = model
		local hMesh = Instance.new("SpecialMesh")
		hMesh.MeshType = Enum.MeshType.Wedge
		hMesh.Parent = hair
		weldParts(head, hair, CFrame.new(h.pos) * CFrame.Angles(math.rad(h.rot.X), math.rad(h.rot.Y), math.rad(h.rot.Z)))
	end

	-- ¦¦ Curved Wooden Shoulder Pauldrons (Left & Right) ¦¦¦¦¦¦¦¦
	for _, side in ipairs({ -1, 1 }) do
		local padBase = Instance.new("Part")
		padBase.Name = "ShoulderPadBase_" .. (side == -1 and "L" or "R")
		padBase.Size = Vector3.new(1.3 * S, 0.45 * S, 1.1 * S)
		padBase.Color = DARK_WOOD
		padBase.Material = Enum.Material.Wood
		padBase.Anchored = false
		padBase.CanCollide = false
		padBase.Parent = model
		weldParts(torso, padBase, CFrame.new(side * 1.55 * S, 0.85 * S, 0) * CFrame.Angles(0, 0, math.rad(-side * 28)))

		-- Wooden planks layered on top of pauldron
		for plankIdx = -1, 1 do
			local plank = Instance.new("Part")
			plank.Name = "ShoulderPlank_" .. (side == -1 and "L" or "R") .. "_" .. (plankIdx + 2)
			plank.Size = Vector3.new(1.2 * S, 0.22 * S, 0.32 * S)
			plank.Color = WOOD_PLANK
			plank.Material = Enum.Material.WoodPlanks
			plank.Anchored = false
			plank.CanCollide = false
			plank.Parent = model
			weldParts(padBase, plank, CFrame.new(0, 0.22 * S, plankIdx * 0.34 * S) * CFrame.Angles(math.rad(plankIdx * 8), 0, 0))
		end

		-- Tribal Feathers behind Left Pauldron (as in reference)
		if side == -1 then
			for fIdx, fAng in ipairs({ -20, 0, 20 }) do
				local sFeather = Instance.new("Part")
				sFeather.Name = "ShoulderFeather_" .. fIdx
				sFeather.Size = Vector3.new(0.35 * S, 0.9 * S, 0.08 * S)
				sFeather.Color = (fIdx == 2 and FEATHER_ORANGE or WOOD_PLANK)
				sFeather.Material = Enum.Material.SmoothPlastic
				sFeather.Anchored = false
				sFeather.CanCollide = false
				sFeather.Parent = model
				local sfMesh = Instance.new("SpecialMesh")
				sfMesh.MeshType = Enum.MeshType.Wedge
				sfMesh.Parent = sFeather
				weldParts(padBase, sFeather, CFrame.new(-0.2 * S, 0.35 * S, 0.65 * S + (fIdx - 2) * 0.25 * S) * CFrame.Angles(math.rad(40 + fAng), math.rad(-15), math.rad(fAng * 0.5)))
			end
		end
	end

	-- ¦¦ Left Arm (Free Swing, Leather Bracer, Bone & Feathers) ¦¦
	local leftUpperArm = Instance.new("Part")
	leftUpperArm.Name = "LeftUpperArm"
	leftUpperArm.Size = Vector3.new(0.85 * S, 1.35 * S, 0.85 * S)
	leftUpperArm.Color = FUR_BROWN
	leftUpperArm.Material = Enum.Material.SmoothPlastic
	leftUpperArm.Anchored = false
	leftUpperArm.CanCollide = false
	leftUpperArm.Parent = model
	makeJoint(torso, leftUpperArm, "LeftShoulder", CFrame.new(-1.6 * S, 0.35 * S, 0) * CFrame.Angles(0, 0, math.rad(-10)))

	-- Bicep Rope Band with Bone & Feather charms (Key feature in reference art)
	local leftBicepWrap = Instance.new("Part")
	leftBicepWrap.Name = "LeftBicepWrap"
	leftBicepWrap.Size = Vector3.new(0.95 * S, 0.25 * S, 0.95 * S)
	leftBicepWrap.Color = ROPE_COLOR
	leftBicepWrap.Material = Enum.Material.SmoothPlastic
	leftBicepWrap.Anchored = false
	leftBicepWrap.CanCollide = false
	leftBicepWrap.Parent = model
	weldParts(leftUpperArm, leftBicepWrap, CFrame.new(0, 0.15 * S, 0))

	-- Hanging small bone on bicep band
	local armBone = Instance.new("Part")
	armBone.Name = "ArmBoneCharm"
	armBone.Size = Vector3.new(0.18 * S, 0.45 * S, 0.18 * S)
	armBone.Color = BONE_WHITE
	armBone.Material = Enum.Material.SmoothPlastic
	armBone.Anchored = false
	armBone.CanCollide = false
	armBone.Parent = model
	local abMesh = Instance.new("SpecialMesh")
	abMesh.MeshType = Enum.MeshType.Head
	abMesh.Scale = Vector3.new(0.7, 1.2, 0.7)
	abMesh.Parent = armBone
	weldParts(leftBicepWrap, armBone, CFrame.new(-0.48 * S, -0.2 * S, 0) * CFrame.Angles(0, 0, math.rad(90)))

	-- Orange & Blue hanging feathers from arm band
	local armFeather1 = Instance.new("Part")
	armFeather1.Name = "ArmFeather_Orange"
	armFeather1.Size = Vector3.new(0.22 * S, 0.55 * S, 0.08 * S)
	armFeather1.Color = FEATHER_ORANGE
	armFeather1.Material = Enum.Material.SmoothPlastic
	armFeather1.Anchored = false
	armFeather1.CanCollide = false
	armFeather1.Parent = model
	local af1Mesh = Instance.new("SpecialMesh")
	af1Mesh.MeshType = Enum.MeshType.Wedge
	af1Mesh.Parent = armFeather1
	weldParts(leftBicepWrap, armFeather1, CFrame.new(-0.5 * S, -0.35 * S, -0.12 * S) * CFrame.Angles(math.rad(180), 0, math.rad(15)))

	local armFeather2 = Instance.new("Part")
	armFeather2.Name = "ArmFeather_Blue"
	armFeather2.Size = Vector3.new(0.22 * S, 0.55 * S, 0.08 * S)
	armFeather2.Color = FEATHER_BLUE
	armFeather2.Material = Enum.Material.SmoothPlastic
	armFeather2.Anchored = false
	armFeather2.CanCollide = false
	armFeather2.Parent = model
	local af2Mesh = Instance.new("SpecialMesh")
	af2Mesh.MeshType = Enum.MeshType.Wedge
	af2Mesh.Parent = armFeather2
	weldParts(leftBicepWrap, armFeather2, CFrame.new(-0.5 * S, -0.35 * S, 0.12 * S) * CFrame.Angles(math.rad(180), 0, math.rad(-15)))

	-- Left Lower Arm with Thick Leather Gauntlet
	local leftLowerArm = Instance.new("Part")
	leftLowerArm.Name = "LeftLowerArm"
	leftLowerArm.Size = Vector3.new(0.8 * S, 1.25 * S, 0.8 * S)
	leftLowerArm.Color = FUR_BROWN
	leftLowerArm.Material = Enum.Material.SmoothPlastic
	leftLowerArm.Anchored = false
	leftLowerArm.CanCollide = false
	leftLowerArm.Parent = model
	makeJoint(leftUpperArm, leftLowerArm, "LeftElbow", CFrame.new(0, -1.2 * S, 0) * CFrame.Angles(math.rad(20), 0, 0))

	local leftGauntlet = Instance.new("Part")
	leftGauntlet.Name = "LeftGauntlet"
	leftGauntlet.Size = Vector3.new(0.95 * S, 0.75 * S, 0.95 * S)
	leftGauntlet.Color = LEATHER_BROWN
	leftGauntlet.Material = Enum.Material.Fabric
	leftGauntlet.Anchored = false
	leftGauntlet.CanCollide = false
	leftGauntlet.Parent = model
	weldParts(leftLowerArm, leftGauntlet, CFrame.new(0, -0.2 * S, 0))

	-- Left Hand (Fisted monkey hand with peach palm)
	local leftHand = Instance.new("Part")
	leftHand.Name = "LeftHand"
	leftHand.Size = Vector3.new(0.75 * S, 0.65 * S, 0.75 * S)
	leftHand.Color = FUR_BROWN
	leftHand.Material = Enum.Material.SmoothPlastic
	leftHand.Anchored = false
	leftHand.CanCollide = false
	leftHand.Parent = model
	local lhMesh = Instance.new("SpecialMesh")
	lhMesh.MeshType = Enum.MeshType.Sphere
	lhMesh.Parent = leftHand
	weldParts(leftLowerArm, leftHand, CFrame.new(0, -0.85 * S, 0))

	local leftPalm = Instance.new("Part")
	leftPalm.Name = "LeftPalmTan"
	leftPalm.Size = Vector3.new(0.55 * S, 0.45 * S, 0.25 * S)
	leftPalm.Color = TAN_SKIN
	leftPalm.Material = Enum.Material.SmoothPlastic
	leftPalm.Anchored = false
	leftPalm.CanCollide = false
	leftPalm.Parent = model
	weldParts(leftHand, leftPalm, CFrame.new(0, -0.05 * S, -0.3 * S))

	-- ¦¦ Right Arm & Giant Tribal Wood-Stone Blade ¦¦¦¦¦¦¦¦¦¦¦¦¦¦
	local rightUpperArm = Instance.new("Part")
	rightUpperArm.Name = "RightUpperArm"
	rightUpperArm.Size = Vector3.new(0.85 * S, 1.35 * S, 0.85 * S)
	rightUpperArm.Color = FUR_BROWN
	rightUpperArm.Material = Enum.Material.SmoothPlastic
	rightUpperArm.Anchored = false
	rightUpperArm.CanCollide = false
	rightUpperArm.Parent = model
	makeJoint(torso, rightUpperArm, "RightShoulder", CFrame.new(1.6 * S, 0.35 * S, 0) * CFrame.Angles(0, 0, math.rad(10)))

	-- Right Bicep Wrap (Orange accent)
	local rightBicepWrap = Instance.new("Part")
	rightBicepWrap.Name = "RightBicepWrap"
	rightBicepWrap.Size = Vector3.new(0.95 * S, 0.25 * S, 0.95 * S)
	rightBicepWrap.Color = FEATHER_ORANGE
	rightBicepWrap.Material = Enum.Material.Fabric
	rightBicepWrap.Anchored = false
	rightBicepWrap.CanCollide = false
	rightBicepWrap.Parent = model
	weldParts(rightUpperArm, rightBicepWrap, CFrame.new(0, 0.15 * S, 0))

	local rightLowerArm = Instance.new("Part")
	rightLowerArm.Name = "RightLowerArm"
	rightLowerArm.Size = Vector3.new(0.8 * S, 1.25 * S, 0.8 * S)
	rightLowerArm.Color = FUR_BROWN
	rightLowerArm.Material = Enum.Material.SmoothPlastic
	rightLowerArm.Anchored = false
	rightLowerArm.CanCollide = false
	rightLowerArm.Parent = model
	makeJoint(rightUpperArm, rightLowerArm, "RightElbow", CFrame.new(0, -1.2 * S, 0) * CFrame.Angles(math.rad(35), 0, 0))

	-- Leather & Rope Wrist Wraps
	local rightGauntlet = Instance.new("Part")
	rightGauntlet.Name = "RightGauntlet"
	rightGauntlet.Size = Vector3.new(0.95 * S, 0.7 * S, 0.95 * S)
	rightGauntlet.Color = LEATHER_BROWN
	rightGauntlet.Material = Enum.Material.Fabric
	rightGauntlet.Anchored = false
	rightGauntlet.CanCollide = false
	rightGauntlet.Parent = model
	weldParts(rightLowerArm, rightGauntlet, CFrame.new(0, -0.2 * S, 0))

	local rightWristRope = Instance.new("Part")
	rightWristRope.Name = "RightWristRope"
	rightWristRope.Size = Vector3.new(1.0 * S, 0.22 * S, 1.0 * S)
	rightWristRope.Color = ROPE_COLOR
	rightWristRope.Material = Enum.Material.SmoothPlastic
	rightWristRope.Anchored = false
	rightWristRope.CanCollide = false
	rightWristRope.Parent = model
	weldParts(rightLowerArm, rightWristRope, CFrame.new(0, -0.5 * S, 0))

	-- Right Hand (Grasping Sword Hilt)
	local rightHand = Instance.new("Part")
	rightHand.Name = "RightHand"
	rightHand.Size = Vector3.new(0.75 * S, 0.65 * S, 0.75 * S)
	rightHand.Color = FUR_BROWN
	rightHand.Material = Enum.Material.SmoothPlastic
	rightHand.Anchored = false
	rightHand.CanCollide = false
	rightHand.Parent = model
	local rhMesh = Instance.new("SpecialMesh")
	rhMesh.MeshType = Enum.MeshType.Sphere
	rhMesh.Parent = rightHand
	weldParts(rightLowerArm, rightHand, CFrame.new(0, -0.85 * S, 0))

	-- ¦¦ Huge Stylized Wood & Stone Broadsword (Reference weapon) ¦¦
	local swordHandle = Instance.new("Part")
	swordHandle.Name = "SwordHandle"
	swordHandle.Size = Vector3.new(0.3 * S, 1.6 * S, 0.3 * S)
	swordHandle.Color = ROPE_COLOR
	swordHandle.Material = Enum.Material.SmoothPlastic
	swordHandle.Anchored = false
	swordHandle.CanCollide = false
	swordHandle.Parent = model
	-- Held upright/slightly tilted resting forward
	weldParts(rightHand, swordHandle, CFrame.new(0.15 * S, -0.2 * S, -0.35 * S) * CFrame.Angles(math.rad(-75), math.rad(10), 0))

	-- Sword Pommel
	local pommel = Instance.new("Part")
	pommel.Name = "SwordPommel"
	pommel.Size = Vector3.new(0.55 * S, 0.45 * S, 0.55 * S)
	pommel.Color = DARK_WOOD
	pommel.Material = Enum.Material.Wood
	pommel.Anchored = false
	pommel.CanCollide = false
	pommel.Parent = model
	local pmMesh = Instance.new("SpecialMesh")
	pmMesh.MeshType = Enum.MeshType.Head
	pmMesh.Parent = pommel
	weldParts(swordHandle, pommel, CFrame.new(0, -0.9 * S, 0))

	-- Wooden Crossguard with Rope Ties
	local crossguard = Instance.new("Part")
	crossguard.Name = "SwordCrossguard"
	crossguard.Size = Vector3.new(1.5 * S, 0.45 * S, 0.65 * S)
	crossguard.Color = DARK_WOOD
	crossguard.Material = Enum.Material.Wood
	crossguard.Anchored = false
	crossguard.CanCollide = false
	crossguard.Parent = model
	weldParts(swordHandle, crossguard, CFrame.new(0, 0.9 * S, 0))

	local guardRope = Instance.new("Part")
	guardRope.Name = "GuardRopeWrap"
	guardRope.Size = Vector3.new(0.7 * S, 0.5 * S, 0.7 * S)
	guardRope.Color = ROPE_COLOR
	guardRope.Material = Enum.Material.SmoothPlastic
	guardRope.Anchored = false
	guardRope.CanCollide = false
	guardRope.Parent = model
	weldParts(crossguard, guardRope, CFrame.new(0, 0, 0))

	-- Wooden Core/Spine of the Blade
	local bladeCore = Instance.new("Part")
	bladeCore.Name = "BladeWoodCore"
	bladeCore.Size = Vector3.new(0.75 * S, 3.2 * S, 0.35 * S)
	bladeCore.Color = WOOD_PLANK
	bladeCore.Material = Enum.Material.Wood
	bladeCore.Anchored = false
	bladeCore.CanCollide = false
	bladeCore.Parent = model
	weldParts(crossguard, bladeCore, CFrame.new(0, 1.8 * S, 0))

	-- Chiseled Stone Edges (Left & Right cutting bevels)
	for _, edgeSide in ipairs({ -1, 1 }) do
		local stoneEdge = Instance.new("Part")
		stoneEdge.Name = "StoneEdge_" .. (edgeSide == -1 and "L" or "R")
		stoneEdge.Size = Vector3.new(0.35 * S, 3.1 * S, 0.4 * S)
		stoneEdge.Color = STONE_BLADE
		stoneEdge.Material = Enum.Material.Slate
		stoneEdge.Anchored = false
		stoneEdge.CanCollide = false
		stoneEdge.Parent = model
		local seMesh = Instance.new("SpecialMesh")
		seMesh.MeshType = Enum.MeshType.Wedge
		seMesh.Parent = stoneEdge
		weldParts(bladeCore, stoneEdge, CFrame.new(edgeSide * 0.48 * S, 0, 0) * CFrame.Angles(0, math.rad(edgeSide == -1 and 90 or -90), 0))
	end

	-- Chiseled Stone Blade Tip
	local bladeTip = Instance.new("Part")
	bladeTip.Name = "BladeStoneTip"
	bladeTip.Size = Vector3.new(1.1 * S, 0.8 * S, 0.38 * S)
	bladeTip.Color = STONE_BLADE
	bladeTip.Material = Enum.Material.Slate
	bladeTip.Anchored = false
	bladeTip.CanCollide = false
	bladeTip.Parent = model
	local btMesh = Instance.new("SpecialMesh")
	btMesh.MeshType = Enum.MeshType.Wedge
	btMesh.Parent = bladeTip
	weldParts(bladeCore, bladeTip, CFrame.new(0, 1.95 * S, 0) * CFrame.Angles(math.rad(180), 0, 0))

	-- ¦¦ Muscular Legs & Tribal Sandals ¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦¦
	for _, side in ipairs({ -1, 1 }) do
		local sideName = (side == -1 and "Left" or "Right")

		local upperLeg = Instance.new("Part")
		upperLeg.Name = sideName .. "UpperLeg"
		upperLeg.Size = Vector3.new(0.9 * S, 1.5 * S, 0.9 * S)
		upperLeg.Color = FUR_BROWN
		upperLeg.Material = Enum.Material.SmoothPlastic
		upperLeg.Anchored = false
		upperLeg.CanCollide = false
		upperLeg.Parent = model
		makeJoint(lowerTorso, upperLeg, sideName .. "Hip", CFrame.new(side * 0.65 * S, -1.1 * S, 0) * CFrame.Angles(0, 0, math.rad(-side * 5)))

		local lowerLeg = Instance.new("Part")
		lowerLeg.Name = sideName .. "LowerLeg"
		lowerLeg.Size = Vector3.new(0.8 * S, 1.4 * S, 0.8 * S)
		lowerLeg.Color = FUR_BROWN
		lowerLeg.Material = Enum.Material.SmoothPlastic
		lowerLeg.Anchored = false
		lowerLeg.CanCollide = false
		lowerLeg.Parent = model
		makeJoint(upperLeg, lowerLeg, sideName .. "Knee", CFrame.new(0, -1.35 * S, 0))

		-- Ankle Rope Wraps
		local ankleRope = Instance.new("Part")
		ankleRope.Name = sideName .. "AnkleRope"
		ankleRope.Size = Vector3.new(0.9 * S, 0.45 * S, 0.9 * S)
		ankleRope.Color = ROPE_COLOR
		ankleRope.Material = Enum.Material.SmoothPlastic
		ankleRope.Anchored = false
		ankleRope.CanCollide = false
		ankleRope.Parent = model
		weldParts(lowerLeg, ankleRope, CFrame.new(0, -0.45 * S, 0))

		-- Foot / Sandal Sole
		local sandal = Instance.new("Part")
		sandal.Name = sideName .. "SandalSole"
		sandal.Size = Vector3.new(0.95 * S, 0.25 * S, 1.4 * S)
		sandal.Color = LEATHER_BROWN
		sandal.Material = Enum.Material.Fabric
		sandal.Anchored = false
		sandal.CanCollide = false
		sandal.Parent = model
		weldParts(lowerLeg, sandal, CFrame.new(0, -0.9 * S, -0.2 * S))

		-- Leather Sandal Toe Strap
		local sandalStrap = Instance.new("Part")
		sandalStrap.Name = sideName .. "SandalStrap"
		sandalStrap.Size = Vector3.new(0.9 * S, 0.3 * S, 0.35 * S)
		sandalStrap.Color = DARK_LEATHER
		sandalStrap.Material = Enum.Material.Fabric
		sandalStrap.Anchored = false
		sandalStrap.CanCollide = false
		sandalStrap.Parent = model
		weldParts(sandal, sandalStrap, CFrame.new(0, 0.2 * S, -0.15 * S))

		-- Visible Monkey Toes (Peach/tan digits)
		for toeIdx = -2, 2 do
			local toe = Instance.new("Part")
			toe.Name = sideName .. "Toe_" .. (toeIdx + 3)
			toe.Size = Vector3.new(0.16 * S, 0.2 * S, 0.3 * S)
			toe.Color = TAN_SKIN
			toe.Material = Enum.Material.SmoothPlastic
			toe.Anchored = false
			toe.CanCollide = false
			toe.Parent = model
			local toeMesh = Instance.new("SpecialMesh")
			toeMesh.MeshType = Enum.MeshType.Sphere
			toeMesh.Scale = Vector3.new(1, 0.9, 1.2)
			toeMesh.Parent = toe
			weldParts(sandal, toe, CFrame.new(toeIdx * 0.18 * S, 0.1 * S, -0.6 * S))
		end
	end

	-- Set properties & anchoring: ONLY HumanoidRootPart is anchored, all limbs are unanchored for Motor6D articulation!
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
	local templateScript = ReplicatedStorage:FindFirstChild("MonkeyWarriorWalkAnimatorTemplate")
	if templateScript then
		local animScript = templateScript:Clone()
		animScript.Name = "MonkeyWarriorWalkAnimator"
		animScript.Parent = model
	end

	model.Parent = BalloonModels
	print("[MonkeyWarriorBuilder] Successfully built and saved rigged MonkeyWarrior model to ReplicatedStorage/BalloonModels/MonkeyWarrior")
	return model
end

-- Run once on startup
buildMonkeyWarrior()

return {
	Build = buildMonkeyWarrior,
}
