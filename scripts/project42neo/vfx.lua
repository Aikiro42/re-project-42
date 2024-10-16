vfx = {}

function vfx.renderStreak(origin, destination, color, width, light, fullbright, timeToLive)
  
  origin = origin or {0, 0}
  destination = destination or {0, 0}
  color = color or {255, 255, 255}
  timeToLive = timeToLive or 0.1
  width = width or 1
  
  local length = world.magnitude(destination, origin)
  local vector = world.distance(origin, destination)
  local primaryParameters = {
    length = length*8,
    initialVelocity = {0.001, 0}
  }

  local particleParameters = {
    type = "streak",
    color = color,
    light = light,
    approach = {0, 0},
    timeToLive = 0,
    layer = "back",
    destructionAction = "shrink",
    destructionTime = timeToLive,
    fade=0.1,
    size = width,
    rotate = true,
    fullbright = fullbright,
    collidesForeground = false,
    variance = {
      length = 0,
    }
  }

  particleParameters = sb.jsonMerge(particleParameters, primaryParameters)

  local periodicActions = {
    {
      time = 0,
      ["repeat"] = false,
      rotate=true,
      action = "particle",
      specification = particleParameters
    }
  }


  local projectileParams = {
    power=0,
    speed=0,
    piercing = true,
    periodicActions = periodicActions
  }

  world.spawnProjectile(
    "project42neoinvisibleprojectile",
    origin,
    nil,
    vector,
    false,
    projectileParams
  )

end