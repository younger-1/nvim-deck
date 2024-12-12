local helper = {}

---Normalize display_text.
---@param display_text string|deck.VirtualText
---@return deck.VirtualText
local function normalize_display_text(display_text)
  if type(display_text) == 'table' then
    display_text[1] = display_text[1] or ''
    return display_text
  end
  return { display_text or '' }
end

---Open a preview buffer with the given data.
---@param win integer
---@param file { contents: string[], filename?: string, filetype?: string, lnum?: integer, col?: integer, end_lnum?: integer, end_col?: integer }
function helper.open_preview_buffer(win, file)
  local buf = vim.api.nvim_create_buf(false, true)

  -- set contents.
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, file.contents)

  -- detect filetype.
  local filetype = file.filetype or vim.filetype.match({
    buf = buf,
    filename = file.filename,
    contents = file.contents,
  })
  if not file.filetype and file.filename then
    local runtime = file.filename:match('/(doc/.*)$')
    if runtime and #vim.api.nvim_get_runtime_file(runtime, false) > 0 then
      filetype = 'help'
    end
  end

  -- treesitter syntax.
  local ok, fallback = pcall(function()
    if filetype and not vim.tbl_contains({ 'diff', 'gitcommit' }, filetype) then
      local lang = vim.treesitter.language.get_lang(filetype)
      if lang and lang ~= 'text' then
        vim.treesitter.start(buf, lang)
        return false
      end
    end
    return true
  end)
  if not ok or fallback then
    -- vim syntax.
    if filetype ~= 'text' then
      vim.api.nvim_buf_call(buf, function()
        vim.api.nvim_set_option_value('filetype', filetype, { buf = 0 })
        vim.treesitter.stop(0)
      end)
    end
  end

  -- highlight cursor position.
  if file.lnum then
    local extmark_option = { line_hl_group = 'Visual' }
    if file.col and file.end_lnum and file.end_col then
      extmark_option.end_row = file.end_lnum - 1
      extmark_option.end_col = file.end_col - 1
      extmark_option.hl_group = 'CurSearch'
      extmark_option.hl_mode = 'combine'
      extmark_option.virt_text = { { '>', 'CurSearch' } }
      extmark_option.virt_text_pos = 'inline'
    elseif file.col then
      extmark_option.virt_text = { { '>', 'CurSearch' } }
      extmark_option.virt_text_pos = 'inline'
      extmark_option.hl_mode = 'combine'
    end
    vim.api.nvim_buf_set_extmark(buf, vim.api.nvim_create_namespace(('deck.helper.open_preview_buffer:%s'):format(buf)), file.lnum - 1, (file.col or 1) - 1, extmark_option)
  end

  -- set window.
  vim.api.nvim_win_set_buf(win, buf)
  vim.api.nvim_win_call(win, function()
    vim.api.nvim_win_set_cursor(win, { file.lnum or 1, (file.col or 1) - 1 })
    vim.cmd.normal({ 'zz', bang = true })
  end)
  local win_config = vim.api.nvim_win_get_config(win)
  if win_config.relative then
    win_config.footer = file.filename and vim.fn.fnamemodify(file.filename, ':~') or ''
    win_config.footer_pos = 'left'
    vim.api.nvim_win_set_config(win, win_config)
  end
end

---Create aligned display texts.
---@generic T: table
---@param items T[]
---@param callback fun(item: T): deck.VirtualText[]
---@param option? { sep?: string }
---@return string[], deck.Highlight[]
function helper.create_aligned_display_texts(items, callback, option)
  local strdisplaywidth ---@type fun(string: string): integer
  do
    local cache = {}
    strdisplaywidth = function(str)
      str = str or ''
      if cache[str] then
        return cache[str]
      end
      cache[str] = vim.fn.strdisplaywidth(str)
      return cache[str]
    end
  end

  ---@type { [integer]: { max_width: integer, columns: deck.VirtualText[] } }
  local column_definitions = {}
  for i, item in ipairs(items) do
    local columns = callback(item)
    if #column_definitions > 1 and #columns ~= #column_definitions then
      error('The number of columns must be the same for all items.')
    end

    for j, column in ipairs(columns) do
      column = normalize_display_text(column)
      column_definitions[j] = column_definitions[j] or { max_width = 0, columns = {} }
      column_definitions[j].max_width = math.max(column_definitions[j].max_width, strdisplaywidth(column[1]))
      column_definitions[j].columns[i] = column
    end
  end

  local sep = normalize_display_text(option and option.sep or ' ')

  local display_texts = {} ---@type string[]
  local highlights = {} ---@type deck.Highlight[][]
  for i in ipairs(items) do
    local offset = 0
    local display_text = {}
    for j, column_definition in ipairs(column_definitions) do
      local column = column_definition.columns[i] or { '', '' }

      -- decorate.
      local hl_group = type(column) == 'table' and column[2]
      if hl_group then
        highlights[i] = highlights[i] or {}
        table.insert(highlights[i], {
          [1] = offset,
          [2] = offset + #column[1],
          hl_group = hl_group,
        })
      end

      -- display_text.
      if j == #column_definitions then
        table.insert(display_text, column[1])
      else
        local padding = (' '):rep(column_definition.max_width - strdisplaywidth(column[1]))
        local padded = ('%s%s'):format(column[1], padding)
        table.insert(display_text, padded)
        table.insert(display_text, sep[1])
        offset = offset + #padded + #sep[1]
      end
    end
    table.insert(display_texts, table.concat(display_text, ''))
  end

  return display_texts, highlights
end

return helper
