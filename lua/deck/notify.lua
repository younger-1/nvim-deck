---@alias deck.notify.Line (string|{ [1]: string, [2]?: string })[]
---@alias deck.notify.Item { message: deck.notify.Line[], timeout: integer, visible_at: integer }

local state = {
  items = {},
  ns = vim.api.nvim_create_namespace('deck.notify'),
  buf = vim.api.nvim_create_buf(false, true),
  win = nil,
  timer = vim.uv.new_timer(),
}

vim.api.nvim_set_decoration_provider(state.ns, {
  on_line = function(_, _, buf, row)
    if buf ~= state.buf then
      return
    end

    local lines = {}
    for _, item in ipairs(state.items) do
      for _, line in ipairs(item.message) do
        table.insert(lines, line)
      end
    end
    local offset = 0
    for _, part in ipairs(lines[row + 1]) do
      if type(part) == 'table' then
        vim.api.nvim_buf_set_extmark(buf, state.ns, row, offset, {
          end_row = row,
          end_col = offset + #part[1],
          hl_group = part[2],
          hl_mode = 'combine',
          ephemeral = true,
        })
        offset = offset + #part[1]
      end
    end
  end,
})

local notify = {}

---@param line deck.notify.Line
---@return string
local function to_plain_text(line)
  local parts = {}
  for _, part in ipairs(line) do
    table.insert(parts, ((type(part) == 'table' and part[1] or part --[[@as string]]):gsub('\n', '')))
  end
  return table.concat(parts, '')
end

---Render notify view.
---@param max_width number
---@param max_height number
local function render(max_width, max_height)
  vim.api.nvim_buf_call(state.buf, function()
    local now = vim.uv.now()

    -- invalidate items.
    for i = #state.items, 1, -1 do
      local item = state.items[i]
      if (now - item.visible_at) > item.timeout then
        table.remove(state.items, i)
      elseif #item.message == 0 then
        table.remove(state.items, i)
      end
    end

    -- check to visible.
    if #state.items == 0 then
      if state.win and vim.api.nvim_win_is_valid(state.win) then
        vim.api.nvim_win_hide(state.win)
        state.win = nil
        state.timer:stop()
        return
      end
    end

    -- remove unnecessary empty lines.
    while to_plain_text(state.items[1].message[1]) == '' do
      table.remove(state.items[1].message, 1)
    end

    -- create lines.
    local lines = {} --[=[@string[]]=]
    for _, item in ipairs(state.items) do
      for _, line in ipairs(item.message) do
        table.insert(lines, to_plain_text(line))
      end
    end

    -- compute width/height.
    local width = max_width
    local height = 0
    for _, line in ipairs(lines) do
      height = height + math.ceil(math.max(vim.api.nvim_strwidth(line), 1) / width)
    end
    height = math.max(1, math.min(max_height, height))

    vim.api.nvim_set_option_value('modifiable', true, { buf = state.buf })
    vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, lines)
    vim.api.nvim_set_option_value('modifiable', false, { buf = state.buf })

    local win_config = {
      noautocmd = true,
      relative = 'editor',
      width = width,
      height = height,
      row = vim.o.lines - height,
      col = vim.o.columns - width,
      style = 'minimal',
      border = 'rounded',
    }
    if state.win and vim.api.nvim_win_is_valid(state.win) then
      win_config.noautocmd = nil
      vim.api.nvim_win_set_config(state.win, win_config)
    else
      state.win = vim.api.nvim_open_win(state.buf, false, win_config)
    end
    vim.api.nvim_set_option_value('wrap', true, { win = state.win })
    vim.api.nvim_set_option_value('winhighlight', 'Normal:Normal,FloatBorder:Normal', { win = state.win })
    vim.cmd.normal({ 'Gzb', bang = true })

    state.timer:stop()
    state.timer:start(
      200,
      0,
      vim.schedule_wrap(function()
        render(max_width, max_height)
      end)
    )
  end)
end

---Show messages
---@param message deck.notify.Line[]
---@param option? { timeout?: number }
function notify.show(message, option)
  vim.schedule(function()
    option = option or {}
    option.timeout = option.timeout or 5000

    if #state.items ~= 0 then
      table.insert(message, 1, { '' })
    end
    table.insert(state.items, {
      message = message,
      timeout = option.timeout,
      visible_at = vim.uv.now(),
    })

    render(math.floor(vim.o.columns * 0.4), math.floor(vim.o.lines * 0.5))
  end)
end

return notify
