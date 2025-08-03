import "Source/Components/Helpers/HintFootstepSound.lua"

FPSPlayer = {}
FPSPlayer.name = "FPSPlayer"
FPSPlayer.sound_step_wood = {}
FPSPlayer.sound_step_rock = {}
FPSPlayer.sound_step_snow = {}
FPSPlayer.sound_step_concrete = {}
FPSPlayer.sound_step_grass = {}
FPSPlayer.sound_step_gravel = {}
FPSPlayer.sound_step_sand = {}
FPSPlayer.sound_step_pavement = {}
FPSPlayer.sound_step_water = {}
FPSPlayer.sound_hit = {}
FPSPlayer.freelookstarted = false
FPSPlayer.freelookmousepos = Vec3(0)
FPSPlayer.freelookrotation = Vec3(0)
FPSPlayer.lookchange = Vec2(0)
FPSPlayer.mousedelta = Vec2(0)
FPSPlayer.currentcameraposition = Vec3(0)
FPSPlayer.lastfootsteptime = 0
FPSPlayer.jumpkey = false
FPSPlayer.running = false
FPSPlayer.lean = 0
FPSPlayer.health = 100
FPSPlayer.maxlean = 0
--FPSPlayer.leanspeed = 1
FPSPlayer.camerashakerotation = Quat(0,0,0,1)
FPSPlayer.smoothedcamerashakerotation = Quat(0,0,0,1)
FPSPlayer.flashlightrotation = Quat(0,0,0,1)
FPSPlayer.weapons = {}
FPSPlayer.initialslot = 0
FPSPlayer.movement = Vec3(0)
FPSPlayer.doResetMousePosition = true
FPSPlayer.raycastdistance = 2.0
FPSPlayer.usePromtTile = nil
camerafog = nil --Fog component'i için değişken.
camerashake = nil --Shake component'i için değişken.
FPSPlayer.leanAngle = 0           -- Anlık eğim açısı
FPSPlayer.maxLeanAngle = 3        -- Maksimum eğim açısı (derece)
FPSPlayer.leanSpeed = 0.03         -- Eğilme hızını ayarlar (0.1-0.3 önerilir)
FPSPlayer.leanReturnSpeed = 0.06  -- Eski konuma dönüş hızı
--[[------------------------------------------------------]]--
--BU KISIM ZEMİNE GÖRE DEĞİŞEN AYAK SESLERİ İÇİN ATANMIŞTIR--
-- Material check helpers (başlangıçta hepsi sıfır)
materialcheckwood_helper     = 0
materialcheckrock_helper     = 0
materialchecksnow_helper     = 0
materialcheckconcrete_helper = 0
materialchecksand_helper     = 0
materialcheckgravel_helper   = 0
materialcheckgrass_helper    = 0
materialcheckpavement_helper = 0
materialcheckwater_helper    = 0

-- Jump check flags (başlangıçta hepsi false)
ftp_wood_jump_check     = false
ftp_rock_jump_check     = false
ftp_snow_jump_check     = false
ftp_concrete_jump_check = false
ftp_sand_jump_check     = false
ftp_gravel_jump_check   = false
ftp_grass_jump_check    = false
ftp_water_jump_check    = false
ftp_pavement_jump_check = false

-- FTP helper flags (başlangıçta hepsi true)
ftp_helpera_1 = true
ftp_helpera_2 = true
ftp_helpera_3 = true
ftp_helpera_4 = true
ftp_helpera_5 = true
ftp_helpera_6 = true
ftp_helpera_7 = true
ftp_helpera_8 = true
ftp_helpera_9 = true
--BU KISIM ZEMİNE GÖRE DEĞİŞEN AYAK SESLERİ İÇİN ATANMIŞTIR--
--[[------------------------------------------------------]]--

