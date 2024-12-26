local kit = require('deck.kit')

---@alias deck.kit.Vim.FloatingWindow.WindowKind 'main' | 'scrollbar_track' | 'scrollbar_thumb'

---@class deck.kit.Vim.FloatingWindow.BorderSize
---@field public top integer
---@field public left integer
---@field public right integer
---@field public bottom integer
---@field public h integer
---@field public v integer

---@class deck.kit.Vim.FloatingWindow.ContentSize
---@field public width integer
---@field public height integer

---@class deck.kit.Vim.FloatingWindow.Config
---@field public row integer 0-indexed utf-8
---@field public col integer 0-indexed utf-8
---@field public width integer
---@field public height integer
---@field public border? string | string[]
---@field public anchor? "NW" | "NE" | "SW" | "SE"
---@field public style? string
---@field public zindex? integer

---@class deck.kit.Vim.FloatingWindow.Viewport
---@field public row integer
---@field public col integer
---@field public inner_width integer window inner width
---@field public inner_height integer window inner height
---@field public outer_width integer window outer width that includes border and scrollbar width
---@field public outer_height integer window outer height that includes border width
---@field public border_size deck.kit.Vim.FloatingWindow.BorderSize
---@field public content_size deck.kit.Vim.FloatingWindow.ContentSize
---@field public scrollbar boolean
---@field public ui_width integer
---@field public ui_height integer
---@field public border string | string[] | nil

---@class deck.kit.Vim.FloatingWindow
---@field private _augroup string
---@field private _buf_option table<string, { [string]: any }>
---@field private _win_option table<string, { [string]: any }>
---@field private _buf integer
---@field private _scrollbar_track_buf integer
---@field private _scrollbar_thumb_buf integer
---@field private _win? integer
---@field private _scrollbar_track_win? integer
---@field private _scrollbar_thumb_win? integer
local FloatingWindow = {}
FloatingWindow.__index = FloatingWindow

---Returns true if the window is visible
---@param win? integer
---@return boolean
local function is_visible(win)
  if not win then
    return false
  end
  if not vim.api.nvim_win_is_valid(win) then
    return false
  end
  return true
end

---Show the window
---@param win? integer
---@param buf integer
---@param config deck.kit.Vim.FloatingWindow.Config
---@return integer
local function show_or_move(win, buf, config)
  local border_size = FloatingWindow.get_border_size(config.border)
  if config.anchor == 'NE' then
    config.col = config.col - config.width - border_size.right - border_size.left
  elseif config.anchor == 'SW' then
    config.row = config.row - config.height - border_size.top - border_size.bottom
  elseif config.anchor == 'SE' then
    config.row = config.row - config.height - border_size.top - border_size.bottom
    config.col = config.col - config.width - border_size.right - border_size.left
  end
  config.anchor = 'NW'

  if is_visible(win) then
    vim.api.nvim_win_set_config(win --[=[@as integer]=], {
      relative = 'editor',
      row = config.row,
      col = config.col,
      width = config.width,
      height = config.height,
      anchor = 'NW',
      style = config.style,
      border = config.border,
      zindex = config.zindex,
    })
    return win --[=[@as integer]=]
  else
    return vim.api.nvim_open_win(buf, false, {
      noautocmd = true,
      relative = 'editor',
      row = config.row,
      col = config.col,
      width = config.width,
      height = config.height,
      anchor = 'NW',
      style = config.style,
      border = config.border,
      zindex = config.zindex,
    })
  end
end

---Hide the window
---@param win integer
local function hide(win)
  if is_visible(win) then
    vim.api.nvim_win_hide(win)
  end
end

