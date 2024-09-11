require "/scripts/util.lua"
require "/scripts/poly.lua"
require "/scripts/vec2.lua"
require "/scripts/status.lua"
require "/items/active/weapons/project42neo-weapon.lua"

Project42Neo = WeaponAbility:new()

function Project42Neo:init()
  
  self.defaultOffset = config.getParameter(self.offsetParameter, {0, 0})

  self.stats = sb.jsonMerge({
    baseDamage = 4.2,
    attackSpeed = 1,
    critChance = 0.2,
    critDamage = 1.5,
    heavyEnergyCost = 20
  }, self.stats or {})

  -- timers
  self.cooldownTimer = self.cooldown
  self.idleTimer = -1
  self.heavyAttackTime = 0.3

  if self.combo.debugInit then
    self.combo.init = self.combo.debugInit
    for i, _ in ipairs(self.combo.attacks[self.combo.init].sequence) do
      self.combo.attacks[self.combo.init].sequence[i].allowRotate = false
      self.combo.attacks[self.combo.init].sequence[i].allowFlip = false
      self.combo.attacks[self.combo.init].sequence[i].aimAngle = 0
      self.combo.attacks[self.combo.init].next = {
        default = self.combo.init
      }
    end
  end

  activeItem.setScriptedAnimationParameter("sheathProperties", config.getParameter("sheath"))
  activeItem.setScriptedAnimationParameter("sheathStatus", "sheathed")
  activeItem.setScriptedAnimationParameter("sheathVisible", true)
  
  animator.setAnimationState("sheath", "sheathed")
  animator.setParticleEmitterActive("blade", false)
  self.weapon:setStance(self.idle.sheathed)

end

function Project42Neo:update(dt, fireMode, shiftHeld)

  WeaponAbility.update(self, dt, fireMode, shiftHeld)

  activeItem.setScriptedAnimationParameter("sheathAnimationState", animator.animationState("sheath"))
  
  self.cooldownTimer = math.max(0, self.cooldownTimer - self.dt)
  
  if self.idleTimer > 0
  and not self.weapon.currentAbility
  then
    self.idleTimer = math.max(0, self.idleTimer - self.dt)
  elseif self.idleTimer == 0 then
    self:setState(self.sheathing)
    self.idleTimer = -1
  end

  if self.cooldownTimer <= 0
  and not self.weapon.currentAbility
  and self:triggering()
  then
    if animator.animationState("sheath") == "sheathed" then
      self:setState(self.unsheathing)
      self.idleTimer = self.idle.timeout
    else
      self:setState(self.attacking, self.combo.init)
    end
  end

end

-- evaluative

function Project42Neo:triggering()
  return self.fireMode == "primary"
end


function Project42Neo:cancelling()
  return self.fireMode == "alt"
end

function Project42Neo:cursorDirection()
  local aimAngle = activeItem.aimAngle(0, activeItem.ownerAimPosition())
  --[[
  if aimAngle < 0 then
    aimAngle = aimAngle + 6.28318530718 -- 2 * pi
  end
  local quarterThreshold = 1.0471975512 -- pi / 3
  --]]
  
  local pi13 = 1.0471975512 -- pi / 3
  local pi23 = 2.09439510239 -- 2 * pi / 3
  local tentativeDirection = "up"
  if aimAngle <= 0 then
    tentativeDirection = "down"
  end
  aimAngle = math.abs(aimAngle)
  if pi13 <= aimAngle and aimAngle <= pi23 then
    return tentativeDirection
  end
  return "side"
end

-- states

function Project42Neo:unsheathing()
  self:setStanceSequence(self.idle.unsheathing, false, self.stats)
  self.weapon:setStance(self.idle.ready)
  animator.setParticleEmitterActive("blade", true)
  animator.setAnimationState("sheath", "ready")
end

function Project42Neo:sheathing()
  self:setStanceSequence(self.idle.sheathing, false, self.stats)
  self.weapon:setStance(self.idle.sheathed)
  animator.setParticleEmitterActive("blade", false)
  animator.setAnimationState("sheath", "sheathed")
end

function Project42Neo:idling()
  self:setStanceSequence(self.idle.sequence, false, self.stats)
end

