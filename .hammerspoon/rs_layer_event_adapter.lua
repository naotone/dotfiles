local actionRouter = require("rs_layer_action_router")

local M = {}
local SYNTHETIC_EVENT_TAG = 0x53444152

function M.new(dependencies)
  local eventAPI = dependencies.event
  local tagProperty = eventAPI.properties.eventSourceUserData

  local function tag(event)
    return event:setProperty(tagProperty, SYNTHETIC_EVENT_TAG)
  end

  local function isSynthetic(event)
    return event:getProperty(tagProperty) == SYNTHETIC_EVENT_TAG
  end

  local function dispatch(original, result, blocked)
    local events = {}
    local spaceDirections = {}
    for _, action in ipairs(result.actions or {}) do
      local direction = actionRouter.missionControlSpaceDirection(action)
      if direction then
        if not action["repeat"] then
          table.insert(spaceDirections, direction)
        end
      else
        local key = action.keyCode or action.key
        local modifiers = action.modifiers or {}
        table.insert(events, tag(eventAPI.newKeyEvent(modifiers, key, true)))
        table.insert(events, tag(eventAPI.newKeyEvent(modifiers, key, false)))
      end
    end

    local swallow = result.swallow or blocked or false
    if #events > 0 and not swallow then
      table.insert(events, tag(original:copy()))
    end

    for _, direction in ipairs(spaceDirections) do
      dependencies.defer(function()
        dependencies.onSpace(direction)
      end)
    end

    if #events > 0 then
      return true, events
    end
    return swallow
  end

  return {isSynthetic = isSynthetic, dispatch = dispatch}
end

return M
