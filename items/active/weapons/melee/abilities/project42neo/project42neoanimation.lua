require "/scripts/util.lua"
require "/scripts/poly.lua"
require "/scripts/vec2.lua"
require "/scripts/status.lua"
require "/scripts/interp.lua"

local oldInit = init or function() end
local oldUpdate = update or function(dt) end

function init()
  oldInit()

  self.sheathProperties = animationConfig.animationParameter("sheathProperties")
  self.sheathJiggleProgress = 0

end

function update(dt)

  localAnimator.clearDrawables()
  localAnimator.clearLightSources()

  oldUpdate()

  __debug_stuff()

  drawQuadrants()

  self.sheathVisible = animationConfig.animationParameter("sheathVisible", false)
  self.ownerVelocity = animationConfig.animationParameter("ownerVelocity", {0, 0})
  self.ownerCrouching = animationConfig.animationParameter("ownerCrouching", false)
  self.sheathJiggleProgress = self.sheathJiggleProgress < 1 and (self.sheathJiggleProgress + dt*3) or 0

  if self.sheathProperties
  and self.sheathVisible
  then

    self.sheathStatus = animationConfig.animationParameter("sheathStatus", "sheathed")
    self.sheathOffset = animationConfig.animationParameter("sheathOffset", {0, 0})
    self.sheathRotation = animationConfig.animationParameter("sheathRotation", 0)
    self.sheathDirectives = animationConfig.animationParameter("sheathDirectives", "")
  
    local offset = vec2.add(vec2.add(self.sheathProperties.offset, self.sheathOffset), movementOffset(self.ownerVelocity))
    offset = {offset[1] * activeItemAnimation.ownerFacingDirection(), offset[2] - (self.ownerCrouching and 0.5 or 0)}
    local rotation = util.toRadians(self.sheathProperties.rotation + self.sheathRotation) + movementTilt(self.ownerVelocity)
    localAnimator.addDrawable({
      image = self.sheathProperties.image[self.sheathStatus] .. ((activeItemAnimation.ownerFacingDirection() > 0) and "?flipx" or "") .. self.sheathDirectives,
      position = vec2.add(activeItemAnimation.ownerPosition(), offset),
      rotation = rotation * activeItemAnimation.ownerFacingDirection(),
      color = {255,255,255},
      fullbright = false,
    }, "Player" .. ((activeItemAnimation.ownerFacingDirection() > 0) and "+1" or "-1"))
  end

end

function movementTilt(velocity)
  return util.clamp(5, -5, util.toRadians(velocity[1] * 0.5))
end

function movementOffset(velocity)
  return {
    0,
    -util.clamp(0.25, -0.25, velocity[2]*0.01)
  }
end

function __debug_stuff()

end

function renderText(offset, text, color, size, fullbright)
  localAnimator.spawnParticle({
    type = "text",
    text= text,
    color = color or {255,255,255},
    size = size or 0.5,
    fullbright = fullbright,
    flippable = false,
    layer = "front"
  }, vec2.add(activeItemAnimation.ownerPosition(), offset))
end

function drawQuadrants()
  local distance = 8
  for i=0, 3 do
    local rot = util.toRadians(45 + 90*i)
    localAnimator.addDrawable({
      image="/items/active/weapons/melee/abilities/project42neo/indicator.png",
      rotation = rot,
      position = vec2.add(activeItemAnimation.ownerPosition(), vec2.rotate({distance, 0}, rot)),
      fullbright = true
    }, "ForegroundEntity+1")
  end
end