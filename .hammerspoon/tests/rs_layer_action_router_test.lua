local function dirname(path)
  return path:match("(.+)/[^/]+$") or "."
end

local testDir = dirname(arg[0] or ".")
local hsDir = dirname(testDir)
package.path = hsDir .. "/?.lua;" .. package.path

local actionRouter = require("rs_layer_action_router")

local function assertEqual(actual, expected, message)
  if actual ~= expected then
    error(string.format("%s: expected=%s actual=%s", message, tostring(expected), tostring(actual)))
  end
end

local function testMissionControlSpaceDirection()
  assertEqual(
    actionRouter.missionControlSpaceDirection({key = "left", modifiers = {"ctrl"}}),
    "left",
    "ctrl+left should be a Mission Control space action"
  )
  assertEqual(
    actionRouter.missionControlSpaceDirection({key = "right", modifiers = {"ctrl"}}),
    "right",
    "ctrl+right should be a Mission Control space action"
  )
end

local function testMissionControlSpaceDirectionIgnoresOtherActions()
  assertEqual(
    actionRouter.missionControlSpaceDirection({key = "left", modifiers = {}}),
    nil,
    "plain left should stay synthetic"
  )
  assertEqual(
    actionRouter.missionControlSpaceDirection({key = "left", modifiers = {"shift", "ctrl"}}),
    nil,
    "ctrl+shift+left should stay synthetic"
  )
  assertEqual(
    actionRouter.missionControlSpaceDirection({key = "up", modifiers = {"ctrl"}}),
    nil,
    "ctrl+up should stay synthetic"
  )
end

local function testAdjacentSpace()
  local spaces = {101, 102, 103}
  assertEqual(actionRouter.adjacentSpace(spaces, 102, "left"), 101, "left should select previous space")
  assertEqual(actionRouter.adjacentSpace(spaces, 102, "right"), 103, "right should select next space")
end

local function testAdjacentSpaceReturnsNilAtEdges()
  local spaces = {101, 102, 103}
  assertEqual(actionRouter.adjacentSpace(spaces, 101, "left"), nil, "left edge should not wrap")
  assertEqual(actionRouter.adjacentSpace(spaces, 103, "right"), nil, "right edge should not wrap")
  assertEqual(actionRouter.adjacentSpace(spaces, 999, "right"), nil, "missing focused space should not move")
end

local tests = {
  testMissionControlSpaceDirection,
  testMissionControlSpaceDirectionIgnoresOtherActions,
  testAdjacentSpace,
  testAdjacentSpaceReturnsNilAtEdges,
}

for _, test in ipairs(tests) do
  test()
end

print("rs_layer_action_router tests passed")
