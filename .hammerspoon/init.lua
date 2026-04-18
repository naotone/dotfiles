local DEBUG_KEYDOWN_INSPECT = false
local DEBUG_INTERNAL_KEYBOARD_BLOCK = true

local rsLayerLogic = require("rs_layer_logic")

local simpleCmd = false
local leftSet = false
local rightSet = false
local leftCmd = 0x37
local rightCmd = 0x36
local eisuu = 0x66
local kana = 0x68

local RS_LAYER_CONFIG = {
  simultaneousThresholdMs = 70,
  activationDelayMs = 120,
  triggerKeys = {"r", "s"},
  navMap = {h = "left", n = "down", e = "up", i = "right"},
  excludedBundleIDs = {},
  excludedAppNames = {},
  debug = true,
}

local RS_EVENT_TYPES = {
  [hs.eventtap.event.types.keyDown] = "keyDown",
  [hs.eventtap.event.types.keyUp] = "keyUp",
}

local MODIFIER_KEYS = {"cmd", "alt", "shift", "ctrl", "fn"}

local function keyStroke(modifiers, character)
  hs.eventtap.keyStroke(modifiers, character, 5000)
end

local function eikanaEvent(event)
  local c = event:getKeyCode()
  local f = event:getFlags()
  local eventType = event:getType()

  if eventType == hs.eventtap.event.types.keyDown then
    if f['cmd'] and c then
      simpleCmd = true
    end
  elseif eventType == hs.eventtap.event.types.keyUp then
    -- Reset simpleCmd on any key up to ensure clean state
    if simpleCmd then
      simpleCmd = false
    end
  elseif eventType == hs.eventtap.event.types.flagsChanged then
    if f['cmd'] then
      if c == leftCmd then
        leftSet = true
        rightSet = false
      elseif c == rightCmd then
        rightSet = true
        leftSet = false
      end
    else
      -- Cmd key released
      if simpleCmd == false then
        if leftSet then
          keyStroke({}, eisuu)
        elseif rightSet then
          keyStroke({}, kana)
        end
      end
      -- Clean up all states
      simpleCmd = false
      leftSet = false
      rightSet = false
    end
  end
end
eikana = hs.eventtap.new({hs.eventtap.event.types.keyDown, hs.eventtap.event.types.keyUp, hs.eventtap.event.types.flagsChanged}, eikanaEvent)
eikana:start()

-- 4 is Forward Button, 3 is Back Button
local appButtonMap = {
  ["Cyberpunk 2077: Ultimate"] = {
    [4] = {key = "c"},
    [3] = {key = "tab"},
  },
  ["Reeder"] = {
    [4] = {key = "down"},
    [3] = {key = "up"},
  },
  ["Mail"] = {
    [4] = {key = "down"},
    [3] = {key = "up"},
  },
  ["Cursor"] = {
    [4] = {key = "pagedown"},
    [3] = {key = "pageup"},
  },
  ["Code"] = {
    [4] = {key = "pagedown"},
    [3] = {key = "pageup"},
  },
  ["Ghostty"] = {
    [4] = {key = "pagedown"},
    [3] = {key = "pageup"},
  },
  ["Terminal"] = {
    [4] = {key = "pagedown"},
    [3] = {key = "pageup"},
  },
}

-- Cache for frontmost application to improve performance
local cachedApp = nil
local lastAppCheck = 0
local APP_CACHE_DURATION = 0.1 -- Cache for 100ms

local function getFrontmostApp()
  local now = hs.timer.secondsSinceEpoch()
  if not cachedApp or (now - lastAppCheck) > APP_CACHE_DURATION then
    cachedApp = hs.application.frontmostApplication()
    lastAppCheck = now
  end
  return cachedApp
end

