local symbols = require('deck.symbols')

local decorators = {}

---@type deck.Decorator
decorators.source_name = {
  name = 'source_name',
  resolve = function(ctx)
    return #ctx.get_source_names() > 1
  end,
  decorate = function(ctx, item, row)
    vim.api.nvim_buf_set_extmark(ctx.buf, ctx.ns, row, 0, {
      virt_text = {
        { ('%s'):format(item[symbols.source].name), 'Comment' },
        { ' ' },
      },
      virt_text_pos = 'right_align',
      hl_mode = 'combine',
    })
  end,
}

---@type deck.Decorator
decorators.highlights = {
  name = 'highlights',
  resolve = function(_, item)
    return type(item.highlights) == 'table'
  end,
  decorate = function(ctx, item, row)
    for _, hi in ipairs(item.highlights or {}) do
      if hi.hl_group then
        vim.api.nvim_buf_set_extmark(ctx.buf, ctx.ns, row, hi[1], {
          end_row = row,
          end_col = hi[2],
          hl_group = hi.hl_group,
          hl_mode = 'combine',
          ephemeral = true,
        })
      end
    end
  end,
}

---@type deck.Decorator
decorators.query_matches = {
  name = 'query_matches',
  resolve = function(_, item)
    return item[symbols.matches]
  end,
  decorate = function(ctx, item, row)
    for _, match in ipairs(item[symbols.matches]) do
      vim.api.nvim_buf_set_extmark(ctx.buf, ctx.ns, row, match[1], {
        end_row = row,
        end_col = match[2],
        hl_group = 'Search',
        hl_mode = 'combine',
        ephemeral = true,
      })
    end
  end,
}

---@type deck.Decorator
decorators.selection = {
  name = 'selection',
  decorate = function(ctx, item, row)
    vim.api.nvim_buf_set_extmark(ctx.buf, ctx.ns, row, 0, {
      sign_text = ctx.get_selected(item) and '*' or ' ',
      sign_hl_group = 'SignColumn',
      hl_mode = 'combine',
    })
  end,
}

---@type deck.Decorator
do
  local get_icon --[[@as (fun(category: string, filename: string):(string?, string?))?]]
  vim.api.nvim_create_autocmd('BufEnter', {
    callback = function()
      if vim.b.deck then
        do -- mini.icons.
          local ok, Icons = pcall(require, 'mini.icons')
          if ok then
            get_icon = function(category, filename)
              return Icons.get(category, filename)
            end
          end
        end
      end
    end,
  })
  decorators.filename = {
    name = 'filename',
    resolve = function(_, item)
      return item.data.filename
    end,
    decorate = function(ctx, item, row)
      local is_dir = vim.fn.isdirectory(item.data.filename) == 1

      -- icons decoration.
      if get_icon then
        local icon, hl = get_icon(is_dir and 'directory' or 'file', item.data.filename)
        if icon then
          vim.api.nvim_buf_set_extmark(ctx.buf, ctx.ns, row, 0, {
            virt_text = {
              -- padding for cursor col.
              { ' ' },
              { icon, hl },
              { ' ' },
            },
            virt_text_pos = 'inline',
            hl_mode = 'combine',
          })
        end
      end

      -- buffer related decoration.
      local buf = vim.fn.bufnr(item.data.filename)
      if not is_dir and buf ~= -1 then
        local modified = vim.api.nvim_get_option_value('modified', { buf = buf })
        vim.api.nvim_buf_set_extmark(ctx.buf, ctx.ns, row, 0, {
          virt_text = {
            { modified and '[+]' or '', 'SpecialKey' },
            { ' ' },
            { ('#%s'):format(buf), 'Comment' },
          },

          virt_text_pos = 'eol',
          hl_mode = 'combine',
          ephemeral = true,
        })
      end
    end,
  }
end

return decorators
