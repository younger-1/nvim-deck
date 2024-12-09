--[=[@doc
  category = "source"
  name = "buffers"
  desc = "Show buffers."
  example = """
    deck.start(require('deck.builtin.source.buffers')({
      ignore_paths = { vim.fn.expand('%:p'):gsub('/$', '') },
      nofile = false,
    }))
  """

  [[options]]
  name = "ignore_paths"
  type = "string[]?"
  default = "[vim.fn.expand('%:p')]"
  desc = "Ignore paths. The default value is intented to hide current buffer."

  [[options]]
  name = "nofile"
  type = "boolean?"
  default = "false"
  desc = "Ignore nofile buffers."
]=]
---@param option? { ignore_paths?: string[], nofile?: boolean }
return function(option)
  option = option or {}
  option.ignore_paths = option.ignore_paths or { vim.fn.expand('%:p'):gsub('/$', '') }
  option.nofile = option.nofile or false

  local ignore_path_map = {}
  for _, ignore_path in ipairs(option.ignore_paths) do
    ignore_path_map[ignore_path] = true
  end

  ---@type deck.Source
  return {
    name = 'buffers',
    execute = function(ctx)
      local buffers = vim.api.nvim_list_bufs()
      for _, buf in ipairs(buffers) do
        local bufname = vim.api.nvim_buf_get_name(buf)
        local acceptable = true
        acceptable = acceptable and not ignore_path_map[bufname]
        acceptable = acceptable and (option.nofile or vim.api.nvim_get_option_value('buftype', { buf = buf }) ~= 'nofile')
        if acceptable then
          local filename = vim.fn.filereadable(bufname) == 1 and bufname
          ctx.item({
            display_text = filename and vim.fn.fnamemodify(filename, ':~') or bufname,
            data = {
              bufnr = buf,
              filename = filename,
            },
          })
        end
      end
      ctx.done()
    end,
    actions = {
      require('deck').alias_action('default', 'open'),
    },
  }
end
