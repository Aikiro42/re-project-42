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