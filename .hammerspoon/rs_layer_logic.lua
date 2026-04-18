local M = {}

local MODIFIER_KEYS = {"cmd", "alt", "shift", "ctrl", "fn"}

local DEFAULT_CONFIG = {
  simultaneousThresholdMs = 70,
  activationDelayMs = 120,
  triggerKeys = {"r", "s"},
  navMap = {h = "left", n = "down", e = "up", i = "right"},
}

local function copyArray(input)
  local out = {}
  for i, value in ipairs(input or {}) do
    out[i] = value
  end
  return out
end

local function copyTable(input)
  local out = {}
  for key, value in pairs(input or {}) do
    out[key] = value
  end
  return out
end

local function normalizeConfig(config)
  local merged = {
    simultaneousThresholdMs = DEFAULT_CONFIG.simultaneousThresholdMs,
    activationDelayMs = DEFAULT_CONFIG.activationDelayMs,
    triggerKeys = copyArray(DEFAULT_CONFIG.triggerKeys),
    navMap = copyTable(DEFAULT_CONFIG.navMap),
  }

  config = config or {}
  if type(config.simultaneousThresholdMs) == "number" then
    merged.simultaneousThresholdMs = config.simultaneousThresholdMs
  end
  if type(config.activationDelayMs) == "number" then
    merged.activationDelayMs = config.activationDelayMs
  end
  if type(config.triggerKeys) == "table" and #config.triggerKeys == 2 then
    merged.triggerKeys = copyArray(config.triggerKeys)
  end
  if type(config.navMap) == "table" then
    merged.navMap = copyTable(config.navMap)
  end

  return merged
end

local function emptyResult(swallow)
  return {
    swallow = swallow and true or false,
    actions = {},
  }
end

local function keyAction(key, modifiers)
  return {
    key = key,
    modifiers = modifiers or {},
  }
end

local function extractModifiers(flags)
  local modifiers = {}
  for _, modifier in ipairs(MODIFIER_KEYS) do
    if flags and flags[modifier] then
      table.insert(modifiers, modifier)
    end
  end
  return modifiers
end

local function hasTriggerModifiers(flags)
  for _, modifier in ipairs(MODIFIER_KEYS) do
    if flags and flags[modifier] then
      return true
    end
  end
  return false
end

local function rebuildPendingOrder(state)
  local newOrder = {}
  for _, key in ipairs(state.pendingOrder) do
    if state.triggers[key] and state.triggers[key].pending then
      table.insert(newOrder, key)
    end
  end
  state.pendingOrder = newOrder
end

local function addPending(state, key)
  local trigger = state.triggers[key]
  if not trigger then
    return
  end
  trigger.pending = true

  for _, existing in ipairs(state.pendingOrder) do
    if existing == key then
      return
    end
  end
  table.insert(state.pendingOrder, key)
end

local function clearPending(state, key)
  local trigger = state.triggers[key]
  if not trigger then
    return
  end
  trigger.pending = false
  rebuildPendingOrder(state)
end

local function clearAllPending(state)
  for _, key in ipairs(state.config.triggerKeys) do
    if state.triggers[key] then
      state.triggers[key].pending = false
    end
  end
  state.pendingOrder = {}
end

local function anyPending(state)
  for _, key in ipairs(state.config.triggerKeys) do
    if state.triggers[key] and state.triggers[key].pending then
      return true
    end
  end
  return false
end

local function flushPending(state, keepKey)
  local actions = {}
  local nextOrder = {}

  for _, key in ipairs(state.pendingOrder) do
    local trigger = state.triggers[key]
    if trigger and trigger.pending then
      if keepKey and key == keepKey then
        table.insert(nextOrder, key)
      else
        table.insert(actions, keyAction(key, {}))
        trigger.pending = false
        trigger.emitted = true
      end
    end
  end

  state.pendingOrder = nextOrder
  if #actions > 0 then
    state.candidateStartMs = nil
  end

  return actions
end

local function setIdleIfAllTriggersReleased(state)
  for _, key in ipairs(state.config.triggerKeys) do
    if state.triggers[key] and state.triggers[key].down then
      return
    end
  end
  state.layerActive = false
  state.candidateStartMs = nil
  clearAllPending(state)
end

local function resetState(state)
  state.layerActive = false
  state.candidateStartMs = nil
  state.pendingOrder = {}
  for _, key in ipairs(state.config.triggerKeys) do
    state.triggers[key] = {
      down = false,
      downAtMs = nil,
      pending = false,
      emitted = false,
      handledDown = false,
    }
  end
end

local function getOtherTriggerKey(state, key)
  for _, candidate in ipairs(state.config.triggerKeys) do
    if candidate ~= key then
      return candidate
    end
  end
  return nil
end

