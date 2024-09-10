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
      self:setState(self.attacking, "init")
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

function Project42Neo:nextComboStep()
  sb.logInfo(activeItem.aimAngle(0, activeItem.ownerAimPosition()))
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

function Project42Neo:attacking(attack)
  
  self:setStanceSequence(self.combo[attack].sequence)
  
  local gracePeriod = self.comboGracePeriod 
  while gracePeriod > 0 do
    gracePeriod = gracePeriod - self.dt
    if self:triggering() then
      local nextAttack = (self.combo[attack].next or {}).default or "init"
      self:setState(self.attacking, nextAttack)
      return
    elseif self:cancelling() then
      break
    end
    coroutine.yield()
  end
  
  self.cooldownTimer = self.cooldown  
  self:setState(self.resetting, attack)
  return
end

function Project42Neo:resetting(attack)
  self:setStanceSequence(self.combo[attack].resetSequence)
  self.weapon:setStance(self.idle.ready)
  self.isAttacking = false
end

-- actions

function Project42Neo:setStanceSequence(stanceSequence)
  if not stanceSequence then return end
  if #stanceSequence == 0 then return end
  for i, stance in ipairs(stanceSequence) do
    self.weapon:setStance(stance)
    self:damage(stance)
    self:shield(stance.shield, -stance.armRotation - stance.weaponRotation)
    util.wait(stance.duration or 0)
    coroutine.yield()
  end
end

function Project42Neo:damage(stance)
  if not stance then return end
  local damageParameters = stance.damage
  if not damageParameters then return end

  local totalRotation = stance.armRotation + stance.weaponRotation
  
  local damageConfig = damageParameters.config
  damageConfig.baseDamage =
      world.threatLevel()
    * (activeItem.ownerPowerMultiplier()^2)
    * (damageConfig.baseDamageFactor or 1)

  sb.logInfo(sb.print(damageParameters.offset))

  local rotation = util.toRadians(
      (damageParameters.rotation or 0)
      - stance.armRotation
      - stance.weaponRotation
  )

  local offset = vec2.rotate(
    vec2.add(
      self.defaultOffset,
      damageParameters.offset or {0, 0}
    ),
    util.toRadians(
      -stance.armRotation
      -stance.weaponRotation
    )
  ) 
  animator.resetTransformationGroup("swoosh")
  animator.rotateTransformationGroup("swoosh", rotation)
  animator.translateTransformationGroup(
    "swoosh",
    offset
  )
  
  
  self.weapon:setDamage(
    damageConfig,
    poly.translate(
      poly.rotate(
        damageParameters.area,
        rotation
      ),
      offset
    )
    
  )

end

function Project42Neo:shield(shieldParameters, weaponRotation)
  if not shieldParameters
  or not weaponRotation
  then return end
  
end

function Project42Neo:uninit()
  self.weapon:setDamage()
end