---Get border size.
---@param border nil | string | string[]
---@return deck.kit.Vim.FloatingWindow.BorderSize
function FloatingWindow.get_border_size(border)
  local maybe_border_size = (function()
    if not border then
      return { top = 0, right = 0, bottom = 0, left = 0 }
    end
    if type(border) == 'string' then
      if border == 'none' then
        return { top = 0, right = 0, bottom = 0, left = 0 }
      elseif border == 'single' then
        return { top = 1, right = 1, bottom = 1, left = 1 }
      elseif border == 'double' then
        return { top = 2, right = 2, bottom = 2, left = 2 }
      elseif border == 'rounded' then
        return { top = 1, right = 1, bottom = 1, left = 1 }
      elseif border == 'solid' then
        return { top = 1, right = 1, bottom = 1, left = 1 }
      elseif border == 'shadow' then
        return { top = 0, right = 1, bottom = 1, left = 0 }
      end
      return { top = 0, right = 0, bottom = 0, left = 0 }
    end
    local chars = border --[=[@as string[]]=]
    while #chars < 8 do
      chars = kit.concat(chars, chars)
    end
    return {
      top = vim.api.nvim_strwidth(chars[2]),
      right = vim.fn.nvim_strwidth(chars[4]),
      bottom = vim.fn.nvim_strwidth(chars[6]),
      left = vim.fn.nvim_strwidth(chars[8]),
    }
  end)()
  maybe_border_size.v = maybe_border_size.top + maybe_border_size.bottom
  maybe_border_size.h = maybe_border_size.left + maybe_border_size.right
  return maybe_border_size
end

---Get content size.
---@param contents string[]
---@param wrap boolean
---@param max_width integer
---@return deck.kit.Vim.FloatingWindow.ContentSize
function FloatingWindow.get_content_size(contents, wrap, max_width)
  local text_widths = {} ---@type integer[]

  --- compute content width.
  local content_width --[=[@as integer]=]
  do
    local max_text_width = 0
    for i, text in ipairs(contents) do
      text_widths[i] = vim.api.nvim_strwidth(text)
      max_text_width = math.max(max_text_width, text_widths[i])
    end
    content_width = max_text_width
  end

  --- compute content height.
  local content_height --[=[@as integer]=]
  do
    if wrap then
      local height = 0
      for _, text_width in ipairs(text_widths) do
        height = height + math.max(1, math.ceil(text_width / max_width))
      end
      content_height = height
    else
      content_height = #text_widths
    end
  end

  return {
    width = content_width,
    height = content_height,
  }
end

---Guess viewport information.
---@param params { border_size: deck.kit.Vim.FloatingWindow.BorderSize, content_size: deck.kit.Vim.FloatingWindow.ContentSize, max_outer_width: integer, max_outer_height: integer }
---@return { inner_width: integer, inner_height: integer, outer_width: integer, outer_height: integer, scrollbar: boolean }
function FloatingWindow.compute_restricted_size(params)
  local inner_size = {
    width = math.min(params.content_size.width, params.max_outer_width - params.border_size.h),
    height = math.min(params.content_size.height, params.max_outer_height - params.border_size.v),
  }

  local scrollbar = inner_size.height < params.content_size.height

  return {
    outer_width = inner_size.width + params.border_size.h + (scrollbar and 1 or 0),
    outer_height = inner_size.height + params.border_size.v,
    inner_width = inner_size.width,
    inner_height = inner_size.height,
    scrollbar = scrollbar,
  }
end

---Create window.
---@return deck.kit.Vim.FloatingWindow
function FloatingWindow.new()
  return setmetatable({
    _augroup = vim.api.nvim_create_augroup(('deck.kit.Vim.FloatingWindow:%s'):format(kit.unique_id()), {
      clear = true,
    }),
    _win_option = {},
    _buf_option = {},
    _buf = vim.api.nvim_create_buf(false, true),
    _scrollbar_track_buf = vim.api.nvim_create_buf(false, true),
    _scrollbar_thumb_buf = vim.api.nvim_create_buf(false, true),
  }, FloatingWindow)
end

---Set window option.
---@param key string
---@param value any
---@param kind? deck.kit.Vim.FloatingWindow.WindowKind
function FloatingWindow:set_win_option(key, value, kind)
  kind = kind or 'main'
  self._win_option[kind] = self._win_option[kind] or {}
  self._win_option[kind][key] = value
  self:_update_option()
