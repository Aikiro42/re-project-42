require "/scripts/poly.lua"
require "/scripts/util.lua"
require "/scripts/interp.lua"
require "/items/active/weapons/weapon.lua"

local oldWeaponInit = Weapon.init
local oldWeaponUpdate = Weapon.update
local oldWeaponDamageSource = Weapon.damageSource

function Weapon:init()

  self.recoilAmount = 0
  self.stanceProgress = 1

  self.relativeWeaponRotation = 0
  self.relativeArmRotation = 0

  self.baseArmRotation = 0
  self.baseWeaponRotation = 0

  self.armFrameAnimations = true

  self.stanceInterpolationMethod = "sin"

  oldWeaponInit(self)

  self.baseOffset = config.getParameter("baseOffset", {0, 0})
  self.weaponOffset = self.weaponOffset or {0, 0}
  self.oldWeaponOffset = self.weaponOffset
  self.newWeaponOffset = self.weaponOffset

  self.oldAimAngle = self.aimAngle or 0

  self.stanceTimer = {
    current = 0,
    max = 0,
    progress = 1
  }

  self.targetBodyRotation = 0
  
end

function Weapon:update(dt, fireMode, shiftHeld)
  
  oldWeaponUpdate(self, dt, fireMode, shiftHeld)

  activeItem.setScriptedAnimationParameter("ownerVelocity", mcontroller.velocity())
  activeItem.setScriptedAnimationParameter("ownerCrouching", mcontroller.crouching())
  
  if self.stanceProgress < 1 then -- prevent from computing when unnecessary

    if self.stanceTimer.max > 0 then
      self.stanceProgress = self.stanceTimer.progress
    else
      self.stanceProgress = math.min(1, self.stanceProgress + dt * (self.stanceTransitionSpeedMult or 4))
    end
      
    if self.stance.velocity then
      mcontroller.setVelocity(self.stance.velocity)
    end

    if self.armAngularVelocity == 0 then
      self.baseArmRotation = interp[self.stanceInterpolationMethod](self.stanceProgress, self.oldArmRotation or 0, self.newArmRotation)
    end

    if self.weaponAngularVelocity == 0 then
      self.baseWeaponRotation = interp[self.stanceInterpolationMethod](self.stanceProgress, self.oldWeaponRotation or 0, self.newWeaponRotation)
    end

    self.weaponOffset = {
      interp[self.stanceInterpolationMethod](self.stanceProgress, self.oldWeaponOffset[1], self.newWeaponOffset[1]),
      interp[self.stanceInterpolationMethod](self.stanceProgress, self.oldWeaponOffset[2], self.newWeaponOffset[2])
    }

  end

  if self.stanceTimer.max > 0 then
    self.stanceTimer.current = self.stanceTimer.current + dt
    self.stanceTimer.progress = self.stanceTimer.current / self.stanceTimer.max
  end

  mcontroller.setRotation(
    self.aimDirection
    * interp[self.stanceInterpolationMethod](self.stanceTimer.progress, 0, -2 * math.pi * (self.stance.flips or 0))
  )

  if not mcontroller.groundMovement() then
    if self.stance.airborneControlVelocity then
      mcontroller.controlApproachVelocity(self.stance.airborneControlVelocity.velocity, self.stance.airborneControlVelocity.force)
    elseif self.stance.airborneVelocity then
      mcontroller.setVelocity(self.stance.airborneControlVelocity)
    end  
  else
    if self.stance.controlVelocity then
      mcontroller.controlApproachVelocity(self.stance.controlVelocity.velocity, self.stance.controlVelocity.force)
    elseif self.stance.velocity then
      mcontroller.setVelocity(self.stance.velocity)
    end  
  end


  self.relativeArmRotation = self.baseArmRotation + self.recoilAmount/2
  self.relativeWeaponRotation = self.baseWeaponRotation + self.recoilAmount/2
  
  if self.stance then
    self:updateAim()
    self.baseArmRotation = self.baseArmRotation + self.armAngularVelocity * dt
    self.baseWeaponRotation = self.baseWeaponRotation + self.weaponAngularVelocity * dt
  end

end