function FPSPlayer:UpdateCameraLean(window)  
    if not window then
        window = ActiveWindow()
        if not window then return end
    end

    local targetLean = 0

    -- Sağ/Sol girişine göre hedef açıyı belirle
    if window:KeyDown(KEY_A) then
        targetLean = self.maxLeanAngle
    elseif window:KeyDown(KEY_D) then
        targetLean = -self.maxLeanAngle
    end

    -- Eğimi yumuşak şekilde hedefe doğru hareket ettir
    if self.leanAngle < targetLean then
        self.leanAngle = math.min(self.leanAngle + self.leanSpeed * 10, targetLean)
    elseif self.leanAngle > targetLean then
        self.leanAngle = math.max(self.leanAngle - self.leanSpeed * 10, targetLean)
    end

    -- Mevcut kamera rotasyonunu al
    local baseRot = self.camera:GetRotation(true)

    -- Eğer CameraShake aktifse, onun değerlerini ekle
    local shakeX, shakeY = 0, 0
    if _G.CURRENT_SHAKE_X then shakeX = _G.CURRENT_SHAKE_X end
    if _G.CURRENT_SHAKE_Y then shakeY = _G.CURRENT_SHAKE_Y end

    -- Lean ve shake'i birleştirerek uygula
    self.camera:SetRotation(
        baseRot.x + shakeX,
        baseRot.y + shakeY,
        self.leanAngle,
        true
    )
end

function FPSPlayer:LoadSounds(path, tbl, count)
    for n = 1, count do
        tbl[n] = LoadSound(path .. n .. ".wav")
    end
end

function FPSPlayer:Start()

    camerafog = self.camera
    camerashake = self.camera
    local entity = self.entity

    self.currentcameraposition = self.camera:GetPosition(true)
    self.camera:SetRenderLayers(1)
    self.camera:SetTessellation(4)

    entity:SetPhysicsMode(PHYSICS_PLAYER)
    if entity:GetMass() == 0.0 then entity:SetMass(78) end
    entity:SetCollisionType(COLLISION_PLAYER)
    entity:SetShadows(false)
    entity:SetRenderLayers(0)
    entity:SetNavObstacle(false)

    if self.navmesh then
        self.agent = CreateNavAgent(self.navmesh, 0.25, 1.8)
        self.agent:SetPosition(entity:GetPosition(true))
    end
    
    self.flashlightrotation = self.camera:GetQuaternion(true)
    self:Listen(EVENT_KEYDOWN, nil)
    self:Listen(EVENT_KEYUP, nil)

    for n = 1, 3 do self.sound_hit[n] = LoadSound("Sound/Impact/bodypunch" .. n .. ".wav") end

-- Jump sounds
    self.sound_jump_wood     = LoadSound("Sound/Footsteps/Wood/jump.wav")
    self.sound_jump_rock     = LoadSound("Sound/Footsteps/Rock/jump.wav")
    self.sound_jump_snow     = LoadSound("Sound/Footsteps/Snow/jump.wav")
    self.sound_jump_concrete = LoadSound("Sound/Footsteps/Concrete/jump.wav")
    self.sound_jump_sand     = LoadSound("Sound/Footsteps/Sand/jump.wav")
    self.sound_jump_gravel   = LoadSound("Sound/Footsteps/Gravel/jump.wav")
    self.sound_jump_grass    = LoadSound("Sound/Footsteps/Grass/jump.wav")
    self.sound_jump_pavement = LoadSound("Sound/Footsteps/Pavement/jump.wav")
    self.sound_jump_water    = LoadSound("Sound/Footsteps/Water/jump.wav")  

    -- Step sounds
    self:LoadSounds("Sound/Footsteps/Wood/step", self.sound_step_wood, 4)
    self:LoadSounds("Sound/Footsteps/Rock/step", self.sound_step_rock, 4)
    self:LoadSounds("Sound/Footsteps/Snow/step", self.sound_step_snow, 4)
    self:LoadSounds("Sound/Footsteps/Concrete/step", self.sound_step_concrete, 4)
    self:LoadSounds("Sound/Footsteps/Sand/step", self.sound_step_sand, 4)
    self:LoadSounds("Sound/Footsteps/Gravel/step", self.sound_step_gravel, 4)
    self:LoadSounds("Sound/Footsteps/Grass/step", self.sound_step_grass, 4)
    self:LoadSounds("Sound/Footsteps/Pavement/step", self.sound_step_pavement, 4)
    self:LoadSounds("Sound/Footsteps/Water/step", self.sound_step_water, 4)

    sound_flashlight = LoadSound("Sound/Items/flashlightswitch.wav")

    -- Dead body collider
    local scale = 0.25
    local points = {
        Vec3(0.5, 0.5, 0.5)*scale, Vec3(-0.5, 0.5, 0.5)*scale,
        Vec3(0.5,-0.5, 0.5)*scale, Vec3(-0.5,-0.5, 0.5)*scale,
        Vec3(0.5, 0.5,-0.5)*scale, Vec3(-0.5, 0.5,-0.5)*scale,
        Vec3(0.5,-0.5,-0.5)*scale, Vec3(-0.5,-0.5,-0.5)*scale,
        Vec3(0,0,-0.667)*scale, Vec3(0,0,0.667)*scale,
        Vec3(0,-0.667,0)*scale, Vec3(0,0.667,0)*scale,
        Vec3(-0.667,0,0)*scale, Vec3(0.667,0,0)*scale
    }
    deadbodycollider = CreateConvexHullCollider(points)

    entity:AddTag("player")
    entity:AddTag("good")
    entity.health = 100
