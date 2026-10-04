-- Demo: pickaxe harvest, blue build preview, 90s tower, llama smash, gold chest + rifle, victory. All inside ~40 s.
local me = function() return PlayerPedId() end
local function fwd(d, side) return GetOffsetFromEntityInWorldCoords(me(), side or 0.0, d, 0.0) end
local function onGround(p)
	local ok, z = GetGroundZFor_3dCoord(p.x, p.y, p.z + 3.0, false)
	return vector3(p.x, p.y, ok and z or p.z)
end
local function walkTo(p, sec, speed)
	TaskGoStraightToCoord(me(), p.x, p.y, p.z, speed or 1.6, math.floor(sec * 1000), GetEntityHeading(me()), 0.4)
end
local function loadGroundAt(p)
	RequestCollisionAtCoord(p.x, p.y, p.z)
	local t = GetGameTimer() + 2500
	while not HasCollisionLoadedAroundEntity(PlayerPedId()) and GetGameTimer() < t do Wait(100) end
	Wait(200)
end
local function caption(txt, sec, color, size)
	Sigf.Text(txt, sec, { y = 0.13, size = size or 54, color = color or '#ffffff' })
end

local camActive = false
local function stopCam()
	if camActive then camActive = false RenderScriptCams(false, true, 500, true, true) end
end

-- Teleport the player to a clean ground spot, keeping the heading.
local function moveTo(p, heading)
	local g = onGround(p)
	SetEntityCoords(me(), g.x, g.y, g.z + 1.0, false, false, false, false)
	if heading then SetEntityHeading(me(), heading) end
	loadGroundAt(g)
	g = onGround(g)
	SetEntityCoords(me(), g.x, g.y, g.z + 1.0, false, false, false, false)
	return g
end

local llamaScene, chestScene, rifleScene, victoryScene, towerDone, afterVictory

function victoryScene()
	Fn.Victory({ sub = 'GTA V x FORTNITE', music = 'fn_win', emote = 'floss' })
	Sigf.After(5.0, function() if afterVictory then afterVictory() end end)
end

function rifleScene()
	caption('GOLD RIFLE vs THE LAST BOT', 4, '#ffcc00', 50)
	-- select the legendary rifle the chest gave (or give it if the pickup was missed)
	local slot
	for i = 1, 5 do local s = Fn.State.slots[i] if s and s.key == 'ar' and s.hex and i > 1 then slot = i end end
	if not slot then slot = 5 Fn.SetSlot(5, 'ar', 'legendary') end
	Fn.Select(slot)
	ClearPedTasks(me())
	local bp = onGround(fwd(9.0))
	local e = Sigf.Ped('g_m_y_ballasout_01', bp + vector3(0, 0, 0.5), { enemy = true, weapon = 'WEAPON_PISTOL', health = 160,
		heading = GetEntityHeading(me()) + 180.0 })
	if not e then Sigf.After(1.0, victoryScene) return end
	FreezeEntityPosition(e, true)
	local ep = GetEntityCoords(e)
	local toward = GetEntityCoords(me()) - ep
	toward = toward / #toward
	local h = GetHeadingFromVector_2d(toward.x, toward.y)
	local wallPos = ep + toward * 2.6
	local ok, z = GetGroundZFor_3dCoord(wallPos.x, wallPos.y, wallPos.z + 3.0, false)
	wallPos = vector3(wallPos.x, wallPos.y, ok and z or ep.z - 1.0)
	local wall = Fn.Build('wall', wallPos, h, 'wood', { free = true })
	if wall then Sigf.Safe('ScaleWall', function() Sigf.ScaleProp(wall, 0.55) end) end
	Sigf.LookAt(wallPos, 0.8)
	Sigf.After(0.5, function() Sigf.Shoot(1.3, wallPos + vector3(0, 0, 1.4)) end)
	Sigf.After(1.7, function()
		if wall and DoesEntityExist(wall) then Fn.Break(wall) end
		Sigf.Shoot(1.4, e)
	end)
	Sigf.After(2.6, function()
		if DoesEntityExist(e) then
			Fn.DamageNumber(GetEntityCoords(e) + vector3(0, 0, 1.2), 140, 'head')
			Sigf.Text3D('ELIMINATED', GetEntityCoords(e) + vector3(0, 0, 1.8), 1.4, { color = { 255, 90, 90 } })
		end
	end)
	Sigf.After(3.1, function()
		if DoesEntityExist(e) then FreezeEntityPosition(e, false) Sigf.KillByHost(e) end
	end)
	Sigf.After(3.2, victoryScene)
