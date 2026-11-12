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
  triggerBounceThresholdMs = 30,
  triggerKeys = {"r", "s"},
  navMap = {h = "left", n = "down", e = "up", i = "right"},
}

local STRESS_RUNS = 500

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

local function countActions(actions, key)
  local count = 0
  for _, action in ipairs(actions or {}) do
    if action.key == key then
      count = count + 1
    end
  end
  return count
end

local function assertNoActions(actual, message)
  assertActions(actual, {}, message)
end

local function newState()
  return rsLayerLogic.new(BASE_CONFIG)
end

local function event(eventType, key, timestampMs, options)
  options = options or {}
  return {
    type = eventType,
    key = key,
    keyCode = options.keyCode,
    timestampMs = timestampMs,
    flags = options.flags or {},
    excluded = options.excluded or false,
    ["repeat"] = options["repeat"] or false,
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

local function testModifierFlagsChangedCarryOver()
  local state = newState()
  rsLayerLogic.processEvent(state, event("keyDown", "r", 0))
  rsLayerLogic.processEvent(state, event("keyDown", "s", 20))

  local ctrlDown = rsLayerLogic.processEvent(state, event("flagsChanged", nil, 160, {flags = {ctrl = true}}))
  assertEqual(ctrlDown.swallow, false, "modifier flagsChanged should pass through")
  assertNoActions(ctrlDown.actions, "modifier flagsChanged should not emit actions")

  local hDown = rsLayerLogic.processEvent(state, event("keyDown", "h", 200))
  assertActions(
    hDown.actions,
    {{key = "left", modifiers = {"ctrl"}}},
    "nav mapping should keep ctrl from flagsChanged"
  )

  rsLayerLogic.processEvent(state, event("keyUp", "h", 210))
  local ctrlUp = rsLayerLogic.processEvent(state, event("flagsChanged", nil, 220, {flags = {}}))
  assertEqual(ctrlUp.swallow, false, "modifier release flagsChanged should pass through")
  assertNoActions(ctrlUp.actions, "modifier release flagsChanged should not emit actions")

  local iDown = rsLayerLogic.processEvent(state, event("keyDown", "i", 240))
  assertActions(
    iDown.actions,
    {{key = "right", modifiers = {}}},
    "nav mapping should clear released modifiers"
  )
end

local function testAllModifierFlagsChangedCarryOver()
  local state = newState()
  rsLayerLogic.processEvent(state, event("keyDown", "r", 0))
  rsLayerLogic.processEvent(state, event("keyDown", "s", 20))

  local flagsDown = rsLayerLogic.processEvent(
    state,
    event(
      "flagsChanged",
      nil,
      160,
      {flags = {cmd = true, alt = true, shift = true, ctrl = true, fn = true, capslock = true}}
    )
  )
  assertEqual(flagsDown.swallow, false, "all modifier flagsChanged should pass through")
  assertNoActions(flagsDown.actions, "all modifier flagsChanged should not emit actions")

  local eDown = rsLayerLogic.processEvent(state, event("keyDown", "e", 200))
  assertActions(
    eDown.actions,
    {{key = "up", modifiers = {"cmd", "alt", "shift", "ctrl", "fn"}}},
    "nav mapping should keep supported modifiers from flagsChanged"
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
  local ctrlDown = rsLayerLogic.processEvent(state, event("flagsChanged", nil, 0, {flags = {ctrl = true}}))
  assertEqual(ctrlDown.swallow, false, "pre-layer modifier flagsChanged should pass through")
  assertActions(ctrlDown.actions, {}, "pre-layer modifier flagsChanged should not emit synthetic actions")

  local sDown = rsLayerLogic.processEvent(state, event("keyDown", "s", 10, {flags = {cmd = true, ctrl = true}}))
  assertEqual(sDown.swallow, false, "cmd+ctrl+s down should pass through")
  assertActions(sDown.actions, {}, "cmd+ctrl+s down should not emit synthetic actions")

  local sUp = rsLayerLogic.processEvent(state, event("keyUp", "s", 20, {flags = {cmd = true, ctrl = true}}))
  assertEqual(sUp.swallow, false, "cmd+ctrl+s up should pass through")
  assertActions(sUp.actions, {}, "cmd+ctrl+s up should not emit synthetic actions")
end

local function testUnrelatedRepeatFlushesPendingTrigger()
  local state = newState()
  rsLayerLogic.processEvent(state, event("keyDown", "a", 0))
  rsLayerLogic.processEvent(state, event("keyDown", "s", 100))

  local repeated = rsLayerLogic.processEvent(state, event("keyDown", "a", 200, {["repeat"] = true}))
  assertEqual(repeated.swallow, false, "unrelated repeat should pass through")
  assertActions(repeated.actions, {{key = "s"}}, "pending trigger should precede unrelated repeat")

  local sUp = rsLayerLogic.processEvent(state, event("keyUp", "s", 220))
  assertEqual(sUp.swallow, true, "trigger up should still be handled")
  assertNoActions(sUp.actions, "flushed trigger should not emit again on release")
end

local function testRepeatedTriggerAutoRepeatDoesNotChatter()
  local state = newState()
  rsLayerLogic.processEvent(state, event("keyDown", "s", 0, {keyCode = 0x02}))

  for i = 1, STRESS_RUNS do
    local repeated = rsLayerLogic.processEvent(
      state,
      event("keyDown", "s", i, {keyCode = 0x02, ["repeat"] = true})
    )
    assertEqual(repeated.swallow, true, "trigger repeat should be swallowed")
    assertNoActions(repeated.actions, "trigger repeat should not emit actions")
  end

  local sUp = rsLayerLogic.processEvent(state, event("keyUp", "s", STRESS_RUNS + 1))
  assertEqual(sUp.swallow, true, "trigger up should still be handled after repeats")
  assertEqual(#sUp.actions, 1, "trigger should emit once after repeated keyDown events")
  assertEqual(sUp.actions[1].key, "s", "trigger should emit the original key")
end

local function testRepeatedLayerArrowInputsDoNotChatter()
  local arrowCount = 0
  local literalTriggerCount = 0

  for i = 1, STRESS_RUNS do
    local state = newState()
    local base = i * 1000
    rsLayerLogic.processEvent(state, event("keyDown", "r", base, {keyCode = 0x01}))
    rsLayerLogic.processEvent(state, event("keyDown", "s", base + 20, {keyCode = 0x02}))

    local hDown = rsLayerLogic.processEvent(state, event("keyDown", "h", base + 160))
    assertEqual(hDown.swallow, true, "nav keyDown should be swallowed")
    arrowCount = arrowCount + countActions(hDown.actions, "left")
    literalTriggerCount = literalTriggerCount + countActions(hDown.actions, "r")
    literalTriggerCount = literalTriggerCount + countActions(hDown.actions, "s")

    local hUp = rsLayerLogic.processEvent(state, event("keyUp", "h", base + 170))
    assertEqual(hUp.swallow, true, "nav keyUp should be swallowed")
    assertNoActions(hUp.actions, "nav keyUp should not emit actions")

    local rUp = rsLayerLogic.processEvent(state, event("keyUp", "r", base + 180))
    assertEqual(rUp.swallow, true, "first trigger release should be swallowed")
    assertNoActions(rUp.actions, "first trigger release should not emit actions")

    local sUp = rsLayerLogic.processEvent(state, event("keyUp", "s", base + 190))
    assertEqual(sUp.swallow, true, "second trigger release should be swallowed")
    assertNoActions(sUp.actions, "second trigger release should not emit actions")
  end

  assertEqual(arrowCount, STRESS_RUNS, "one arrow action should be emitted per nav keyDown")
  assertEqual(literalTriggerCount, 0, "layer use should not leak trigger keys")
end

local function testHeldNavAutoRepeatEmitsOneArrowPerKeyDown()
  local state = newState()
  local arrowCount = 0

  rsLayerLogic.processEvent(state, event("keyDown", "r", 0, {keyCode = 0x01}))
  rsLayerLogic.processEvent(state, event("keyDown", "s", 20, {keyCode = 0x02}))

  local initial = rsLayerLogic.processEvent(state, event("keyDown", "h", 160))
  assertEqual(initial.swallow, true, "initial nav keyDown should be swallowed")
  arrowCount = arrowCount + countActions(initial.actions, "left")

  for i = 1, STRESS_RUNS do
    local repeated = rsLayerLogic.processEvent(state, event("keyDown", "h", 160 + i, {["repeat"] = true}))
    assertEqual(repeated.swallow, true, "nav repeat should be swallowed")
    assertEqual(repeated.actions[1]["repeat"], true, "nav action should preserve repeat metadata")
    arrowCount = arrowCount + countActions(repeated.actions, "left")
  end

  local hUp = rsLayerLogic.processEvent(state, event("keyUp", "h", 700))
  assertEqual(hUp.swallow, true, "nav keyUp should be swallowed")
  assertNoActions(hUp.actions, "nav keyUp should not emit actions")

  assertEqual(arrowCount, STRESS_RUNS + 1, "nav repeat should emit exactly one arrow per keyDown")
end

local function testActiveLayerTriggerBounceDoesNotLeakTriggerKeys()
  local arrowCount = 0
  local literalTriggerCount = 0

  for i = 1, STRESS_RUNS do
    local state = newState()
    local base = i * 1000
    rsLayerLogic.processEvent(state, event("keyDown", "r", base, {keyCode = 0x01}))
    rsLayerLogic.processEvent(state, event("keyDown", "s", base + 20, {keyCode = 0x02}))

    local firstNav = rsLayerLogic.processEvent(state, event("keyDown", "h", base + 160))
    assertEqual(firstNav.swallow, true, "first nav keyDown should be swallowed")
    arrowCount = arrowCount + countActions(firstNav.actions, "left")
    rsLayerLogic.processEvent(state, event("keyUp", "h", base + 162))

    local bouncedUp = rsLayerLogic.processEvent(state, event("keyUp", "s", base + 165))
    assertEqual(bouncedUp.swallow, true, "bounced trigger keyUp should be swallowed")
    assertNoActions(bouncedUp.actions, "bounced trigger keyUp should not emit actions")

    local bouncedDown = rsLayerLogic.processEvent(state, event("keyDown", "s", base + 166, {keyCode = 0x02}))
    assertEqual(bouncedDown.swallow, true, "bounced trigger keyDown should be swallowed")
    assertNoActions(bouncedDown.actions, "bounced trigger keyDown should not emit actions")

    local secondNav = rsLayerLogic.processEvent(state, event("keyDown", "h", base + 170))
    assertEqual(secondNav.swallow, true, "nav after trigger bounce should still be swallowed")
    arrowCount = arrowCount + countActions(secondNav.actions, "left")
    literalTriggerCount = literalTriggerCount + countActions(secondNav.actions, "r")
    literalTriggerCount = literalTriggerCount + countActions(secondNav.actions, "s")
  end

  assertEqual(arrowCount, STRESS_RUNS * 2, "trigger bounce should not drop arrow mapping")
  assertEqual(literalTriggerCount, 0, "trigger bounce should not leak trigger keys")
end

local function testTriggerReleaseBounceWindowExpires()
  local state = newState()
  rsLayerLogic.processEvent(state, event("keyDown", "r", 0, {keyCode = 0x01}))
  rsLayerLogic.processEvent(state, event("keyDown", "s", 20, {keyCode = 0x02}))

  local firstNav = rsLayerLogic.processEvent(state, event("keyDown", "h", 160))
  assertEqual(firstNav.swallow, true, "first nav keyDown should be swallowed")
  assertActions(firstNav.actions, {{key = "left", modifiers = {}}}, "first nav should map to left")

  local sUp = rsLayerLogic.processEvent(state, event("keyUp", "s", 165))
  assertEqual(sUp.swallow, true, "trigger release should be swallowed")
  assertNoActions(sUp.actions, "trigger release should not emit actions")
  rsLayerLogic.processEvent(state, event("keyUp", "h", 180))

  local hDown = rsLayerLogic.processEvent(state, event("keyDown", "h", 196))
  assertEqual(hDown.swallow, false, "nav after bounce window should pass through")
  assertNoActions(hDown.actions, "nav after bounce window should not emit synthetic actions")
end

local function testTriggerTapEmitsOriginalKeyCode()
  local state = newState()
  rsLayerLogic.processEvent(state, event("keyDown", "s", 0, {keyCode = 0x02}))
  local sUp = rsLayerLogic.processEvent(state, event("keyUp", "s", 40))
  assertEqual(sUp.actions[1].keyCode, 0x02, "trigger tap should keep original keyCode for emit")
end

local function activateLayer(state)
  rsLayerLogic.processEvent(state, event("keyDown", "r", 0))
  rsLayerLogic.processEvent(state, event("keyDown", "s", 20))
  rsLayerLogic.processEvent(state, event("flagsChanged", nil, 160))
end

local function testModifiedTriggerReleaseEndsLayer()
  for _, modifier in ipairs({"shift", "ctrl", "cmd", "alt", "fn"}) do
    local state = newState()
    activateLayer(state)
    local options = {flags = {[modifier] = true}}
    rsLayerLogic.processEvent(state, event("flagsChanged", nil, 170, options))
    for index, key in ipairs({"r", "s"}) do
      local up = rsLayerLogic.processEvent(state, event("keyUp", key, 180 + index, options))
      assertEqual(up.swallow, true, "managed trigger release with " .. modifier .. " should be swallowed")
      assertNoActions(up.actions, "managed trigger release should not leak text")
      assertEqual(state.triggers[key].down, false, "released trigger should no longer be down")
    end
    rsLayerLogic.processEvent(state, event("flagsChanged", nil, 200))
    local nav = rsLayerLogic.processEvent(state, event("keyDown", "h", 210))
    assertEqual(nav.swallow, false, "plain nav key after modified trigger release should pass through")
    assertNoActions(nav.actions, "released layer should not emit arrows")
  end
end

local function testManagedTriggerRepeatWithModifierDoesNotLeak()
  local state = newState()
  rsLayerLogic.processEvent(state, event("keyDown", "s", 0, {keyCode = 0x02}))
  local repeated = rsLayerLogic.processEvent(state, event("keyDown", "s", 20, {
    flags = {shift = true}, ["repeat"] = true,
  }))
  assertEqual(repeated.swallow, true, "managed trigger repeat with modifiers should stay consumed")
  assertNoActions(repeated.actions, "managed trigger repeat should not emit text")
  local up = rsLayerLogic.processEvent(state, event("keyUp", "s", 40, {flags = {shift = true}}))
  assertEqual(up.swallow, true, "managed trigger tap release with modifiers should be consumed")
  assertActions(up.actions, {{key = "s"}}, "tap should preserve modifiers from its original press")
  assertEqual(up.actions[1].keyCode, 0x02, "tap should preserve its physical keycode")
end

local function testShortcutTriggerStaysUnmanagedAfterModifierRelease()
  local state = newState()
  rsLayerLogic.processEvent(state, event("keyDown", "s", 0, {flags = {cmd = true}}))
  rsLayerLogic.processEvent(state, event("flagsChanged", nil, 10))
  local repeated = rsLayerLogic.processEvent(state, event("keyDown", "s", 20, {["repeat"] = true}))
  assertEqual(repeated.swallow, false, "shortcut repeat after modifier release should pass through")
  local up = rsLayerLogic.processEvent(state, event("keyUp", "s", 30))
  assertEqual(up.swallow, false, "shortcut trigger release should pass through")
  assertNoActions(up.actions, "shortcut trigger should never be replayed")
end

local function testDuplicateNavDownEmitsOnlyOnce()
  local state = newState()
  activateLayer(state)
  local first = rsLayerLogic.processEvent(state, event("keyDown", "h", 170))
  assertActions(first.actions, {{key = "left"}}, "initial press should emit one arrow")
  for i = 1, STRESS_RUNS do
    local duplicate = rsLayerLogic.processEvent(state, event("keyDown", "h", 170 + i))
    assertEqual(duplicate.swallow, true, "duplicate nav down should be consumed")
    assertNoActions(duplicate.actions, "duplicate non-repeat down should not emit an arrow")
  end
  rsLayerLogic.processEvent(state, event("keyUp", "h", 700))
  local nextPress = rsLayerLogic.processEvent(state, event("keyDown", "h", 710))
  assertActions(nextPress.actions, {{key = "left"}}, "fresh press should emit another arrow")
end

local function testHeldNavStopsUntilReleaseAfterTriggerBounce()
  local state = newState()
  activateLayer(state)
  rsLayerLogic.processEvent(state, event("keyDown", "h", 170))
  rsLayerLogic.processEvent(state, event("keyDown", "i", 171))
  rsLayerLogic.processEvent(state, event("keyUp", "s", 180))
  for _, time in ipairs({181, 185, 300}) do
    if time == 185 then
      rsLayerLogic.processEvent(state, event("keyDown", "s", 184))
      assertTrue(state.layerActive, "trigger bounce should resume the layer")
    end
    for _, key in ipairs({"h", "i"}) do
      local repeated = rsLayerLogic.processEvent(state, event("keyDown", key, time, {["repeat"] = true}))
      assertEqual(repeated.swallow, true, "held nav must not leak original text after release")
      assertNoActions(repeated.actions, "held nav must not resume after trigger bounce")
    end
  end
  local up = rsLayerLogic.processEvent(state, event("keyUp", "h", 310))
  assertEqual(up.swallow, true, "consumed nav release should also be consumed")
  local fresh = rsLayerLogic.processEvent(state, event("keyDown", "h", 320))
  assertActions(fresh.actions, {{key = "left"}}, "repressed nav should work in resumed layer")
end

local function testHeldNavStaysConsumedAfterBothTriggersRelease()
  local state = newState()
  activateLayer(state)
  rsLayerLogic.processEvent(state, event("keyDown", "h", 170))
  rsLayerLogic.processEvent(state, event("keyUp", "r", 180))
  rsLayerLogic.processEvent(state, event("keyUp", "s", 190))
  local repeated = rsLayerLogic.processEvent(state, event("keyDown", "h", 500, {["repeat"] = true}))
  assertEqual(repeated.swallow, true, "held nav should remain consumed after full layer release")
  assertNoActions(repeated.actions, "full layer release must stop arrows")
  assertEqual(rsLayerLogic.processEvent(state, event("keyUp", "h", 510)).swallow, true, "owned nav up should be consumed")
  assertEqual(rsLayerLogic.processEvent(state, event("keyDown", "h", 520)).swallow, false, "fresh nav outside layer should type normally")
end

local function testPreviouslyHeldNavDoesNotBecomeAnArrow()
  local state = newState()
  rsLayerLogic.processEvent(state, event("keyDown", "h", -10))
  activateLayer(state)
  local repeated = rsLayerLogic.processEvent(state, event("keyDown", "h", 170, {["repeat"] = true}))
  assertEqual(repeated.swallow, false, "nav pressed outside layer should keep its original repeat")
  assertNoActions(repeated.actions, "unmanaged nav repeat should not emit arrows")
  assertEqual(rsLayerLogic.processEvent(state, event("keyUp", "h", 180)).swallow, false, "unmanaged nav release should pass through")
end

local function testResetAndExclusionClearNavPresses()
  for _, excluded in ipairs({false, true}) do
    local state = newState()
    activateLayer(state)
    rsLayerLogic.processEvent(state, event("keyDown", "h", 170))
    if excluded then
      local result = rsLayerLogic.processEvent(state, event("keyDown", "a", 180, {excluded = true}))
      assertEqual(result.swallow, false, "excluded event should pass through")
    else
      rsLayerLogic.reset(state)
    end
    assertEqual(state.layerActive, false, "reset should clear the layer")
    assertEqual(rsLayerLogic.processEvent(state, event("keyUp", "h", 190)).swallow, false, "reset should clear nav ownership")
    activateLayer(state)
    local fresh = rsLayerLogic.processEvent(state, event("keyDown", "h", 200))
    assertActions(fresh.actions, {{key = "left"}}, "new press after reset should map normally")
  end
end

local tests = {
  testSingleRTap,
  testSingleSTap,
  testOutsideThresholdEmitsRs,
  testInsideThresholdWithoutActivationDelayEmitsRs,
  testLayerActivationAndNavMapping,
  testModifierCarryOver,
  testModifierFlagsChangedCarryOver,
  testAllModifierFlagsChangedCarryOver,
  testExcludedAppPassThroughAndReset,
  testFlushPendingOnOtherKey,
  testTriggerKeyUpWithoutManagedDownShouldPassThrough,
  testTriggerWithModifierShouldPassThrough,
  testUnrelatedRepeatFlushesPendingTrigger,
  testRepeatedTriggerAutoRepeatDoesNotChatter,
  testRepeatedLayerArrowInputsDoNotChatter,
  testHeldNavAutoRepeatEmitsOneArrowPerKeyDown,
  testActiveLayerTriggerBounceDoesNotLeakTriggerKeys,
  testTriggerReleaseBounceWindowExpires,
  testTriggerTapEmitsOriginalKeyCode,
  testModifiedTriggerReleaseEndsLayer,
  testManagedTriggerRepeatWithModifierDoesNotLeak,
  testShortcutTriggerStaysUnmanagedAfterModifierRelease,
  testDuplicateNavDownEmitsOnlyOnce,
  testHeldNavStopsUntilReleaseAfterTriggerBounce,
  testHeldNavStaysConsumedAfterBothTriggersRelease,
  testPreviouslyHeldNavDoesNotBecomeAnArrow,
  testResetAndExclusionClearNavPresses,
}

local failures = 0
for _, test in ipairs(tests) do
  local ok, err = pcall(test)
  if not ok then
    failures = failures + 1
    print(err)
  end
end
assert(failures == 0, string.format("%d/%d rs_layer_logic tests failed", failures, #tests))

print(string.format("rs_layer_logic tests passed (%d cases, stress runs: %d)", #tests, STRESS_RUNS))