end

function FPSPlayer:Kill(attacker)
    self.camera:SetParent(nil)
    self.camera:SetCollider(deadbodycollider)
    self.camera:SetVelocity(self.entity:GetVelocity())
    self.camera:SetMass(10)
    self.camera:SetCollisionType(COLLISION_DEBRIS)
    self.camera:AddTorque(50, Random(-20, 20), Random(-20, 20))

    if self.weapon then
        self.weapon:DetachFromPlayer(self)
    end

    self.weapon = nil
    self.entity:SetMass(0)
    self.entity:SetCollisionType(COLLISION_NONE)
    self.entity:SetCollider(nil)
    self.entity:SetPhysicsMode(PHYSICS_DISABLED)

    if self.flashlight then
        self.flashlight:SetHidden(true)
    end

    self:Disable()
end

function FPSPlayer:ToggleFlashlight()
    if self.flashlight == nil or self.flashlight:GetHidden() then
        self:ShowFlashlight()
    else
        self:HideFlashlight()
    end
end

function FPSPlayer:ShowFlashlight()
    if self.sound_flashlight then 
        self.sound_flashlight:Play() 
    end

    if self.flashlight == nil or self.flashlight:GetHidden() then
        if self.flashlight == nil then
            local world = self.entity:GetWorld()
            self.flashlight = CreateSpotLight(world)
            self.flashlight:SetConeAngles(20, 10)
            self.flashlight:SetRange(0.01, 10)
        end
        self.flashlightrotation = self.camera:GetQuaternion(true)
        self.flashlight:SetHidden(false)
        self:UpdateFlashlight()
        self:FireOutputs("ShowFlashlight")
    end
end

function FPSPlayer:HideFlashlight()
    if self.flashlight then
        self.flashlight:SetHidden(true)
        self:FireOutputs("HideFlashlight")
    end
end

function FPSPlayer:ProcessEvent(e)
    if not self:GetEnabled() then return true end
    if self.entity.health <= 0 then return true end

    local world = self.entity:GetWorld()

    if e.id == EVENT_KEYDOWN then
        if e.data == KEY_SPACE then
            self.jumpkey = true
        elseif e.data == KEY_SHIFT then
            -- if self.weapon and not self.weapon:PlayerCanRun() then return true end
            -- self.running = true
        elseif e.data == KEY_F then
            self:ToggleFlashlight()
elseif e.data == KEY_E then
    if world and self.camera then
        local window = ActiveWindow()
        local framebuffer = window:GetFramebuffer()
        local fbsize = framebuffer:GetSize()
        local cx = Round(fbsize.x / 2)
        local cy = Round(fbsize.y / 2)

        -- Raycast (Pick) kontrolü
        local pickInfo = self.camera:Pick(framebuffer, cx, cy, 0, true)
        if pickInfo.success and pickInfo.entity and pickInfo.entity:GetDistance(self.entity) < self.raycastdistance then
            for _, component in ipairs(pickInfo.entity.components) do
                if component.Use and type(component.Use) == "function" and component:GetEnabled() then
                    component:Use(self.entity) -- Hedef objenin Use() fonksiyonunu çağır
                    break
                end
            end
        end
    end
end
    elseif e.id == EVENT_KEYUP then
        if e.data == KEY_SPACE then
            self.jumpkey = false
        elseif e.data == KEY_SHIFT then
            -- self.running = false
        end
    end
    return true
end

