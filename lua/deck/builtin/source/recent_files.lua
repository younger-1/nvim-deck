local VFile = require('deck.helper.vfile')
local Async = require('deck.kit.Async')

local pruned = false

--[=[@doc
  category = "source"
  name = "recent_files"
  desc = "List recent files."
  example = """
    require('deck.builtin.source.recent_files'):setup({
      path = '~/.deck.recent_files'
    })
    vim.api.nvim_create_autocmd('BufEnter', {
      callback = function()
        local bufname = vim.api.nvim_buf_get_name(0)
        if vim.fn.filereadable(bufname) == 1 then
          require('deck.builtin.source.recent_files'):add(vim.fs.normalize(bufname))
        end
      end,
    })
    deck.start(require('deck.builtin.source.recent_files')({
      ignore_paths = { '**/node_modules/', '**/.git/' },
    }))
  """

  [[options]]
  name = "ignore_paths"
  type = "string[]?"
  default = "[]"
  desc = "Ignore paths."
]=]
return setmetatable({
  vfile = VFile.new(vim.fs.normalize('~/.deck.recent_files')),

  ---Setup.
  ---@param config { path: string }
  setup = function(self, config)
    local path = vim.fs.normalize(config.path)
    if vim.fn.filereadable(path) == 0 then
      error('`config.path` must be readable file.')
    end
    self.vfile = VFile.new(path)
  end,

  ---Prune entries (remove duplicates and non-existent entries).
  ---@param self unknown
  prune = function(self)
    local seen = {}
    for i = #self.vfile.contents, 1, -1 do
      local path = self.vfile.contents[i]
      if seen[path] or vim.fn.filereadable(path) == 0 then
        table.remove(self.vfile.contents, i)
      end
      seen[path] = true
    end
  end,

  ---Add entry.
  ---@param self unknown
  ---@param target_path string
  add = function(self, target_path)
    if not target_path then
      return
    end
    target_path = vim.fs.normalize(target_path)

    local exists = vim.fn.filereadable(target_path) == 1
    if not exists then
      return
    end

    local seen = { [target_path] = true }
    for i = #self.vfile.contents, 1, -1 do
      local path = self.vfile.contents[i]
      if seen[path] then
        table.remove(self.vfile.contents, i)
      end
      seen[path] = true
    end
    table.insert(self.vfile.contents, target_path)
  end,
}, {
  ---@param option { ignore_paths?: string[] }
  __call = function(self, option)
    option = option or {}
    option.ignore_paths = option.ignore_paths or { vim.fn.expand('%:p'):gsub('/$', '') }

    local ignore_path_map = {}
    for _, ignore_path in ipairs(option.ignore_paths) do
      ignore_path_map[ignore_path] = true
    end

    if not pruned then
      self:prune()
      pruned = true
    end

    ---@type deck.Source
    return {
      name = 'recent_files',
      execute = function(ctx)
        Async.run(function()
          local contents = self.vfile.contents
          for i = #contents, 1, -1 do
            local path = contents[i]
            if not ignore_path_map[path] then
              ctx.item({
                display_text = vim.fn.fnamemodify(path, ':~'),
                data = {
                  filename = path,
                },
              })
            end
          end
          ctx.done()
        end)
      end,
      actions = {
        require('deck').alias_action('default', 'open'),
      },
    }
  end,
})