local mouseTap = hs.eventtap.new({hs.eventtap.event.types.otherMouseDown}, function(event)
  local button = event:getProperty(hs.eventtap.event.properties['mouseEventButtonNumber'])

  -- Get app info with caching
  local app = getFrontmostApp()
  local appName = app and app:name() or "Unknown App"
  local bundleID = app and app:bundleID() or "Unknown Bundle"

  -- Debug output with detailed app information
  hs.console.printStyledtext(string.format("Button %d | App: '%s' | Bundle: %s", button, appName, bundleID))

  local btnMap = appButtonMap[appName]
  if btnMap and btnMap[button] then
    -- App-specific custom mapping
    local action = btnMap[button]
    if action.mods then
      hs.eventtap.keyStroke(action.mods, action.key)
    else
      hs.eventtap.keyStroke({}, action.key)
    end
    return true
  else
    if button == 4 then
      hs.eventtap.keyStroke({"cmd"}, "]")
      return true
    elseif button == 3 then
      hs.eventtap.keyStroke({"cmd"}, "[")
              return true
      end
  end

  return false
end)

local function startMouseTap()
  if mouseTap then
    mouseTap:stop()
  end

  mouseTap = hs.eventtap.new({hs.eventtap.event.types.otherMouseDown}, function(event)
    local success, result = pcall(function()
      local button = event:getProperty(hs.eventtap.event.properties['mouseEventButtonNumber'])
      local app = getFrontmostApp()
      local appName = app and app:name() or "Unknown App"
      local bundleID = app and app:bundleID() or "Unknown Bundle"
      -- hs.console.printStyledtext(string.format("Button %d | App: '%s' | Bundle: %s", button, appName, bundleID))

      local btnMap = appButtonMap[appName]
      if btnMap and btnMap[button] then
        -- App-specific custom mapping
        local action = btnMap[button]
        if action.mods then
          hs.eventtap.keyStroke(action.mods, action.key)
        else
          hs.eventtap.keyStroke({}, action.key)
        end
        return true
      else
        if button == 4 then
          hs.eventtap.keyStroke({"cmd"}, "]")
          return true
        elseif button == 3 then
          hs.eventtap.keyStroke({"cmd"}, "[")
          return true
        end
      end

      return false
    end)

    if not success then
      hs.console.printStyledtext("MouseTap error: " .. tostring(result))
      -- Restart the tap after error
      hs.timer.doAfter(1, startMouseTap)
      return false
    end

    return result
  end)

  mouseTap:start()
  hs.console.printStyledtext("MouseTap started successfully")
end

startMouseTap()

-- Disable Control+Space global shortcut for specific apps
local disableShortcuts = {
  ["Cyberpunk 2077: Ultimate"] = {
    {mods = {"ctrl"}, key = "space"}
  }
}

local function toSet(items)
  local set = {}
  for _, item in ipairs(items or {}) do
    set[item] = true
  end
  return set
end

local function countActiveModifiers(flags)
  local count = 0
  for _, modifier in ipairs(MODIFIER_KEYS) do
    if flags and flags[modifier] then
      count = count + 1
    end
  end
  return count
end

local function getEventTimestampMs(event)
  local ts = event:timestamp()
  if ts and ts > 0 then
    return ts / 1000000
  end
  return hs.timer.absoluteTime() / 1000000
end

local rsExcludedBundleIDSet = toSet(RS_LAYER_CONFIG.excludedBundleIDs)
local rsExcludedAppNameSet = toSet(RS_LAYER_CONFIG.excludedAppNames)
local rsLayerState = rsLayerLogic.new(RS_LAYER_CONFIG)
local rsLayerEnabled = true
local rsLayerDebugEnabled = RS_LAYER_CONFIG.debug and true or false
local postingSyntheticKey = false
local rsEventSeq = 0
local keyTap = nil

local rsWatchedKeySet = {}
for _, triggerKey in ipairs(RS_LAYER_CONFIG.triggerKeys or {}) do
  rsWatchedKeySet[triggerKey] = true
