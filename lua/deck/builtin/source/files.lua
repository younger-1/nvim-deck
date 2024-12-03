local notify = require('deck.notify')
local IO = require('deck.kit.IO')
local System = require('deck.kit.System')

--[=[@doc
  category = "source"
  name = "files"
  desc = "Show files under specified root directory."
  example = """
    deck.start(require('deck.builtin.source.files')({
      root_dir = vim.fn.getcwd(),
      ignore_globs = { '**/node_modules/', '**/.git/' },
    }))
  """

  [[options]]
  name = "ignore_globs"
  type = "string[]?"
  default = "[]"
  desc = "Ignore glob patterns."

  [[options]]
  name = "root_dir"
  type = "string"
  desc = "Target root directory."
]=]
---@param option { root_dir: string, ignore_globs?: string[] }
return function(option)
  local root_dir = vim.fs.normalize(vim.fn.fnamemodify(option.root_dir, ':p'))
  local ignore_glob_patterns = vim.iter(option.ignore_globs or {}):map(function(glob)
    return vim.glob.to_lpeg(glob)
  end):totable()

  ---@type deck.Source
  return {
    name = 'files',
    execute = function(ctx)
      local is_root_dir_ignore = vim.iter(ignore_glob_patterns):any(function(glob)
        return glob:match(root_dir)
      end)
      if is_root_dir_ignore then
        ctx.done()
        return
      end

      if vim.fn.executable('rg') == 1 then
        local command = {
          'rg',
          '--files',
          '--follow'
        }
        for _, glob in ipairs(option.ignore_globs or {}) do
          table.insert(command, '--glob')
          table.insert(command, '!' .. glob)
        end
        System.spawn(command, {
          cwd = root_dir,
          env = {},
          buffering = System.LineBuffering.new({
            ignore_empty = true
          }),
          on_stdout = function(text)
            local path = vim.fs.joinpath(root_dir, text)
            ctx.item({
              display_text = path,
              data = {
                filename = path
              }
            })
          end,
          on_stderr = function(text)
            notify.show({
              { { ('[files: stderr] %s'):format(text), 'ErrorMsg' } }
            })
          end,
          on_exit = function()
            ctx.done()
          end
        })
        return
      end

      IO.walk(root_dir, function(err, entry)
        if err then
          return
        end
        if ctx.aborted() then
          return IO.WalkStatus.Break
        end
        for _, ignore_glob in ipairs(ignore_glob_patterns) do
          if ignore_glob:match(entry.path) then
            if entry.type ~= 'file' then
              return IO.WalkStatus.SkipDir
            end
            return
          end
        end

        if entry.type == 'file' then
          ctx.item({
            display_text = vim.fn.fnamemodify(entry.path, ':~'):gsub(vim.pesc(root_dir), '.'),
            data = {
              filename = entry.path
            }
          })
        end
      end):next(function()
        ctx.done()
      end)
    end,
    actions = {
      require('deck').alias_action('default', 'open'),
    }
  }
end
