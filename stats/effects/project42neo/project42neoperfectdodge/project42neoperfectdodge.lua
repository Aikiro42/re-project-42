function init()

  if mcontroller.facingDirection() == 1 then
    animator.burstParticleEmitter("dodgeRight")
  else
    animator.burstParticleEmitter("dodgeLeft")
  end

  effect.addStatModifierGroup({{stat = "invulnerable", amount = 1}})
  script.setUpdateDelta(0)
end