end

---Get window option.
---@param key string
---@param kind? deck.kit.Vim.FloatingWindow.WindowKind
---@return any
function FloatingWindow:get_win_option(key, kind)
  kind = kind or 'main'
  local win = ({
    main = self._win,
    scrollbar_track = self._scrollbar_track_win,
    scrollbar_thumb = self._scrollbar_thumb_win,
  })[kind] --[=[@as integer]=]
  if not is_visible(win) then
    return self._win_option[kind] and self._win_option[kind][key]
  end
  return vim.api.nvim_get_option_value(key, { win = win }) or vim.api.nvim_get_option_value(key, { scope = 'global' })
end

---Set buffer option.
---@param key string
---@param value any
---@param kind? deck.kit.Vim.FloatingWindow.WindowKind
function FloatingWindow:set_buf_option(key, value, kind)
  kind = kind or 'main'
  self._buf_option[kind] = self._buf_option[kind] or {}
  self._buf_option[kind][key] = value
  self:_update_option()
end

---Get window option.
---@param key string
---@param kind? deck.kit.Vim.FloatingWindow.WindowKind
---@return any
function FloatingWindow:get_buf_option(key, kind)
  kind = kind or 'main'
  local buf = ({
    main = self._buf,
    scrollbar_track = self._scrollbar_track_buf,
    scrollbar_thumb = self._scrollbar_thumb_buf,
  })[kind] --[=[@as integer]=]
  if not buf then
    return self._buf_option[kind] and self._buf_option[kind][key]
  end
  return vim.api.nvim_get_option_value(key, { buf = buf }) or vim.api.nvim_get_option_value(key, { scope = 'global' })
end

---Returns the related bufnr.
---@param kind? deck.kit.Vim.FloatingWindow.WindowKind
---@return integer
function FloatingWindow:get_buf(kind)
  if kind == 'scrollbar_track' then
    return self._scrollbar_track_buf
  elseif kind == 'scrollbar_thumb' then
    return self._scrollbar_thumb_buf
  end
  return self._buf
end

---Returns the current win.
---@param kind? deck.kit.Vim.FloatingWindow.WindowKind
---@return integer?
function FloatingWindow:get_win(kind)
  if kind == 'scrollbar_track' then
    return self._scrollbar_track_win
  elseif kind == 'scrollbar_thumb' then
    return self._scrollbar_thumb_win
  end
  return self._win
end

---Show the window
---@param config deck.kit.Vim.FloatingWindow.Config
function FloatingWindow:show(config)
  local zindex = config.zindex or 1000

  self._win = show_or_move(self._win, self._buf, {
    row = config.row,
    col = config.col,
    width = config.width,
    height = config.height,
    anchor = config.anchor,
    style = config.style,
    border = config.border,
    zindex = zindex,
  })

  vim.api.nvim_clear_autocmds({ group = self._augroup })
  vim.api.nvim_create_autocmd('WinScrolled', {
    group = self._augroup,
    callback = function(event)
      if tostring(event.match) == tostring(self._win) then
        self:_update_scrollbar()
      end
    end,
  })

  self:_update_scrollbar()
  self:_update_option()
end

---Hide the window
function FloatingWindow:hide()
  vim.api.nvim_clear_autocmds({ group = self._augroup })
  hide(self._win)
  hide(self._scrollbar_track_win)
  hide(self._scrollbar_thumb_win)
end

---Scroll the window.
---@param delta integer
function FloatingWindow:scroll(delta)
  if not is_visible(self._win) then
    return
  end
  vim.api.nvim_win_call(self._win, function()
    local topline = vim.fn.getwininfo(self._win)[1].height
    topline = topline + delta
    topline = math.max(topline, 1)
    topline = math.min(topline, vim.api.nvim_buf_line_count(self._buf) - vim.api.nvim_win_get_height(self._win) + 1)
    vim.api.nvim_command(('normal! %szt'):format(topline))
  end)
