local helper = require('deck.helper')
local Git = require('deck.helper.git')
local Async = require('deck.kit.Async')

---@param option { cwd: string }
return function(option)
  local git = Git.new(option.cwd)
  ---@type deck.Source
  return {
    name = 'git',
    events = {
      BufWinEnter = function(ctx)
        ctx.execute()
      end
    },
    execute = function(ctx)
      Async.run(function()
        local branches = git:branch():await() --[=[@as deck.builtin.source.git.Branch[]]=]
        local current_branch = vim.iter(branches):find(function(branch)
          return branch.current
        end) --[=[@as deck.builtin.source.git.Branch?]=]

        local menu = {}

        table.insert(menu, {
          columns = {
            'status',
            { 'show current status', 'Comment' }
          },
          execute = function()
            require('deck').start(require('deck.builtin.source.git.status')({
              cwd = option.cwd,
            }))
          end,
        })

        table.insert(menu, {
          columns = {
            'branch',
            { 'show branches', 'Comment' }
          },
          execute = function()
            require('deck').start(require('deck.builtin.source.git.branch')({
              cwd = option.cwd,
            }))
          end,
        })

        table.insert(menu, {
          columns = {
            'log',
            { 'show logs', 'Comment' }
          },
          execute = function()
            require('deck').start(require('deck.builtin.source.git.log')({
              cwd = option.cwd,
            }))
          end,
        })

        table.insert(menu, {
          columns = {
            'remote',
            { 'show remotes', 'Comment' }
          },
          execute = function()
            require('deck').start(require('deck.builtin.source.git.remote')({
              cwd = option.cwd,
            }))
          end,
        })

        table.insert(menu, {
          columns = {
            '@ fetch --all --prune',
            { 'fetch all branches and prune', 'Comment' }
          },
          execute = function()
            git:exec_print({ 'git', 'fetch', '--all', '--prune' })
          end,
        })

        -- push current branch.
        if current_branch then
          if current_branch.upstream then
            table.insert(menu, {
              columns = {
                '@ pull',
                { ('pull `%s` from `%s`'):format(current_branch.name, current_branch.upstream), 'Comment' }
              },
              branch = current_branch,
              ---@param action_ctx deck.Context
              execute = function(action_ctx)
                git:exec_print({ 'git', 'pull', current_branch.remotename, current_branch.name }):next(function()
                  action_ctx.execute()
                end)
              end,
            })
          end
          table.insert(menu, {
            columns = {
              '@ push',
              { ('push `%s` %s'):format(current_branch.name, current_branch.track or 'up-to-date'), 'Comment' }
            },
            branch = current_branch,
            ---@param action_ctx deck.Context
            execute = function(action_ctx)
              git:push({
                branch = current_branch,
              }):next(function()
                action_ctx.execute()
              end)
            end,
          })
          table.insert(menu, {
            columns = {
              '@ push --force',
              { ('push --force `%s` %s'):format(current_branch.name, current_branch.track or 'up-to-date'), 'Comment' }
            },
            branch = current_branch,
            ---@param action_ctx deck.Context
            execute = function(action_ctx)
              git:push({
                branch = current_branch,
                force = true,
              }):next(function()
                action_ctx.execute()
              end)
            end,
          })
        end

        local display_texts, highlights = helper.create_aligned_display_texts(menu, function(item)
          return item.columns
        end, { sep = ' │ ' })

        for i, item in ipairs(menu) do
          ctx.item({
            display_text = display_texts[i],
            highlights = highlights[i],
            data = item,
          })
        end

        ctx.done()
      end)
    end,
    actions = {
      require('deck').alias_action('default', 'git.execute'),
      {
        name = 'git.execute',
        resolve = function(ctx)
          return #ctx.get_action_items() == 1
        end,
        execute = function(ctx)
          local item = ctx.get_cursor_item()
          if item and item.data.execute then
            item.data.execute(ctx)
          end
        end,
      }
    }
  }
end
