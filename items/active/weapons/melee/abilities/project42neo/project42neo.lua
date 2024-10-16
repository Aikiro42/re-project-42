require "/scripts/project42neo/util.lua"
require "/scripts/project42neo/vfx.lua"
require "/scripts/poly.lua"
require "/scripts/vec2.lua"
require "/scripts/status.lua"
require "/scripts/interp.lua"
require "/items/active/weapons/project42neo-weapon.lua"

Project42Neo = WeaponAbility:new()

local print = function(str)
  chat.addMessage(str)
end

function Project42Neo:__debugInit()

  if not self.debugEnabled then return end

end

function Project42Neo:__debugUpdate(dt, fireMode, shiftHeld)

  if not self.debugEnabled then return end

  status.giveResource("health", 9999)
    
end

-- SECTION: [MAIN] ______________________________________________________________________________________

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
  self.__maintainAirTimer = 0
  self.heavyAttackTime = 0.3
  self.__rightAngle = util.toRadians(self.directionAngleThreshold)
  self.__leftAngle = math.pi - self.__rightAngle
  activeItem.setScriptedAnimationParameter("leftAngle", self.__leftAngle)
  activeItem.setScriptedAnimationParameter("rightAngle", self.__rightAngle)

  self.dodge = sb.jsonMerge({
    duration = 0.1,
    cooldown = 0.5,
    speed = 100
  }, self.dodge or {})

  self.dodgeTimer = self.dodge.cooldown
  
  self.currentDamage = {
    duration = 0
  }
  self.currentShield = {
    duration = 0,
    listener = damageListener("damageTaken", function(notifications)
      for _, notification in ipairs(notifications) do
        if notification.hitType == "ShieldHit" then
          animator.playSound("parry")
          if self.attackKey then
            local nextStep = self:getNextStep(self.attackKey)
            if self.combo.attacks[nextStep].attackIndex then
              self:setState(self.attacking, nextStep, self.combo.attacks[nextStep].attackIndex)
            end
          end
          -- self.currentShield.duration = 1
          break
        end
      end
    end)
  }

  if self.combo.debugAttack then
    self.combo.init = {
      default = self.combo.debugAttack,
      normal = {
        default = self.combo.debugAttack
      },
      normalAirborne = {
        default = self.combo.debugAttack
      }
    }
    for i, _ in ipairs(self.combo.attacks[self.combo.init.default].sequence) do
      self.combo.attacks[self.combo.init.default].sequence[i].allowRotate = false
      self.combo.attacks[self.combo.init.default].sequence[i].allowFlip = false
      self.combo.attacks[self.combo.init.default].sequence[i].aimAngle = 0
      self.combo.attacks[self.combo.init.default].next = {
        default = self.combo.init.default,
        normal = {
          default = self.combo.init.default,
          up = self.combo.init.default,
          side = self.combo.init.default,
          down = self.combo.init.default
        },
        normalAirborne = {
          default = self.combo.init.default,
          up = self.combo.init.default,
          side = self.combo.init.default,
          down = self.combo.init.default
        },
        heavy = {
          default = self.combo.init.default,
          up = self.combo.init.default,
          side = self.combo.init.default,
          down = self.combo.init.default
        },
        heavyAirborne = {
          default = self.combo.init.default,
          up = self.combo.init.default,
          side = self.combo.init.default,
          down = self.combo.init.default
        }
      }
    end
  end

  activeItem.setScriptedAnimationParameter("sheathProperties", config.getParameter("sheath"))
  activeItem.setScriptedAnimationParameter("sheathStatus", "sheathed")
  activeItem.setScriptedAnimationParameter("sheathVisible", true)
  
  animator.setAnimationState("sheath", "sheathed")
  animator.setParticleEmitterActive("blade", false)
  self.weapon:setStance(self.idle.sheathed)

  self:__debugInit()

end

function Project42Neo:update(dt, fireMode, shiftHeld)

  WeaponAbility.update(self, dt, fireMode, shiftHeld)

  status.addEphemeralEffect("nofalldamage", 1)
  activeItem.setScriptedAnimationParameter("sheathAnimationState", animator.animationState("sheath"))
  
  self.cooldownTimer = math.max(0, self.cooldownTimer - self.dt)

  self:__debugUpdate(dt, fireMode, shiftHeld)
  self:updateCursor()
  self:updateShield()
  self:updateDamage()
  self:updateDodge()

  if not self:cancelling() then
    self.cancelled = false
  end

  if not self:triggering() then
    self.triggered = false
  end
  
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
  then

    if self:triggering() then

      if animator.animationState("sheath") == "sheathed" then
        self:setState(self.unsheathing)
      else
        self:setState(self.attacking, self:getFirstStep())
      end
      self.idleTimer = self.idle.timeout

    elseif self:cancelling(true) then

      if animator.animationState("sheath") == "sheathed" then
        self:setState(self.unsheathing)
      else
        self:setState(self.dodging)
      end
      self.idleTimer = self.idle.timeout

    end

  end

