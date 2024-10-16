require "/scripts/vec2.lua"
require "/scripts/interp.lua"
require "/scripts/util.lua"

function init()
    self.sourceEntity = projectile.sourceEntity()
    if not self.sourceEntity then projectile.die() end
    self.time = projectile.timeToLive()
    self.timer = self.time
    self.origin = mcontroller.position()

    message.setHandler("screenshake", jerk)

end

function update(dt)
    self.timer = math.max(0, self.timer - dt)
    interpToSource(self.timer/self.time)
end

function interpToSource(progress)
    if not world.entityExists(self.sourceEntity) then projectile.die() end
    local destination = world.entityPosition(self.sourceEntity)
    local newPosition = {
        interp.sin(progress, destination[1], self.origin[1]),
        interp.sin(progress, destination[2], self.origin[2])
    }
    mcontroller.setPosition(newPosition)
end

function jerk()
    self.origin = vec2.add(
        mcontroller.position(),
        vec2.rotate({0.5, 0}, sb.nrand(2 * math.pi, 0))
    )
    mcontroller.setPosition(self.origin)
end

function die()
    projectile.die()
end