function Weapon:updateAim()
  for _,group in pairs(self.transformationGroups) do
    animator.resetTransformationGroup(group.name)
    animator.translateTransformationGroup(group.name, group.offset)
    animator.rotateTransformationGroup(group.name, group.rotation, group.rotationCenter)
    animator.translateTransformationGroup(group.name, self.weaponOffset)
    animator.rotateTransformationGroup(group.name, self.relativeWeaponRotation, self.relativeWeaponRotationCenter)
  end

  local aimAngle, aimDirection = activeItem.aimAngleAndDirection(self.aimOffset, activeItem.ownerAimPosition())

  if self.stance.allowRotate then
    self.aimAngle = aimAngle
    self.oldAimAngle = self.aimAngle
    self.newAimAngle = nil
  elseif self.newAimAngle then
    self.aimAngle = interp[self.stanceInterpolationMethod](self.stanceProgress, self.oldAimAngle, self.newAimAngle)
  end
  activeItem.setArmAngle(self.aimAngle + self.baseArmRotation + self.recoilAmount/2)

  local isPrimary = activeItem.hand() == "primary"
  if isPrimary then
    -- primary hand weapons should set their aim direction whenever they can be flipped,
    -- unless paired with an alt hand that CAN'T flip, in which case they should use that
    -- weapon's aim direction
    if self.stance.allowFlip then
      if activeItem.callOtherHandScript("dwDisallowFlip") then
        local altAimDirection = activeItem.callOtherHandScript("dwAimDirection")
        if altAimDirection then
          self.aimDirection = altAimDirection
        end
      else
        self.aimDirection = aimDirection
      end
    end
  elseif self.stance.allowFlip then
    -- alt hand weapons should be slaved to the primary whenever they can be flipped
    local primaryAimDirection = activeItem.callOtherHandScript("dwAimDirection")
    if primaryAimDirection then
      self.aimDirection = primaryAimDirection
    else
      self.aimDirection = aimDirection
    end
  end

  activeItem.setFacingDirection(self.aimDirection)

  if self.armFrameAnimations then
    activeItem.setFrontArmFrame(self.stance.frontArmFrame)
    activeItem.setBackArmFrame(self.stance.backArmFrame)
  end
end

function Weapon:setCameraFocusEntity(entityID, override)
  if override
  or not self.cameraFocusEntity
  or not world.entityExists(self.cameraFocusEntity) then
    self.cameraFocusEntity = entityID
    activeItem.setCameraFocusEntity(self.cameraFocusEntity)
  end
end

function Weapon:screenShake(intensity)
  intensity = (intensity or 0.3)/2


  local offset = vec2.rotate({intensity, 0}, sb.nrand(math.pi, math.pi))

  local cam = world.spawnProjectile(
    "project42neoscreenshakeprojectile",
    vec2.add(mcontroller.position(), offset),
    activeItem.ownerEntityId(),
    {1, 0},
    true
  )

  self:setCameraFocusEntity(cam)

end