local function canStartCandidate(state, key, timestampMs)
  local otherKey = getOtherTriggerKey(state, key)
  if not otherKey then
    return false
  end

  local trigger = state.triggers[key]
  local other = state.triggers[otherKey]
  if not trigger or not other then
    return false
  end
  if not trigger.down or not other.down then
    return false
  end
  if not trigger.pending or not other.pending then
    return false
  end

  local delta = math.abs((trigger.downAtMs or timestampMs) - (other.downAtMs or timestampMs))
  if delta > state.config.simultaneousThresholdMs then
    return false
  end

  state.candidateStartMs = math.max(trigger.downAtMs or timestampMs, other.downAtMs or timestampMs)
  return true
end

local function shouldActivateLayer(state, nowMs)
  if state.layerActive then
    return false
  end
  if not state.candidateStartMs then
    return false
  end
  if not anyPending(state) then
    return false
  end

  for _, key in ipairs(state.config.triggerKeys) do
    local trigger = state.triggers[key]
    if not trigger or not trigger.down or not trigger.pending then
      return false
    end
  end

  return (nowMs - state.candidateStartMs) >= state.config.activationDelayMs
end

local function maybeActivateLayer(state, nowMs)
  if not shouldActivateLayer(state, nowMs) then
    return false
  end

  state.layerActive = true
  for _, key in ipairs(state.config.triggerKeys) do
    local trigger = state.triggers[key]
    trigger.pending = false
    trigger.emitted = true
  end
  state.pendingOrder = {}
  state.candidateStartMs = nil
  return true
end

local function processTriggerDown(state, key, timestampMs)
  local result = emptyResult(false)
  local trigger = state.triggers[key]
  if not trigger then
    return result
  end

  if trigger.down then
    if trigger.handledDown then
      result.swallow = true
    end
    return result
  end

  result.swallow = true
  trigger.down = true
  trigger.downAtMs = timestampMs
  trigger.emitted = false
  trigger.handledDown = true
  addPending(state, key)

  local otherKey = getOtherTriggerKey(state, key)
  local other = otherKey and state.triggers[otherKey] or nil
  if other and other.down and other.pending then
    if not canStartCandidate(state, key, timestampMs) then
      result.actions = flushPending(state, key)
    end
  else
    state.candidateStartMs = nil
  end

  maybeActivateLayer(state, timestampMs)
  return result
end

local function processTriggerUp(state, key, timestampMs)
  local result = emptyResult(false)
  local trigger = state.triggers[key]
  if not trigger then
    return result
  end

  if not trigger.down then
    return result
  end

  result.swallow = trigger.handledDown and true or false
  trigger.down = false
  trigger.downAtMs = nil

  if not result.swallow then
    trigger.pending = false
    trigger.emitted = false
    trigger.handledDown = false
    setIdleIfAllTriggersReleased(state)
    maybeActivateLayer(state, timestampMs)
    return result
  end

  if state.layerActive then
    state.layerActive = false
    state.candidateStartMs = nil
    clearPending(state, key)
    trigger.emitted = false
    trigger.handledDown = false
    setIdleIfAllTriggersReleased(state)
    return result
  end

  if trigger.pending then
    local otherKey = getOtherTriggerKey(state, key)
    local other = otherKey and state.triggers[otherKey] or nil
    if other and other.down and other.pending and state.candidateStartMs then
      result.actions = flushPending(state)
    else
      clearPending(state, key)
      table.insert(result.actions, keyAction(key, {}))
      trigger.emitted = true
    end
  else
    clearPending(state, key)
  end

  trigger.emitted = false
  trigger.handledDown = false
  setIdleIfAllTriggersReleased(state)
  maybeActivateLayer(state, timestampMs)
  return result
end

function M.new(config)
  local state = {
    config = normalizeConfig(config),
    triggers = {},
    triggerSet = {},
    pendingOrder = {},
    layerActive = false,
    candidateStartMs = nil,
  }

  for _, key in ipairs(state.config.triggerKeys) do
    state.triggerSet[key] = true
  end

  resetState(state)
  return state
end

function M.reset(state)
  if not state then
    return
  end
  resetState(state)
end

function M.processEvent(state, event)
  if not state or type(event) ~= "table" then
    return emptyResult(false)
  end

  local eventType = event.type
  if eventType ~= "keyDown" and eventType ~= "keyUp" then
    return emptyResult(false)
  end

  if event.excluded then
    resetState(state)
    return emptyResult(false)
  end

  local timestampMs = event.timestampMs or 0
  maybeActivateLayer(state, timestampMs)

  local key = event.key
  if not key then
    return emptyResult(false)
  end

  if state.triggerSet[key] and hasTriggerModifiers(event.flags) then
    return emptyResult(false)
  end

  if state.triggerSet[key] then
    if eventType == "keyDown" then
      return processTriggerDown(state, key, timestampMs)
    end
    return processTriggerUp(state, key, timestampMs)
  end

  if state.layerActive and state.config.navMap[key] then
    local mappedKey = state.config.navMap[key]
    local result = emptyResult(true)
    if eventType == "keyDown" then
      table.insert(result.actions, keyAction(mappedKey, extractModifiers(event.flags)))
    end
    return result
  end

  if eventType == "keyDown" and anyPending(state) then
    local result = emptyResult(false)
    result.actions = flushPending(state)
    return result
  end

  return emptyResult(false)
end

return M
