local start_preset = {}

---@type deck.StartPreset
start_preset.helpgrep = {
  name = 'helpgrep',
  start = function()
    require('deck').start(require('deck.builtin.source.helpgrep')())
  end,
}

---@type deck.StartPreset
start_preset.deck_history = {
  name = 'deck.history',
  start = function()
    require('deck').start(require('deck.builtin.source.deck.history')(), {
      history = false,
    })
  end,
}

return start_preset