end

function chestScene()
	CreateThread(function()
		local right = GetOffsetFromEntityInWorldCoords(me(), 14.0, 0.0, 0.0) - GetEntityCoords(me())
		moveTo(GetEntityCoords(me()) + right, GetEntityHeading(me()))
		SetGameplayCamRelativeHeading(0.0)
		caption('GOLDEN CHEST: LEGENDARY LOOT', 4, '#ffcc00', 50)
		local chestPos = onGround(fwd(5.0, 0.0))
		loadGroundAt(chestPos)
		chestPos = onGround(chestPos)
		local ch = Fn.Chest(chestPos, { life = 40, loot = 1, gold = true, heading = GetEntityHeading(me()) })
		Sigf.After(2.6, function() if ch and DoesEntityExist(ch) then Fn.Open(ch) end end)
		Sigf.After(3.6, function() walkTo(chestPos + vector3(1.5, 0.0, 0.0), 1.6, 1.8) end)
		Sigf.After(3.8, function() caption('LEGENDARY ASSAULT RIFLE', 3, '#ff9a30', 54) end)
		Sigf.After(5.2, rifleScene)
	end)
end

function llamaScene()
	caption('SMASH THE LLAMA!', 4, '#d070ff', 60)
	local lp = onGround(fwd(4.0))
	local l = Fn.Llama(lp, { life = 30, hits = 3 })
		Sigf.After(1.2, function() Fn.Swing(me(), l) end)
	Sigf.After(1.9, function() Fn.Swing(me(), l) end)
	Sigf.After(2.6, function() Fn.Swing(me(), l) end)
	Sigf.After(5.0, chestScene)
end

