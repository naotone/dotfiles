local function dirname(path)
  return path:match("(.+)/[^/]+$") or "."
end

local hsDir = dirname(dirname(arg[0] or "."))
package.path = hsDir .. "/?.lua;" .. package.path

local function assertEqual(actual, expected, message)
  if actual ~= expected then
    error(string.format("%s: expected=%s actual=%s", message, tostring(expected), tostring(actual)))
  end
end

local function copy(input)
  local result = {}
  for key, value in pairs(input or {}) do
    result[key] = value
  end
  return result
end

local function newRuntime(appName)
  local runtime = {timers = {}, posts = {}, moves = {}, logs = {}, now = 1, appName = appName or "Editor"}
  local types = {keyDown = 10, keyUp = 11, flagsChanged = 12, otherMouseDown = 25}
  local properties = {keyboardEventAutorepeat = 8, keyboardEventKeyboardType = 10, eventSourceUserData = 42}
  local keycodes = {[0] = "a", [1] = "s", [2] = "d", [4] = "h", [38] = "j", [40] = "k", [37] = "l", [49] = "space"}
  local methods = {}
  function methods:getType() return self.type end
  function methods:getKeyCode() return self.keyCode end
  function methods:getFlags() return copy(self.flags) end
  function methods:timestamp() return self.time * 1000000 end
  function methods:getProperty(property) return self.properties[property] or 0 end
  function methods:setProperty(property, value)
    self.properties[property] = value
    return self
  end
  function methods:copy()
    return setmetatable({
      type = self.type, keyCode = self.keyCode, flags = copy(self.flags),
      time = self.time, properties = copy(self.properties),
    }, {__index = methods})
  end
  function methods:post()
    table.insert(runtime.posts, self)
    return self
  end
  function runtime.event(kind, keyCode, time, flags, repeated)
    return setmetatable({
      type = types[kind], keyCode = keyCode, time = time or 1, flags = flags or {},
      properties = {[properties.keyboardEventAutorepeat] = repeated and 1 or 0},
    }, {__index = methods})
  end

  local app = {name = function() return runtime.appName end, bundleID = function() return "test.editor" end}
  local hs = {
    keycodes = {map = keycodes},
    console = {printStyledtext = function(message) table.insert(runtime.logs, message) end},
    application = {frontmostApplication = function() return app end},
    timer = {
      secondsSinceEpoch = function() return runtime.now / 1000 end,
      absoluteTime = function() return runtime.now * 1000000 end,
      doAfter = function(_, callback)
        local timer = {callback = callback, cancelled = false}
        function timer:stop() self.cancelled = true end
        table.insert(runtime.timers, timer)
        return timer
      end,
    },
    menubar = {new = function() return {setTitle = function() end, setMenu = function() end} end},
    spaces = {
      focusedSpace = function() return 102 end,
      spaceDisplay = function() return "display" end,
      spacesForScreen = function() return {101, 102, 103} end,
      gotoSpace = function(target)
        assertEqual(runtime.inCallback, false, "Spaces should run after the event callback")
        table.insert(runtime.moves, target)
        return true
      end,
    },
  }
  local keyboardTapCount = 0
  hs.eventtap = {
    event = {
      types = types, properties = properties,
      newKeyEvent = function(modifiers, key, down)
        local flags = {}
        for _, modifier in ipairs(modifiers) do flags[modifier] = true end
        return runtime.event(down and "keyDown" or "keyUp", key, runtime.now, flags)
      end,
    },
    new = function(watchedTypes, callback)
      local tap = {callback = callback, enabled = false, starts = 0, stops = 0}
      function tap:start() self.enabled = true; self.starts = self.starts + 1; return self end
      function tap:stop() self.enabled = false; self.stops = self.stops + 1; return self end
      function tap:isEnabled() return self.enabled end
      if #watchedTypes == 3 and watchedTypes[1] == types.keyDown then
        keyboardTapCount = keyboardTapCount + 1
        if keyboardTapCount == 2 then runtime.layerTap = tap end
      end
      return tap
    end,
    keyStroke = function(modifiers, key)
      hs.eventtap.event.newKeyEvent(modifiers, key, true):post()
      hs.eventtap.event.newKeyEvent(modifiers, key, false):post()
    end,
  }
  local env = setmetatable({hs = hs}, {__index = _G})
  assert(loadfile(hsDir .. "/init.lua", "t", env))()
  runtime.env = env
  runtime.properties = properties
  runtime.types = types
  function runtime.send(event)
    runtime.now = event.time
    runtime.inCallback = true
    local swallow, events = runtime.layerTap.callback(event)
    runtime.inCallback = false
    return swallow, events or {}
  end
  function runtime.activate()
    runtime.send(runtime.event("keyDown", 1, 10))
    runtime.send(runtime.event("keyDown", 2, 30))
    runtime.send(runtime.event("flagsChanged", 0, 160))
  end
  function runtime.runTimers()
    while #runtime.timers > 0 do
      local timer = table.remove(runtime.timers, 1)
      if not timer.cancelled then timer.callback() end
    end
  end
  return runtime
