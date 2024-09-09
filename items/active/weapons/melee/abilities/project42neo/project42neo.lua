require "/scripts/util.lua"
require "/scripts/poly.lua"
require "/scripts/vec2.lua"
require "/scripts/status.lua"
require "/items/active/weapons/project42neo-weapon.lua"

Project42Neo = WeaponAbility:new()

function Project42Neo:init()
  self.cooldownTimer = self.cooldown
  
  self.comboSteps = #(self.combo or {nil})
  
  self.defaultOffset = config.getParameter(self.offsetParameter, {0, 0})

end

function Project42Neo:update(dt, fireMode, shiftHeld)

  WeaponAbility.update(self, dt, fireMode, shiftHeld)

  self.cooldownTimer = math.max(0, self.cooldownTimer - self.dt)

  if self.cooldownTimer <= 0
  and not self.weapon.currentAbility
  and self:canActivate()
  then
    if self.comboSteps <= 0 then
      sb.logError("Error: No steps in combo; combo array is either empty or null.")
      return
    end
    self:setState(self.slashing, 1)
  end

end

function Project42Neo:canActivate()
  return self.fireMode == (self.isPrimary and "primary" or "alt")
end

function Project42Neo:cancelling()
  return self.fireMode == (self.isPrimary and "alt" or "primary")
end

function Project42Neo:slashing(comboStep)
  
  if not self.initStance then
    self.initStance = self.weapon.stance
  end
  
  status.overConsumeResource("energy", self.energyCost)
  
  for i, stance in ipairs(self.combo[comboStep]) do
    
    self.weapon:setStance(stance)
    
    if stance.damage then
      
      local damageConfig = stance.damage.config
      damageConfig.baseDamage =
          world.threatLevel()
        * (activeItem.ownerPowerMultiplier()^2)
        * (damageConfig.baseDamageFactor or 1)

      local offset = vec2.add(self.defaultOffset, stance.damage.offset or {0, 0})
      local rotation = util.toRadians(stance.damage.rotate or 0)

      animator.resetTransformationGroup("swoosh")
      animator.rotateTransformationGroup("swoosh", rotation)
      animator.translateTransformationGroup("swoosh", offset)
      self.weapon:setDamage(
        damageConfig,
        poly.translate(poly.rotate(stance.damage.area, rotation), offset)
      )

    end

    util.wait(stance.duration or 0)
    
    coroutine.yield()
  end

  local gracePeriod = self.comboGracePeriod
  while gracePeriod > 0 do
    gracePeriod = gracePeriod - self.dt
    if self:canActivate() then
      local nextComboStep = (comboStep % self.comboSteps) + 1
      self:setState(self.slashing, nextComboStep)
      return
    elseif self:cancelling() then
      break
    end
    coroutine.yield()
  end
  
  self.weapon:setStance(self.initStance)
  self.initStance = nil
  self.cooldownTimer = self.cooldown
end

function Project42Neo:uninit()
  self.weapon:setDamage()
end
