require "/scripts/util.lua"
require "/scripts/status.lua"
require "/scripts/vec2.lua"
require "/items/active/weapons/project42neo-weapon.lua"

function init()
  --[[
  animator.setGlobalTag("paletteSwaps", config.getParameter("paletteSwaps", ""))
  animator.setGlobalTag("directives", "")
  animator.setGlobalTag("bladeDirectives", "")
  --]]

  self.weapon = Weapon:new()

  self.weapon:addTransformationGroup("weapon", {0,0}, util.toRadians(config.getParameter("baseWeaponRotation", 0)))
  
  local primaryAbility = getPrimaryAbility()
  self.weapon:addAbility(primaryAbility)

  local secondaryAttack = getAltAbility()
  if secondaryAttack then
    self.weapon:addAbility(secondaryAttack)
  end

  self.weapon:init()

  self.screenShakeListener = damageListener("inflictedDamage", function(notifications)
    if #notifications > 0 then
      -- sb.logInfo(sb.printJson(notifications, 1))
      self.weapon:screenShake(0.5)
    end
  end)

end

function update(dt, fireMode, shiftHeld)
  self.weapon:update(dt, fireMode, shiftHeld)
  self.screenShakeListener:update()
end

function uninit()
  self.weapon:uninit()
end