end

local function testArrowEventsAreReturnedWithoutStoppingTap()
  local runtime = newRuntime()
  runtime.activate()
  local swallowed, events = runtime.send(runtime.event("keyDown", 4, 170, {shift = true}))
  assertEqual(runtime.layerTap.stops, 0, "SD output must not stop event monitoring")
  assertEqual(runtime.layerTap.starts, 1, "SD output must not restart event monitoring")
  assertEqual(#runtime.posts, 0, "SD output should use callback return values")
  assertEqual(swallowed, true, "mapped original should be suppressed")
  assertEqual(#events, 2, "one nav down should return one arrow pair")
  for index, event in ipairs(events) do
    assertEqual(event.keyCode, "left", "event should contain mapped arrow")
    assertEqual(event.type, index == 1 and runtime.types.keyDown or runtime.types.keyUp, "arrow pair order")
    assertEqual(event.flags.shift, true, "arrow should preserve modifiers")
    assert(event:getProperty(runtime.properties.eventSourceUserData) ~= 0, "synthetic event should be tagged")
    local replayed, outputs = runtime.send(event)
    assertEqual(replayed, false, "tagged event should pass through")
    assertEqual(#outputs, 0, "tagged event should not be transformed again")
  end
end

local function testPendingCharactersPrecedeOriginalExactlyOnce()
  local runtime = newRuntime()
  runtime.send(runtime.event("keyDown", 1, 10))
  local original = runtime.event("keyDown", 0, 20, {shift = true}, true)
  local swallowed, events = runtime.send(original)
  assertEqual(swallowed, true, "original should be replaced to preserve ordering")
  assertEqual(#events, 3, "pending character pair and one original copy should be returned")
  assertEqual(events[1].keyCode, 1, "pending character should retain its physical keycode")
  assertEqual(events[2].keyCode, 1, "pending character up should precede original")
  assertEqual(events[1].type, runtime.types.keyDown, "pending down should come first")
  assertEqual(events[2].type, runtime.types.keyUp, "pending up should come second")
  assertEqual(events[3].keyCode, 0, "original should come last")
  assert(events[3] ~= original, "original should be copied")
  assertEqual(original:getProperty(runtime.properties.eventSourceUserData), 0, "original must not be mutated")
  assertEqual(events[3].flags.shift, true, "copy should preserve flags")
  assertEqual(events[3]:getProperty(runtime.properties.keyboardEventAutorepeat), 1, "copy should preserve autorepeat")
  for _, event in ipairs(events) do
    local replayed, outputs = runtime.send(event)
    assertEqual(replayed, false, "replayed event should pass through")
    assertEqual(#outputs, 0, "replayed event must not generate more output")
  end
  local _, released = runtime.send(runtime.event("keyUp", 1, 30))
  assertEqual(#released, 0, "flushed trigger should not emit twice")
end

local function testBlockedShortcutIsNotReplayedWithPendingText()
  local runtime = newRuntime("Cyberpunk 2077: Ultimate")
  runtime.send(runtime.event("keyDown", 1, 10))
  local swallowed, events = runtime.send(runtime.event("keyDown", 49, 20, {ctrl = true}))
  assertEqual(swallowed, true, "blocked shortcut should be suppressed")
  assertEqual(#events, 2, "pending text should still be emitted without blocked shortcut")
  assertEqual(events[1].keyCode, 1, "pending text should retain its physical keycode")
  assertEqual(events[2].keyCode, 1, "blocked shortcut must not appear in returned events")
end

local function testSpaceSwitchOccursOncePerPressAfterCallback()
  local runtime = newRuntime()
  runtime.activate()
  local swallowed, events = runtime.send(runtime.event("keyDown", 4, 170, {ctrl = true}))
  assertEqual(swallowed, true, "space shortcut should be consumed")
  assertEqual(#events, 0, "space shortcut should not also emit a synthetic arrow")
  assertEqual(#runtime.moves, 0, "space switch must be deferred")
  assertEqual(#runtime.timers, 1, "one space switch should be scheduled")
  for i = 1, 500 do
    local _, repeated = runtime.send(runtime.event("keyDown", 4, 170 + i, {ctrl = true}, true))
    assertEqual(#repeated, 0, "space repeat must not emit synthetic arrows")
  end
  assertEqual(#runtime.timers, 1, "space repeats must not queue more switches")
  runtime.runTimers()
  assertEqual(#runtime.moves, 1, "one press should switch exactly once")
  assertEqual(runtime.moves[1], 101, "left should switch to previous space")
  runtime.send(runtime.event("keyUp", 4, 700, {ctrl = true}))
  runtime.send(runtime.event("keyDown", 4, 710, {ctrl = true}))
  runtime.runTimers()
  assertEqual(#runtime.moves, 2, "a fresh press should switch again")
  assertEqual(runtime.layerTap.stops, 0, "space switching should not stop monitoring")
end

local function testOrdinaryRepeatsStopUntilNavIsRepressed()
  local runtime = newRuntime()
  runtime.activate()
  runtime.send(runtime.event("keyDown", 4, 170))
  for i = 1, 500 do
    local swallowed, events = runtime.send(runtime.event("keyDown", 4, 170 + i, nil, true))
    assertEqual(swallowed, true, "ordinary repeat should replace the physical event")
    assertEqual(#events, 2, "ordinary repeat should produce exactly one arrow pair")
    assertEqual(events[1].keyCode, "left", "ordinary repeat should retain arrow mapping")
  end
  runtime.send(runtime.event("keyUp", 2, 700, {shift = true}))
  local swallowed, stopped = runtime.send(runtime.event("keyDown", 4, 701, nil, true))
  assertEqual(swallowed, true, "held nav after SD release should stay consumed")
  assertEqual(#stopped, 0, "held nav after SD release should stop")
  runtime.send(runtime.event("keyDown", 2, 710))
  local _, bounced = runtime.send(runtime.event("keyDown", 4, 711, nil, true))
  assertEqual(#bounced, 0, "trigger bounce should not restart a held nav key")
  runtime.send(runtime.event("keyUp", 4, 720))
  local _, fresh = runtime.send(runtime.event("keyDown", 4, 730))
  assertEqual(#fresh, 2, "fresh nav press should work after bounce")
end

local function testOutputFailureLeavesMonitoringEnabled()
  local runtime = newRuntime()
  runtime.activate()
  local eventAPI = runtime.env.hs.eventtap.event
  local originalNewKeyEvent = eventAPI.newKeyEvent
  eventAPI.newKeyEvent = function() error("synthetic event failure") end
  local swallowed, events = runtime.send(runtime.event("keyDown", 4, 170))
  assertEqual(swallowed, true, "failed mapped input should not leak its original character")
  assertEqual(#events, 0, "failed output should not return a partial event pair")
  assertEqual(runtime.layerTap:isEnabled(), true, "output failure should leave the tap enabled")
  assertEqual(runtime.layerTap.stops, 0, "output failure should not stop the tap")
  assert(table.concat(runtime.logs, "\n"):find("synthetic event failure", 1, true), "output failure should be logged")
  eventAPI.newKeyEvent = originalNewKeyEvent
  runtime.activate()
  local _, recovered = runtime.send(runtime.event("keyDown", 4, 180))
  assertEqual(#recovered, 2, "state should recover after output failure")
end

local function testDeferredSpaceFailureDoesNotReplayInput()
  local runtime = newRuntime()
  runtime.env.hs.spaces.gotoSpace = function() error("space failure") end
  runtime.activate()
  runtime.send(runtime.event("keyDown", 4, 170, {ctrl = true}))
  runtime.runTimers()
  assert(table.concat(runtime.logs, "\n"):find("space failure", 1, true), "deferred space failure should be logged")
  assertEqual(#runtime.posts, 0, "space failure should not replay synthetic input")
  assertEqual(runtime.layerTap.stops, 0, "space failure should not stop monitoring")
  local _, repeated = runtime.send(runtime.event("keyDown", 4, 180, {ctrl = true}, true))
  assertEqual(#repeated, 0, "repeat after failed space switch should remain consumed")
  assertEqual(#runtime.timers, 0, "repeat must not retry a failed switch")
end

local tests = {
  testArrowEventsAreReturnedWithoutStoppingTap,
  testPendingCharactersPrecedeOriginalExactlyOnce,
  testBlockedShortcutIsNotReplayedWithPendingText,
  testSpaceSwitchOccursOncePerPressAfterCallback,
  testOrdinaryRepeatsStopUntilNavIsRepressed,
  testOutputFailureLeavesMonitoringEnabled,
  testDeferredSpaceFailureDoesNotReplayInput,
}
local failures = 0
for _, test in ipairs(tests) do
  local ok, err = pcall(test)
  if not ok then failures = failures + 1; print(err) end
end
assert(failures == 0, string.format("%d/%d event tap tests failed", failures, #tests))
print(string.format("rs_layer_event_tap tests passed (%d cases)", #tests))