function FPSPlayer:UnCrouchFilter(entity, extra)
    if self.entity == extra then
        return false
    end
    if entity:GetCollider() == nil or entity:GetCollisionType() == COLLISION_NONE or entity:GetCollisionType() == COLLISION_TRIGGER then
        return false
    end
    return true
end

function FPSPlayer:Load(properties, binstream, scene, flags, extra)
    properties.health = self.entity.health
end

function FPSPlayer:Load(properties, binstream, scene, flags, extra)
    local world = self.entity:GetWorld()
    local entity = self.entity

	self.weapons = {}
	for n = 0, 3 do
        local key = "slot" .. tostring(n)
		if type(properties[key]) == "string" then
			local path = properties[key]
            local prefab = LoadPrefab(world, path)
			self.weapons[n + 1] = prefab
        end
    end
    
    if not self.camera then
        self.camera = CreateCamera(world)
        self.camera:Listen()
        local font = LoadFont("Fonts/arial.ttf")
        local use = LoadMaterial("Materials/HUD/Use.mat") 
        --mat:SetTexture(tex, TEXTURE_BASE)
        self.usePromtTile = CreateTile(self.camera, 48, 48)
        self.usePromtTile:SetMaterial(use)
    end

    local pos = entity:GetPosition(true)
    self.camera:SetPosition(pos.x, pos.y + self.eyeheight, pos.z)
    self.camera:SetRotation(0, 0, 0)
    self.camera:SetFov(self.fov)

    if type(self.selectedslot) ~= "number" then
        self.selectedslot = self.initialslot + 1
    end
    if self.weapons[self.selectedslot] then
        local entity = self.weapons[self.selectedslot]
        local weapon = entity:GetComponent("FPSGun")
        if not weapon then weapon = entity:GetComponent("FPSMelee") end
        if weapon then weapon:AttachToPlayer(self) end
    end

    local n
    for n = 1, #scene.navmeshes do
        self.navmesh = scene.navmeshes[n]
    end

    entity.health = self.health
    self.health = nil

    return true
end

