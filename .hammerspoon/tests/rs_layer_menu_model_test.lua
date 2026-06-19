local function dirname(path)
  return path:match("(.+)/[^/]+$") or "."
end

local testDir = dirname(arg[0] or ".")
local hsDir = dirname(testDir)
package.path = hsDir .. "/?.lua;" .. package.path

local rsLayerMenuModel = require("rs_layer_menu_model")

local function assertEqual(actual, expected, message)
  if actual ~= expected then
    error(string.format("%s: expected=%s actual=%s", message, tostring(expected), tostring(actual)))
  end
end

local function assertTrue(value, message)
  if not value then
    error(message)
  end
end

local function assertNil(value, message)
  if value ~= nil then
    error(string.format("%s: expected=nil actual=%s", message, tostring(value)))
  end
end

local function buildState()
  return {
    internalKeyboardDisabled = true,
    rsLayerEnabled = false,
    rsLayerDebugEnabled = true,
    debugKeyDownEnabled = false,
    internalKeyboardDebugEnabled = true,
  }
end

local function buildCallbacks()
  return {
    toggleInternalKeyboardBlock = function() end,
    toggleRsLayer = function() end,
    resetRsLayerState = function() end,
    openHammerspoonConfig = function() end,
    toggleRsLayerDebug = function() end,
    toggleDebugKeyDown = function() end,
    toggleInternalKeyboardDebug = function() end,
    dumpRsLayerState = function() end,
    checkEventTaps = function() end,
    openHammerspoonConsole = function() end,
  }
end

local function testItemsUseConsistentOrderAndCheckedState()
  local callbacks = buildCallbacks()
  local items = rsLayerMenuModel.items(buildState(), callbacks)

  assertEqual(items[1].title, "Internal Keyboard Block", "internal keyboard title")
  assertEqual(items[1].checked, true, "internal keyboard checked")
  assertEqual(items[1].fn, callbacks.toggleInternalKeyboardBlock, "internal keyboard callback")
  assertEqual(items[2].title, "SD Arrow Layer", "rs layer title")
  assertEqual(items[2].checked, false, "rs layer checked")
  assertEqual(items[2].fn, callbacks.toggleRsLayer, "rs layer callback")
  assertEqual(items[3].title, "-", "first separator")
  assertEqual(items[4].title, "Reset SD Arrow State", "reset title")
  assertNil(items[4].checked, "reset should not be checked")
  assertEqual(items[4].fn, callbacks.resetRsLayerState, "reset callback")
  assertEqual(items[5].title, "Open Hammerspoon Config", "open config title")
  assertNil(items[5].checked, "open config should not be checked")
  assertEqual(items[5].fn, callbacks.openHammerspoonConfig, "open config callback")
  assertEqual(items[6].title, "-", "second separator")
  assertEqual(items[7].title, "Debug", "debug submenu title")
  assertNil(items[7].checked, "debug submenu should not be checked")
  assertTrue(type(items[7].menu) == "table", "debug submenu should be a table")
end

local function testDebugSubmenuIncludesAllDebugItems()
  local callbacks = {
    toggleRsLayerDebug = function() end,
    toggleDebugKeyDown = function() end,
    toggleInternalKeyboardDebug = function() end,
    dumpRsLayerState = function() end,
    checkEventTaps = function() end,
    openHammerspoonConsole = function() end,
  }
  local items = rsLayerMenuModel.items(buildState(), callbacks)
  local debugMenu = items[7].menu

  assertEqual(debugMenu[1].title, "SD Arrow Debug Log", "rs debug title")
  assertEqual(debugMenu[1].checked, true, "rs debug checked")
  assertEqual(debugMenu[1].fn, callbacks.toggleRsLayerDebug, "rs debug callback")
  assertEqual(debugMenu[2].title, "KeyDown Inspector", "keyDown inspector title")
  assertEqual(debugMenu[2].checked, false, "keyDown inspector checked")
  assertEqual(debugMenu[2].fn, callbacks.toggleDebugKeyDown, "keyDown inspector callback")
  assertEqual(debugMenu[3].title, "Internal Keyboard Block Debug Log", "internal debug title")
  assertEqual(debugMenu[3].checked, true, "internal debug checked")
  assertEqual(debugMenu[3].fn, callbacks.toggleInternalKeyboardDebug, "internal debug callback")
  assertEqual(debugMenu[4].title, "-", "debug separator")
  assertEqual(debugMenu[5].title, "Dump SD Arrow State", "dump state title")
  assertNil(debugMenu[5].checked, "dump state should not be checked")
  assertEqual(debugMenu[5].fn, callbacks.dumpRsLayerState, "dump state callback")
  assertEqual(debugMenu[6].title, "Check Event Taps", "check taps title")
  assertNil(debugMenu[6].checked, "check taps should not be checked")
  assertEqual(debugMenu[6].fn, callbacks.checkEventTaps, "check taps callback")
  assertEqual(debugMenu[7].title, "Open Hammerspoon Console", "open console title")
  assertNil(debugMenu[7].checked, "open console should not be checked")
  assertEqual(debugMenu[7].fn, callbacks.openHammerspoonConsole, "open console callback")
end

local function testItemsDefaultCallbacksToNoop()
  local items = rsLayerMenuModel.items(buildState())
  assertTrue(type(items[1].fn) == "function", "internal keyboard callback should default to a function")
  assertTrue(type(items[2].fn) == "function", "rs layer callback should default to a function")
  assertTrue(type(items[4].fn) == "function", "reset callback should default to a function")
  assertTrue(type(items[5].fn) == "function", "open config callback should default to a function")
  assertTrue(type(items[7].menu[1].fn) == "function", "rs debug callback should default to a function")
  assertTrue(type(items[7].menu[2].fn) == "function", "keyDown debug callback should default to a function")
  assertTrue(type(items[7].menu[3].fn) == "function", "internal debug callback should default to a function")
  assertTrue(type(items[7].menu[5].fn) == "function", "dump state callback should default to a function")
  assertTrue(type(items[7].menu[6].fn) == "function", "check taps callback should default to a function")
  assertTrue(type(items[7].menu[7].fn) == "function", "open console callback should default to a function")
end

local tests = {
  testItemsUseConsistentOrderAndCheckedState,
  testDebugSubmenuIncludesAllDebugItems,
  testItemsDefaultCallbacksToNoop,
}

for _, test in ipairs(tests) do
  test()
end

print("rs_layer_menu_model tests passed")
