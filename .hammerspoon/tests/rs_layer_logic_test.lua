local function dirname(path)
  return path:match("(.+)/[^/]+$") or "."
end

local testDir = dirname(arg[0] or ".")
local hsDir = dirname(testDir)
package.path = hsDir .. "/?.lua;" .. package.path

local rsLayerLogic = require("rs_layer_logic")

local BASE_CONFIG = {
  simultaneousThresholdMs = 70,
  activationDelayMs = 120,
  triggerKeys = {"r", "s"},
  navMap = {h = "left", n = "down", e = "up", i = "right"},
}

local function deepEqual(a, b)
  if type(a) ~= type(b) then
    return false
  end
  if type(a) ~= "table" then
    return a == b
  end

  for k, v in pairs(a) do
    if not deepEqual(v, b[k]) then
      return false
    end
  end
  for k, _ in pairs(b) do
    if a[k] == nil then
      return false
    end
  end

  return true
end

local function assertTrue(value, message)
  if not value then
    error(message)
  end
end

local function assertEqual(actual, expected, message)
  if actual ~= expected then
    error(string.format("%s: expected=%s actual=%s", message, tostring(expected), tostring(actual)))
  end
end

local function normalizeAction(action)
  local mods = {}
  for _, mod in ipairs(action.modifiers or {}) do
    table.insert(mods, mod)
  end
  table.sort(mods)
  return {
    key = action.key,
    modifiers = mods,
  }
end

local function assertActions(actual, expected, message)
  local normalizedActual = {}
  for _, action in ipairs(actual or {}) do
    table.insert(normalizedActual, normalizeAction(action))
  end

  local normalizedExpected = {}
  for _, action in ipairs(expected or {}) do
    table.insert(normalizedExpected, normalizeAction(action))
  end

  if not deepEqual(normalizedActual, normalizedExpected) then
    error(string.format("%s: actions mismatch", message))
  end
end

local function newState()
  return rsLayerLogic.new(BASE_CONFIG)
end

local function event(eventType, key, timestampMs, options)
  options = options or {}
  return {
    type = eventType,
    key = key,
    timestampMs = timestampMs,
    flags = options.flags or {},
    excluded = options.excluded or false,
  }
end

local function testSingleRTap()
  local state = newState()
  local down = rsLayerLogic.processEvent(state, event("keyDown", "r", 0))
  assertEqual(down.swallow, true, "single r down should be swallowed")
  assertActions(down.actions, {}, "single r down should not emit actions")

  local up = rsLayerLogic.processEvent(state, event("keyUp", "r", 40))
  assertEqual(up.swallow, true, "single r up should be swallowed")
  assertActions(up.actions, {{key = "r", modifiers = {}}}, "single r up should emit r")
end

local function testSingleSTap()
  local state = newState()
  rsLayerLogic.processEvent(state, event("keyDown", "s", 0))
  local up = rsLayerLogic.processEvent(state, event("keyUp", "s", 30))
  assertActions(up.actions, {{key = "s", modifiers = {}}}, "single s up should emit s")
end

local function testOutsideThresholdEmitsRs()
  local state = newState()
  rsLayerLogic.processEvent(state, event("keyDown", "r", 0))

  local sDown = rsLayerLogic.processEvent(state, event("keyDown", "s", 100))
  assertActions(sDown.actions, {{key = "r", modifiers = {}}}, "second trigger outside threshold should flush r")

  local rUp = rsLayerLogic.processEvent(state, event("keyUp", "r", 110))
  assertActions(rUp.actions, {}, "r was already flushed")

  local sUp = rsLayerLogic.processEvent(state, event("keyUp", "s", 130))
  assertActions(sUp.actions, {{key = "s", modifiers = {}}}, "s should emit on release")
end

local function testInsideThresholdWithoutActivationDelayEmitsRs()
  local state = newState()
  rsLayerLogic.processEvent(state, event("keyDown", "r", 0))
  rsLayerLogic.processEvent(state, event("keyDown", "s", 20))

  local rUp = rsLayerLogic.processEvent(state, event("keyUp", "r", 80))
  assertActions(
    rUp.actions,
    {
      {key = "r", modifiers = {}},
      {key = "s", modifiers = {}},
    },
    "releasing trigger before activation should flush rs in press order"
  )

  local sUp = rsLayerLogic.processEvent(state, event("keyUp", "s", 90))
  assertActions(sUp.actions, {}, "s should not emit twice")
end