function FPSPlayer:Update()

    if not self:GetEnabled() then return end
    if self.entity.health <= 0 then return end

    -- Disable running if it is not allowed
    if self.running and self.weapon and not self.weapon:PlayerCanRun() then
        self.running = false
    end
    self.movement = Vec3(0, 0, 0)

    local jump = 0
    local crouchkey = false
    local crouched = false

    local entity = self.entity
    local world = entity:GetWorld()
    local window = ActiveWindow()

    if window then
        self.running = window:KeyDown(KEY_SHIFT)

        local framebuffer = window:GetFramebuffer()
        local clientsize = window:ClientSize()

        local cx = Round(clientsize.x / 2)
        local cy = Round(clientsize.y / 2)
        local mpos = window:GetMousePosition()
        if self.doResetMousePosition then
            window:SetMousePosition(cx, cy)
        end
        local centerpos = window:GetMousePosition()

        if self.freelookstarted then
            local looksmoothing = self.mousesmoothing
            local lookspeed = self.mouselookspeed / 10.0

            local dx = mpos.x - centerpos.x
            local dy = mpos.y - centerpos.y

            if looksmoothing > 0.0 then
                self.mousedelta.x = CurveValue(dx, self.mousedelta.x, 1.0 + looksmoothing)
                self.mousedelta.y = CurveValue(dy, self.mousedelta.y, 1.0 + looksmoothing)
            else
                self.mousedelta.x = dx
                self.mousedelta.y = dy
            end

            self.freelookrotation.x = Clamp(self.freelookrotation.x + self.mousedelta.y * lookspeed, -90.0, 90.0)
            self.freelookrotation.y = self.freelookrotation.y + self.mousedelta.x * lookspeed
            self.camera:SetRotation(self.freelookrotation, true)
            self.freelookmousepos = Vec3(mpos.x, mpos.y)
        else
            self.freelookstarted = true
            self.freelookrotation = self.camera:GetRotation(true)
            self.freelookmousepos = Vec3(window:GetMousePosition().x, window:GetMousePosition().y)
            window:SetCursor(CURSOR_NONE)
        end

        if window:KeyHit(KEY_G) then
            local a = Random(360.0)
            self.camerashakerotation = Quat(Vec3(Cos(a) * 30.0, Sin(a) * 30.0, 0.0))
        end

        -- Camera shake when hit
        local speed = 0.1
        local q = Vec4(self.camerashakerotation.x, self.camerashakerotation.y, self.camerashakerotation.z, self.camerashakerotation.w)
        local diff = q:Length()
        self.camerashakerotation = self.camerashakerotation:Slerp(Quat(0, 0, 0, 1), math.min(1.0, speed / diff))
        self.smoothedcamerashakerotation = self.smoothedcamerashakerotation:Slerp(self.camerashakerotation, 0.5)
        self.camera:Turn(self.smoothedcamerashakerotation:ToEuler(), false)

        -- We use the base class' enabled bool to lock the movement.
        if self:GetEnabled() then
            local speed = self.movespeed
            crouchkey = window:KeyDown(KEY_C)
            if entity:GetAirborne() then
                speed = speed * 0.25
            else
                if self.running then
                    speed = speed * 2.0
                elseif crouched then
                    speed = speed * 0.5
                end

                if self.jumpkey and not crouched then
                    jump = self.jumpforce
                    local concretejump = self.sound_jump_concrete
                    if ftp_helpera_1 == true and materialcheckwood ~= -1 or ftp_wood_jump_check == true then
                        if self.sound_jump_wood then self.sound_jump_wood:Play() end
                    elseif ftp_helpera_2 == true and materialcheckrock ~= -1 or ftp_rock_jump_check == true then
                        if self.sound_jump_rock then self.sound_jump_rock:Play() end
                    elseif ftp_helpera_3 == true and materialchecksnow ~= -1 or ftp_snow_jump_check == true then
                        if self.sound_jump_snow then self.sound_jump_snow:Play() end
                    elseif ftp_helpera_4 == true and materialcheckconcrete ~= -1 or ftp_concrete_jump_check == true then
                        if self.sound_jump_concrete then self.sound_jump_concrete:Play() end
                    elseif ftp_helpera_5 == true and materialchecksand ~= -1 or ftp_sand_jump_check == true then
                        if self.sound_jump_sand then self.sound_jump_sand:Play() end
                    elseif ftp_helpera_6 == true and materialcheckgravel ~= -1 or ftp_gravel_jump_check == true then
                        if self.sound_jump_gravel then self.sound_jump_gravel:Play() end
                    elseif ftp_helpera_7 == true and materialcheckgrass ~= -1 or ftp_grass_jump_check == true then
                        if self.sound_jump_grass then self.sound_jump_grass:Play() end
                    elseif ftp_helpera_8 == true and materialcheckpavement ~= -1 or ftp_pavement_jump_check == true then
                        if self.sound_jump_pavement then self.sound_jump_pavement:Play() end
                    elseif ftp_helpera_9 == true and materialcheckwater ~= -1 or ftp_water_jump_check == true then
                        if self.sound_jump_water then self.sound_jump_water:Play() end
                    end
                end
            end

            if window:KeyDown(KEY_D) then self.movement.x = self.movement.x + speed end
            if window:KeyDown(KEY_A) then self.movement.x = self.movement.x - speed end
            if window:KeyDown(KEY_W) then self.movement.z = self.movement.z + speed end
            if window:KeyDown(KEY_S) then self.movement.z = self.movement.z - speed end
            if self.movement.x ~= 0.0 and self.movement.z ~= 0.0 then
                self.movement = self.movement * 0.707
            end
            if jump ~= 0.0 then
                self.movement.x = self.movement.x * self.jumplunge
                if self.movement.z > 0.0 then
                    self.movement.z = self.movement.z * self.jumplunge
                end
            end
        end
        --to decide later if we want to show or hide prompt tile
        local doHideTile = true
        --cx and cy are screen center coordinates which were created above
        local pickInfo = self.camera:Pick(framebuffer, cx, cy, 0, true)
        if pickInfo.success and pickInfo.entity and pickInfo.entity:GetDistance(self.entity) < self.raycastdistance then
            --iterate all components of picked entity
            for _, component in ipairs(pickInfo.entity.components) do
                --find out if component of picked entity have Use function and it's enabled
                if component.Use and type(component.Use) == "function" and component:GetEnabled() then
                    --move tile to center of screen
                    self.usePromtTile:SetPosition(cx, cy)
                    doHideTile = false
                    --stop iterating once we found usable object
                    break
                end
            end
        end
       self.usePromtTile:SetHidden(doHideTile)
    end

    entity:SetInput(self.camera.rotation.y, self.movement.z, self.movement.x, jump, crouchkey)

    self:UpdateCameraLean(window)

    if self.agent then self.agent:SetPosition(entity:GetPosition(true)) end

    local eye = self.eyeheight
    if entity:GetCrouched() then
        if not entity:GetAirborne() then eye = self.croucheyeheight end
        crouched = true
    else
        eye = self.eyeheight
        crouched = false
    end

    local y = TransformPoint(self.currentcameraposition, nil, entity).y
    local h = eye
    if not entity:GetAirborne() and (y < eye or eye ~= self.eyeheight) then
        h = Mix(y, eye, 0.25)
    end
    self.currentcameraposition = TransformPoint(0, h, 0, entity, nil)
    self.camera:SetPosition(self.currentcameraposition, true)

    if self.maxlean > 0.0 then
        local localpos = TransformPoint(self.camera:GetPosition(true), nil, entity)
        if window:KeyDown(KEY_E) then self.lean = self.lean - self.leanspeed end
        if window:KeyDown(KEY_Q) then self.lean = self.lean + self.leanspeed end
        self.lean = Clamp(self.lean, -self.maxlean, self.maxlean)
        if self.lean ~= 0.0 then
            self.camera:SetPosition(entity:GetPosition(true), true)
            local r = self.camera:GetRotation(true)
            self.camera:SetRotation(0, r.y, 0, true)
            self.camera:Turn(0, 0, self.lean)
            self.camera:Move(localpos)
            self.camera:Turn(r.x, 0, 0)
        end
        if not window:KeyDown(KEY_E) and not window:KeyDown(KEY_Q) then
            if self.lean > 0.0 then
                self.lean = self.lean - self.leanspeed
                self.lean = math.max(self.lean, 0.0)
            elseif self.lean < 0.0 then
                self.lean = self.lean + self.leanspeed
                self.lean = math.min(self.lean, 0.0)
            end
        end
    end

    self:UpdateFlashlight()
    self:UpdateFootsteps()

    self.jumpkey = false