end
for navKey, _ in pairs(RS_LAYER_CONFIG.navMap or {}) do
  rsWatchedKeySet[navKey] = true
end

local function toBoolString(value)
  if value then
    return "1"
  end
  return "0"
end

local function formatModifiers(flags)
  local out = {}
  for _, modifier in ipairs(MODIFIER_KEYS) do
    if flags and flags[modifier] then
      table.insert(out, modifier)
    end
  end
  return table.concat(out, "+")
end

local function formatActions(actions)
  local out = {}
  for _, action in ipairs(actions or {}) do
    local modifiers = table.concat(action.modifiers or {}, "+")
    if modifiers ~= "" then
      table.insert(out, modifiers .. "+" .. tostring(action.key))
    else
      table.insert(out, tostring(action.key))
    end
  end
  return table.concat(out, ",")
end

local function rsStateSummary()
  local triggerParts = {}
  for _, triggerKey in ipairs(RS_LAYER_CONFIG.triggerKeys or {}) do
    local t = rsLayerState.triggers and rsLayerState.triggers[triggerKey] or nil
    if t then
      table.insert(
        triggerParts,
        string.format(
          "%s[d=%s,p=%s,h=%s,at=%s]",
          triggerKey,
          toBoolString(t.down),
          toBoolString(t.pending),
          toBoolString(t.handledDown),
          tostring(t.downAtMs or "-")
        )
      )
    else
      table.insert(triggerParts, triggerKey .. "[nil]")
    end
  end

  local pendingOrder = table.concat(rsLayerState.pendingOrder or {}, ",")
  return string.format(
    "layer=%s candidate=%s pending=%s %s",
    toBoolString(rsLayerState.layerActive),
    tostring(rsLayerState.candidateStartMs or "-"),
    pendingOrder ~= "" and pendingOrder or "-",
    table.concat(triggerParts, " ")
  )
end

local function rsDebugLog(message)
  if rsLayerDebugEnabled then
    hs.console.printStyledtext("[RS] " .. message)
  end
end

function setRsLayerDebug(enabled)
  rsLayerDebugEnabled = enabled and true or false
  hs.console.printStyledtext("RS debug: " .. (rsLayerDebugEnabled and "ON" or "OFF"))
end

function resetRsLayerState()
  rsLayerLogic.reset(rsLayerState)
  hs.console.printStyledtext("[RS] state reset")
end

function dumpRsLayerState()
  hs.console.printStyledtext("[RS] " .. rsStateSummary())
end

local function isRsLayerExcludedApp(appName, bundleID)
  if bundleID and rsExcludedBundleIDSet[bundleID] then
    return true
  end
  if appName and rsExcludedAppNameSet[appName] then
    return true
  end
  return false
end

local function emitSyntheticActions(actions)
  if not actions or #actions == 0 then
    return
  end

  local keyTapWasEnabled = keyTap and keyTap:isEnabled() or false
  if keyTapWasEnabled then
    keyTap:stop()
  end
  postingSyntheticKey = true
  local ok, err = pcall(function()
    rsDebugLog("emit start actions=" .. formatActions(actions))
    for _, action in ipairs(actions) do
      keyStroke(action.modifiers or {}, action.key)
    end
  end)
  postingSyntheticKey = false
  if keyTapWasEnabled and keyTap then
    keyTap:start()
  end

  if not ok then
    hs.console.printStyledtext("RS layer emit error: " .. tostring(err))
  else
    rsDebugLog("emit end")
  end
end

