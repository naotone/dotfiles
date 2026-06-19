local M = {}

local function buildActionToNavKeyMap(navMap)
  local actionToNavKey = {}
  for navKey, action in pairs(navMap or {}) do
    if type(action) == "string" then
      local existing = actionToNavKey[action]
      if existing and existing ~= navKey then
        return nil, string.format(
          "duplicate navMap action '%s' for keys '%s' and '%s'",
          action,
          tostring(existing),
          tostring(navKey)
        )
      end
      actionToNavKey[action] = navKey
    end
  end
  return actionToNavKey, nil
end

local function registerKeyCode(mapping, keyCode, logicalKey)
  if type(keyCode) ~= "number" or type(logicalKey) ~= "string" then
    return true, nil
  end

  local existing = mapping[keyCode]
  if existing then
    return false, string.format(
      "duplicate keyCode mapping %s (%s vs %s)",
      tostring(keyCode),
      tostring(existing),
      tostring(logicalKey)
    )
  end

  mapping[keyCode] = logicalKey
  return true, nil
end

function M.new(config)
  config = config or {}

  local actionToNavKey, navErr = buildActionToNavKeyMap(config.navMap)
  if not actionToNavKey then
    return nil, navErr
  end

  local mapping = {}

  for index, logicalKey in ipairs(config.triggerKeys or {}) do
    local keyCode = (config.triggerKeyCodes or {})[index]
    local ok, err = registerKeyCode(mapping, keyCode, logicalKey)
    if not ok then
      return nil, err
    end
  end

  for rawCode, action in pairs(config.navKeyCodeMap or {}) do
    local keyCode = tonumber(rawCode)
    if keyCode and type(action) == "string" then
      local logicalKey = actionToNavKey[action]
      if not logicalKey then
        return nil, string.format("navKeyCodeMap action '%s' is not defined in navMap", action)
      end
      local ok, err = registerKeyCode(mapping, keyCode, logicalKey)
      if not ok then
        return nil, err
      end
    end
  end

  return {
    keyCodeToLogicalKey = mapping,
  }, nil
end

function M.resolveKey(state, keyCode, fallbackKey)
  if state and type(keyCode) == "number" then
    local resolved = state.keyCodeToLogicalKey and state.keyCodeToLogicalKey[keyCode] or nil
    if resolved then
      return resolved
    end
  end
  return fallbackKey
end

return M
