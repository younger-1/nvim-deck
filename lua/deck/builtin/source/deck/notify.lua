local notify = require('deck.notify')

--[=[@doc
  category = "source"
  name = "deck.notify"
  desc = "Show deck.notify history."
  example = """
    deck.start(require('deck.builtin.source.deck.notify')())
  """
]=]
return function()
  ---@type deck.Source
  return {
    name = 'deck.notify',
    execute = function(ctx)
      for _, item in ipairs(notify.get_history()) do
        for _, line in ipairs(item.message) do
          ctx.item({
            display_text = line,
          })
        end
      end
      ctx.done()
    end,
  }
end
