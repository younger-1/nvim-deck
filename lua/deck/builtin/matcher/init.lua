local kit = require('deck.kit')
local Character = require('deck.kit.App.Character')
local matcher = {}

local Empty = {}

---Search query text in label text.
---@param label string
---@param query string
---@return integer?
local function search_ignorecase(label, query)
  local query_head_char = query:byte(1)

  local label_len = #label
  local query_len = #query
  local label_i = 1
  local query_i = 1
  local memo_i = nil --[[@as integer?]]
  while label_i <= label_len do
    if Character.match_ignorecase(label:byte(label_i), query_head_char) then
      label_i = label_i + 1
      query_i = query_i + 1
      memo_i = nil
      while query_i <= query_len and label_i <= label_len do
        local label_char = label:byte(label_i)
        local query_char = query:byte(query_i)
        if not Character.match_ignorecase(label_char, query_char) then
          break
        end
        if not memo_i and query_char == query_head_char then
          memo_i = label_i
        end

        label_i = label_i + 1
        query_i = query_i + 1
      end
      if query_i > query_len then
        return label_i - query_len
      end
      label_i = memo_i or label_i
      query_i = 1
    else
      label_i = label_i + 1
    end
  end
  return nil
end

-- matcher.default.
do
  local parse_query_cache = {
    query = '',
    parsed = {},
    queries = {},
  }

  ---@return { negated: boolean, query: string }[]
  local function parse_query(query)
    if parse_query_cache.query ~= query then
      parse_query_cache.query = query

      -- create parsed.
      kit.clear(parse_query_cache.parsed)
      local i = 1
      local chunk = {}
      while i <= #query do
        local c = query:sub(i, i)
        if c == '\\' then
          table.insert(chunk, query:sub(i + 1, i + 1))
          i = i + 1
        elseif c ~= ' ' then
          table.insert(chunk, c)
        elseif #chunk > 0 then
          table.insert(parse_query_cache.parsed, table.concat(chunk, ''))
          chunk = {}
        end
        i = i + 1
      end
      if #chunk > 0 then
        table.insert(parse_query_cache.parsed, table.concat(chunk, ''))
      end

      -- create queries.
      kit.clear(parse_query_cache.queries)
      for _, q in ipairs(parse_query_cache.parsed) do
        if q:sub(1, 1) == '!' then
          table.insert(parse_query_cache.queries, {
            negated = true,
            query = q:sub(2),
          })
        else
          table.insert(parse_query_cache.queries, {
            negated = false,
            query = q,
          })
        end
      end
    end
    return parse_query_cache.queries
  end

  matcher.default = {
    ---@type deck.Matcher.MatchFunction
    match = function(query, text)
      if query == '' then
        return 1
      end

      local matched = true
      for _, q in ipairs(parse_query(query)) do
        if q.negated then
          if q.query ~= '' and search_ignorecase(text, q.query) then
            matched = false
            break
          end
        elseif q.query ~= '' then
          local idx = search_ignorecase(text, q.query)
          if not idx then
            matched = false
            break
          end
        end
        if not matched then
          return 0
        end
      end
      return matched and 1 or 0
    end,
    ---@type deck.Matcher.DecorFunction
    decor = function(query, text)
      if query == '' then
        return Empty
      end

      local matches = {}
      for _, q in ipairs(parse_query(query)) do
        if not q.negated and q.query ~= '' then
          local idx = search_ignorecase(text, q.query)
          if idx then
            table.insert(matches, { idx - 1, idx - 1 + #q.query })
          end
        end
      end
      return matches
    end,
  }
end

-- matcher.fuzzy.
do
  matcher.fuzzy = {
    ---@type deck.Matcher.MatchFunction
    match = function(query, text)
      return vim.fn.matchfuzzypos({ text }, query)[3][1] or 0
    end,
    ---@type deck.Matcher.DecorFunction
    decor = function(query, text)
      local chars = vim.fn.matchfuzzypos({ text }, query)[2][1] or {}
      local matches = {}
      for _, char in ipairs(chars) do
        if matches[#matches] and matches[#matches][2] == char - 1 then
          matches[#matches][2] = char + 1
        else
          table.insert(matches, { char, char + 1 })
        end
      end
      return matches
    end,
  }
end

return matcher
