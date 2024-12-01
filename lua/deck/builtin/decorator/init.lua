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
    })
  end
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
          ephemeral = true,
        })
      end
    end
  end
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
        ephemeral = true,
      })
    end
  end
}

---@type deck.Decorator
decorators.selection = {
  name = 'selection',
  decorate = function(ctx, item, row)
    vim.api.nvim_buf_set_extmark(ctx.buf, ctx.ns, row, 0, {
      sign_text = ctx.get_selected(item) and '*' or ' ',
      sign_hl_group = 'SignColumn',
    })
  end
}

---@type deck.Decorator
decorators.filename = {
  name = 'filename',
  resolve = function(_, item)
    return item.data.filename
  end,
  decorate = function(ctx, item, row)
    local is_dir = vim.fn.isdirectory(item.data.filename) == 1

    -- icons decoration.
    local ok, Icons = pcall(require, 'mini.icons')
    if ok then
      local icon, hl = Icons.get(is_dir and 'directory' or 'file', item.data.filename)
      if icon and hl then
        vim.api.nvim_buf_set_extmark(ctx.buf, ctx.ns, row, 0, {
          virt_text = {
            -- padding for cursor col.
            { ' ' }, { icon, hl }, { ' ' }
          },
          virt_text_pos = 'inline',
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
          { ('#%s'):format(buf),      'Comment' },
        },

        virt_text_pos = 'eol',
        ephemeral = true
      })
    end
  end
}

return decorators
