-- Fortnite library for the GTA V kit (client): the guest's signature mechanics as bricks, ready for a GTA V x Fortnite mod.
-- Loaded only in mods that opt in (use-guest.ps1 -Guest fortnite -> mod/guest.txt), as lib/cl_fn.lua.
-- Read guests/fortnite/FORTNITE.md first: it explains what makes it read as Fortnite on screen and in which order to build.
Fn = Fn or {}

-- ---------- tunables (change them in client.lua: Fn.Grid = 5.0 ...) ----------
Fn.Grid = 4.0                          -- build tile size in metres (Fortnite's tile ~5 m; 4 m fits GTA's streets)
Fn.Models = {                          -- build pieces: kit pieces (use-guest.ps1 copies them) or base-game fallbacks
	wall  = { wood = 'sigf_fn_wall_wood',  brick = 'sigf_fn_wall_brick',  metal = 'sigf_fn_wall_metal' },
	floor = { wood = 'sigf_fn_floor_wood', brick = 'sigf_fn_floor_brick', metal = 'sigf_fn_floor_metal' },
	ramp  = { wood = 'sigf_fn_ramp_wood',  brick = 'sigf_fn_ramp_brick',  metal = 'sigf_fn_ramp_metal' },
	cone  = { wood = 'sigf_fn_cone_wood',  brick = 'sigf_fn_cone_brick',  metal = 'sigf_fn_cone_metal' },
	chest = 'sigf_fn_chest',               -- make it: um fal model3d + model.ps1 (FORTNITE.md), else the fallback
	llama = 'sigf_fn_llama',
}
Fn.Fallback = {                        -- base-game props used when a kit piece is missing (stunt blocks: clean shapes)
	wall = 'stt_prop_stunt_bblock_mdm3', floor = 'stt_prop_stunt_bblock_sml2', ramp = 'prop_mp_ramp_02',
	cone = 'prop_mp_cone_01', chest = 'prop_box_wood05a', llama = 'prop_alien_egg_01',
}
Fn.PieceHP = { wood = 150, brick = 300, metal = 450 }
Fn.BuildTime = { wood = 0.35, brick = 0.6, metal = 0.9 }   -- seconds to fade in (Fortnite builds visibly)
Fn.Cost = 10                                               -- materials per piece
-- Sounds: a name from mod/sfx (sounds.ps1) replaces the base-game one, e.g. Fn.Sounds.build = 'fn_build'.
Fn.Sounds = { build = nil, smash = nil, chest = nil, pickup = nil }
local GAME_SOUNDS = {
	build  = { 'CLICK_BACK', 'WEB_NAVIGATION_SOUNDS_PHONE' },
	smash  = { 'Glass_Smash', 'FBI_HEIST_RAID' },
	chest  = { 'PICK_UP', 'HUD_FRONTEND_DEFAULT_SOUNDSET' },
	pickup = { 'PICK_UP', 'HUD_FRONTEND_DEFAULT_SOUNDSET' },
}
local function play(kind, pos)
	if Fn.Sounds[kind] then Sigf.Sound(Fn.Sounds[kind], pos, { volume = 1.6, range = 90.0 }) return end
	local g = GAME_SOUNDS[kind]
	Sigf.GameSound(g[1], g[2], pos)
end

-- Rarity: Fortnite colours + GTA weapon tint (0 normal, 1 green, 5 blue, 3 pink, 2 gold).
Fn.Rarity = {
	common    = { name = 'Common',    color = { 170, 170, 170 }, hex = '#b4b4b4', tint = 0 },
	uncommon  = { name = 'Uncommon',  color = { 96, 170, 58 },   hex = '#60aa3a', tint = 1 },
	rare      = { name = 'Rare',      color = { 73, 172, 242 },  hex = '#49acf2', tint = 5 },
	epic      = { name = 'Epic',      color = { 177, 91, 226 },  hex = '#b15be2', tint = 3 },
	legendary = { name = 'Legendary', color = { 211, 120, 53 },  hex = '#d37835', tint = 2 },
}
Fn.RarityOrder = { 'common', 'uncommon', 'rare', 'epic', 'legendary' }

-- Fortnite weapon -> closest GTA weapon (same role and feel).
Fn.Weapons = {
	ar      = { hash = 'WEAPON_CARBINERIFLE',   name = 'Assault Rifle' },
	scar    = { hash = 'WEAPON_SPECIALCARBINE', name = 'Burst Rifle' },
	pump    = { hash = 'WEAPON_PUMPSHOTGUN',    name = 'Pump Shotgun' },
	tac     = { hash = 'WEAPON_ASSAULTSHOTGUN', name = 'Tactical Shotgun' },
	smg     = { hash = 'WEAPON_SMG',            name = 'SMG' },
	sniper  = { hash = 'WEAPON_HEAVYSNIPER',    name = 'Bolt Sniper' },
	rocket  = { hash = 'WEAPON_RPG',            name = 'Rocket Launcher' },
	pistol  = { hash = 'WEAPON_PISTOL',         name = 'Pistol' },
	grenade = { hash = 'WEAPON_GRENADE',        name = 'Grenade' },
	pickaxe = { hash = 'WEAPON_HATCHET',        name = 'Pickaxe' },
}

-- Emotes: base-game dances that read as Fortnite emotes. Check names in the catalog (animDictsCompact.json, "dance").
Fn.Emotes = {
	floss   = { 'anim@amb@nightclub@mini@dance@dance_solo@male@var_a@', 'high_center' },
	default = { 'anim@amb@nightclub@dancers@crowddance_facedj@hi_intensity', 'hi_dance_facedj_09_v2_male^1' },
	wave    = { 'random@mugging5', '001445_01_gangintimidation_1_female_idle_b' },
	salute  = { 'anim@mp_player_intcelebrationmale@salute', 'salute' },
}

-- ---------- HUD (lib/nui/guest.js): Fortnite layout on the stream ----------
Fn.State = { mats = { wood = 0, brick = 0, metal = 0 }, mat = 'wood', elims = 0, alive = 0, slots = {}, slot = 1 }
local hudOn = false