keyTap = hs.eventtap.new({hs.eventtap.event.types.keyDown, hs.eventtap.event.types.keyUp}, function(event)
  if postingSyntheticKey then
    return false
  end

  local eventType = event:getType()
  local eventTypeName = RS_EVENT_TYPES[eventType]
  if not eventTypeName then
    return false
  end

  local app = getFrontmostApp()
  local appName = app and app:name() or "Unknown App"
  local bundleID = app and app:bundleID() or ""
  local keyCode = event:getKeyCode()
  local keyString = hs.keycodes.map[keyCode]
  local flags = event:getFlags()
  local isExcludedApp = isRsLayerExcludedApp(appName, bundleID)
  rsEventSeq = rsEventSeq + 1

  if rsLayerDebugEnabled and not keyString then
    rsDebugLog(string.format(
      "#%d type=%s keyCode=%s key=nil mods=%s app=%s bundle=%s",
      rsEventSeq,
      eventTypeName,
      tostring(keyCode),
      formatModifiers(flags),
      tostring(appName),
      tostring(bundleID)
    ))
  end

  if rsLayerEnabled and keyString then
    local ok, rsResult = pcall(rsLayerLogic.processEvent, rsLayerState, {
      type = eventTypeName,
      key = keyString,
      timestampMs = getEventTimestampMs(event),
      flags = flags,
      excluded = isExcludedApp,
    })
    if not ok then
      hs.console.printStyledtext("RS layer process error: " .. tostring(rsResult))
      rsLayerLogic.reset(rsLayerState)
      rsDebugLog(string.format(
        "#%d type=%s key=%s excluded=%s process_error=%s state=%s",
        rsEventSeq,
        eventTypeName,
        tostring(keyString),
        toBoolString(isExcludedApp),
        tostring(rsResult),
        rsStateSummary()
      ))
    else
      if rsLayerDebugEnabled and (
        rsWatchedKeySet[keyString] or
        rsResult.swallow or
        (rsResult.actions and #rsResult.actions > 0) or
        isExcludedApp
      ) then
        rsDebugLog(string.format(
          "#%d type=%s key=%s excluded=%s swallow=%s actions=%s mods=%s app=%s bundle=%s state=%s",
          rsEventSeq,
          eventTypeName,
          tostring(keyString),
          toBoolString(isExcludedApp),
          toBoolString(rsResult.swallow),
          formatActions(rsResult.actions),
          formatModifiers(flags),
          tostring(appName),
          tostring(bundleID),
          rsStateSummary()
        ))
      end
      emitSyntheticActions(rsResult.actions)
      if rsResult.swallow then
        return true
      end
    end
  end

  if eventType == hs.eventtap.event.types.keyDown then
    local shortcuts = disableShortcuts[appName]
    if shortcuts and keyString then
      for _, shortcut in ipairs(shortcuts) do
        local modsMatch = true
        for _, mod in ipairs(shortcut.mods) do
          if not flags[mod] then
            modsMatch = false
            break
          end
        end

        if modsMatch and keyString == shortcut.key and countActiveModifiers(flags) == #shortcut.mods then
          hs.console.printStyledtext(string.format("Blocked shortcut: %s+%s in %s",
            table.concat(shortcut.mods, "+"), shortcut.key, appName))
          return true
        end
      end
    end
  end

  return false
end)

keyTap:start()

function checkEventTaps()
  hs.console.printStyledtext("=== Event Taps Status ===")
  if eikana then
    hs.console.printStyledtext("eikana: " .. (eikana:isEnabled() and "ENABLED" or "DISABLED"))
  end
  if mouseTap then
    hs.console.printStyledtext("mouseTap: " .. (mouseTap:isEnabled() and "ENABLED" or "DISABLED"))
  end
  if keyTap then
    hs.console.printStyledtext("keyTap: " .. (keyTap:isEnabled() and "ENABLED" or "DISABLED"))
  end
  hs.console.printStyledtext("rsLayer: " .. (rsLayerEnabled and "ENABLED" or "DISABLED"))
  hs.console.printStyledtext("========================")
end

-- Initial status check
hs.console.printStyledtext("Hammerspoon configuration loaded successfully")
checkEventTaps()



-- Debug: keyDown inspector
if keyDownInspectTap then
  keyDownInspectTap:stop()
end

local debugKeyDownEnabled = false

local function setDebugKeyDownEnabled(enabled)
  debugKeyDownEnabled = enabled and true or false
  if debugKeyDownEnabled then
    keyDownInspectTap:start()
  else
    keyDownInspectTap:stop()
  end
end

keyDownInspectTap = hs.eventtap.new({hs.eventtap.event.types.keyDown}, function(e)
  hs.console.printStyledtext(hs.inspect({
    keyCode = e:getKeyCode(),
    keyboardType = e:getProperty(hs.eventtap.event.properties.keyboardEventKeyboardType),
  }))
  return false
end)

setDebugKeyDownEnabled(DEBUG_KEYDOWN_INSPECT)

-- Internal keyboard block
local INTERNAL_KEYBOARD_TYPE = 91

if disableInternalTap then
  disableInternalTap:stop()
end

local internalKeyboardDisabled = false

local internalKeyboardMenu = hs.menubar.new()

local setInternalKeyboardDisabled
local internalBlockLastLogMs = 0
local INTERNAL_BLOCK_LOG_INTERVAL_MS = 50

local function currentTimeMs()
  return hs.timer.absoluteTime() / 1000000
end

local function maybeLogInternalBlock(event, keyCode, keyboardType)
  if not DEBUG_INTERNAL_KEYBOARD_BLOCK then
    return
  end
  local now = currentTimeMs()
  if (now - internalBlockLastLogMs) < INTERNAL_BLOCK_LOG_INTERVAL_MS then
    return
  end
  internalBlockLastLogMs = now
  local eventType = event:getType()
  local keyName = hs.keycodes.map[keyCode]
  hs.console.printStyledtext(string.format(
    "[INTERNAL_BLOCK] type=%s keyCode=%s key=%s keyboardType=%s blocked=1",
    tostring(eventType),
    tostring(keyCode),
    tostring(keyName),
    tostring(keyboardType)
  ))
end

local function openHammerspoonConfig()
  local path = hs.configdir .. "/init.lua"
  hs.execute(string.format([[open "%s"]], path))
end

local function refreshInternalKeyboardMenu()
  if not internalKeyboardMenu then
    return
  end
  internalKeyboardMenu:setTitle(internalKeyboardDisabled and "⌨️OFF" or "⌨️")
  local toggleTitle = internalKeyboardDisabled and "Enable internal keyboard" or "Disable internal keyboard"
  internalKeyboardMenu:setMenu({
    {title = toggleTitle, fn = function() setInternalKeyboardDisabled(not internalKeyboardDisabled) end},
    {title = "Open Hammerspoon config", fn = openHammerspoonConfig},
  })
end

setInternalKeyboardDisabled = function(enabled)
  internalKeyboardDisabled = enabled and true or false
  if internalKeyboardDisabled then
    if not disableInternalTap then
      disableInternalTap = hs.eventtap.new(
        {hs.eventtap.event.types.keyDown, hs.eventtap.event.types.keyUp},
        function(e)
          local keyCode = e:getKeyCode()
          if keyCode == eisuu or keyCode == kana then
            return false
          end
          local t = e:getProperty(hs.eventtap.event.properties.keyboardEventKeyboardType)
          if t == INTERNAL_KEYBOARD_TYPE then
            maybeLogInternalBlock(e, keyCode, t)
            return true
          end
          return false
        end
      )
    end
    disableInternalTap:start()
  else
    if disableInternalTap then
      disableInternalTap:stop()
    end
  end
  refreshInternalKeyboardMenu()
end

function setInternalKeyboardBlockEnabled(enabled)
  setInternalKeyboardDisabled(enabled and true or false)
  hs.console.printStyledtext("Internal keyboard block: " .. (internalKeyboardDisabled and "ON" or "OFF"))
end

function toggleInternalKeyboardBlock()
  setInternalKeyboardBlockEnabled(not internalKeyboardDisabled)
end

setInternalKeyboardDisabled(false)
refreshInternalKeyboardMenu()
