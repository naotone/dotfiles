local M = {}

local function noop()
end

function M.items(state, callbacks)
  state = state or {}
  callbacks = callbacks or {}

  return {
    {
      title = "Internal Keyboard Block",
      checked = state.internalKeyboardDisabled and true or false,
      fn = callbacks.toggleInternalKeyboardBlock or noop,
    },
    {
      title = "SD Arrow Layer",
      checked = state.rsLayerEnabled and true or false,
      fn = callbacks.toggleRsLayer or noop,
    },
    {title = "-"},
    {
      title = "Reset SD Arrow State",
      fn = callbacks.resetRsLayerState or noop,
    },
    {
      title = "Open Hammerspoon Config",
      fn = callbacks.openHammerspoonConfig or noop,
    },
    {title = "-"},
    {
      title = "Debug",
      menu = {
        {
          title = "SD Arrow Debug Log",
          checked = state.rsLayerDebugEnabled and true or false,
          fn = callbacks.toggleRsLayerDebug or noop,
        },
        {
          title = "KeyDown Inspector",
          checked = state.debugKeyDownEnabled and true or false,
          fn = callbacks.toggleDebugKeyDown or noop,
        },
        {
          title = "Internal Keyboard Block Debug Log",
          checked = state.internalKeyboardDebugEnabled and true or false,
          fn = callbacks.toggleInternalKeyboardDebug or noop,
        },
        {title = "-"},
        {
          title = "Dump SD Arrow State",
          fn = callbacks.dumpRsLayerState or noop,
        },
        {
          title = "Check Event Taps",
          fn = callbacks.checkEventTaps or noop,
        },
        {
          title = "Open Hammerspoon Console",
          fn = callbacks.openHammerspoonConsole or noop,
        },
      },
    },
  }
end

return M
