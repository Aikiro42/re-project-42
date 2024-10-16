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