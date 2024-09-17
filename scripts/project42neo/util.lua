require "/scripts/poly.lua"
require "/scripts/util.lua"

function util.wait(duration, action)
  local timer = duration
  local dt = script.updateDt()
  while timer > 0 do
    if action ~= nil and action(dt, timer) then return end
    timer = timer - dt
    coroutine.yield(false)
  end
end

function util.colorToHex(rgba)
  local hex = string.format("%02x%02x%02x", rgba[1], rgba[2], rgba[3])
  if #rgba == 4 then
    hex = hex .. string.format("%02x", rgba[4])
  end
  return hex
end

-- Given an entity's collision poly, an origin and a destination,
-- corrects the destination so that if an entity teleports from
-- the origin, it will not end up colliding.
function util.correctCollision(collisionPoly, origin, destination, correctionThreshold, debugMode)

  local boundBox = poly.boundBox(collisionPoly)

  local debugCross = function(color)
    if not debugMode then return end
    color = color or "#AAAAAA"
    local crossVectors = {
      {boundBox[1], 0},
      {0, boundBox[2]},
      {boundBox[3], 0},
      {0, boundBox[4]}
    }
    for _, vector in ipairs(crossVectors) do
      world.debugLine(destination, vec2.add(destination, vector), color)
    end  
  end

  local polarRectangle = function(theta)
    local a, b
    if theta >= math.pi then
        a = math.abs(boundBox[1])
        b = math.abs(boundBox[2])
    else
        a = math.abs(boundBox[3])
        b = math.abs(boundBox[4])
    end

    local ratio = b/a
    if math.abs(math.tan(theta)) <= ratio then
        return a/math.abs(math.cos(theta))
    else
        return b/math.abs(math.sin(theta))
    end

  end

  local willCollide = function(position)
    return world.polyCollision(collisionPoly, position or destination, {"Block", "Dynamic"})
  end

  local collision = function(ray, position)
    local endpoint = vec2.add(position or destination, ray)
    return world.lineCollision(position or destination, endpoint, {"Block", "Dynamic"})
  end

  local adjust = function(checkOffset, position, extraOffset)
    if extraOffset then
      checkOffset = vec2.add(checkOffset, extraOffset)
    end
    position = position or destination
    local collisionPoint = collision(checkOffset, position)
    if not collisionPoint then
      return position
    end
    local collisionVector = vec2.sub(vec2.add(checkOffset, position), collisionPoint)
    return vec2.sub(position, collisionVector)
  end

  -- no collision
  if not willCollide(destination) then
    return destination
  end

  debugCross("red")

  -- correct rectangle collision point
  local angle = vec2.angle(vec2.sub(destination, origin))
  local polarCheckOffset = vec2.rotate(
    {polarRectangle(angle), 0},
    angle
  )
  destination = adjust(polarCheckOffset, destination)

  debugCross("orange")

  -- adjust up/down/left/right
  local xtra = 1/32
  local adjusts = {
    {{boundBox[1], 0}, {-xtra, 0}},
    {{0, boundBox[2]}, {0, -xtra}},
    {{boundBox[3], 0}, {xtra, 0}},
    {{0, boundBox[4]}, {0, xtra}}
  }
  for _, vectors in ipairs(adjusts) do
    destination = adjust(vectors[1], destination, vectors[2])
  end
  
  debugCross("yellow")

  -- attempt autocorrect
  if willCollide(destination) then
    destination = world.resolvePolyCollision(collisionPoly, destination, correctionThreshold or 5)
  end

  -- return new position or nil
  if willCollide(destination) then return nil end

  return destination

end

--[[

function setTpLock()

  local checkCenterOffset = 0.2
  local currentPlayerPos = mcontroller.position()
  local playerCenterOffset = poly.center(playerCollisionPoly)
  local tpDestination = tpRay()
  
  world.debugLine(currentPlayerPos, tpDestination, "cyan")

  if not playerCollides(tpDestination) then
    tpLock = tpDestination
    return
  end

  local checkLineOffset = vec2.rotate({1, 0}, activeItem.aimAngle(0, activeItem.ownerAimPosition()))
  local checkAngle = vec2.angle(checkLineOffset)
  checkLineOffset = vec2.rotate({polarRectangle(checkAngle, poly.boundBox(playerCollisionPoly)), 0}, activeItem.aimAngle(0, activeItem.ownerAimPosition()))
  local checkLine = vec2.add(tpDestination, checkLineOffset)
  world.debugLine(tpDestination, checkLine, "yellow")

  local collisionPoint = world.lineCollision(tpDestination, checkLine, {"Block", "Dynamic"})
  if collisionPoint then
    local correctionOffset = vec2.sub(collisionPoint, checkLine)
    tpDestination = vec2.add(tpDestination, correctionOffset)
    if not playerCollides(tpDestination) then
      tpLock = tpDestination
      return
    end
  end

  local floorLine = vec2.add(tpDestination, {0, -2.5})
  local floor = world.lineCollision(vec2.add(tpDestination, {0, -checkCenterOffset}), floorLine, {"Block", "Dynamic"})
  local ceilingLine = vec2.add(tpDestination, {0, 1.22})
  local ceiling = world.lineCollision(vec2.add(tpDestination, {0, checkCenterOffset}), ceilingLine, {"Block", "Dynamic"})

  if floor and ceiling then
    goto wall_resolve
  end

  if floor and not ceiling then
    local correctionOffset = vec2.sub(floor, floorLine)
    tpDestination = vec2.add(tpDestination, correctionOffset)
    if not playerCollides(tpDestination) then
      tpLock = tpDestination
      return
    else
      goto wall_resolve
    end
  end

  if ceiling and not floor then
    local correctionOffset = vec2.sub(ceiling, ceilingLine)
    tpDestination = vec2.add(tpDestination, correctionOffset)
    if not playerCollides(tpDestination) then
      tpLock = tpDestination
      return
    else
      goto wall_resolve
    end
  end

  ::wall_resolve::

  local rightWallLine = vec2.add(tpDestination, {0.75, 0})
  local rightWall = world.lineCollision(vec2.add(tpDestination, {checkCenterOffset, 0}), rightWallLine, {"Block", "Dynamic"})
  local leftWallLine = vec2.add(tpDestination, {-0.75, 0})
  local leftWall = world.lineCollision(vec2.add(tpDestination, {-checkCenterOffset, 0}), leftWallLine, {"Block", "Dynamic"})

  if leftWall and rightWall then
    tpLock = nil
    return
  end

  if leftWall and not rightWall then
    local correctionOffset = vec2.sub(leftWall, leftWallLine)
    tpDestination = vec2.add(tpDestination, correctionOffset)
    if not playerCollides(tpDestination) then
      tpLock = tpDestination
      return
    else
      goto auto_resolve
    end
  end

  if rightWall and not leftWall then
    local correctionOffset = vec2.sub(rightWall, rightWallLine)
    tpDestination = vec2.add(tpDestination, correctionOffset)
    if not playerCollides(tpDestination) then
      tpLock = tpDestination
      return
    else
      goto auto_resolve
    end
  end
  
  ::auto_resolve::
    
  tpDestination = resolvePlayerCollision(tpDestination)
  if tpDestination then
    tpLock = tpDestination
    return
  end

  tpLock = nil

end
--]]