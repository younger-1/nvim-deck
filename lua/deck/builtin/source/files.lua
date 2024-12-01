local IO = require('deck.kit.IO')

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
  local root_dir = vim.fs.normalize(option.root_dir)
  local ignore_globs = vim.iter(option.ignore_globs or {}):map(function(glob)
    return vim.glob.to_lpeg(glob)
  end):totable()

  ---@type deck.Source
  return {
    name = 'files',
    execute = function(ctx)
      IO.walk(root_dir, function(err, entry)
        if err then
          return
        end
        if ctx.aborted() then
          return IO.WalkStatus.Break
        end
        for _, ignore_glob in ipairs(ignore_globs) do
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
