require "/scripts/util.lua"
require "/scripts/poly.lua"
require "/scripts/vec2.lua"
require "/scripts/status.lua"
require "/items/active/weapons/project42neo-weapon.lua"

Project42Neo = WeaponAbility:new()

function Project42Neo:init()
  
  self.defaultOffset = config.getParameter(self.offsetParameter, {0, 0})

  -- timers
  self.cooldownTimer = self.cooldown
  self.idleTimer = 0
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

  animator.setAnimationState("sheath", "sheathed")
  self.weapon:setStance(self.idle.sheathed)

end

function Project42Neo:update(dt, fireMode, shiftHeld)

  WeaponAbility.update(self, dt, fireMode, shiftHeld)
  
  self.cooldownTimer = math.max(0, self.cooldownTimer - self.dt)

  if self.cooldownTimer <= 0
  and not self.weapon.currentAbility
  and not self.isAttacking
  and self:triggering()
  then
    if animator.animationState("sheath") == "sheathed" then
      self:setState(self.unsheathing)
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
  self:setStanceSequence(self.idle.unsheathing)
  self.weapon:setStance(self.idle.ready)
  animator.setAnimationState("sheath", "unsheathed")
end

function Project42Neo:sheathing()
  self:setStanceSequence(self.idle.sheathing)
  self.weapon:setStance(self.idle.sheathed)
  animator.setAnimationState("sheath", "sheathed")
end

function Project42Neo:idling()
  self:setStanceSequence(self.idle.sequence)
end

function Project42Neo:attacking(attack, isHeavy)

  self:setStanceSequence(self.combo.attacks[attack].sequence, isHeavy, self.stats.attackSpeed)

  if isHeavy then
    self.cooldownTimer = self.cooldown  
    self:setState(self.resetting, attack)
    return  
  end

  local heavyAttack = -1
  if self:triggering() then
    heavyAttack = 0
  end

  local gracePeriod = self.comboGracePeriod
  while gracePeriod > 0 or heavyAttack >= 0 do
    
    -- timers
    gracePeriod = gracePeriod - self.dt
    if self:triggering() and heavyAttack >= 0 then
      heavyAttack = heavyAttack + self.dt
    else
      heavyAttack = -1
    end
    
    if heavyAttack >= self.heavyAttackTime then
      local nextAttack = (self.combo.attacks[attack].next or {}).heavy or self.combo.init
      self:setState(self.attacking, nextAttack, true)
      return
    end

    if heavyAttack < 0 then
      if self:triggering() and heavyAttack < self.heavyAttackTime then
        local nextAttack = (self.combo.attacks[attack].next or {}).default or self.combo.init
        self:setState(self.attacking, nextAttack)
        return
      elseif self:cancelling() then
        break
      end
    end
    coroutine.yield()
  end
  
  self.cooldownTimer = self.cooldown  
  self:setState(self.resetting, attack)
  return
end

function Project42Neo:resetting(attack)
  self:setStanceSequence(self.combo.attacks[attack].resetSequence)
  self.weapon:setStance(self.idle.ready)
  self.isAttacking = false
end

-- actions

function Project42Neo:getNextStep(nexts)
  if not nexts then
    return self.attacks.init
  end

  return nexts.default or self.attacks.init
  
end

function Project42Neo:setStanceSequence(stanceSequence, isHeavy, speedMult)
  if not stanceSequence then return end
  if #stanceSequence == 0 then return end
  for i, stance in ipairs(stanceSequence) do
    if speedMult and stance.duration then
      stance.duration = stance.duration * 1/speedMult
    end
    self.weapon:setStance(stance)
    self:damage(stance, isHeavy)
    self:shield(stance)
    self:projectile(stance)
    util.wait(stance.duration or 0)
    coroutine.yield()
  end
end

function Project42Neo:damage(stance, isHeavy)
  if not stance then return end
  if not stance.damage then return end
  
  local damageParameters = stance.damage

  if isHeavy then animator.playSound("heavy") end

  local totalRotation = stance.armRotation + stance.weaponRotation
  
  local damageConfig = damageParameters.config
  damageConfig.baseDamage =
      world.threatLevel()
    * (activeItem.ownerPowerMultiplier()^2)
    * (damageParameters.multiplier or 1)
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
