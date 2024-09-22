require "/scripts/util.lua"
require "/scripts/vec2.lua"
require "/scripts/versioningutils.lua"
require "/items/buildscripts/project42neo-abilities.lua"

function build(directory, config, parameters, level, seed)

  local configParameter = function(keyName, defaultValue)
    if parameters[keyName] ~= nil then
      return parameters[keyName]
    elseif config[keyName] ~= nil then
      return config[keyName]
    else
      return defaultValue
    end
  end
  
  construct(config, "primaryAbility")
  local sequenceDirectoryPath = config.primaryAbility.stanceSequenceDirectory or "/items/buildscripts/project42neo/stanceSequences.config"
  local sequenceDirectory = root.assetJson(sequenceDirectoryPath)
  local compileAnimationScripts = function(scripts)
    local compiledScripts = {nil}
    for _, scriptArray in ipairs(scripts) do
      for _, script in ipairs(scriptArray) do
        table.insert(compiledScripts, script)
      end
    end
    return compiledScripts
  end
  local applyStanceSequence = function (sequenceName, attackKey, sequenceType)
  
    local sequencePath = sequenceDirectory[sequenceName]
    local sequenceConfig = root.assetJson(sequencePath)

    construct (config, "animationCustom", "animatedParts")
    config.animationCustom.animatedParts = config.animationCustom.animatedParts or {}

    construct(config.animationCustom.animatedParts, "stateTypes", "swoosh", "states")
    config.animationCustom.animatedParts.stateTypes.swoosh.states[sequenceName] = sequenceConfig.state
  
    construct(config.animationCustom.animatedParts, "parts", "swoosh", "partStates", "swoosh", sequenceName)  
    config.animationCustom.animatedParts.parts.swoosh.partStates.swoosh[sequenceName].properties = sequenceConfig.properties

    local extras = {
      "sounds",
      "lights",
      "particleEmitters"
    }

    for _, extra in ipairs(extras) do
      if sequenceConfig[extra] then
        construct(config.animationCustom, extra)
        config.animationCustom[extra] = sb.jsonMerge(
          config.animationCustom[extra],
          sequenceConfig[extra]
        )
      end
    end
    
    if sequenceType == "sheathing" then
      construct(config.primaryAbility, "idle")
      config.primaryAbility.idle.sheathing = sequenceConfig.sequence
    elseif sequenceType == "unsheathing" then
      construct(config.primaryAbility, "idle")
      config.primaryAbility.idle.unsheathing = sequenceConfig.sequence
    else
      construct(config.primaryAbility, "combo", "attacks", sequenceName)
      config.primaryAbility.combo.attacks[attackKey or sequenceName].sequence = sequenceConfig.sequence
      config.primaryAbility.combo.attacks[attackKey or sequenceName].attackIndex = sequenceConfig.attackIndex  
    end
  end

  if level and not configParameter("fixedLevel", true) then
    parameters.level = level
  end

  local primaryAnimationScripts = setupAbility(config, parameters, "primary")
  local altAnimationScripts = setupAbility(config, parameters, "alt")
  parameters.animationScripts = compileAnimationScripts({
    altAnimationScripts,
    primaryAnimationScripts
  })

  -- SECTION: configure primary ability, expected to be project42neo
  
  construct(config, "primaryAbility", "idle")
  if type(config.primaryAbility.idle.sheathing) == "string" then
    applyStanceSequence(config.primaryAbility.idle.sheathing, nil, "sheathing")
  end
  if type(config.primaryAbility.idle.unsheathing) == "string" then
    applyStanceSequence(config.primaryAbility.idle.unsheathing, nil, "unsheathing")
  end

  construct(config, "primaryAbility", "combo", "attacks")
  for attackKey, attackConfig in pairs(config.primaryAbility.combo.attacks or {}) do
    if type(attackConfig.sequence) == "string" then
      applyStanceSequence(attackConfig.sequence, attackKey)
    end
  end

  local elementalType = configParameter("elementalType", "physical")
  -- TODO: elemental type and config (for shift abilities)
  --[[
  replacePatternInData(config, nil, "<elementalType>", elementalType)
  if config.altAbility and config.altAbility.elementalConfig then
    util.mergeTable(config.altAbility, config.altAbility.elementalConfig[elementalType])
  end
  --]]

  -- calculate damage level multiplier
  config.damageLevelMultiplier = root.evalFunction("weaponDamageLevelMultiplier", configParameter("level", 1))

  -- offsets
  if config.baseOffset then

    local swordParts = {
      "blade",
      "bladeFullbright",
      "charge",
      "chargeFullbright"
    }

    for _, part in ipairs(swordParts) do

      construct(config, "animationCustom", "animatedParts", "parts", part, "properties")
      config.animationCustom.animatedParts.parts[part].properties.offset = config.baseOffset

    end

  end

  -- populate tooltip fields
  if config.tooltipKind ~= "base" then
    config.tooltipFields = {}
    config.tooltipFields.levelLabel = util.round(configParameter("level", 1), 1)
    config.tooltipFields.dpsLabel = util.round((config.primaryAbility.baseDps or 0) * config.damageLevelMultiplier, 1)
    config.tooltipFields.speedLabel = util.round(1 / (config.primaryAbility.fireTime or 1.0), 1)
    config.tooltipFields.damagePerShotLabel = util.round((config.primaryAbility.baseDps or 0) * (config.primaryAbility.fireTime or 1.0) * config.damageLevelMultiplier, 1)
    config.tooltipFields.energyPerShotLabel = util.round((config.primaryAbility.energyUsage or 0) * (config.primaryAbility.fireTime or 1.0), 1)
    if elementalType ~= "physical" then
      config.tooltipFields.damageKindImage = "/interface/elements/"..elementalType..".png"
    end
    if config.primaryAbility then
      config.tooltipFields.primaryAbilityTitleLabel = "Primary:"
      config.tooltipFields.primaryAbilityLabel = config.primaryAbility.name or "unknown"
    end
    if config.altAbility then
      config.tooltipFields.altAbilityTitleLabel = "Special:"
      config.tooltipFields.altAbilityLabel = config.altAbility.name or "unknown"
    end
  end

  -- set price
  -- TODO: should this be handled elsewhere?
  config.price = (config.price or 0) * root.evalFunction("itemLevelPriceMultiplier", configParameter("level", 1))

  return config, parameters
end