end

function Project42Neo:uninit()
  mcontroller.setRotation(0)
  self.weapon:setDamage()
end

-- SECTION: [UPDATE] ____________________________________________________________________________________

function Project42Neo:updateCursor()
  local direction = self:cursorDirection(true)
  local cursor = ({left=true, right=true})[direction] and "side" or direction
  activeItem.setCursor("/cursors/project42neo/meleecursor/meleecursor-" .. cursor .. ".cursor")
  activeItem.setScriptedAnimationParameter("cursorDirection", direction)
end

function Project42Neo:updateShield()

  self.currentShield.duration = self.currentShield.duration - self.dt
  if self.currentShield.duration <= 0 then
    self.currentShield.args = nil    
  end

  if self.currentShield.args then
    -- determine shield boundBox
    --[[
    local entityQueryArea = poly.boundBox(poly.translate(self.currentShield.args.shieldArea, mcontroller.position()))
    entityQueryArea = {
      {entityQueryArea[1], entityQueryArea[2]},
      {entityQueryArea[3], entityQueryArea[4]}
    }
    
    -- query entities within shield boundbox
    local detected = world.entityQuery(entityQueryArea[1], entityQueryArea[2], {
      withoutEntityId = activeItem.ownerEntityId(),
      includedTypes = {"projectile"},
      order = "nearest"
    })
    for _, eID in ipairs(detected) do
      if ({projectile=true, npc=true})[world.entityType(eID)] then
        animator.playSound("parry")
        activeItem.setShieldPolys({self.currentShield.args.shieldArea})
      end
    end
    --]]
    activeItem.setShieldPolys({self.currentShield.args.shieldArea})
    self.currentShield.listener:update()
  else
    activeItem.setShieldPolys()
  end

end

function Project42Neo:updateDamage()

  self.currentDamage.duration = self.currentDamage.duration - self.dt
  if self.currentDamage.duration <= 0 then
    self.currentDamage.args = nil
  end

  if self.currentDamage.args then
    self.weapon:setDamage(
      self.currentDamage.args.damageConfig,
      self.currentDamage.args.damageArea,
      nil,
      self.currentDamage.args.damageOffset or {0, 0},
      self.currentDamage.args.damageRotation or 0,
      self.currentDamage.args.damageLocked
    )
  else
    self.weapon:setDamage()
  end

end

function Project42Neo:updateDodge()
  self.dodgeTimer = math.max(0, self.dodgeTimer - self.dt)
end

function Project42Neo:maintainAir(stopTime, maxControlForce, controlVelocity)

end

-- SECTION: [EVALUATIVE] ________________________________________________________________________________

function Project42Neo:triggering(triggered)
  if triggered and not self.triggered then
    self.triggered = true
    return self.fireMode == (self.activatingFireMode or self.abilitySlot)
  end
  return self.fireMode == (self.activatingFireMode or self.abilitySlot) and not self.triggered
end


function Project42Neo:cancelling(cancelled)
  if cancelled and not self.cancelled then
    self.cancelled = true
    return self.fireMode == "alt"
  end
  return self.fireMode == "alt" and not self.cancelled
end

function Project42Neo:cursorDirection(specifySide)
  local aimAngle = activeItem.aimAngle(0, activeItem.ownerAimPosition())
  --[[
  if aimAngle < 0 then
    aimAngle = aimAngle + 6.28318530718 -- 2 * pi
  end
  local quarterThreshold = 1.0471975512 -- pi / 3
  --]]
    
  local verticalDirection = aimAngle <= 0 and "down" or "up"
  aimAngle = math.abs(aimAngle)

  if aimAngle < self.__rightAngle then
    return specifySide and "right" or "side"
  elseif self.__leftAngle < aimAngle then
    return specifySide and "left" or "side"
  else
    return verticalDirection
  end

end

-- SECTION: [STATES] ____________________________________________________________________________________