-- Everything runs from one timeline that starts once the world is really on screen.
Sigf.Demo(0, function()
	CreateThread(function()
		local deadline = GetGameTimer() + 40000
		while GetGameTimer() < deadline do
			local p = me()
			if GetEntityModel(p) == GetHashKey('mp_m_freemode_01') and IsScreenFadedIn() and not GetIsLoadingScreenActive()
				and HasCollisionLoadedAroundEntity(p) then break end
			Wait(250)
		end
		Wait(200)
		Sigf.Pilot(false)
		SetEntityInvincible(me(), true)
		-- gameplay camera stays right behind the player unless a scripted camera is on
		Sigf.Frame(function()
			local p = me()
			if GetEntityHealth(p) < GetEntityMaxHealth(p) then SetEntityHealth(p, GetEntityMaxHealth(p)) end
			if GetPedArmour(p) < 100 then SetPedArmour(p, 100) end
			if not camActive then
				SetGameplayCamRelativeHeading(0.0)
				SetGameplayCamRelativePitch(-12.0, 1.0)
			end
		end)
		Fn.Hud(true)
		Fn.Shield(100)
		Fn.SetSlot(1, 'ar', 'uncommon')
		Fn.Select(1)
		local O = GetEntityCoords(me())
		local H0 = GetEntityHeading(me())
		local at = Sigf.After

		local function act2()
			ClearPedTasks(me())
			moveTo(O + vector3(-30.0, 0.0, 0.0), H0)
			SetGameplayCamRelativeHeading(0.0)
		-- 1. pickaxe harvest: a tree and a car wreck, materials go up
		caption('PICKAXE: HARVEST WOOD + METAL', 5, '#ffffff', 50)
		local tree = Sigf.Prop('prop_tree_cedar_02', onGround(fwd(4.2, 1.9)), { ground = true, life = 40 })
		if tree then Fn.Harvestable(tree, 'wood', 12, 2, 'tree') end
		local car = Sigf.Prop('prop_rub_carwreck_2', onGround(fwd(4.5, -2.5)), { ground = true, life = 40 })
		if car then Fn.Harvestable(car, 'metal', 15, 1) end
		at(0.2, function() if tree then Fn.Swing(me(), tree) end end)
		at(1.0, function() if tree then Fn.Swing(me(), tree) end end)
				at(1.9, function() if car then Fn.Swing(me(), car) end end)

		-- 2. build preview: blue ghost wall, placed, then a blue ghost ramp, placed
		local wallObj, rampObj
		local towerEnded = false
		at(4.2, function()
			caption('BUILD PREVIEW: THE BLUE GHOST', 6, '#4aa8ff', 50)
			Fn.AddMats('wood', 150)
			Fn.State.mat = 'wood'
			ClearPedTasks(me())
			local sp0, sh0 = Fn.Spot('wall', me())
			local f0 = fwd(1.0) - GetEntityCoords(me())
			Fn.Prev.pos = onGround(sp0 + f0 * 7.0)
			Fn.Prev.heading = sh0
			Fn.Preview(true, 'wall')
		end)
		local spot, sh
		at(6.3, function()
			spot, sh = Fn.Prev.pos, Fn.Prev.heading
			wallObj = Fn.Place()
		end)
		at(6.4, function()
			if not spot then return end
			local right = fwd(0.0, 4.0) - GetEntityCoords(me())
			Fn.Prev.pos = spot + right
			Fn.Prev.heading = sh
			Fn.Preview(true, 'ramp')
		end)
		at(8.4, function() rampObj = Fn.Place() end)
		at(8.7, function() Fn.Preview(false) Fn.Prev.pos = nil end)

		-- 3. cranking 90s: a tower of ramps and floors, filmed from the side
		at(8.9, function()
			caption('CRANKING 90s: BUILD UP FAST', 7, '#ffcc00', 54)
			if wallObj and DoesEntityExist(wallObj) then Fn.Break(wallObj) end
			if rampObj and DoesEntityExist(rampObj) then Fn.Break(rampObj) end
			local right = GetOffsetFromEntityInWorldCoords(me(), 22.0, 0.0, 0.0) - GetEntityCoords(me())
			local S = moveTo(GetEntityCoords(me()) + right, H0)
			local f = GetOffsetFromEntityInWorldCoords(me(), 0.0, 1.0, 0.0) - GetEntityCoords(me())
			local r = GetOffsetFromEntityInWorldCoords(me(), 1.0, 0.0, 0.0) - GetEntityCoords(me())
			local cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
			SetCamFov(cam, 65.0)
			camActive = true
			RenderScriptCams(true, true, 700, true, true)
			local cp = GetEntityCoords(me()) - f * 7.0 + vector3(0, 0, 4.0)
			SetCamCoord(cam, cp.x, cp.y, cp.z)
			Sigf.Frame(function()
				if not camActive then DestroyCam(cam, false) return false end
				local pp = GetEntityCoords(me())
				local hr = math.rad(GetEntityHeading(me()))
				local fv = vector3(-math.sin(hr), math.cos(hr), 0.0)
				local want = pp - fv * 7.5 + vector3(-fv.y * 2.5, fv.x * 2.5, 3.5)
				local k = math.min(1.0, GetFrameTime() * 3.0)
				cp = cp + (want - cp) * k
				SetCamCoord(cam, cp.x, cp.y, cp.z)
				PointCamAtCoord(cam, pp.x + fv.x * 2.5, pp.y + fv.y * 2.5, pp.z + 1.2)
			end)
			Fn.Crank90(me(), 4, { mat = 'brick', done = function() Sigf.After(1.0, towerDone) end })
		end)
		at(21.0, function() towerDone() end)

		-- 4. llama, 5. chest + rifle + victory
		towerDone = function()
			if towerEnded then return end
			towerEnded = true
			Sigf.Stop('fn_crank')
			ClearPedTasks(me())
			stopCam()
			for _, o in ipairs(Fn.Pieces()) do Fn.Break(o) end
		end
		end
		afterVictory = function() CreateThread(act2) end
		llamaScene()
	end)
end)
