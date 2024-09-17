function init()

  animator.playSound("activate")

  animator.burstParticleEmitter("dodgeShine")
  if mcontroller.facingDirection() == 1 then
    animator.burstParticleEmitter("dodgeRight")
  else
    animator.burstParticleEmitter("dodgeLeft")
  end

  effect.addStatModifierGroup({{stat = "invulnerable", amount = 1}})

  -- self.radius
  local detectedEntities = world.entityQuery(mcontroller.position(), 40, {
    withoutEntityId = entity.id(),
    includedTypes = {"creature"},
    order = "nearest"
  })

  if #detectedEntities > 0 then
    for i, id in ipairs(detectedEntities) do
      if world.entityCanDamage(entity.id(), id) -- if player can damage enemy
      then
        world.sendEntityMessage(id, "applyStatusEffect", "project42neostasis", nil, entity.id())
        --[[
        message.setHandler("applyStatusEffect", function(_, _, effectConfig, duration, sourceEntityId)
          status.addEphemeralEffect(effectConfig, duration, sourceEntityId)
        end)
        --]]
      end
    end
  end

  script.setUpdateDelta(0)

end
