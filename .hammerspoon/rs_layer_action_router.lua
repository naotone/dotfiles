local M = {}

local function hasOnlyCtrl(modifiers)
  if type(modifiers) ~= "table" or #modifiers ~= 1 then
    return false
  end
  return modifiers[1] == "ctrl"
end

function M.missionControlSpaceDirection(action)
  if type(action) ~= "table" then
    return nil
  end
  if action.key ~= "left" and action.key ~= "right" then
    return nil
  end
  if not hasOnlyCtrl(action.modifiers or {}) then
    return nil
  end
  return action.key
end

function M.adjacentSpace(spaces, focusedSpace, direction)
  if type(spaces) ~= "table" or (direction ~= "left" and direction ~= "right") then
    return nil
  end

  local focusedIndex = nil
  for index, spaceID in ipairs(spaces) do
    if spaceID == focusedSpace then
      focusedIndex = index
      break
    end
  end
  if not focusedIndex then
    return nil
  end

  local targetIndex = direction == "left" and focusedIndex - 1 or focusedIndex + 1
  return spaces[targetIndex]
end

return M