function Project42Neo:attacking(attackKey, isHeavy)

  self.isAttacking = true
  
  -- attack
  self:setStanceSequence(self.combo.attacks[attackKey].sequence, isHeavy, self.stats)

  -- if input is held down after attack, initiate heavy
  local triggered = self:triggering()
  if triggered and not isHeavy then
    self:setState(self.charging, attackKey)
    return
  end

  -- otherwise, initiate grace period
  local gracePeriod = self.comboGracePeriod
  while gracePeriod > 0 do
    
    -- tick down grace period
    gracePeriod = gracePeriod - self.dt

    -- if triggered within grace period, initiate next attack
    if self:triggering() and not triggered then
      local nextAttackKey = self:getNextStep(attackKey, false)
      self:setState(self.attacking, nextAttackKey)
      return
    
    -- if cancelled within grace period, reset
    elseif self:cancelling() then
      break
    end

    coroutine.yield()

  end
  
  self.cooldownTimer = self.cooldown  
  self:setState(self.resetting, attackKey)
  return
end

function Project42Neo:charging(attackKey)
  
  local heavyAttackTimer = self.heavyAttackTime
  local progress = 0
  local heavyReady = false

  if self.combo.attacks[attackKey].autoFireHeavy == nil then
    self.combo.attacks[attackKey].autoFireHeavy = false
  end
  animator.playSound("heavyLoop", -1)

  local chargingStance = sb.jsonMerge(self.weapon.stance, {
    allowRotate = true,
    allowFlip = true,
    snap = false
  })
  chargingStance.animationStates = nil
  chargingStance.playSounds = nil
  self.weapon:setStance(chargingStance)

  while self:triggering() do

    heavyAttackTimer = math.max(0, heavyAttackTimer - self.dt)
    progress = math.min(1, 1 - (heavyAttackTimer/self.heavyAttackTime))
    animator.setSoundVolume("heavyLoop", progress)

    if heavyAttackTimer <= 0 then
      if not heavyReady then
        animator.burstParticleEmitter("charge")
        animator.playSound("heavyReady")
        heavyReady = true
        self.weapon:screenShake(0.5)
      end
      if self.combo.attacks[attackKey].autoFireHeavy then break end
    end

    coroutine.yield()
  end
    
  animator.stopAllSounds("heavyLoop")

  if heavyAttackTimer <= 0 then
    local nextAttackKey = self:getNextStep(attackKey, true)
    self:setState(self.attacking, nextAttackKey, true)
  else
    local nextAttackKey = self:getNextStep(attackKey, false)
    self:setState(self.attacking, nextAttackKey)
  end

end

function Project42Neo:resetting(attackKey)
  self:setStanceSequence(self.combo.attacks[attackKey].resetSequence)
  self.weapon:setStance(self.idle.ready)
  self.isAttacking = false
end

-- actions

function Project42Neo:getNextStep(attackKey, isHeavy)
  local next = self.combo.attacks[attackKey].next or self.combo.defaultNext
  return isHeavy and next.heavy or next.default
end

function Project42Neo:setStanceSequence(stanceSequence, isHeavy, stats)
  if not stanceSequence then return end
  if #stanceSequence == 0 then return end

  for i, stance in ipairs(stanceSequence) do
    if stance.duration then
      stance.duration = stance.duration / math.max(0.001, stats.attackSpeed)
    end
    self.weapon:setStance(stance)
    self:damage(stance, isHeavy, stats)
    self:shield(stance)
    self:projectile(stance)
    util.wait(stance.duration or 0)
    coroutine.yield()
  end
end

function Project42Neo:damage(stance, isHeavy, stats)
  if not stance then return end
  if not stance.damage then return end

  status.overConsumeResource("energy", isHeavy and stats.heavyEnergyCost or stance.damage.energyCost or 0)
  
  local damageParameters = stance.damage

  if isHeavy then
    animator.playSound("heavy")
    self.weapon:screenShake(1)
  end

  local totalRotation = stance.armRotation + stance.weaponRotation
  
  local damageConfig = damageParameters.config
  damageConfig.baseDamage =
      stats.baseDamage
    * activeItem.ownerPowerMultiplier()
    * (isHeavy and damageParameters.heavyMultiplier or damageParameters.multiplier)
  
  animator.resetTransformationGroup("swoosh")

  local rotation = util.toRadians(
    (damageParameters.rotation or 0)
  )
  local offset = vec2.rotate(damageParameters.offset or {0, 0}, rotation)

  animator.rotateTransformationGroup("swoosh", rotation)
  animator.translateTransformationGroup("swoosh", offset)
    
  self.weapon:setDamage(
    damageConfig,
    poly.translate(
      poly.rotate(
        damageParameters.area or {},
        rotation
      ),
      offset
    )
  )

end

function Project42Neo:shield(stance)
  if not stance then return end
  if not stance.shield then return end
end

function Project42Neo:projectile(stance)
  if not stance then return end
  if not stance.projectile then return end



end

function Project42Neo:uninit()
  self.weapon:setDamage()
end