function Project42Neo:unsheathing()
  -- print("unsheathing")
  self:setStanceSequence(self.idle.unsheathing, false, self.stats)
  self.weapon:setStance(self.idle.ready)
  animator.setParticleEmitterActive("blade", true)
  animator.setAnimationState("sheath", "ready")
end

function Project42Neo:sheathing()
  -- print("sheathing")
  self:setStanceSequence(self.idle.sheathing, false, self.stats)
  self.weapon:setStance(self.idle.sheathed)
  animator.setParticleEmitterActive("blade", false)
  animator.setAnimationState("sheath", "sheathed")
end

function Project42Neo:idling()
  -- print("idling")
  self:setStanceSequence(self.idle.sequence, false, self.stats)
end

function Project42Neo:attacking(attackKey, isHeavy, attackIndex)

  self.isAttacking = true
  self.idleTimer = self.idle.timeout
  -- attack
  -- print("attack: " .. attackKey .. (isHeavy and "(heavy)" or ""))
  self.attackKey = attackKey

  self:setStanceSequence(self.combo.attacks[attackKey].sequence, isHeavy, self.stats, function()
    self:setState(self.dodging)
  end, attackIndex)

  if (self.combo.attacks[attackKey].next or {}).auto then
    local nextStep = self.combo.attacks[attackKey].next.auto
    local nextAttackIndex = self.combo.attacks[nextStep].attackIndex
    self:setState(self.attacking, nextStep, attackIndex and nextAttackIndex or nil)
  end

  -- if input is held down after attack, initiate heavy
  local triggered = self:triggering()
  if triggered and not isHeavy then
    self:setState(self.charging, attackKey)
  else
    self:setState(self.transisting, attackKey)
  end

end

function Project42Neo:transisting(attackKey)

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
      print("CANCELLED (transisting)")
      self:setState(self.dodging)
      return
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

  if self.combo.attacks[attackKey].maintainAir == nil then
    self.combo.attacks[attackKey].maintainAir = true
  end

  animator.playSound("heavyLoop", -1)

  local chargingStance = sb.jsonMerge(self.weapon.stance, {
    allowRotate = true,
    allowFlip = true,
    snap = false
  })
  chargingStance.animationStates = nil
  chargingStance.playSounds = nil
  chargingStance.velocity = nil
  chargingStance.momentum = nil
  self.weapon:setStance(chargingStance)

  while self:triggering() do

    heavyAttackTimer = math.max(0, heavyAttackTimer - self.dt)
    progress = math.min(1, 1 - (heavyAttackTimer/self.heavyAttackTime))
    animator.setSoundVolume("heavyLoop", progress)

    if self.combo.attacks[attackKey].maintainAir then
      self:maintainAir()
    end

    if heavyAttackTimer <= 0 then
      if not heavyReady then
        animator.burstParticleEmitter("charge")
        animator.playSound("heavyReady")
        self.weapon:setStance(self.idle.ready)
        heavyReady = true
        self.weapon:screenShake(0.5)
      end
      if self.combo.attacks[attackKey].autoFireHeavy then
        break
      else
        status.addEphemeralEffect("project42neoperfectheavy")
      end
    end

    coroutine.yield()
  end
    
  animator.stopAllSounds("heavyLoop")

  if heavyAttackTimer <= 0 then
    local nextAttackKey = self:getNextStep(attackKey, true)
    self:setState(self.attacking, nextAttackKey, true)
  else
    self:setState(self.transisting, attackKey)
  end

end

function Project42Neo:resetting(attackKey)
  self.attackKey = nil
  self:setStanceSequence(self.combo.attacks[attackKey].resetSequence)
  self.weapon:setStance(self.idle.ready)
  self.isAttacking = false
end

function Project42Neo:dodging()
  if self.dodgeTimer > 0 then return end

  self.cancelled = true
  
  -- determine dodge direction
  local direction = mcontroller.xVelocity() < -0 and -1 or 1
  if direction == 0 then direction = ({left=-1, right=1})[self:cursorDirection(true)] end

  self.weapon:setStance(self.idle.ready)
  status.addEphemeralEffect("project42neododge", self.dodge.duration)
  animator.playSound("dodge")
  util.wait(self.dodge.duration, function(dt, timer)
    local progress = timer / self.dodge.duration
    mcontroller.setVelocity({
      interp.sin(progress, 0, direction * self.dodge.speed),
      0
    })
  end)
    
  self.weapon:setStance(self.idle.ready)

  self.dodgeTimer = self.dodge.cooldown

