local function dirname(path)
  return path:match("(.+)/[^/]+$") or "."
end

local testDir = dirname(arg[0] or ".")
local hsDir = dirname(testDir)
package.path = hsDir .. "/?.lua;" .. package.path

local rsKeyResolver = require("rs_key_resolver")

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

local function testResolvesPhysicalKeyCodesBeforeFallback()
  local state, err = rsKeyResolver.new({
    triggerKeys = {"r", "s"},
    triggerKeyCodes = {0x01, 0x02},
    navMap = {h = "left", n = "down", e = "up", i = "right"},
    navKeyCodeMap = {
      [0x04] = "left",
      [0x26] = "down",
      [0x28] = "up",
      [0x25] = "right",
    },
  })
  assertTrue(state ~= nil, "resolver should be created")
  assertEqual(err, nil, "resolver should not return error")

  assertEqual(
    rsKeyResolver.resolveKey(state, 0x01, "s"),
    "r",
    "trigger keyCode should resolve to trigger key regardless of fallback"
  )
  assertEqual(
    rsKeyResolver.resolveKey(state, 0x26, "j"),
    "n",
    "nav keyCode should resolve to nav key regardless of fallback"
  )
end

local function testFallsBackToKeyStringWhenKeyCodeIsNotConfigured()
  local state, err = rsKeyResolver.new({
    triggerKeys = {"r", "s"},
    triggerKeyCodes = {0x01, 0x02},
    navMap = {h = "left", n = "down", e = "up", i = "right"},
    navKeyCodeMap = {
      [0x04] = "left",
      [0x26] = "down",
      [0x28] = "up",
      [0x25] = "right",
    },
  })
  assertTrue(state ~= nil, "resolver should be created")
  assertEqual(err, nil, "resolver should not return error")

  assertEqual(
    rsKeyResolver.resolveKey(state, 0x31, "space"),
    "space",
    "unknown keyCode should use fallback key string"
  )
end

local function testFailsOnDuplicateKeyCodeConfiguration()
  local state, err = rsKeyResolver.new({
    triggerKeys = {"r", "s"},
    triggerKeyCodes = {0x01, 0x02},
    navMap = {h = "left", n = "down", e = "up", i = "right"},
    navKeyCodeMap = {
      [0x01] = "left",
    },
  })
  assertEqual(state, nil, "duplicate keyCode config should fail")
  assertTrue(type(err) == "string" and err ~= "", "duplicate keyCode config should return an error string")
end

local tests = {
  testResolvesPhysicalKeyCodesBeforeFallback,
  testFallsBackToKeyStringWhenKeyCodeIsNotConfigured,
  testFailsOnDuplicateKeyCodeConfiguration,
}

for _, test in ipairs(tests) do
  test()
end

print("rs_key_resolver tests passed")