end

---Returns true if the window is visible
function FloatingWindow:is_visible()
  return is_visible(self._win)
end

---Get window viewport.
---NOTE: this method can only be called if window is showing.
---@return deck.kit.Vim.FloatingWindow.Viewport
function FloatingWindow:get_viewport()
  if not self:is_visible() then
    error('this method can only be called if window is showing.')
  end

  local win_config = vim.api.nvim_win_get_config(self:get_win() --[[@as integer]])
  local border_size = FloatingWindow.get_border_size(win_config.border)
  local content_size = FloatingWindow.get_content_size(
    vim.api.nvim_buf_get_lines(self:get_buf(), 0, -1, false),
    self:get_win_option('wrap'),
    win_config.width
  )
  local scrollbar = win_config.height < content_size.height

  local ui_width = border_size.left + border_size.right + (scrollbar and 1 or 0)
  local ui_height = border_size.top + border_size.bottom
  return {
    row = win_config.row,
    col = win_config.col,
    inner_width = win_config.width,
    inner_height = win_config.height,
    outer_width = win_config.width + ui_width,
    outer_height = win_config.height + ui_height,
    ui_width = ui_width,
    ui_height = ui_height,
    border_size = border_size,
    content_size = content_size,
    scrollbar = scrollbar,
    border = win_config.border,
  }
end

---Update scrollbar.
function FloatingWindow:_update_scrollbar()
  if is_visible(self._win) then
    local win_config = vim.api.nvim_win_get_config(self._win)
    local border_size = FloatingWindow.get_border_size(win_config.border)

    local viewport = self:get_viewport()
    if viewport.scrollbar then
      do
        self._scrollbar_track_win = show_or_move(self._scrollbar_track_win, self._scrollbar_track_buf, {
          row = win_config.row + border_size.top,
          col = win_config.col + viewport.outer_width - 1,
          width = 1,
          height = viewport.inner_height,
          style = 'minimal',
          zindex = win_config.zindex + 1,
        })
      end
      do
        local topline = vim.fn.getwininfo(self._win)[1].topline
        local ratio = topline / (viewport.content_size.height - viewport.inner_height)
        local thumb_height = math.ceil(viewport.inner_height / viewport.content_size.height * viewport.inner_height)
        local thumb_row = math.floor((viewport.inner_height - thumb_height) * ratio)
        thumb_row = math.min(viewport.inner_height - thumb_height, thumb_row)
        self._scrollbar_thumb_win = show_or_move(self._scrollbar_thumb_win, self._scrollbar_thumb_buf, {
          row = win_config.row + border_size.top + thumb_row,
          col = win_config.col + viewport.outer_width - 1,
          width = 1,
          height = thumb_height,
          style = 'minimal',
          zindex = win_config.zindex + 2,
        })
      end
      return
    end
  end
  hide(self._scrollbar_track_win)
  hide(self._scrollbar_thumb_win)
end

---Update options.
function FloatingWindow:_update_option()
  -- update buf.
  for kind, buf in pairs({
    main = self._buf,
    scrollbar_track = self._scrollbar_track_buf,
    scrollbar_thumb = self._scrollbar_thumb_buf,
  }) do
    for k, v in pairs(self._buf_option[kind] or {}) do
      if vim.api.nvim_get_option_value(k, { buf = buf }) ~= v then
        vim.api.nvim_set_option_value(k, v, { buf = buf })
      end
    end
  end

  -- update win.
  for kind, win in pairs({
    main = self._win,
    scrollbar_track = self._scrollbar_track_win,
    scrollbar_thumb = self._scrollbar_thumb_win,
  }) do
    if is_visible(win) then
      for k, v in pairs(self._win_option[kind] or {}) do
        if vim.api.nvim_get_option_value(k, { win = win }) ~= v then
          vim.api.nvim_set_option_value(k, v, { win = win })
        end
      end
    end
  end
end

return FloatingWindow
