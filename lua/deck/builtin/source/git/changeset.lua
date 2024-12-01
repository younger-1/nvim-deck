local helper = require('deck.helper')
local Git = require('deck.helper.git')
local Async = require('deck.kit.Async')

---@param option { cwd: string, from_rev: string, to_rev?: string }
return function(option)
  local git = Git.new(option.cwd)
  ---@type deck.Source
  return {
    name = 'git.changeset',
    execute = function(ctx)
      Async.run(function()
        local changeset = git:get_changeset({ from_rev = option.from_rev, to_rev = option.to_rev }):await() ---@type deck.builtin.source.git.Change[]
        local display_texts, highlights = helper.create_aligned_display_texts(changeset, function(change)
          return { change.type, git:to_relative(change.filename) }
        end, { sep = ' │ ' })

        for i, change in ipairs(changeset) do
          ctx.item({
            display_text = display_texts[i],
            highlights = highlights[i],
            data = change,
          })
        end
        ctx.done()
      end)
    end,
    actions = {
      require('deck').alias_action('default', 'git.branch.vimdiff'),
      {
        name = 'git.changeset.vimdiff',
        execute = function(ctx)
          for _, item in ipairs(ctx.get_action_items()) do
            git:vimdiff({
              from_rev = option.from_rev,
              to_rev = option.to_rev,
              filename = item.data.filename,
            }):sync(5000)
          end
        end
      }
    },
    previewers = {
      {
        name = 'git.changeset.unified_diff',
        preview = function(ctx, env)
          local item = ctx.get_cursor_item()
          if item then
            helper.open_preview_buffer(env.win, {
              contents = git:get_unified_diff({
                from_rev = option.from_rev,
                to_rev = option.to_rev,
                filename = item.data.filename
              }):sync(5000),
              filename = item.data.filename,
              filetype = 'diff'
            })
          end
        end
      }
    }
  }
end