local lastSent = ''
local function push(extra)
	local me = PlayerPedId()
	local hp = math.max(0, GetEntityHealth(me) - 100)
	local maxHp = math.max(1, GetEntityMaxHealth(me) - 100)
	-- Slots as a dense list with their index (a sparse Lua table does not encode to JSON).
	local slots = {}
	for i = 1, 5 do local s = Fn.State.slots[i] if s then slots[#slots + 1] = { i = i, name = s.name, hex = s.hex } end end
	local msg = { t = 'fn', hp = math.floor(hp * 100 / maxHp), shield = GetPedArmour(me), mats = Fn.State.mats, mat = Fn.State.mat,
		elims = Fn.State.elims, alive = Fn.State.alive, slots = slots, slot = Fn.State.slot }
	if extra then for k, v in pairs(extra) do msg[k] = v end end
	local key = json.encode(msg)
	if key == lastSent then return end   -- 4 polls a second, most with nothing new
	lastSent = key
	SendNUIMessage(msg)
end

-- Fn.Hud(true): health/shield bars, materials, weapon slots, players left, eliminations, storm timer, kill feed.
function Fn.Hud(on)
	hudOn = on ~= false
	SendNUIMessage({ t = 'fnshow', on = hudOn })
	if hudOn then
		Sigf.Every(0.25, push, 'fn_hud')
	else Sigf.Stop('fn_hud') end
end

function Fn.AddMats(kind, n)
	Fn.State.mats[kind] = math.max(0, (Fn.State.mats[kind] or 0) + n)
	push({ matPop = kind, matDelta = n })
end

function Fn.SetAlive(n) Fn.State.alive = n push() end

-- Kill feed line + elimination counter (killer = 'You' counts for the player).
function Fn.Elim(killer, victim, weaponName)
	Fn.State.alive = math.max(0, Fn.State.alive - 1)
	SendNUIMessage({ t = 'fnfeed', killer = killer, victim = victim, weapon = weaponName or '' })
	if killer == 'You' then
		Fn.State.elims = Fn.State.elims + 1
		SendNUIMessage({ t = 'fnelim', name = victim })
	end
	push()
end

-- Weapon slots: Fn.SetSlot(1, 'pump', 'epic') puts a rarity-coloured slot in the hotbar and gives the weapon.
function Fn.SetSlot(i, weapon, rarity)
	local w, r = Fn.Weapons[weapon], Fn.Rarity[rarity or 'common']
	Fn.State.slots[i] = { name = w.name, hex = r.hex, key = weapon }
	local me, h = PlayerPedId(), GetHashKey(w.hash)
	GiveWeaponToPed(me, h, 250, false, false)
	SetPedWeaponTintIndex(me, h, r.tint)
	push()
end

function Fn.Select(i)
	local s = Fn.State.slots[i]
	if not s then return end
	Fn.State.slot = i
	SetCurrentPedWeapon(PlayerPedId(), GetHashKey(Fn.Weapons[s.key].hash), true)
	push()
end

-- Shield (blue bar) = GTA armour, 0-100. Fn.Shield(50) like a small shield potion.
function Fn.Shield(n, ped) SetPedArmour(ped or PlayerPedId(), math.min(100, n)) push() end

-- "+50" style number over a hit (white body, yellow head, blue shield), like Fortnite's damage numbers.
function Fn.DamageNumber(pos, amount, kind)
	local c = kind == 'head' and { 255, 220, 40 } or kind == 'shield' and { 90, 190, 255 } or { 255, 255, 255 }
	Sigf.Text3D(tostring(math.floor(amount)), pos + vector3(Sigf.Rand(-0.3, 0.3), 0, 0.3), 1.0, { color = c, scale = 0.7, rise = 1.2 })
end

-- ---------- building ----------
local pieces = {}   -- obj -> { hp, max, kind, mat }

local function pieceModel(kind, mat)
	local m = Fn.Models[kind]
	m = type(m) == 'table' and m[mat or 'wood'] or m
	if m and IsModelInCdimage(GetHashKey(m)) then return m, true end
	return Fn.Fallback[kind], false
end

-- Snap a point to the build grid; heading snapped to 90 degrees.
function Fn.Snap(pos, heading)
	local g = Fn.Grid
	local x = math.floor(pos.x / g + 0.5) * g
	local y = math.floor(pos.y / g + 0.5) * g
	local h = (math.floor(((heading or 0) + 45) / 90) % 4) * 90.0
	return vector3(x, y, pos.z), h
end

-- One piece. kind: 'wall' | 'floor' | 'ramp' | 'cone'; mat: 'wood' | 'brick' | 'metal'. Fades in, has hit points,
-- breaks with debris when shot. Returns the object. opts: free (no material cost), owner (ped, for bots), silent.
function Fn.Build(kind, pos, heading, mat, opts)
	opts = opts or {}
	mat = mat or Fn.State.mat
	if not opts.free and not opts.owner then
		if (Fn.State.mats[mat] or 0) < Fn.Cost then Sigf.Text('NOT ENOUGH ' .. mat:upper(), 1.2, { y = 0.7, size = 34, font = 'body' }) return nil end
		Fn.AddMats(mat, -Fn.Cost)
	end
	local model, own = pieceModel(kind, mat)
	local obj = Sigf.Prop(model, pos, { heading = heading, alpha = 60 })
	if not obj then return nil end
	if not own and kind ~= 'ramp' then PlaceObjectOnGroundProperly(obj) end
	local max = Fn.PieceHP[mat] or 150
	pieces[obj] = { hp = max, mat = mat }
	-- Builds visibly: the piece goes from ghost to solid while its "hp" counts up, like Fortnite.
	local t0, dur = GetGameTimer(), (Fn.BuildTime[mat] or 0.4) * 1000
	Sigf.Frame(function()
		if not DoesEntityExist(obj) then return false end
		local k = math.min(1, (GetGameTimer() - t0) / dur)
		SetEntityAlpha(obj, math.floor(60 + 195 * k), false)
		if k >= 1 then ResetEntityAlpha(obj) return false end
	end)
	if not opts.silent then play('build', pos) end
	return obj
end

-- Where a piece would go in front of a ped: grid position and heading (also used by the blue preview).
function Fn.Spot(kind, ped)
	ped = ped or PlayerPedId()
	local h = GetEntityHeading(ped)
	local ahead = GetOffsetFromEntityInWorldCoords(ped, 0.0, Fn.Grid * (kind == 'wall' and 0.6 or 1.0), 0.0)
	local p, sh = Fn.Snap(ahead, h)
	local ok, z = GetGroundZFor_3dCoord(p.x, p.y, ahead.z + 2.0, false)
	return vector3(p.x, p.y, ok and z or ahead.z - 1.0), sh
end

-- Builds in front of a ped (the player by default), on the grid, facing where it looks. Fortnite's "wall + ramp" in 2 calls.
function Fn.BuildFront(kind, mat, ped, opts)
	local p, sh = Fn.Spot(kind, ped)
	return Fn.Build(kind, p, sh, mat, opts)
end

-- A 1x1 box around a ped: 4 walls + a cone on top (the classic panic box). Returns the pieces.
function Fn.Box(ped, mat, opts)
	ped = ped or PlayerPedId()
	local c, h = Fn.Snap(GetEntityCoords(ped), GetEntityHeading(ped))
	local ok, z = GetGroundZFor_3dCoord(c.x, c.y, c.z + 2.0, false)
	c = vector3(c.x, c.y, ok and z or c.z - 1.0)
	local out, half = {}, Fn.Grid / 2
	for i = 0, 3 do
		local a = math.rad(h + i * 90)
		local p = c + vector3(-math.sin(a) * half, math.cos(a) * half, 0)
		out[#out + 1] = Fn.Build('wall', p, h + i * 90, mat, opts)
	end
	out[#out + 1] = Fn.Build('cone', c + vector3(0, 0, Fn.Grid), h, mat, opts)
	return out
end

-- Remove a piece with its debris effect.
function Fn.Break(obj)
	local p = pieces[obj]
	if not p then return end
	pieces[obj] = nil
	local pos = GetEntityCoords(obj)
	Sigf.Fx('core', p.mat == 'wood' and 'ent_dst_wood_splinter' or 'ent_dst_concrete_large', pos, { scale = 1.5 })
	play('smash', pos)
	Sigf.Remove(obj)
end

function Fn.Pieces() local t = {} for o in pairs(pieces) do t[#t + 1] = o end return t end

-- Hits on pieces: every damage event takes hit points (pickaxe or bullets); a damage number shows; 0 = it breaks.
CreateThread(function()
	while true do
		Wait(100)
		for obj, p in pairs(pieces) do
			if not DoesEntityExist(obj) then pieces[obj] = nil
			elseif HasEntityBeenDamagedByAnyPed(obj) then
				ClearEntityLastDamageEntity(obj)
				local dmg = 25
				p.hp = p.hp - dmg
				Fn.DamageNumber(GetEntityCoords(obj) + vector3(0, 0, 1.5), dmg)
				if p.hp <= 0 then Fn.Break(obj) end
			end
		end
	end
end)

-- ---------- harvesting: pickaxe, trees, cars, fences, the llama ----------
-- Fn.Harvestable(obj, 'wood', 6, 5, 'tree'): a prop that gives materials per hit and breaks after `hits` hits.
-- kind: 'tree' (falls over), 'llama' (piñata: candy + loot), anything else (splinters / sparks / bricks).
-- Hits come from Fn.Swing (pickaxe) or from any shot / melee damage on the object.
Fn.Targets = {}
Fn.Sounds.hit = nil
function Fn.Harvestable(obj, mat, perHit, hits, kind)
	Fn.Targets[obj] = { mat = mat or 'wood', per = perHit or 6, left = hits or 6, max = hits or 6, kind = kind or 'prop' }
	return obj
end
Fn.Farm = function(obj, mat, perHit, hits) return Fn.Harvestable(obj, mat, perHit, hits) end   -- older name

local HIT_FX = {
	wood  = { 'core', 'ent_dst_wood_splinter' },
	brick = { 'core', 'ent_dst_concrete_large' },
	metal = Sigf.FX.sparks,
}

local function breakTarget(obj, t)
	Fn.Targets[obj] = nil
	local pos = GetEntityCoords(obj)
	if t.kind == 'tree' then
		-- the tree tips over before it disappears
		local rot, t0 = GetEntityRotation(obj, 2), GetGameTimer()
		local dirYaw = Sigf.Rand(0, 360)
		FreezeEntityPosition(obj, true)
		Sigf.Frame(function()
			if not DoesEntityExist(obj) then return false end
			local k = math.min(1, (GetGameTimer() - t0) / 900)
			SetEntityRotation(obj, rot.x + 88.0 * k * k, rot.y, rot.z, 2, true)
			if k >= 1 then
				Sigf.Fx('core', 'ent_dst_wood_splinter', GetEntityCoords(obj), { scale = 2.0 })
				Sigf.Fx(Sigf.FX.smoke[1], Sigf.FX.smoke[2], pos, { scale = 2.0 })
				Sigf.Remove(obj)
				return false
			end
		end)
		return
	end
	local fx = HIT_FX[t.mat] or HIT_FX.wood
	Sigf.Fx(fx[1], fx[2], pos + vector3(0, 0, 0.6), { scale = 2.2 })
	Sigf.Fx(Sigf.FX.smoke[1], Sigf.FX.smoke[2], pos, { scale = 1.5 })
	play('smash', pos)
	Sigf.Remove(obj)
end

local function smashLlama(obj, t, byPlayer)
	Fn.Targets[obj] = nil
	local pos = GetEntityCoords(obj)
	for i = 0, 3 do
		Sigf.After(i * 0.15, function()
			Sigf.Fx(Sigf.FX.poof[1], Sigf.FX.poof[2], pos + vector3(0, 0, 1.5), { scale = 0.6 })
			Sigf.Fx(Sigf.FX.firework[1], Sigf.FX.firework[2], pos + vector3(Sigf.Rand(-1, 1), Sigf.Rand(-1, 1), 1.5 + i * 0.4), { scale = 0.7 })
			Sigf.Fx(Sigf.FX.money[1], Sigf.FX.money[2], pos + vector3(0, 0, 1.0), { scale = 3.0 })
		end)
	end
	Sigf.Light(pos + vector3(0, 0, 1.5), { 200, 90, 255 }, 14.0, 12.0, 3)
	Sigf.Text('LLAMA SMASHED!', 2.5, { y = 0.24, size = 64, color = '#e070ff' })
	Sigf.Shake(0.4)
	play('chest', pos)
	if byPlayer then
		Fn.AddMats('wood', 100) Fn.AddMats('brick', 100) Fn.AddMats('metal', 100)
		Fn.Shield(100)
	end
	local keys = { 'ar', 'pump', 'smg', 'tac', 'scar' }
	for i = 1, 4 do
		local a = (i / 4) * 6.28
		Fn.Loot(pos + vector3(math.cos(a) * 2.6, math.sin(a) * 2.6, 0.4), Sigf.Pick(keys), i == 1 and 'epic' or Fn.RollRarity(2))
	end
	Sigf.Remove(obj)
end

-- One hit on a target by `ped` (nil = a shot). Effects, materials (the player's), break at zero hits.
function Fn.HitTarget(obj, ped)
	local t = Fn.Targets[obj]
	if not t or not DoesEntityExist(obj) then return end
	local byPlayer = (ped == PlayerPedId())
	t.left = t.left - 1
	local pos = GetEntityCoords(obj)
	local fx = HIT_FX[t.mat] or HIT_FX.wood
	if t.kind == 'llama' then
		Sigf.Fx(Sigf.FX.money[1], Sigf.FX.money[2], pos + vector3(0, 0, 1.2), { scale = 1.2 })
		Sigf.Text('CRACK!', 0.8, { y = 0.32, size = 56, color = '#ff82e6' })
	else
		Sigf.Fx(fx[1], fx[2], pos + vector3(0, 0, 1.0), { scale = 1.8 })
		Sigf.Fx(fx[1], fx[2], pos + vector3(0, 0, 1.6), { scale = 1.4 })
		Sigf.Text3D('+' .. t.per, pos + vector3(Sigf.Rand(-0.5, 0.5), 0, 1.6), 1.0, { color = { 255, 255, 255 }, scale = 1.2, rise = 1.4 })
	end
	if Fn.Sounds.hit then Sigf.Sound(Fn.Sounds.hit, pos) else play('smash', pos) end
	-- the object shudders
	SetEntityAlpha(obj, 170, false)
	Sigf.After(0.09, function() if DoesEntityExist(obj) then ResetEntityAlpha(obj) end end)
	local rot = GetEntityRotation(obj, 2)
	SetEntityRotation(obj, rot.x + Sigf.Rand(-3, 3), rot.y + Sigf.Rand(-3, 3), rot.z, 2, true)
	if byPlayer then Fn.AddMats(t.mat, t.per) Sigf.Shake(0.15) end
	if t.left <= 0 then
		if t.kind == 'llama' then smashLlama(obj, t, byPlayer) else breakTarget(obj, t) end
	end
end

-- Nearest target within `range` of a position.
function Fn.NearTarget(pos, range)
	local best, bd = nil, range or 3.5
	for obj in pairs(Fn.Targets) do
		if DoesEntityExist(obj) then
			local d = #(GetEntityCoords(obj) - pos)
			if d < bd then best, bd = obj, d end
		else Fn.Targets[obj] = nil end
	end
	return best
end

-- Swing the pickaxe (a ped; the player by default) at a target or at the nearest one: pickaxe in hand, overhead swing,
-- the hit lands at the end of the swing. Returns the target, or nil when nothing is in reach.
function Fn.Swing(ped, target)
	ped = ped or PlayerPedId()
	local pos = GetEntityCoords(ped)
	target = target or Fn.NearTarget(pos, 3.6)
	local pick = Sigf.Prop('prop_tool_pickaxe', pos, { life = 2.4, frozen = false, collision = false })
	if pick then Sigf.Attach(pick, ped, 28422, vector3(0.08, 0.0, -0.02), vector3(0.0, -90.0, 0.0)) end
	if target then
		local tp = GetEntityCoords(target)
		TaskTurnPedToFaceCoord(ped, tp.x, tp.y, tp.z, 400)
	end
	Sigf.After(0.3, function()
		if DoesEntityExist(ped) then Sigf.Anim(ped, 'melee@large_wpn@streamed_core', 'long_0_attack', 1.2, 48) end
	end)
	if target then
		Sigf.After(0.8, function()
			if DoesEntityExist(ped) and DoesEntityExist(target) then Fn.HitTarget(target, ped) end
		end)
	end
	return target
end

-- Shots and melee hits from anyone on a target count as a hit too.
CreateThread(function()
	while true do
		Wait(100)
		for obj, t in pairs(Fn.Targets) do
			if not DoesEntityExist(obj) then Fn.Targets[obj] = nil
			elseif HasEntityBeenDamagedByAnyPed(obj) then
				ClearEntityLastDamageEntity(obj)
				Fn.HitTarget(obj, PlayerPedId())
			end
		end
	end
end)

-- ---------- ghost preview: the blue outline of the piece before it is placed ----------
-- Fn.Preview(true, 'ramp', 'wood', ped): a blue ghost follows the ped's grid spot every frame (red when the materials
-- are short). Fn.Place() builds it. Keys for players: hold Z wall, X floor, C ramp, V cone to preview, release to build.
Fn.Prev = { on = false }
local PT = 0.2
local function boxShape(x0, x1, y0, y1, z0, z1)
	local v = {}
	for _, z in ipairs({ z0, z1 }) do for _, y in ipairs({ y0, y1 }) do for _, x in ipairs({ x0, x1 }) do v[#v + 1] = { x, y, z } end end end
	return v, { { 1, 2, 4 }, { 1, 4, 3 }, { 5, 7, 8 }, { 5, 8, 6 }, { 1, 5, 6 }, { 1, 6, 2 }, { 3, 4, 8 }, { 3, 8, 7 }, { 1, 3, 7 }, { 1, 7, 5 }, { 2, 6, 8 }, { 2, 8, 4 } },
		{ { 1, 2 }, { 2, 4 }, { 4, 3 }, { 3, 1 }, { 5, 6 }, { 6, 8 }, { 8, 7 }, { 7, 5 }, { 1, 5 }, { 2, 6 }, { 3, 7 }, { 4, 8 } }
end
local function shapeOf(kind)
	local g = Fn.Grid
	local h = g / 2
	if kind == 'wall' then return boxShape(-h, h, -PT, PT, 0, g)
	elseif kind == 'floor' then return boxShape(-h, h, -h, h, 0, PT * 2)
	elseif kind == 'ramp' then
		return { { -h, -h, 0 }, { h, -h, 0 }, { -h, h, 0 }, { h, h, 0 }, { -h, h, g }, { h, h, g } },
			{ { 1, 2, 6 }, { 1, 6, 5 }, { 1, 5, 3 }, { 2, 4, 6 }, { 3, 5, 6 }, { 3, 6, 4 } },
			{ { 1, 2 }, { 2, 4 }, { 4, 3 }, { 3, 1 }, { 3, 5 }, { 4, 6 }, { 5, 6 }, { 1, 5 }, { 2, 6 } }
	else
		return { { -h, -h, 0 }, { h, -h, 0 }, { h, h, 0 }, { -h, h, 0 }, { 0, 0, g / 2 } },
			{ { 1, 2, 5 }, { 2, 3, 5 }, { 3, 4, 5 }, { 4, 1, 5 } },
			{ { 1, 2 }, { 2, 3 }, { 3, 4 }, { 4, 1 }, { 1, 5 }, { 2, 5 }, { 3, 5 }, { 4, 5 } }
	end
end

local function drawGhost(kind, pos, heading, color, pulse)
	local verts, tris, edges = shapeOf(kind)
	local a = math.rad(heading)
	local ca, sa = math.cos(a), math.sin(a)
	local w = {}
	for i, v in ipairs(verts) do w[i] = vector3(pos.x + v[1] * ca - v[2] * sa, pos.y + v[1] * sa + v[2] * ca, pos.z + v[3]) end
	local fa = math.floor(110 + 50 * pulse)
	for _, t in ipairs(tris) do
		local p1, p2, p3 = w[t[1]], w[t[2]], w[t[3]]
		DrawPoly(p1.x, p1.y, p1.z, p2.x, p2.y, p2.z, p3.x, p3.y, p3.z, color[1], color[2], color[3], fa)
		DrawPoly(p3.x, p3.y, p3.z, p2.x, p2.y, p2.z, p1.x, p1.y, p1.z, color[1], color[2], color[3], fa)
	end
	for _, e in ipairs(edges) do
		local p1, p2 = w[e[1]], w[e[2]]
		DrawLine(p1.x, p1.y, p1.z, p2.x, p2.y, p2.z, 190, 230, 255, 255)
	end
end

-- A blue ghost of a piece at a spot for `sec` seconds (builders show where the next piece goes).
function Fn.GhostFlash(kind, pos, heading, sec)
	local t0 = GetGameTimer()
	Sigf.Frame(function()
		if GetGameTimer() - t0 > sec * 1000 then return false end
		drawGhost(kind, pos, heading, { 60, 150, 255 }, 0.5 + 0.5 * math.sin(GetGameTimer() / 90))
	end)
end

function Fn.Preview(on, kind, mat, ped)
	local P = Fn.Prev
	P.on, P.kind, P.mat, P.ped = on ~= false, kind or P.kind or 'wall', mat or P.mat, ped
	if not P.on or P.running then return end
	P.running = true
	Sigf.Frame(function()
		if not P.on then P.running = false return false end
		local pedE = P.ped or PlayerPedId()
		local pos, h
		if P.pos then pos, h = P.pos, P.heading or 0.0 else pos, h = Fn.Spot(P.kind, pedE) end
		P.at, P.heading_at = pos, h
		local m = P.mat or Fn.State.mat
		local ok = (Fn.State.mats[m] or 0) >= Fn.Cost
		drawGhost(P.kind, pos, h, ok and { 60, 150, 255 } or { 255, 70, 70 }, 0.5 + 0.5 * math.sin(GetGameTimer() / 150))
	end, 'fn_preview')
end

-- Place the previewed piece (the preview stays on unless stop = true).
function Fn.Place(stop)
	local P = Fn.Prev
	if not P.at then return nil end
	local obj = Fn.Build(P.kind, P.at, P.heading_at, P.mat or Fn.State.mat)
	if stop then P.on = false end
	return obj
end

-- Keys for players at home: hold to preview, release to place; G pickaxe; B cycles the material; H cranks a 90s tower.
local function key(name, label, k, press, release)
	RegisterCommand('+' .. name, press, false)
	RegisterCommand('-' .. name, release or function() end, false)
	RegisterKeyMapping('+' .. name, label, 'keyboard', k)
end
for _, spec in ipairs({ { 'wall', 'Z' }, { 'floor', 'X' }, { 'ramp', 'C' }, { 'cone', 'V' } }) do
	key('fn_' .. spec[1], 'Fortnite: build ' .. spec[1], spec[2],
		function() Fn.Preview(true, spec[1]) end,
		function() Fn.Place(true) end)
end
key('fn_pick', 'Fortnite: swing pickaxe', 'G', function() Fn.Swing() end)
key('fn_mat', 'Fortnite: next material', 'B', function()
	Fn.State.mat = ({ wood = 'brick', brick = 'metal', metal = 'wood' })[Fn.State.mat] or 'wood'
	Sigf.Text(Fn.State.mat:upper(), 1, { y = 0.7, size = 34, font = 'body' })
end)
key('fn_crank', 'Fortnite: auto 90s tower', 'H', function() Fn.Crank90(PlayerPedId(), 5) end)

-- ---------- cranking 90s: ramp, floor, turn, ramp... up a tower in seconds ----------
-- Fn.Crank90(ped, levels, { mat = 'wood', speed = 6, free = true, done = fn }): the ped runs up a spiral of ramps with
-- a floor landing and a wall at every turn; each piece pops in just before the ped reaches it.
function Fn.Crank90(ped, levels, o)
	o = o or {}
	ped = ped or PlayerPedId()
	local G = Fn.Grid
	local h = G / 2
	local mat = o.mat or 'wood'
	local speed = o.speed or 5.5
	local p0 = GetEntityCoords(ped)
	local hd = GetEntityHeading(ped)
	local c = Fn.Snap(p0, hd)
	local ok, gz = GetGroundZFor_3dCoord(c.x, c.y, p0.z + 1.0, false)
	local z = ok and gz or p0.z - 1.0
	local _, sh = Fn.Snap(p0, hd)
	local d = vector3(-math.sin(math.rad(sh)), math.cos(math.rad(sh)), 0.0)
	d = math.abs(d.x) > math.abs(d.y) and vector3(d.x > 0 and 1 or -1, 0, 0) or vector3(0, d.y > 0 and 1 or -1, 0)
	local F = vector3(c.x, c.y, z)
	local path = { { F.x, F.y, z, GetHeadingFromVector_2d(d.x, d.y), 0 } }
	local buildAt = {}   -- path distance -> piece spec
	local dist = 0.0
	local function add(x, y, zz, hh)
		local last = path[#path]
		dist = dist + math.sqrt((x - last[1]) ^ 2 + (y - last[2]) ^ 2 + (zz - last[3]) ^ 2)
		path[#path + 1] = { x, y, zz, hh, dist }
	end
	for k = 1, levels do
		local hh = GetHeadingFromVector_2d(d.x, d.y)
		local low = F + d * h
		local rampC = F + d * G
		local F2 = F + d * (2 * G)
		local zNext = F.z + G
		buildAt[#buildAt + 1] = { at = math.max(0, dist - 1.0), kind = 'ramp', pos = vector3(rampC.x, rampC.y, F.z), h = hh }
		buildAt[#buildAt + 1] = { at = dist + 1.5, kind = 'floor', pos = vector3(F2.x, F2.y, zNext - PT), h = hh }
		buildAt[#buildAt + 1] = { at = dist + 1.5, kind = 'wall', pos = vector3(F2.x + d.x * h, F2.y + d.y * h, zNext), h = hh }
		add(low.x, low.y, F.z, hh)
		add(F.x + d.x * (G + h), F.y + d.y * (G + h), zNext, hh)
		add(F2.x, F2.y, zNext, hh)
		F = vector3(F2.x, F2.y, zNext)
		d = vector3(-d.y, d.x, 0)   -- quarter turn left
		local ld = GetHeadingFromVector_2d(d.x, d.y)
		path[#path][4] = ld
	end
	local total = dist
	local k, nextB, legAt = 1, 1, GetGameTimer()
	ClearPedTasksImmediately(ped)
	local function go(i)
		local w = path[i + 1]
		legAt = GetGameTimer()
		if w then TaskGoStraightToCoord(ped, w[1], w[2], w[3] + 1.0, 3.0, -1, w[4] or 0.0, 0.3) end
	end
	go(1)
	Sigf.Text('90s!', 1.5, { y = 0.22, size = 56, color = '#4aa8ff' })
	-- The ped really runs (a go-to task gives the sprint animation); the height comes from the ramp it is on.
	Sigf.Frame(function(dt)
		if not DoesEntityExist(ped) or IsPedDeadOrDying(ped, true) then return false end
		local a, b = path[k], path[k + 1]
		if not b then return false end
		local p = GetEntityCoords(ped)
		local ex, ey = b[1] - a[1], b[2] - a[2]
		local len2 = math.max(0.001, ex * ex + ey * ey)
		local t = math.min(1, math.max(0, ((p.x - a[1]) * ex + (p.y - a[2]) * ey) / len2))
		local s = a[5] + t * (b[5] - a[5])
		while buildAt[nextB] and buildAt[nextB].at <= s + 2.2 do
			local bp = buildAt[nextB]
			Fn.GhostFlash(bp.kind, bp.pos, bp.h, 0.4)
			Sigf.After(0.4, function() Fn.Build(bp.kind, bp.pos, bp.h, mat, { free = o.free ~= false }) end)
			nextB = nextB + 1
		end
		local dx, dy = b[1] - p.x, b[2] - p.y
		local forced = GetGameTimer() - legAt > 3500
		if dx * dx + dy * dy < 0.5 or forced then
			if forced then SetEntityCoordsNoOffset(ped, b[1], b[2], b[3] + 1.0, false, false, false) end
			k = k + 1
			if not path[k + 1] then
				ClearPedTasks(ped)
				if o.done then Sigf.Safe('Crank90 done', o.done, ped) end
				return false
			end
			go(k)
			return
		end
		-- physics does the running; lift the ped back onto the ramp if it sinks into it
		local want = a[3] + t * (b[3] - a[3]) + 1.0
		if p.z < want - 0.6 then SetEntityCoordsNoOffset(ped, p.x, p.y, want, false, false, false) end
	end, 'fn_crank')
	return total / speed
end

-- ---------- storm ----------
-- Fn.Storm.Start({ center = vector3, radius = 300, to = 30, seconds = 120, damage = 5, color = { 150, 60, 255 } })
-- Purple wall around the safe zone, shrinking; outside it: purple filter, damage every second, storm timer on the HUD.
Fn.Storm = { on = false, filter = 'PPPurple' }
function Fn.Storm.Start(o)
	local S = Fn.Storm
	S.on, S.center, S.r0, S.r1 = true, o.center or Sigf.Arena(), o.radius or 300.0, o.to or 30.0
	S.t0, S.dur, S.damage, S.color = GetGameTimer(), (o.seconds or 120) * 1000, o.damage or 5, o.color or { 150, 60, 255 }
	S.inside = true
	Sigf.Frame(function()
		if not S.on then return false end
		local k = math.min(1, (GetGameTimer() - S.t0) / S.dur)
		S.radius = S.r0 + (S.r1 - S.r0) * k
		local c, col = S.center, S.color
		DrawMarker(1, c.x, c.y, c.z - 40.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, S.radius * 2, S.radius * 2, 250.0,
			col[1], col[2], col[3], 110, false, false, 2, false, nil, nil, false)
		local left = math.max(0, math.ceil((S.dur - (GetGameTimer() - S.t0)) / 1000))
		if hudOn and left ~= S.left then S.left = left SendNUIMessage({ t = 'fnstorm', left = left }) end
	end, 'fn_storm')
	Sigf.Every(1.0, function()
		if not S.on then return end
		local me = PlayerPedId()
		local d = #(GetEntityCoords(me).xy - S.center.xy)
		local inside = d <= S.radius
		if inside ~= S.inside then
			S.inside = inside
			if inside then AnimpostfxStop(S.filter) else AnimpostfxPlay(S.filter, 0, true) end
		end
		if not inside and not GetPlayerInvincible(PlayerId()) then ApplyDamageToPed(me, S.damage, false) end
		-- Peds outside take storm damage too (they die in it: the circle closes the fight).
		for _, ped in ipairs(Sigf.Peds()) do
			if #(GetEntityCoords(ped).xy - S.center.xy) > S.radius then ApplyDamageToPed(ped, S.damage, false) end
		end
	end, 'fn_storm_dmg')
end

function Fn.Storm.Stop()
	Fn.Storm.on = false
	Sigf.Stop('fn_storm_dmg')
	AnimpostfxStop(Fn.Storm.filter)
	SendNUIMessage({ t = 'fnstorm', left = -1 })
end

function Fn.Storm.Inside(pos) return Fn.Storm.on and #(pos.xy - Fn.Storm.center.xy) <= Fn.Storm.radius end

-- ---------- battle bus and skydive ----------
-- Fn.Bus({ from = vector3, to = vector3, height = 350, speed = 35, color = { 40, 120, 255 } }) -> the bus entity.
-- A blue bus under a blimp crosses the sky; Fn.Jump(ped) drops a ped out of it with a glider (GTA parachute).
function Fn.Bus(o)
	o = o or {}
	local c = Sigf.Arena()
	local from = o.from or (c + vector3(-600.0, -600.0, 0.0))
	local to = o.to or (c + vector3(600.0, 600.0, 0.0))
	local z = (o.height or 350.0) + c.z
	local heading = GetHeadingFromVector_2d(to.x - from.x, to.y - from.y)
	local blimp = Sigf.Vehicle('blimp', vector3(from.x, from.y, z + 9.0), heading)
	local bus = Sigf.Vehicle(o.model or 'bus', vector3(from.x, from.y, z), heading, { color = o.color or { 40, 120, 255 }, color2 = { 255, 255, 255 }, plate = 'BATTLE' })
	if not blimp or not bus then return nil end
	for _, v in ipairs({ bus, blimp }) do FreezeEntityPosition(v, true) SetEntityCollision(v, false, false) end
	Fn.BusEntity = bus
	local t0, len = GetGameTimer(), #(to.xy - from.xy)
	local speed = o.speed or 35.0
	Sigf.Frame(function()
		if not DoesEntityExist(bus) then return false end
		local d = (GetGameTimer() - t0) / 1000 * speed
		if d > len then Sigf.Remove(bus) Sigf.Remove(blimp) Fn.BusEntity = nil return false end
		local k = d / len
		local x, y = from.x + (to.x - from.x) * k, from.y + (to.y - from.y) * k
		SetEntityCoordsNoOffset(bus, x, y, z, false, false, false)
		SetEntityHeading(bus, heading)
		SetEntityCoordsNoOffset(blimp, x, y, z + 9.0, false, false, false)
		SetEntityHeading(blimp, heading)
	end, 'fn_bus')
	return bus
end

-- Drop a ped (the player by default) out of the bus: freefall, then the glider opens near the ground.
function Fn.Jump(ped, from)
	ped = ped or PlayerPedId()
	local p = from or (Fn.BusEntity and GetEntityCoords(Fn.BusEntity)) or (Sigf.Arena() + vector3(0, 0, 300))
	GiveWeaponToPed(ped, GetHashKey('GADGET_PARACHUTE'), 1, false, false)
	SetEntityCoords(ped, p.x, p.y, p.z - 6.0, false, false, false, false)
	if ped == PlayerPedId() then TriggerEvent('sigf:pilot', false) end
	TaskSkyDive(ped)
	CreateThread(function()
		while DoesEntityExist(ped) and GetEntityHeightAboveGround(ped) > 120.0 do Wait(100) end
		if DoesEntityExist(ped) then TaskParachute(ped, true) end
		-- Parachute state 0-2 = falling / opening / gliding; -1 = landed (60 s at most).
		local t = GetGameTimer() + 60000
		while DoesEntityExist(ped) and GetGameTimer() < t and (IsPedInParachuteFreeFall(ped) or (GetPedParachuteState(ped) >= 0 and GetPedParachuteState(ped) <= 2)) do Wait(200) end
		if ped == PlayerPedId() then TriggerEvent('sigf:pilot', true) end
	end)
end

-- ---------- loot ----------
local loot, lootId = {}, 0   -- id -> { pos, weapon, rarity, beam, glow }

Fn.WeaponProps = { ar = 'w_ar_carbinerifle', scar = 'w_ar_specialcarbine', pump = 'w_sg_pumpshotgun', tac = 'w_sg_assaultshotgun',
	smg = 'w_sb_smg', sniper = 'w_sr_heavysniper', rocket = 'w_lr_rpg', pistol = 'w_pi_pistol' }
-- Loot weapons hover and spin so they read from far away.
CreateThread(function()
	while true do
		Wait(0)
		local t = GetGameTimer() / 1000.0
		for _, l in pairs(loot) do
			if l.prop and DoesEntityExist(l.prop) then
				SetEntityCoordsNoOffset(l.prop, l.pos.x, l.pos.y, l.pos.z + 0.7 + math.sin(t * 3.0) * 0.12, false, false, false)
				SetEntityRotation(l.prop, 90.0, 0.0, (t * 90.0) % 360.0, 2, true)
			end
		end
	end
end)

-- Weapon on the ground with its rarity beam; the player picks it up by walking on it (slot `slot`, default next free).
-- It disappears after `life` seconds (60; 0 = never).
function Fn.Loot(pos, weapon, rarity, slot, life)
	rarity = rarity or 'common'
	local r = Fn.Rarity[rarity]
	life = life or 60
	lootId = lootId + 1
	local id = lootId
	local beam = Sigf.Marker(1, pos - vector3(0, 0, 0.9), vector3(0.25, 0.25, 6.0), { r.color[1], r.color[2], r.color[3], 120 }, life)
	local glow = Sigf.Light(pos + vector3(0, 0, 0.5), r.color, 3.0, 4.0, life)
	local prop = Fn.WeaponProps[weapon] and Sigf.Prop(Fn.WeaponProps[weapon], pos + vector3(0, 0, 0.5), { life = life > 0 and life or nil, collision = false, rot = vector3(90.0, 0.0, 0.0) })
	if prop then
		SetEntityAlwaysPrerender(prop, true)
		Sigf.Safe('ScaleLoot', function() Sigf.ScaleProp(prop, rarity == 'legendary' and 2.6 or 1.8) end)
		if rarity == 'legendary' or rarity == 'epic' then
			Sigf.Fx('core', 'ent_amb_sparking_wires', prop, { loop = true, life = life > 0 and life or 60, scale = 0.7 })
		end
	end
	loot[id] = { pos = pos, weapon = weapon, rarity = rarity, beam = beam, glow = glow, slot = slot, prop = prop,
		until_ = life > 0 and GetGameTimer() + life * 1000 or nil }
	if rarity == 'legendary' then
		Sigf.Fx(Sigf.FX.firework[1], Sigf.FX.firework[2], pos + vector3(0, 0, 1.0), { scale = 0.3 })
		Sigf.Light(pos + vector3(0, 0, 1.0), r.color, 9.0, 10.0, life)
	end
	return id
end

-- Random rarity, weighted like Fortnite (lots of grey and green, rare gold). bias > 1 = better loot (chests use 2).
function Fn.RollRarity(bias)
	local w = { 40, 30, 18, 9, 3 }
	if bias and bias > 1 then w = { 10, 25, 30, 22, 13 } end
	local total, roll = 0, 0
	for _, v in ipairs(w) do total = total + v end
	roll = math.random() * total
	for i, v in ipairs(w) do roll = roll - v if roll <= 0 then return Fn.RarityOrder[i] end end
	return 'common'
end

-- Chest: golden glow, shimmer, opens when the player comes close (or Fn.Open(chest)) and spills loot.
-- opts: loot (2 items), heading, life (120 s; 0 = never). Its light and shimmer go with it.
local chests = {}
function Fn.Chest(pos, opts)
	opts = opts or {}
	local obj = Sigf.Prop(pieceModel('chest'), pos, { heading = opts.heading or 0.0, ground = true, life = opts.life or 120 })
	if not obj then return nil end
	Sigf.Safe('ScaleChest', function() Sigf.ScaleProp(obj, opts.scale or 1.5) end)
	Sigf.Light(obj, { 255, 200, 60 }, 7.0, 9.0, 0)
	chests[obj] = { loot = opts.loot or 2, gold = opts.gold,
		beam = Sigf.Marker(1, pos - vector3(0, 0, 0.9), vector3(0.5, 0.5, 5.0), { 255, 200, 40, 90 }, opts.life or 120),
		fx = Sigf.Fx('core', 'ent_amb_sparking_wires', obj, { loop = true, scale = 0.4, offset = vector3(0, 0, 0.6) }) }
	return obj
end

function Fn.Open(obj)
	local c = chests[obj]
	if not c then return end
	chests[obj] = nil
	Sigf.StopFx(c.fx)
	if c.beam then Sigf.Stop(c.beam) end
	local pos = GetEntityCoords(obj)
	if c.llama then
		Fn.AddMats('wood', 200) Fn.AddMats('brick', 200) Fn.AddMats('metal', 200)
		Fn.Shield(100)
		Sigf.Fx(Sigf.FX.poof[1], Sigf.FX.poof[2], pos, { scale = 1.5 })
	else
		Sigf.Fx(Sigf.FX.firework[1], Sigf.FX.firework[2], pos + vector3(0, 0, 1.0), { scale = 0.4 })
		local keys = { 'ar', 'pump', 'smg', 'scar', 'tac', 'sniper', 'rocket' }
		for i = 1, c.loot do
			local a = (i / c.loot) * 6.28
			if c.gold and i == 1 then Fn.Loot(pos + vector3(math.cos(a) * 1.5, math.sin(a) * 1.5, 0.2), 'ar', 'legendary')
			else Fn.Loot(pos + vector3(math.cos(a) * 1.5, math.sin(a) * 1.5, 0.2), Sigf.Pick(keys), Fn.RollRarity(2)) end
		end
	end
	play('chest', pos)
	Sigf.Remove(obj)
end

-- Supply llama: a piñata full of materials, ammo and shields; open it like a chest.
function Fn.Llama(pos, opts)
	opts = opts or {}
	local obj = Sigf.Prop(pieceModel('llama'), pos, { ground = true, life = opts.life or 120 })
	if obj then
		Sigf.Light(obj, { 160, 90, 255 }, 5.0, 6.0, 0)
		Sigf.Safe('ScaleLlama', function() Sigf.ScaleProp(obj, opts.scale or 1.8) end)
		Fn.Harvestable(obj, 'wood', 0, opts.hits or 5, 'llama')   -- smash it with the pickaxe or bullets
	end
	return obj
end

-- Pick up: chests within 2 m open, loot within 1.5 m goes into the hotbar.
CreateThread(function()
	while true do
		Wait(150)
		local me = PlayerPedId()
		local here = GetEntityCoords(me)
		for obj in pairs(chests) do
			if not DoesEntityExist(obj) then chests[obj] = nil
			elseif #(GetEntityCoords(obj) - here) < 2.2 then Fn.Open(obj) end
		end
		local now = GetGameTimer()
		for id, l in pairs(loot) do
			if l.until_ and now > l.until_ then loot[id] = nil if l.prop then Sigf.Remove(l.prop) end
			elseif #(l.pos - here) < 1.6 then
				loot[id] = nil
				Sigf.Stop(l.beam) Sigf.Stop(l.glow)
				if l.prop then Sigf.Remove(l.prop) end
				local slot = l.slot
				if not slot then slot = 1 while Fn.State.slots[slot] and slot < 5 do slot = slot + 1 end end
				Fn.SetSlot(slot, l.weapon, l.rarity)
				Fn.Select(slot)
				play('pickup')
				SendNUIMessage({ t = 'fnpickup', name = Fn.Weapons[l.weapon].name, hex = Fn.Rarity[l.rarity].hex })
			end
		end
	end
end)

-- ---------- opponents ----------
-- Bots that play like Fortnite players: they fight, and when they get shot they build a wall (or a box) to cover.
-- opts: model(s), weapon, count, health, shield, builds (true), within (m from the arena centre).
Fn.BotModels = { 'a_m_y_skater_01', 'a_m_y_hipster_01', 'a_f_y_hipster_02', 'a_m_y_beach_01', 'a_f_y_beach_01', 'a_m_y_runner_01' }
local bots, fnGroup = {}, nil
local function botGroup()
	if fnGroup then return fnGroup end
	local _, g = AddRelationshipGroup('SIGF_FN')
	SetRelationshipBetweenGroups(5, g, g)
	for _, other in ipairs({ 'SIGF_A', 'SIGF_B', 'PLAYER' }) do
		SetRelationshipBetweenGroups(5, g, GetHashKey(other))
		SetRelationshipBetweenGroups(5, GetHashKey(other), g)
	end
	fnGroup = g
	return g
end

function Fn.Bots(count, opts)
	opts = opts or {}
	local out = {}
	for i = 1, count or 4 do
		local p = Sigf.Ground(opts.center or Sigf.Arena(), opts.within or 40.0) + vector3(0, 0, 0.5)
		local ped = Sigf.Ped(opts.model or Sigf.Pick(Fn.BotModels), p, { enemy = true, weapon = opts.weapon or Fn.Weapons[Sigf.Pick({ 'ar', 'pump', 'smg' })].hash,
			health = opts.health or 100, armor = opts.shield or 50, accuracy = opts.accuracy or 20 })
		if ped then
			-- Battle royale: every bot fights every other bot (and the gangs, and the demo player).
			SetPedRelationshipGroupHash(ped, botGroup())
			TaskCombatHatedTargetsAroundPed(ped, 150.0, 0)
			bots[ped] = { builds = opts.builds ~= false, lastBuild = 0 }
			out[#out + 1] = ped
		end
	end
	Fn.State.alive = Fn.State.alive + #out
	return out
end

CreateThread(function()
	while true do
		Wait(200)
		local now = GetGameTimer()
		for ped, b in pairs(bots) do
			if not DoesEntityExist(ped) or IsPedDeadOrDying(ped, true) then bots[ped] = nil
			elseif b.builds and now - b.lastBuild > 4000 and HasEntityBeenDamagedByAnyPed(ped) then
				ClearEntityLastDamageEntity(ped)
				b.lastBuild = now
				if math.random() < 0.3 then Fn.Box(ped, Sigf.Pick({ 'wood', 'brick' }), { owner = ped, silent = true })
				else Fn.BuildFront('wall', 'wood', ped, { owner = ped }) end
			end
		end
	end
end)

-- ---------- emotes and the win ----------
function Fn.Emote(ped, name, sec)
	local e = Fn.Emotes[name or 'default'] or Fn.Emotes.default
	Sigf.Anim(ped or PlayerPedId(), e[1], e[2], sec or 4, 1)
end

-- "#1 VICTORY ROYALE": banner, slow motion, emote, optional music (mod/sfx/<music>.ogg).
function Fn.Victory(opts)
	opts = opts or {}
	SendNUIMessage({ t = 'fnvictory', title = opts.title or 'VICTORY ROYALE', sub = opts.sub })
	Sigf.Slowmo(0.4, 2.5)
	if opts.music then Sigf.Music(opts.music, { volume = 0.6 }) end
	Fn.Emote(PlayerPedId(), opts.emote or 'default', 6)
	Sigf.Fx(Sigf.FX.firework[1], Sigf.FX.firework[2], GetEntityCoords(PlayerPedId()) + vector3(0, 0, 8.0), { scale = 1.5 })
end

Fn.Names = { 'Cactus Cal', 'Runway Rita', 'Sandy Sam', 'Dusty Dan', 'Hangar Hank', 'Mesa Mia', 'Tumbleweed Tom', 'Desert Dee' }
-- Kills of tracked peds feed the HUD (kill feed, eliminations, players left) when the Fortnite HUD is on.
Sigf.OnKill(function(ped, killer, weapon)
	if not hudOn then return end
	local who = (killer == PlayerPedId()) and 'You' or 'Bot'
	Fn.Elim(who, Fn.Names[(ped % 8) + 1], '')
end)