end

-- SECTION: [ACTIONS] ___________________________________________________________________________________

function Project42Neo:getFirstStep()
  local nexts = self.combo.init
  local direction = self:cursorDirection()

  local nextStep

  nextStep = nexts["normal" .. (not mcontroller.groundMovement() and "Airborne" or "")][direction]
    or nexts["normal" .. (not mcontroller.groundMovement() and "Airborne" or "")].default

  return nextStep or nexts.default
end

function Project42Neo:getNextStep(attackKey, isHeavy)
  local nexts = sb.jsonMerge(self.combo.defaultNext, self.combo.attacks[attackKey].next or {})
  
  local direction = self:cursorDirection()

  local nextStep

  if isHeavy then
    nextStep = nexts["heavy" .. (not mcontroller.groundMovement() and "Airborne" or "")][direction]
      or nexts["heavy" .. (not mcontroller.groundMovement() and "Airborne" or "")].default
  else
    nextStep = nexts["normal" .. (not mcontroller.groundMovement() and "Airborne" or "")][direction]
      or nexts["normal" .. (not mcontroller.groundMovement() and "Airborne" or "")].default
  end

  return nextStep or nexts.default

end

function Project42Neo:setStanceSequence(stanceSequence, isHeavy, stats, cancelCallback, startingIndex)
  if not stanceSequence then return end
  if #stanceSequence == 0 then return end

  local i = startingIndex or 1
  while i <= #stanceSequence do
    local stance = stanceSequence[i]
    local duration = stance.duration
    if duration then
      duration = math.max(
        (stance.damage or stance.shield) and 0.05 or 0,
        duration / math.max(0.001, stats.attackSpeed)
      )
    end
    self:teleport(stance)
    self:statuses(stance)
    self.weapon:setStance(stance)
    self:damage(stance, duration, isHeavy, stats)
    self:shield(stance, duration)
    self:projectiles(stance)
    util.wait(duration or 0, function()
      if self:cancelling(true) and cancelCallback then
        print("CANCELED (in stance)")
        stanceSequence = {}
        i = 1
        isHeavy = false
        cancelCallback()
        return
      end
    end)
    i = i + 1
    coroutine.yield()
  end
  
end

function Project42Neo:damage(stance, stanceDuration, isHeavy, stats)
  if not stance then return end
  if not stance.damage then return end
  stanceDuration = stanceDuration or stance.duration

  status.overConsumeResource("energy", isHeavy and stats.heavyEnergyCost or stance.damage.energyCost or 0)
  status.consumeResource("health", isHeavy and stats.heavyHealthCost or stance.damage.healthCost or 0)
  
  local damageParameters = stance.damage

  if isHeavy then
    animator.playSound("heavy")
    self.weapon:screenShake(1)
  end
  
  local damageConfig = sb.jsonMerge(self.globalDamageConfig, damageParameters.config or {})
  damageConfig.baseDamage =
      stats.baseDamage
    * activeItem.ownerPowerMultiplier()
    * (isHeavy and damageParameters.heavyMultiplier or damageParameters.multiplier)
  
  local rotation = util.toRadians(
    (damageParameters.rotation or 0)
  )
  local offset = vec2.rotate(damageParameters.offset or {0, 0}, rotation)
  
  animator.resetTransformationGroup("swoosh")
  animator.rotateTransformationGroup("swoosh", rotation)
  animator.translateTransformationGroup("swoosh", offset)

  local dmgArea = animator[damageParameters.lock and "partProperty" or "partPoly"]("swoosh", "damageArea")
  if damageParameters.lock then
    dmgArea = poly.rotate(dmgArea, -self.weapon.relativeArmRotation)
    -- dmgArea = poly.translate(dmgArea, vec2.mul(activeItem.handPosition(), -1))
  end
  
  self.currentDamage.duration = damageParameters.duration or stanceDuration or 0.1
  self.currentDamage.args = {
    damageConfig = damageConfig,
    damageArea = dmgArea
  }

end

