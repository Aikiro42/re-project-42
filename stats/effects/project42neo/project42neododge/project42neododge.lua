require "/scripts/project42neo/util.lua"
require "/scripts/interp.lua"

function init()
  -- invulnerability
  -- effect.addStatModifierGroup({{stat = "invulnerable", amount = 1}})
  self.directives = "?fade=FFFFFF=0.5?multiply=FFFFFF3F"
  self.maxShieldHealth = 65536
  
  self.transparency = 0.5
  self.color = {255,255,255}
  self.fade = 0.2
  
  self.maxDuration = effect.duration()
  self.lastShieldHealth = self.maxShieldHealth
  status.setResource("damageAbsorption", self.maxShieldHealth)

  -- turn white and become transparent
  effect.setParentDirectives(updateColor(0, self.color, self.transparency))

end

function update(dt)

  -- turn white and become transparent
  effect.setParentDirectives(
    updateColor(
      effect.duration()/self.maxDuration,
      self.color
    )
  )
  
  if self.lastShieldHealth > status.resource("damageAbsorption") then
    animator.playSound("hit")
    self.lastShieldHealth = status.resource("damageAbsorption")
  end

  -- particles
  if mcontroller.xVelocity() ~= 0 or mcontroller.yVelocity() ~= 0 then
    if mcontroller.facingDirection() == 1 then
      animator.setParticleEmitterActive("dodgeRight", true)
      animator.setParticleEmitterActive("dodgeLeft", false)
    else
      animator.setParticleEmitterActive("dodgeRight", false)
      animator.setParticleEmitterActive("dodgeLeft", true)
    end
  else
    animator.setParticleEmitterActive("dodgeRight", false)
    animator.setParticleEmitterActive("dodgeLeft", false)
  end

end

function uninit()
  status.setResource("damageAbsorption", 0)
end

function updateColor(progress, color)
  
  local newFade = interp.sin(progress, 0, self.fade)
  local newTransparency = interp.sin(progress, 1, self.transparency)

  return string.format("?fade=%s=%.2f?multiply=FFFFFF%s",
    util.colorToHex(color),
    newFade,
    string.format("%02X", math.floor(newTransparency * 255))
  )
end