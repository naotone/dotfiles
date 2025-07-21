local simpleCmd = false
local leftSet = false
local rightSet = false
local leftCmd = 0x37
local rightCmd = 0x36
local eisuu = 0x66
local kana = 0x68

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

local keyTap = hs.eventtap.new({hs.eventtap.event.types.keyDown}, function(event)
  local app = hs.application.frontmostApplication()
  local appName = app and app:name() or "Unknown App"

  local shortcuts = disableShortcuts[appName]
  if shortcuts then
    local keyCode = event:getKeyCode()
    local flags = event:getFlags()
    local keyString = hs.keycodes.map[keyCode]

    for _, shortcut in ipairs(shortcuts) do
      local modsMatch = true

      for _, mod in ipairs(shortcut.mods) do
        if not flags[mod] then
          modsMatch = false
          break
        end
      end

      if modsMatch and keyString == shortcut.key then
        local flagCount = 0
        for _ in pairs(flags) do flagCount = flagCount + 1 end

        if flagCount == #shortcut.mods then
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
  hs.console.printStyledtext("========================")
end

-- Initial status check
hs.console.printStyledtext("Hammerspoon configuration loaded successfully")
checkEventTaps()