function Project42Neo:shield(stance, stanceDuration)

  if not stance then return end
  if not stance.shield then return end
  stanceDuration = stanceDuration or stance.duration

  --[[
  "shield": {
    "shieldArea": [Poly],
    "duration": float,
    "offset": Vec2
    "rotation": degrees,

    "parryProjectile": {
      "type": string,
      "parameters": {projectileParams}
    }
    "parryStatuses": [statuses]
  }
  --]]
  
  local shieldParameters = stance.shield
  
  local rotation = util.toRadians(
    (shieldParameters.rotation or 0)
  )
  local offset = vec2.rotate(shieldParameters.offset or {0, 0}, rotation)

  local shieldArea = animator.partPoly("swoosh", "shieldArea") or poly.translate(
    poly.rotate(
      shieldParameters.area or {},
      stance.aimAngle or activeItem.aimAngle(0, activeItem.ownerAimPosition())
    ),
    offset
  )

  self.currentShield.duration = shieldParameters.duration or stanceDuration or 0
  self.currentShield.args = {
    shieldArea = shieldArea,
  }
  self.currentShield.parryProjectile = sb.jsonMerge({
    type = "standardbullet"
  }, stance.shield.parryProjectile or {})

end

function Project42Neo:projectiles(stance)
  if not stance then return nil end
  if not stance.projectiles then return nil end

  --[[
  "projectiles": [
    {
      "type": "standardbullet", // non-null
      "aimAngleOverride": 0
      "aimAngle": 0,
      "offset": [0, 0],
      "track": false,
      "parameters": {...},
      "cam": false
    },
    {...}
  ]
  --]]

  local mainProjectile = nil
  for _, projectile in ipairs(stance.projectiles) do
    if projectile.type then
      local baseAimAngle = activeItem.aimAngle(0, activeItem.ownerAimPosition())
      local aimAngle = projectile.aimAngleOverride
      or baseAimAngle + (projectile.aimAngle or 0)
      local aimDirection = vec2.rotate({1, 0}, aimAngle)
      local spawnPos = vec2.add(
        mcontroller.position(),
        vec2.rotate(
          stance.projectile.offset or {0, 0},
          baseAimAngle
        )
      )

      local projectileId = world.spawnProjectile(
        stance.projectile.type,
        spawnPos,
        activeItem.ownerEntityId(),
        aimDirection,
        stance.projectile.track,
        stance.projectile.parameters
      )

      if projectile.cam then
        self.weapon:setCameraFocusEntity(projectileId, true)
      end

      mainProjectile = mainProjectile or projectileId
    end
  end

  return mainProjectile

end

function Project42Neo:teleport(stance)
  if not stance then return end
  if not stance.teleport then return end
  if not stance.teleport.delta then return end

  --[[
  "teleport": {
    "delta": [0, 0],
      // if number, rotate {delta, 0} by aimAngle, cap to aimPosition;
      // if vector, use it as offset
    "lineOfSight": true,
    "correctionThreshold": 5,
    "endVelocity": 0 // if nil, maintain velocity; if number, multiply maintained velocity; if vector, set velocity
  }
  --]]
  
  local offset = stance.teleport.delta
  if type(offset) == "number" then
    local tentativeOffset = vec2.rotate({offset, 0}, activeItem.aimAngle(0, activeItem.ownerAimPosition()))
    local aimOffset = vec2.sub(activeItem.ownerAimPosition(), mcontroller.position())
    offset = vec2.mag(aimOffset) < vec2.mag(tentativeOffset) and aimOffset or tentativeOffset
  end

  local endVelocity = stance.teleport.endVelocity or mcontroller.velocity()
  if type(endVelocity) == "number" then
    endVelocity = vec2.mul(mcontroller.velocity(), endVelocity)
  end

  if stance.teleport.lineOfSight == nil then
    stance.teleport.lineOfSight = true
  end

  local origin = mcontroller.position()
  local dest = vec2.add(origin, offset)
  if stance.teleport.lineOfSight then
    dest = world.lineCollision(origin, dest, {"Block", "Dynamic"}) or dest
  end
  dest = util.correctCollision(mcontroller.collisionPoly(), origin, dest, stance.teleport.correctionThreshold)
  
  if dest then
    mcontroller.setPosition(dest)
    -- vfx.renderStreak(origin, dest, {255, 0, 0}, 25)
    mcontroller.setVelocity(endVelocity)
  else
    print("Failed teleport!")
  end
  
end

function Project42Neo:statuses(stance)
  if not stance then return end
  if not stance.statusEffects then return end
  if #stance.statusEffects == 0 then
    stance.statusEffects = {nil}
  end
  for _, effect in ipairs(stance.statusEffects) do
    status.addEphemeralEffect(effect)
  end
end

function Project42Neo:parry()
end