function Weapon:setStance(stance)

  if not stance then return end
  if stance.disabled then return end
  if self.stance == stance then return end

  local snapWeapon = stance.snap or (self.weaponAngularVelocity and self.weaponAngularVelocity ~= 0)
  local snapArm = stance.snap or (self.armAngularVelocity and self.armAngularVelocity ~= 0)

  if stance.velocity ~= nil then
    mcontroller.setVelocity(stance.velocity)
  end

  if stance.momentum ~= nil then
    local appliedMomentum
    if stance.aimMomentum then
      local aimAngle, aimDirection = activeItem.aimAngleAndDirection(0, activeItem.ownerAimPosition())
      appliedMomentum = vec2.rotate(stance.momentum, aimAngle)
      appliedMomentum[1] = aimDirection * appliedMomentum[1]
    else
      appliedMomentum = stance.momentum
    end
    mcontroller.addMomentum(appliedMomentum)
  end

  if stance.weaponHidden ~= nil then
    activeItem.setHoldingItem(not stance.weaponHidden)
  else
    activeItem.setHoldingItem(true)
  end

  if stance.sheathVisible ~= nil then
    activeItem.setScriptedAnimationParameter("sheathVisible", stance.sheathVisible)
  end
  if stance.sheathStatus ~= nil then
    activeItem.setScriptedAnimationParameter("sheathStatus", stance.sheathStatus)
  end

  activeItem.setScriptedAnimationParameter("sheathOffset", stance.sheathOffset or {0, 0})
  activeItem.setScriptedAnimationParameter("sheathRotation", stance.sheathRotation or 0)
  activeItem.setScriptedAnimationParameter("sheathDirectives", stance.sheathDirectives or "")

  self.newWeaponRotation = util.toRadians(stance.weaponRotation or 0)
  self.newWeaponOffset = stance.weaponOffset or {0, 0}
  self.newArmRotation = util.toRadians(stance.armRotation or 0)
  
  self.targetBodyRotation = (stance.flips or 0) * -2 * math.pi

  self.stanceInterpolationMethod = stance.interpolationMethod or "sin"
  
  -- snap if was rotating
  self.oldWeaponRotation = snapWeapon and self.newWeaponRotation or self.relativeWeaponRotation
  self.oldWeaponOffset = snapWeapon and self.newWeaponOffset or self.weaponOffset
  self.oldArmRotation = snapArm and self.newArmRotation or self.relativeArmRotation
  self.oldAimAngle = stance.snap and stance.aimAngle or self.oldAimAngle

  -- stance.allowRotate = stance.allowRotate == nil or stance.allowRotate
  -- stance.allowFlip = stance.allowFlip == nil or stance.allowFlip

  self.stance = stance
  
  self.newAimAngle = stance.aimAngle

  self.stanceTimer = {
    current = 0,
    max = stance.duration or 0,
    progress = 0
  }
  self.stanceTransitionSpeedMult = stance.transitionSpeedMult
  self.weaponOffset = self.oldWeaponOffset

  self.relativeWeaponRotationCenter = stance.weaponRotationCenter or {0, 0}
  
  self.armAngularVelocity = util.toRadians(stance.armAngularVelocity or 0)
  self.weaponAngularVelocity = util.toRadians(stance.weaponAngularVelocity or 0)

  if snapWeapon then
    self.oldWeaponRotation = self.newWeaponRotation
    self.baseWeaponRotation = self.newWeaponRotation
    self.relativeWeaponRotation = self.baseWeaponRotation + self.recoilAmount/2
  end

  if snapArm then
    self.oldArmRotation = self.newArmRotation
    self.baseArmRotation = self.newArmRotation
    self.relativeArmRotation = self.baseArmRotation + self.recoilAmount/2
  end

  animator.setGlobalTag("stanceDirectives", stance.weaponDirectives or "")
  
  for stateType, state in pairs(stance.animationStates or {}) do
    animator.setAnimationState(stateType, state)
  end

  for light, active in pairs(stance.lights or {}) do
    animator.setLightActive(light, active)
  end

  for _, soundName in pairs(stance.playSounds or {}) do
    animator.playSound(soundName)
  end

  for _, soundName in pairs(stance.loopSounds or {}) do
    animator.playSound(soundName, -1)
  end

  for _, soundName in pairs(stance.stopSounds or {}) do
    animator.stopAllSounds(soundName)
  end

  for _, particleEmitterName in pairs(stance.burstParticleEmitters or {}) do
    animator.burstParticleEmitter(particleEmitterName)
  end

  if self.armFrameAnimations then
    activeItem.setFrontArmFrame(self.stance.frontArmFrame)
    activeItem.setBackArmFrame(self.stance.backArmFrame)
  end
  activeItem.setTwoHandedGrip(stance.twoHanded or false)
  activeItem.setRecoil(stance.recoil == true)

  self.stanceProgress = stance.snap and 1 or 0

end

function Weapon:setDamage(damageConfig, damageArea, damageTimeout)
-- function Weapon:setDamage(damageConfig, damageArea, damageTimeout, offset, rotation, lockRotation)
  --[[
  if damageArea then
    local mcRotation = mcontroller.rotation()
    local mcDirection = mcontroller.facingDirection()
    damageArea = poly.rotate(damageArea, rotation + (lockRotation and 0 or mcRotation * mcDirection))
    damageArea = poly.translate(damageArea, vec2.rotate(offset, lockRotation and 0 or mcRotation * mcDirection))
  end
  --]]
  self.damageWasSet = true
  self.damageCleared = false
  activeItem.setItemDamageSources({ self:damageSource(damageConfig, damageArea, damageTimeout) })
end

function getShiftAbility()
  local shiftAbilityConfig = config.getParameter("shiftAbility")
  if shiftAbilityConfig then
    return getAbility("shift", shiftAbilityConfig)
  end
end