end

function FPSPlayer:UpdateFootsteps()
    local entity = self.entity
    local world = entity:GetWorld()
    if not world then return end

    if not entity:GetAirborne() and self.movement:Length() > 0.0 then
        local now = world:GetTime()
        local speed = entity:GetVelocity().xz:Length()
        local footsteptime = Clamp(500.0 * self.movespeed / speed, 250.0, 1000.0)

        if now - self.lastfootsteptime > footsteptime then
            self.lastfootsteptime = now

            -- RAYCAST: Oyuncunun hemen altına doğru bir ışın gönder
            local pos = self.entity:GetPosition(true)
            local pickinfo = world:Pick(pos, pos - Vec3(0, 0.6, 0), 0, true) -- Aşağıya doğru raycast


            --[[
            Print("Raycast başarılı mı?: " .. tostring(pickinfo.success))
            Print("Çarpan entity: " .. tostring(pickinfo.entity))
            Print("Çarpan mesh: " .. tostring(pickinfo.face))
            Print("terrain: " .. tostring(pickinfo.meshlayer))
            Print("Materyal: " .. tostring(pickinfo.face and pickinfo.face:GetMaterial()))
            --]]

            local materialpath3 = nil
            local materialpath = nil


            if pickinfo.success and pickinfo.face and pickinfo.face:GetMaterial() then
                materialpath = pickinfo.face:GetMaterial().path 
                materialpath2 = StripAll(materialpath)
                --Print(materialpath2)
                materialcheckwood = Find(materialpath2, "Wood")
                materialcheckrock = Find(materialpath2, "Rock")
                materialchecksnow = Find(materialpath2, "Snow")
                materialcheckconcrete = Find(materialpath2, "Concrete")
                materialchecksand = Find(materialpath2, "Sand")
                materialcheckpavement = Find(materialpath2, "Pavement")
                materialcheckgrass = Find(materialpath2, "Grass")
                materialcheckwater = Find(materialpath2, "Water")
                materialcheckgravel = Find(materialpath2, "Gravel")
            end 
            
            if pickinfo.success and pickinfo.mesh and pickinfo.mesh:GetMaterial().path  then
                materialpath = pickinfo.mesh:GetMaterial().path 
                materialpath2 = StripAll(materialpath)
                --Print(materialpath2)
                materialcheckwood = Find(materialpath2, "Wood")
                materialcheckrock = Find(materialpath2, "Rock")
                materialchecksnow = Find(materialpath2, "Snow")
                materialcheckconcrete = Find(materialpath2, "Concrete")
                materialchecksand = Find(materialpath2, "Sand")
                materialcheckpavement = Find(materialpath2, "Pavement")
                materialcheckgrass = Find(materialpath2, "Grass")
                materialcheckwater = Find(materialpath2, "Water")
                materialcheckgravel = Find(materialpath2, "Gravel")
            end
            
            if pickinfo.entity == nil then
                materialcheckwood = -1
                materialcheckrock = -1
            end
            --Print(materialcheckwood)
            local wood = self.sound_step_wood
            local rock = self.sound_step_rock
            local snow = self.sound_step_snow
            local concrete = self.sound_step_concrete
            local sand = self.sound_step_sand
            local pavement = self.sound_step_pavement
            local grass = self.sound_step_grass
            local water = self.sound_step_water
            local gravel = self.sound_step_gravel
            if ftp_helpera_1 == true and materialcheckwood ~= -1 or materialcheckwood_helper == 1 then
                local index = Floor(math.random(1, #wood))
                wood[index]:Play()
            elseif ftp_helpera_2 == true and materialcheckrock ~= -1 or materialcheckrock_helper == 1 then
                local index = Floor(math.random(1, #rock))
                rock[index]:Play()
            elseif ftp_helpera_3 == true and materialchecksnow ~= -1 or materialchecksnow_helper == 1 then
                local index = Floor(math.random(1, #snow))
                snow[index]:Play()
            elseif ftp_helpera_4 == true and materialcheckconcrete ~= -1 or materialcheckconcrete_helper == 1 then
                local index = Floor(math.random(1, #concrete))
                concrete[index]:Play()
            elseif ftp_helpera_5 == true and materialchecksand ~= -1 or materialchecksand_helper == 1 then
                local index = Floor(math.random(1, #sand))
                sand[index]:Play()
            elseif ftp_helpera_6 == true and materialcheckgravel ~= -1 or materialcheckgravel_helper == 1 then
                local index = Floor(math.random(1, #gravel))
                gravel[index]:Play()
            elseif ftp_helpera_7 == true and materialcheckgrass ~= -1 or materialcheckgrass_helper == 1 then
                local index = Floor(math.random(1, #grass))
                grass[index]:Play()
            elseif ftp_helpera_8 == true and materialcheckpavement ~= -1 or materialcheckpavement_helper == 1 then
                local index = Floor(math.random(1, #pavement))
                pavement[index]:Play()
            elseif ftp_helpera_9 == true and materialcheckwater ~= -1 or materialcheckwater_helper == 1 then
                local index = Floor(math.random(1, #water))
                water[index]:Play()
            else 
                local index = Floor(math.random(1, #pavement))
                pavement[index]:Play()
            end
        end
    end
end

function FPSPlayer:UpdateFlashlight()
    if self.flashlight then
        local pos = self.camera:GetPosition(true)
        pos = pos + TransformNormal(0, -1, 0, self.camera, nil) * 0.25
        pos = pos + TransformNormal(1, 0, 0, self.camera, nil) * 0.25
        self.flashlight:SetPosition(pos, true)
        self.flashlightrotation = self.flashlightrotation:Slerp(self.camera:GetQuaternion(true), 0.2)
        self.flashlight:SetRotation(self.flashlightrotation, true)
    end
end

function FPSPlayer:Damage(amount, attacker)
    local a = math.random() * 360.0
    self.camerashakerotation = Quat(Vec3(math.cos(a) * 45.0, math.sin(a) * 45.0, 0.0))
    if #self.sound_hit > 0 then
        local index = Floor(math.random(1, #self.sound_hit))
        if self.sound_hit[index] then
            self.sound_hit[index]:Play()
        end
    end
end

RegisterComponent("FPSPlayer", FPSPlayer)
return FPSPlayer