local function testLayerActivationAndNavMapping()
  local state = newState()
  rsLayerLogic.processEvent(state, event("keyDown", "r", 0))
  rsLayerLogic.processEvent(state, event("keyDown", "s", 20))

  local hDown = rsLayerLogic.processEvent(state, event("keyDown", "h", 200))
  assertEqual(hDown.swallow, true, "mapped nav key should be swallowed")
  assertActions(hDown.actions, {{key = "left", modifiers = {}}}, "h should map to left")
  assertTrue(state.layerActive, "layer should be active")

  local hUp = rsLayerLogic.processEvent(state, event("keyUp", "h", 210))
  assertEqual(hUp.swallow, true, "mapped nav key up should be swallowed")
  assertActions(hUp.actions, {}, "mapped nav key up should not emit action")

  rsLayerLogic.processEvent(state, event("keyUp", "r", 220))
  assertTrue(not state.layerActive, "layer should be inactive after releasing trigger")
end

local function testModifierCarryOver()
  local state = newState()
  rsLayerLogic.processEvent(state, event("keyDown", "r", 0))
  rsLayerLogic.processEvent(state, event("keyDown", "s", 20))

  local iDown = rsLayerLogic.processEvent(
    state,
    event("keyDown", "i", 200, {flags = {shift = true, cmd = true, capslock = true}})
  )
  assertActions(
    iDown.actions,
    {{key = "right", modifiers = {"cmd", "shift"}}},
    "nav mapping should keep supported modifiers only"
  )
end

local function testExcludedAppPassThroughAndReset()
  local state = newState()
  local excludedDown = rsLayerLogic.processEvent(state, event("keyDown", "r", 0, {excluded = true}))
  assertEqual(excludedDown.swallow, false, "excluded app should pass through keyDown")
  assertActions(excludedDown.actions, {}, "excluded app should not emit actions")

  local excludedUp = rsLayerLogic.processEvent(state, event("keyUp", "r", 20, {excluded = true}))
  assertEqual(excludedUp.swallow, false, "excluded app should pass through keyUp")

  local normalDown = rsLayerLogic.processEvent(state, event("keyDown", "r", 100))
  assertEqual(normalDown.swallow, true, "state should recover after excluded app events")
  local normalUp = rsLayerLogic.processEvent(state, event("keyUp", "r", 120))
  assertActions(normalUp.actions, {{key = "r", modifiers = {}}}, "normal app should keep behavior")
end

local function testFlushPendingOnOtherKey()
  local state = newState()
  rsLayerLogic.processEvent(state, event("keyDown", "r", 0))
  local aDown = rsLayerLogic.processEvent(state, event("keyDown", "a", 20))
  assertEqual(aDown.swallow, false, "non-trigger key should pass through")
  assertActions(aDown.actions, {{key = "r", modifiers = {}}}, "pending trigger should flush before other keys")
end

local function testTriggerKeyUpWithoutManagedDownShouldPassThrough()
  local state = newState()
  local rUp = rsLayerLogic.processEvent(state, event("keyUp", "r", 0))
  assertEqual(rUp.swallow, false, "trigger keyUp without managed keyDown should pass through")
  assertActions(rUp.actions, {}, "unexpected keyUp should not emit synthetic actions")
end

local function testTriggerWithModifierShouldPassThrough()
  local state = newState()
  local sDown = rsLayerLogic.processEvent(state, event("keyDown", "s", 0, {flags = {cmd = true}}))
  assertEqual(sDown.swallow, false, "cmd+s down should pass through")
  assertActions(sDown.actions, {}, "cmd+s down should not emit synthetic actions")

  local sUp = rsLayerLogic.processEvent(state, event("keyUp", "s", 20, {flags = {cmd = true}}))
  assertEqual(sUp.swallow, false, "cmd+s up should pass through")
  assertActions(sUp.actions, {}, "cmd+s up should not emit synthetic actions")
end

local tests = {
  testSingleRTap,
  testSingleSTap,
  testOutsideThresholdEmitsRs,
  testInsideThresholdWithoutActivationDelayEmitsRs,
  testLayerActivationAndNavMapping,
  testModifierCarryOver,
  testExcludedAppPassThroughAndReset,
  testFlushPendingOnOtherKey,
  testTriggerKeyUpWithoutManagedDownShouldPassThrough,
  testTriggerWithModifierShouldPassThrough,
}

for _, test in ipairs(tests) do
  test()
end

print("rs_layer_logic tests passed")
