function init()
    self.powerModifier = config.getParameter("powerModifier", 1.25)
    effect.addStatModifierGroup({{stat = "powerMultiplier", effectiveMultiplier = self.powerModifier}})
end

function update(dt)

end

function uninit()

end
